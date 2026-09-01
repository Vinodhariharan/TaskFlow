import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/habit.dart';
import '../models/habit_stats.dart';
import '../screens/expense_widgets.dart' show formatCurrency;
import 'currency_settings.dart';
import 'expense_service.dart';
import 'habit_service.dart';
import 'settings_service.dart';
import 'task_service.dart';

/// Handles a widget button press that must NOT open the app — ticking a task
/// off from the Tasks widget, or logging the tracked habit from the Habit
/// widget.
///
/// This runs in a separate background isolate that home_widget spins up, so
/// it can only rely on plugins (SharedPreferences works; anything UI-bound
/// does not). It deliberately goes through the same TaskService the app uses
/// rather than touching stored JSON directly, so completion keeps all its
/// real behaviour — including rolling a recurring task forward to its next
/// occurrence instead of just checking it off.
///
/// Must stay a top-level function with the vm:entry-point pragma: it's looked
/// up by callback handle at runtime, so nothing references it statically and
/// tree shaking would otherwise drop it from release builds.
@pragma('vm:entry-point')
Future<void> widgetInteractionCallback(Uri? uri) async {
  if (uri == null) return;
  final id = uri.queryParameters['id'];
  switch (uri.host) {
    case 'toggle':
      if (id == null || id.isEmpty) return;
      await TaskService().toggleComplete(id);
      // Re-render straight away so the row disappears under the finger
      // rather than waiting for the app to next open.
      await WidgetService.instance.refresh();
    case 'habit':
      if (id == null || id.isEmpty) return;
      final habit = await HabitService().getHabitById(id);
      if (habit == null) return;
      // Increment, never toggle: HabitService.increment clamps at the
      // target, so a second tap on a finished habit is a harmless no-op.
      // Nothing on a home screen should be able to wipe a day's 8/8 by
      // being brushed with a thumb — undoing is done in the app, where
      // there's a minus button and something to read.
      await HabitService().increment(habit);
      await WidgetService.instance.refresh();
  }
}

