import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

/// Wraps flutter_local_notifications for task reminders. One scheduled
/// notification per task at most, keyed by a stable int id derived from the
/// task's uuid — rescheduled (cancel + re-add) whenever the task's title,
/// reminder time, or scheduled date changes, and re-armed for every
/// upcoming reminder on app start (device reboots can clear pending
/// exact-alarm-based notifications; a boot-time re-registration receiver
/// would cover that too, but isn't set up here — reopening the app is
/// enough to catch up in the meantime).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'task_reminders';
  static const _channelName = 'Task reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  int _idFor(String taskId) => taskId.hashCode & 0x7fffffff;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to whatever the default location already is (UTC) rather
      // than crashing startup over a timezone lookup failure.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  /// Requests the Android 13+ notification permission and, separately, the
  /// exact-alarm permission (which opens a system settings screen if not
  /// already granted). Call this the first time a user turns a reminder on,
  /// not unconditionally at startup. Swallows failures — a denied or
  /// unavailable permission request should never block the caller (e.g. the
  /// Add Task sheet) from continuing.
  Future<void> requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
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
      final moment = DateTime(
          base.year, base.month, base.day, task.reminderHour!, task.reminderMinute!);
      return moment.isAfter(now) ? moment : null;
    }
    // No scheduled date: the reminder is implicitly "today at this time".
    // If that moment has already passed today, roll it to tomorrow instead
    // of silently scheduling nothing — picking a time earlier than now
    // otherwise looks identical to a reminder that was never set at all.
    var moment =
        DateTime(now.year, now.month, now.day, task.reminderHour!, task.reminderMinute!);
    if (!moment.isAfter(now)) {
      moment = moment.add(const Duration(days: 1));
    }
    return moment;
  }

  /// Cancels any existing notification for [task], then schedules a fresh
  /// one if it currently has a reminder set for a moment still in the
  /// future. Safe to call after any edit — it's always cancel-then-add.
  /// Failures (denied permissions, plugin/platform errors) are swallowed so
  /// a broken reminder never blocks saving the task itself.
  Future<void> scheduleForTask(Task task) async {
    try {
      if (!_initialized) await init();
      final id = _idFor(task.id);
      await _plugin.cancel(id);
      if (task.isCompleted) return;
      final moment = _nextReminderMoment(task);
      if (moment == null) return;

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactNotifications() ?? false;

      await _plugin.zonedSchedule(
        id,
        task.title,
        task.note != null && task.note!.isNotEmpty
            ? task.note
            : 'Task reminder',
        tz.TZDateTime.from(moment, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Reminders for tasks you\'ve set a time on',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // A missing permission or platform error shouldn't stop the task
      // itself from saving — the reminder just won't fire this time.
    }
  }

  Future<void> cancelForTask(String taskId) async {
    try {
      if (!_initialized) await init();
      await _plugin.cancel(_idFor(taskId));
    } catch (_) {
      // Best-effort — nothing useful to do if cancellation fails.
    }
  }

  /// Re-schedules every upcoming reminder from scratch — call once on app
  /// start so reminders catch up after a device reboot or reinstall.
  Future<void> rescheduleAll(List<Task> tasks) async {
    if (!_initialized) await init();
    for (final task in tasks) {
      if (task.hasReminder && !task.isCompleted) {
        await scheduleForTask(task);
      }
    }
  }
}
