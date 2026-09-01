import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/habit.dart';
import 'package:taskflow/models/habit_stats.dart';

/// A fixed "today" so the tests never depend on when they run.
/// 2026-03-04 is a Wednesday, which makes the weekday cases readable.
final _today = DateTime(2026, 3, 4);

Habit _habit({
  int targetCount = 1,
  Set<int>? activeWeekdays,
  DateTime? createdDate,
}) =>
    Habit(
      id: 'h1',
      name: 'Test habit',
      createdDate: createdDate ?? DateTime(2026, 1, 1),
      targetCount: targetCount,
      activeWeekdays: activeWeekdays,
    );

/// Builds a log from day-offsets before [_today] to counts.
Map<String, int> _log(Map<int, int> daysAgoToCount) => {
      for (final e in daysAgoToCount.entries)
        habitDateKey(_today.subtract(Duration(days: e.key))): e.value,
    };

void main() {
  group('currentStreak', () {
    test('counts consecutive completed days back from today', () {
      final h = _habit();
      final log = _log({0: 1, 1: 1, 2: 1});
      expect(currentStreak(h, log, now: _today), 3);
    });

    test('an unfinished today does not break yesterday\'s streak', () {
      // Nothing logged for today; the run of previous days must survive,
      // because there is still time to do it.
      final h = _habit();
      final log = _log({1: 1, 2: 1, 3: 1});
      expect(currentStreak(h, log, now: _today), 3);
    });

    test('a gap before today ends the streak', () {
      final h = _habit();
      // Today and yesterday done, but the day before was missed.
      final log = _log({0: 1, 1: 1, 3: 1, 4: 1});
      expect(currentStreak(h, log, now: _today), 2);
    });

    test('weekdays-only habit keeps its streak across the weekend', () {
      // Mon-Fri habit. _today is Wed 4 Mar 2026; the preceding Sat/Sun
      // (28 Feb / 1 Mar) are unscheduled and must be skipped, not treated
      // as misses.
      final h = _habit(activeWeekdays: {1, 2, 3, 4, 5});
      final log = _log({
        0: 1, // Wed
        1: 1, // Tue
        2: 1, // Mon
        // 3 = Sun, 4 = Sat — deliberately absent
        5: 1, // Fri
        6: 1, // Thu
      });
      expect(currentStreak(h, log, now: _today), 5);
    });

    test('a counted habit short of its target is not a done day', () {
      final h = _habit(targetCount: 8);
      // Today reached 8, yesterday only got to 3.
      final log = _log({0: 8, 1: 3, 2: 8});
      expect(currentStreak(h, log, now: _today), 1);
    });

    test('counts a day that exceeds its target', () {
      final h = _habit(targetCount: 8);
      expect(currentStreak(h, _log({0: 10, 1: 8}), now: _today), 2);
    });

    test('stops at createdDate rather than running backwards forever', () {
      // Created 3 days ago and done every day since. Days before it existed
      // have no log entries but must not be read as misses beyond the start.
      final h = _habit(createdDate: _today.subtract(const Duration(days: 2)));
      final log = _log({0: 1, 1: 1, 2: 1});
      expect(currentStreak(h, log, now: _today), 3);
    });

    test('is zero for a habit never completed', () {
      expect(currentStreak(_habit(), const {}, now: _today), 0);
    });
  });

  group('bestStreak', () {
    test('finds the longest past run, not the current one', () {
      final h = _habit(createdDate: _today.subtract(const Duration(days: 10)));
      // A 4-day run a while back, a 2-day run now, a gap between.
      final log = _log({0: 1, 1: 1, 3: 1, 4: 1, 5: 1, 6: 1});
      expect(bestStreak(h, log, now: _today), 4);
      expect(currentStreak(h, log, now: _today), 2);
    });

    test('an unfinished today does not truncate the best run', () {
      final h = _habit(createdDate: _today.subtract(const Duration(days: 5)));
      final log = _log({1: 1, 2: 1, 3: 1});
      expect(bestStreak(h, log, now: _today), 3);
    });
  });

  group('completionRate', () {
    test('is the share of scheduled days completed', () {
      final h = _habit(createdDate: _today.subtract(const Duration(days: 9)));
      // 5 of the last 10 days done.
      final log = _log({0: 1, 1: 1, 2: 1, 3: 1, 4: 1});
      expect(completionRate(h, log, days: 10, now: _today), closeTo(0.5, 1e-9));
    });

    test('ignores days before the habit existed', () {
      // Created 2 days ago, done both days: a full rate, not 2/30.
      final h = _habit(createdDate: _today.subtract(const Duration(days: 1)));
      final log = _log({0: 1, 1: 1});
      expect(completionRate(h, log, days: 30, now: _today), 1.0);
    });

    test('ignores unscheduled weekdays', () {
      // Sundays only. In the last 14 days there are exactly 2 Sundays
      // (1 Mar and 22 Feb); doing one of them is half, not 1/14.
      final h = _habit(activeWeekdays: {7});
      final log = _log({3: 1}); // Sun 1 Mar
      expect(completionRate(h, log, days: 14, now: _today),
          closeTo(0.5, 1e-9));
    });

    test('is zero when nothing was scheduled in the window', () {
      final h = _habit(activeWeekdays: {6}); // Saturdays only
      expect(completionRate(h, const {}, days: 3, now: _today), 0);
    });
  });

  group('Habit serialization', () {
    test('round-trips through JSON', () {
      final h = Habit(
        id: 'abc',
        name: 'Drink water',
        createdDate: DateTime(2026, 2, 1),
        note: 'with lemon',
        iconIndex: 4,
        colorIndex: 2,
        targetCount: 8,
        unit: 'glasses',
        activeWeekdays: {1, 3, 5},
        reminderHour: 9,
        reminderMinute: 30,
      );
      final back = Habit.fromJsonString(h.toJsonString());
      expect(back.id, h.id);
      expect(back.name, h.name);
      expect(back.targetCount, 8);
      expect(back.unit, 'glasses');
      expect(back.activeWeekdays, {1, 3, 5});
      expect(back.reminderHour, 9);
      expect(back.reminderMinute, 30);
      expect(back.archived, isFalse);
    });

    test('tolerates a minimal payload from an older version', () {
      final back = Habit.fromJson({
        'id': 'x',
        'name': 'Read',
        'createdDate': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(back.targetCount, 1);
      expect(back.isSimple, isTrue);
      expect(back.activeWeekdays, isEmpty);
      expect(back.isActiveOn(DateTime(2026, 3, 7)), isTrue);
    });
  });
}
