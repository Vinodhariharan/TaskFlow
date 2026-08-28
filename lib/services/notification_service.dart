import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

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
    ),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _lastScheduleError;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  int _idFor(String taskId) => taskId.hashCode & 0x7fffffff;

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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
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
      'TaskFlow test',
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
      'TaskFlow scheduled test',
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