/// Pushes a small summary of tasks, spending and one tracked habit into the
/// Android home screen widgets.
///
/// The widgets are deliberately read-only snapshots: the native side just
/// renders whatever strings are stored here, so all the formatting and
/// currency handling stays in Dart where it already exists, and the Kotlin
/// stays simple enough to be obviously correct without a device to test on.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _taskProvider = 'TaskWidgetProvider';
  static const _expenseProvider = 'ExpenseWidgetProvider';
  static const _habitProvider = 'HabitWidgetProvider';

  /// How many days of history the habit widget's dot strip shows. Matches
  /// the seven ImageViews in habit_widget.xml.
  @visibleForTesting
  static const habitWeekDays = 7;

  /// How many task titles each widget lists. Matches the fixed number of
  /// TextViews in task_widget.xml — a list would need a RemoteViewsService,
  /// which is a lot of machinery for three lines.
  static const _taskLineCount = 3;

  final _taskService = TaskService();
  final _expenseService = ExpenseService();
  final _habitService = HabitService();
  final _settingsService = SettingsService();

  bool _refreshing = false;
  bool _again = false;

  /// Recomputes every widget. Safe to call from anywhere, as often as you
  /// like — overlapping calls collapse into one trailing refresh rather than
  /// piling up reads of the same data.
  Future<void> refresh() async {
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _again = false;
        await _refreshTasks();
        await _refreshExpenses();
        await _refreshHabit();
      } while (_again);
    } catch (_) {
      // A widget that can't update is not worth breaking the app over.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshTasks() async {
    final today = await _taskService.getTodayTasks();
    final pending = today.where((t) => !t.isCompleted).toList();
    final done = today.length - pending.length;

    await HomeWidget.saveWidgetData<String>(
      'task_count',
      pending.isEmpty ? 'All clear' : '${pending.length} to do',
    );
    await HomeWidget.saveWidgetData<String>(
      'task_progress',
      today.isEmpty ? 'Nothing scheduled' : '$done of ${today.length} done',
    );

    for (var i = 0; i < _taskLineCount; i++) {
      // Empty string rather than null so the native side can hide the row by
      // testing for blank, without needing a separate "how many" key.
      await HomeWidget.saveWidgetData<String>(
        'task_$i',
        i < pending.length ? pending[i].title : '',
      );
      // The id behind each row, so its tick button and its "open this task"
      // tap can both address the right task.
      await HomeWidget.saveWidgetData<String>(
        'task_${i}_id',
        i < pending.length ? pending[i].id : '',
      );
    }

    await HomeWidget.updateWidget(name: _taskProvider, androidName: _taskProvider);
  }

  Future<void> _refreshExpenses() async {
    await CurrencySettings.instance.load();
    final kpis = await _expenseService.getKpis();

    await HomeWidget.saveWidgetData<String>(
      'expense_month',
      formatCurrency(kpis.thisMonth),
    );
    await HomeWidget.saveWidgetData<String>(
      'expense_30d',
      formatCurrency(kpis.last30Days),
    );

    await HomeWidget.updateWidget(
        name: _expenseProvider, androidName: _expenseProvider);
  }

  /// Renders whichever habit the widget is set to track. Everything the
  /// native side draws is decided here — including the seven-day strip,
  /// which arrives as a seven-character string rather than seven keys.
  Future<void> _refreshHabit() async {
    final habits = await _habitService.getHabits();
    final chosenId = await _settingsService.getWidgetHabitId();
    // Falls back to the first habit so a freshly-placed widget shows
    // something real before anyone has been to the detail screen to pick.
    final habit = habits.where((h) => h.id == chosenId).firstOrNull ??
        habits.firstOrNull;

    if (habit == null) {
      await _saveHabitData(
        id: '',
        name: 'No habits yet',
        progress: 'Tap to add one',
        streak: '',
        color: '#FF6C63FF',
        week: 's' * habitWeekDays,
        action: '',
      );
      return;
    }

    final now = DateTime.now();
    final log = await _habitService.logFor(habit.id);
    final count = log[habitDateKey(now)] ?? 0;
    final target = habit.targetCount < 1 ? 1 : habit.targetCount;
    final scheduledToday = habit.isActiveOn(now);
    final done = isDoneOn(habit, log, now);
    final streak = currentStreak(habit, log, now: now);

    await _saveHabitData(
      id: habit.id,
      name: habit.name,
      progress: habitProgressLine(habit, count, target, scheduledToday, done),
      streak: streak == 0
          ? 'No streak yet'
          : '$streak day${streak == 1 ? '' : 's'} in a row',
      color: '#${habit.color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      week: habitWeekStrip(habit, log, now),
      // Nothing to tap on a day the habit isn't expected — the button is
      // hidden rather than logging a count against a rest day.
      action: !scheduledToday ? '' : (done ? '✓' : '+'),
    );
  }

  @visibleForTesting
  static String habitProgressLine(
      Habit habit, int count, int target, bool scheduled, bool done) {
    if (!scheduled) return 'Rest day';
    if (habit.isSimple) return done ? 'Done today' : 'Not done yet';
    final unit = habit.unit == null ? '' : ' ${habit.unit}';
    return '$count of $target$unit';
  }

  /// The last [habitWeekDays] days, oldest first, one character each:
  /// `d` done, `m` missed, `o` still open (only ever today), `s` skipped
  /// because the habit isn't scheduled that day.
  @visibleForTesting
  static String habitWeekStrip(
      Habit habit, Map<String, int> log, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final created = DateTime(habit.createdDate.year, habit.createdDate.month,
        habit.createdDate.day);
    final buffer = StringBuffer();
    for (var i = habitWeekDays - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      if (!habit.isActiveOn(day) || day.isBefore(created)) {
        // Days before the habit existed are drawn like rest days: faint,
        // and never as a miss.
        buffer.write('s');
      } else if (isDoneOn(habit, log, day)) {
        buffer.write('d');
      } else {
        buffer.write(day == today ? 'o' : 'm');
      }
    }
    return buffer.toString();
  }

  Future<void> _saveHabitData({
    required String id,
    required String name,
    required String progress,
    required String streak,
    required String color,
    required String week,
    required String action,
  }) async {
    await HomeWidget.saveWidgetData<String>('habit_id', id);
    await HomeWidget.saveWidgetData<String>('habit_name', name);
    await HomeWidget.saveWidgetData<String>('habit_progress', progress);
    await HomeWidget.saveWidgetData<String>('habit_streak', streak);
    await HomeWidget.saveWidgetData<String>('habit_color', color);
    await HomeWidget.saveWidgetData<String>('habit_week', week);
    await HomeWidget.saveWidgetData<String>('habit_action', action);
    await HomeWidget.updateWidget(
        name: _habitProvider, androidName: _habitProvider);
  }
}
