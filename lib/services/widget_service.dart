import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/habit.dart';
import '../models/habit_stats.dart';
import '../screens/expense_widgets.dart' show formatCurrency;
import 'currency_settings.dart';
import 'expense_service.dart';
import 'habit_service.dart';
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

  final _taskService = TaskService();
  final _expenseService = ExpenseService();
  final _habitService = HabitService();

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

    // Every outstanding task, not a fixed few: the widget scrolls through
    // them via a RemoteViewsService, so there's no row count to match. JSON
    // because Android parses it with the framework's own org.json, leaving
    // no hand-rolled separator to get wrong on a task titled with a stray
    // character.
    await HomeWidget.saveWidgetData<String>(
      'task_list',
      jsonEncode([
        for (final task in pending) {'id': task.id, 'title': task.title},
      ]),
    );

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

  /// Writes one entry per habit, keyed by habit id, plus the list the
  /// configuration activity offers when a widget is placed.
  ///
  /// Per-habit keys rather than one set of "the chosen habit" keys, because
  /// each placed widget picks its own habit: the provider is handed a widget
  /// id, looks up which habit that widget was configured with, and reads
  /// that habit's entry. Everything it draws — including the seven-day strip,
  /// which crosses as a seven-character string — is decided here, so the
  /// streak rules stay in habit_stats.dart with nothing reimplemented in
  /// Kotlin.
  Future<void> _refreshHabit() async {
    final habits = await _habitService.getHabits();
    final now = DateTime.now();

    for (final habit in habits) {
      final log = await _habitService.logFor(habit.id);
      final count = log[habitDateKey(now)] ?? 0;
      final target = habit.targetCount < 1 ? 1 : habit.targetCount;
      final scheduled = habit.isActiveOn(now);
      final done = isDoneOn(habit, log, now);
      final streak = currentStreak(habit, log, now: now);

      await HomeWidget.saveWidgetData<String>(
          'habit_${habit.id}_name', habit.name);
      await HomeWidget.saveWidgetData<String>(
        'habit_${habit.id}_status',
        habitStatusLine(habit, count, target, scheduled, done, streak),
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_${habit.id}_color',
        '#${habit.color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      );
      await HomeWidget.saveWidgetData<String>(
          'habit_${habit.id}_week', habitWeekStrip(habit, log, now));
      // Nothing to tap on a day the habit isn't expected — the button is
      // hidden rather than logging a count against a rest day.
      await HomeWidget.saveWidgetData<String>(
        'habit_${habit.id}_action',
        !scheduled ? '' : (done ? '✓' : '+'),
      );
    }

    // What the configuration activity lists. JSON because Android parses it
    // with the framework's own org.json, so there's no hand-rolled
    // separator to get wrong on a habit named with a stray character.
    await HomeWidget.saveWidgetData<String>(
      'habit_options',
      jsonEncode([
        for (final habit in habits) {'id': habit.id, 'name': habit.name},
      ]),
    );
    // What a widget shows before it's been configured, or after the habit it
    // was pointed at has been deleted. Empty when there are no habits, which
    // is how the widget knows to say so.
    await HomeWidget.saveWidgetData<String>(
      'habit_default_id',
      habits.isEmpty ? '' : habits.first.id,
    );

    await HomeWidget.updateWidget(
        name: _habitProvider, androidName: _habitProvider);
  }

  /// The one line of detail the compact widget has room for: where today
  /// stands, and the streak behind it.
  @visibleForTesting
  static String habitStatusLine(Habit habit, int count, int target,
      bool scheduled, bool done, int streak) {
    final progress = habitProgressLine(habit, count, target, scheduled, done);
    if (streak == 0) return progress;
    return '$progress · $streak day${streak == 1 ? '' : 's'}';
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

}
