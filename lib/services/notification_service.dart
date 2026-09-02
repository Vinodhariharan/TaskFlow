import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/habit.dart';
import '../models/task.dart';
import '../app_info.dart';

/// A snapshot of everything that decides whether a reminder can actually
/// fire, so Settings can show it instead of the user guessing why nothing
/// arrived.
class NotificationDiagnostics {
  final bool? notificationsEnabled;
  final bool? canScheduleExact;
  final String timeZone;
  final List<PendingNotificationRequest> pending;

  /// Why reading the pending list failed, if it did — kept separate so one
  /// broken probe doesn't blank out the rest of the report.
  final String? pendingError;

  /// The most recent error swallowed by scheduling/cancelling. Scheduling
  /// deliberately never rethrows (a broken reminder must not block saving a
  /// task), which is exactly how a release-only R8/Gson crash stayed
  /// invisible — so it gets surfaced here instead.
  final String? lastScheduleError;

  const NotificationDiagnostics({
    required this.notificationsEnabled,
    required this.canScheduleExact,
    required this.timeZone,
    required this.pending,
    this.pendingError,
    this.lastScheduleError,
  });
}

/// Wraps flutter_local_notifications for task reminders. One scheduled
/// notification per task at most, keyed by a stable int id derived from the
/// task's uuid — rescheduled (cancel + re-add) whenever the task's title,
/// reminder time, or scheduled date changes.
///
/// Delivery relies on two things declared in the app's AndroidManifest (not
/// the plugin's): the ScheduledNotificationReceiver, which turns the fired
/// alarm into a shown notification, and USE_EXACT_ALARM, without which
/// Android 14+ downgrades every reminder to a Doze-deferrable inexact alarm.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'task_reminders';
  static const _channelName = 'Task reminders';
  static const _channelDescription = 'Reminders for tasks you\'ve set a time on';

  /// Fixed ids for the Settings diagnostics, kept well clear of the hashed
  /// per-task ids so a test can never collide with a real reminder.
  static const _testNowId = 1;
  static const _testScheduledId = 2;

  static const _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
  );

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      // Named here too: the per-notification icon overrides the one from
      // initialize(), and leaving it unset has been known to fall back to
      // the app icon on some OEM builds.
      icon: '@drawable/ic_stat_notify',
    ),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _lastScheduleError;

  /// Called with a task id when a reminder is tapped. Set by the app shell so
  /// the tap can open that task's page. Stored rather than hard-wired to a
  /// navigator so this service stays free of UI imports.
  void Function(String taskId)? onReminderTapped;

  /// A tap that arrived before [onReminderTapped] was wired up — i.e. the app
  /// was launched from a cold start *by* the notification, so the callback
  /// didn't exist yet. Held here and replayed by [consumePendingTap].
  String? _pendingTaskId;

  void _handleTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final handler = onReminderTapped;
    if (handler != null) {
      handler(payload);
    } else {
      _pendingTaskId = payload;
    }
  }

  /// Returns the task id of a reminder tapped while the app was not running,
  /// clearing it so it's only ever acted on once. Covers both a tap that
  /// arrived before the handler was set and the launch-details path Android
  /// uses when the process was started by the notification.
  Future<String?> consumePendingTap() async {
    if (_pendingTaskId != null) {
      final id = _pendingTaskId;
      _pendingTaskId = null;
      return id;
    }
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final payload = details?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) return payload;
      }
    } catch (_) {
      // Not worth failing startup over.
    }
    return null;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  int _idFor(String taskId) => taskId.hashCode & 0x7fffffff;

  /// Habit notification ids live in their own namespace, derived from a
  /// prefixed string so a habit and a task can never land on the same id
  /// even if their uuids somehow collided.
  ///
  /// The low three bits are reserved for the weekday, because a habit
  /// scheduled on specific days needs one repeating notification per day
  /// (Android repeats weekly on a given weekday, or daily, but can't express
  /// "Mon/Wed/Fri" in a single alarm). Weekday 0 means the daily case.
  int _idForHabit(String habitId, {int weekday = 0}) =>
      (('habit:$habitId'.hashCode & 0x7ffffff8)) + (weekday & 0x7);

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to whatever the default location already is (UTC) rather
      // than crashing startup over a timezone lookup failure. Scheduling
      // still uses the correct absolute instant either way.
    }
    await _plugin.initialize(
      const InitializationSettings(
        // A dedicated white silhouette, not the launcher icon. Android
        // masks the status bar icon to its alpha and tints it, so a
        // full-colour launcher icon — which is what this passed until now —
        // arrives as a featureless blob.
        android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _handleTap(response.payload),
    );
    // Create the channel explicitly rather than relying on it being created
    // lazily at first show — otherwise its importance (and so whether it
    // makes a sound / appears as a heads-up) is whatever the first
    // notification happened to ask for.
    try {
      await _android?.createNotificationChannel(_channel);
    } catch (_) {
      // Pre-Android-8 has no channels; nothing to do.
    }
    _initialized = true;
  }

  /// Requests the Android 13+ notification permission, and the exact-alarm
  /// permission if it somehow isn't already held. Safe to call repeatedly —
  /// Android only shows each prompt once. Swallows failures so a denied or
  /// unavailable request never blocks the caller.
  Future<void> requestPermissions() async {
    try {
      await init();
      final android = _android;
      if (android == null) return;
      await android.requestNotificationsPermission();
      final canExact = await android.canScheduleExactNotifications() ?? false;
      if (!canExact) {
        await android.requestExactAlarmsPermission();
      }
    } catch (_) {
      // Permission dialogs can be unavailable on some OEM builds; scheduling
      // itself still falls back to inexact alarms when exact isn't granted.
    }
  }

  DateTime? _nextReminderMoment(Task task) {
    if (!task.hasReminder) return null;
    final now = DateTime.now();
    if (task.scheduledDate != null) {
      final base = task.scheduledDate!;
      final moment = DateTime(base.year, base.month, base.day,
          task.reminderHour!, task.reminderMinute!);
      return moment.isAfter(now) ? moment : null;
    }
    // No scheduled date: the reminder is implicitly "today at this time".
    // If that moment has already passed today, roll it to tomorrow instead
    // of silently scheduling nothing — picking a time earlier than now
    // otherwise looks identical to a reminder that was never set at all.
    var moment = DateTime(
        now.year, now.month, now.day, task.reminderHour!, task.reminderMinute!);
    if (!moment.isAfter(now)) {
      moment = moment.add(const Duration(days: 1));
    }
    return moment;
  }

  /// Cancels any existing notification for [task], then schedules a fresh
  /// one if it currently has a reminder set for a moment still in the
  /// future. Safe to call after any edit — it's always cancel-then-add.
  /// Failures are swallowed so a broken reminder never blocks saving the
  /// task itself.
  Future<void> scheduleForTask(Task task) async {
    try {
      await init();
      final id = _idFor(task.id);
      await _plugin.cancel(id);
      if (task.isCompleted) return;
      final moment = _nextReminderMoment(task);
      if (moment == null) return;

      final canExact = await _android?.canScheduleExactNotifications() ?? false;

      await _plugin.zonedSchedule(
        id,
        task.title,
        task.note != null && task.note!.isNotEmpty
            ? task.note
            : 'Task reminder',
        tz.TZDateTime.from(moment, tz.local),
        _details,
        androidScheduleMode: canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // Carries the task id so tapping the reminder can open that task.
        payload: task.id,
      );
      _lastScheduleError = null;
    } catch (e) {
      // A missing permission or platform error shouldn't stop the task
      // itself from saving — the reminder just won't fire this time. Record
      // it though: swallowing silently is how a release-only R8/Gson crash
      // went unnoticed for several builds.
      _lastScheduleError = e.toString();
    }
  }

  Future<void> cancelForTask(String taskId) async {
    try {
      await init();
      await _plugin.cancel(_idFor(taskId));
    } catch (e) {
      _lastScheduleError = e.toString();
    }
  }

  /// Re-schedules every upcoming reminder from scratch — call once on app
  /// start so reminders catch up after a reinstall or a permission finally
  /// being granted.
  Future<void> rescheduleAll(List<Task> tasks) async {
    await init();
    for (final task in tasks) {
      if (task.hasReminder && !task.isCompleted) {
        await scheduleForTask(task);
      }
    }
  }

  // ── Habit reminders ───────────────────────────────────────────────────────

  /// Habit reminders repeat rather than firing once, which is the whole
  /// difference from a task: a task's reminder is for a specific date, a
  /// habit's is "every day at 7am" (or every Mon/Wed/Fri).
  ///
  /// Android can express "daily at a time" or "weekly on a weekday at a
  /// time", but not an arbitrary set of days, so a habit on specific days
  /// gets one repeating notification per day. Always cancel-then-add, so
  /// editing a habit's days never leaves an orphaned alarm behind.
  Future<void> scheduleForHabit(Habit habit) async {
    try {
      await init();
      await cancelForHabit(habit.id);
      if (habit.archived || !habit.hasReminder) return;

      final canExact = await _android?.canScheduleExactNotifications() ?? false;
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      final body = habit.targetCount > 1
          ? 'Time for ${habit.name} — ${habit.targetCount}× today'
          : 'Time for ${habit.name}';

      if (habit.activeWeekdays.isEmpty) {
        await _plugin.zonedSchedule(
          _idForHabit(habit.id),
          habit.name,
          body,
          _nextInstanceOf(habit.reminderHour!, habit.reminderMinute!),
          _details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'habit:${habit.id}',
        );
        return;
      }

      for (final weekday in habit.activeWeekdays) {
        await _plugin.zonedSchedule(
          _idForHabit(habit.id, weekday: weekday),
          habit.name,
          body,
          _nextInstanceOfWeekday(
              weekday, habit.reminderHour!, habit.reminderMinute!),
          _details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'habit:${habit.id}',
        );
      }
      _lastScheduleError = null;
    } catch (e) {
      // As with tasks: a reminder that won't schedule must never stop the
      // habit itself from being saved.
      _lastScheduleError = e.toString();
    }
  }

  /// Clears the daily alarm and all seven possible weekday alarms, so a
  /// habit that switched from Mon/Wed/Fri to daily leaves nothing stale.
  Future<void> cancelForHabit(String habitId) async {
    try {
      await init();
      await _plugin.cancel(_idForHabit(habitId));
      for (var weekday = 1; weekday <= 7; weekday++) {
        await _plugin.cancel(_idForHabit(habitId, weekday: weekday));
      }
    } catch (e) {
      _lastScheduleError = e.toString();
    }
  }

  Future<void> rescheduleAllHabits(List<Habit> habits) async {
    await init();
    for (final habit in habits) {
      if (habit.hasReminder && !habit.archived) {
        await scheduleForHabit(habit);
      }
    }
  }

  /// The next time today's clock hits [hour]:[minute], rolling to tomorrow
  /// if it's already gone.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// The next [weekday] (1 = Monday .. 7 = Sunday) at [hour]:[minute].
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var next = _nextInstanceOf(hour, minute);
    while (next.weekday != weekday) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  // ── Diagnostics (Settings > Notifications) ────────────────────────────────

  /// Each probe is isolated: reading the pending list is the one that failed
  /// under R8, and when it threw it took the whole report down with it,
  /// hiding the permission answers that were actually fine.
  Future<NotificationDiagnostics> diagnostics() async {
    await init();
    final android = _android;

    bool? enabled;
    try {
      enabled = await android?.areNotificationsEnabled();
    } catch (_) {
      enabled = null;
    }

    bool? exact;
    try {
      exact = await android?.canScheduleExactNotifications();
    } catch (_) {
      exact = null;
    }

    var pending = <PendingNotificationRequest>[];
    String? pendingError;
    try {
      pending = await _plugin.pendingNotificationRequests();
    } catch (e) {
      pendingError = e.toString();
    }

    return NotificationDiagnostics(
      notificationsEnabled: enabled,
      canScheduleExact: exact,
      timeZone: tz.local.name,
      pending: pending,
      pendingError: pendingError,
      lastScheduleError: _lastScheduleError,
    );
  }

  /// Shows a notification immediately. Deliberately does NOT swallow errors —
  /// this exists to surface what's wrong, so the caller can display it.
  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      _testNowId,
      '$kAppName test',
      'Notifications are working. Scheduled reminders are separate — use the timed test for those.',
      _details,
    );
  }

  /// Schedules a notification a short delay out, through the exact same
  /// path a real reminder uses, and reports back when it should arrive and
  /// whether it got an exact alarm.
  Future<({DateTime at, bool exact})> scheduleTestNotification({
    Duration delay = const Duration(minutes: 1),
  }) async {
    await init();
    final when = DateTime.now().add(delay);
    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      _testScheduledId,
      '$kAppName scheduled test',
      'This is what a task reminder will look like.',
      tz.TZDateTime.from(when, tz.local),
      _details,
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return (at: when, exact: canExact);
  }
}
