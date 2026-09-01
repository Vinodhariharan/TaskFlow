import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/habit.dart';
import 'package:taskflow/models/habit_stats.dart';
import 'package:taskflow/services/widget_service.dart';

/// The habit widget's seven-day strip and progress line are decided in Dart
/// and drawn blindly by HabitWidgetProvider, so the rules only exist here.
/// A wrong character means a wrong dot on someone's home screen with nothing
/// to catch it on the native side.
void main() {
  // A Wednesday, so a weekday-only habit's window spans a real weekend.
  final wednesday = DateTime(2026, 9, 2);

  Habit habitOf({
    int targetCount = 1,
    Set<int>? activeWeekdays,
    DateTime? created,
    String? unit,
  }) =>
      Habit(
        id: 'h1',
        name: 'Read',
        createdDate: created ?? DateTime(2026, 1, 1),
        targetCount: targetCount,
        unit: unit,
        activeWeekdays: activeWeekdays,
      );

  Map<String, int> logOf(List<DateTime> days, {int count = 1}) =>
      {for (final d in days) habitDateKey(d): count};

  group('week strip', () {
    test('is one character per day, oldest first', () {
      final strip = WidgetService.habitWeekStrip(habitOf(), {}, wednesday);
      expect(strip.length, WidgetService.habitWeekDays);
    });

    test('marks done days, missed days, and today still open', () {
      // Done: 6 and 4 days ago. Everything else missed; today untouched.
      final log = logOf([
        wednesday.subtract(const Duration(days: 6)),
        wednesday.subtract(const Duration(days: 4)),
      ]);
      expect(WidgetService.habitWeekStrip(habitOf(), log, wednesday),
          'dmdmmmo');
    });

    test('today reads as done once it is done, not as open', () {
      final log = logOf([wednesday]);
      expect(WidgetService.habitWeekStrip(habitOf(), log, wednesday).endsWith('d'),
          isTrue);
    });

    test('rest days are skipped, never shown as misses', () {
      // Mon-Fri only. The window ending Wednesday covers Thu Fri Sat Sun Mon
      // Tue Wed, so positions 2 and 3 are the weekend.
      final strip = WidgetService.habitWeekStrip(
          habitOf(activeWeekdays: {1, 2, 3, 4, 5}), {}, wednesday);
      expect(strip, 'mmssmmo');
    });

    test('days before the habit existed are not misses either', () {
      // Created on the Monday: Mon and Tue are real misses, Wed is still
      // open, and the four days before it existed are blanked out.
      final strip = WidgetService.habitWeekStrip(
          habitOf(created: wednesday.subtract(const Duration(days: 2))),
          {},
          wednesday);
      expect(strip, 'ssssmmo');
    });

    test('a counted habit short of its target is a miss, not a hit', () {
      final yesterday = wednesday.subtract(const Duration(days: 1));
      final log = logOf([yesterday], count: 6);
      final strip =
          WidgetService.habitWeekStrip(habitOf(targetCount: 8), log, wednesday);
      expect(strip[WidgetService.habitWeekDays - 2], 'm');
    });
  });

  group('progress line', () {
    test('a simple habit reads as done or not', () {
      expect(WidgetService.habitProgressLine(habitOf(), 1, 1, true, true),
          'Done today');
      expect(WidgetService.habitProgressLine(habitOf(), 0, 1, true, false),
          'Not done yet');
    });

    test('a counted habit shows the count, with its unit when it has one', () {
      final habit = habitOf(targetCount: 8, unit: 'glasses');
      expect(WidgetService.habitProgressLine(habit, 3, 8, true, false),
          '3 of 8 glasses');
      expect(
          WidgetService.habitProgressLine(
              habitOf(targetCount: 8), 3, 8, true, false),
          '3 of 8');
    });

    test('an unscheduled day says so rather than showing 0 of 8', () {
      final habit = habitOf(targetCount: 8, unit: 'glasses');
      expect(WidgetService.habitProgressLine(habit, 0, 8, false, false),
          'Rest day');
    });
  });

  group('status line', () {
    test('joins progress and streak when there is a streak', () {
      final habit = habitOf(targetCount: 8, unit: 'glasses');
      expect(
          WidgetService.habitStatusLine(habit, 3, 8, true, false, 5),
          '3 of 8 glasses · 5 days');
    });

    test('says days, not day, only when it means it', () {
      expect(WidgetService.habitStatusLine(habitOf(), 1, 1, true, true, 1),
          'Done today · 1 day');
    });

    test('drops the streak entirely at zero rather than saying "0 days"', () {
      expect(WidgetService.habitStatusLine(habitOf(), 0, 1, true, false, 0),
          'Not done yet');
    });
  });
}
