import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/models/habit_stats.dart';
import 'package:taskflow/services/habit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a new habit starts with no logged days', () async {
    final service = HabitService();
    final habit = await service.addHabit(name: 'Read');
    expect(await service.logFor(habit.id), isEmpty);
    expect(await service.countOn(habit.id, DateTime.now()), 0);
  });

  test('toggle marks a simple habit done and undone', () async {
    final service = HabitService();
    final habit = await service.addHabit(name: 'Stretch');

    await service.toggle(habit);
    expect(await service.countOn(habit.id, DateTime.now()), 1);

    await service.toggle(habit);
    expect(await service.countOn(habit.id, DateTime.now()), 0);
  });

  test('increment stops at the target instead of running past it', () async {
    final service = HabitService();
    final habit = await service.addHabit(name: 'Water', targetCount: 3);

    for (var i = 0; i < 6; i++) {
      await service.increment(habit);
    }
    expect(await service.countOn(habit.id, DateTime.now()), 3);
  });

  test('decrement never goes below zero', () async {
    final service = HabitService();
    final habit = await service.addHabit(name: 'Water', targetCount: 3);

    await service.increment(habit);
    await service.decrement(habit);
    await service.decrement(habit);
    expect(await service.countOn(habit.id, DateTime.now()), 0);
  });

  test('a zeroed day is dropped from the log rather than stored as 0',
      () async {
    final service = HabitService();
    final habit = await service.addHabit(name: 'Water', targetCount: 3);

    await service.increment(habit);
    expect(await service.logFor(habit.id), isNotEmpty);

    await service.decrement(habit);
    expect(await service.logFor(habit.id), isEmpty,
        reason: 'an empty day should leave no entry behind');
  });

  test('counts are kept per day, not merged', () async {
    final service = HabitService();
    final habit = await service.addHabit(name: 'Water', targetCount: 5);
    final today = DateTime(2026, 3, 4);
    final yesterday = DateTime(2026, 3, 3);

    await service.setCount(habit.id, today, 5);
    await service.setCount(habit.id, yesterday, 2);

    final log = await service.logFor(habit.id);
    expect(log[habitDateKey(today)], 5);
    expect(log[habitDateKey(yesterday)], 2);
  });

  test('archiving hides a habit but keeps its history', () async {
    final service = HabitService();
    final habit = await service.addHabit(name: 'Journal');
    await service.toggle(habit);

    await service.setArchived(habit.id, true);

    expect(await service.getHabits(), isEmpty);
    expect(await service.getHabits(includeArchived: true), hasLength(1));
    expect(await service.logFor(habit.id), isNotEmpty,
        reason: 'archiving must not discard the record');
  });

  test('deleting a habit also drops its logged days', () async {
    final service = HabitService();
    final habit = await service.addHabit(name: 'Journal');
    await service.toggle(habit);

    await service.deleteHabit(habit.id);

    expect(await service.getHabits(includeArchived: true), isEmpty);
    expect(await service.logFor(habit.id), isEmpty);
  });

  test('today\'s list only includes habits scheduled for today', () async {
    final service = HabitService();
    // 2026-03-04 is a Wednesday.
    final wednesday = DateTime(2026, 3, 4);
    await service.addHabit(name: 'Weekdays', activeWeekdays: {1, 2, 3, 4, 5});
    await service.addHabit(name: 'Weekends', activeWeekdays: {6, 7});
    await service.addHabit(name: 'Every day');

    final today = await service.getTodayHabits(now: wednesday);
    expect(today.map((h) => h.name), containsAll(['Weekdays', 'Every day']));
    expect(today.map((h) => h.name), isNot(contains('Weekends')));
  });

  test('getTodayCounts returns one entry per habit logged today', () async {
    final service = HabitService();
    final a = await service.addHabit(name: 'A', targetCount: 2);
    final b = await service.addHabit(name: 'B');
    await service.addHabit(name: 'C'); // untouched

    await service.increment(a);
    await service.toggle(b);

    final counts = await service.getTodayCounts();
    expect(counts[a.id], 1);
    expect(counts[b.id], 1);
    expect(counts.length, 2, reason: 'untouched habits should not appear');
  });

  test('habits survive a reload from storage', () async {
    final habit = await HabitService().addHabit(
      name: 'Water',
      targetCount: 8,
      unit: 'glasses',
      activeWeekdays: {1, 3, 5},
    );
    await HabitService().increment(habit);

    // A fresh instance reads the same SharedPreferences.
    final reloaded = await HabitService().getHabitById(habit.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.targetCount, 8);
    expect(reloaded.unit, 'glasses');
    expect(reloaded.activeWeekdays, {1, 3, 5});
    expect(await HabitService().countOn(habit.id, DateTime.now()), 1);
  });

}
