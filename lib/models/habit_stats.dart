import 'habit.dart';

/// Streak and completion maths for habits.
///
/// Deliberately pure: every function takes a [Habit] plus its log map and
/// returns a number, with no storage access, so the rules below can be
/// tested directly rather than only observed on a device.
///
/// The rules are where habit trackers usually go wrong:
///
///  * A day only counts when the logged count reaches the habit's target —
///    6 of 8 glasses is not a done day.
///  * Days the habit isn't scheduled on are **skipped, not broken**. A
///    weekdays-only habit must keep its streak across the weekend.
///  * An unfinished *today* doesn't break anything — there's still time.
///    The streak is measured from yesterday in that case.
///  * Nothing before [Habit.createdDate] counts as a miss; the streak stops
///    there rather than running backwards forever.

/// Log keys are plain `yyyy-MM-dd` strings — sortable, timezone-free, and
/// stable across DST, which a millisecond timestamp would not be.
String habitDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [habit] was completed on [date], given [log] (`yyyy-MM-dd` ->
/// count). Always false for days the habit isn't scheduled on.
bool isDoneOn(Habit habit, Map<String, int> log, DateTime date) {
  if (!habit.isActiveOn(date)) return false;
  final count = log[habitDateKey(date)] ?? 0;
  return count >= (habit.targetCount < 1 ? 1 : habit.targetCount);
}

/// The run of scheduled days completed up to now, counting backwards.
///
/// Today is included when it's already done, and skipped (not counted as a
/// break) when it isn't — so the number never drops just because it's
/// morning.
int currentStreak(Habit habit, Map<String, int> log, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final start = _dateOnly(habit.createdDate);

  var cursor = today;
  // An unfinished today is "not yet", not a miss — start from yesterday.
  if (habit.isActiveOn(today) && !isDoneOn(habit, log, today)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }

  var streak = 0;
  while (!cursor.isBefore(start)) {
    if (habit.isActiveOn(cursor)) {
      if (!isDoneOn(habit, log, cursor)) break;
      streak++;
    }
    // Unscheduled days fall through untouched: neither counted nor fatal.
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// The longest run of completed scheduled days ever recorded, using the same
/// skip rules as [currentStreak].
int bestStreak(Habit habit, Map<String, int> log, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final start = _dateOnly(habit.createdDate);
  if (today.isBefore(start)) return 0;

  var best = 0;
  var run = 0;
  for (var cursor = start;
      !cursor.isAfter(today);
      cursor = cursor.add(const Duration(days: 1))) {
    if (!habit.isActiveOn(cursor)) continue;
    if (isDoneOn(habit, log, cursor)) {
      run++;
      if (run > best) best = run;
    } else {
      // Today still being open shouldn't truncate the best run.
      if (cursor == today) break;
      run = 0;
    }
  }
  return best;
}

/// Share of scheduled days completed over the last [days] days, as 0..1.
///
/// Only days the habit was scheduled on *and* existed for are counted, so a
/// habit created three days ago isn't punished for the 27 before it. Returns
/// 0 when there were no scheduled days in the window at all.
double completionRate(
  Habit habit,
  Map<String, int> log, {
  int days = 30,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final start = _dateOnly(habit.createdDate);

  var scheduled = 0;
  var done = 0;
  for (var i = 0; i < days; i++) {
    final day = today.subtract(Duration(days: i));
    if (day.isBefore(start)) break;
    if (!habit.isActiveOn(day)) continue;
    scheduled++;
    if (isDoneOn(habit, log, day)) done++;
  }
  if (scheduled == 0) return 0;
  return done / scheduled;
}
