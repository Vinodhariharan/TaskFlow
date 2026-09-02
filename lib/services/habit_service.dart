import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/habit.dart';
import '../models/habit_stats.dart';
import 'habit_change_notifier.dart';
import 'notification_service.dart';

/// Storage for habits and their per-day completion log.
///
/// Follows TaskService's load/save shape and SharedPreferences conventions,
/// with one difference that defines the feature: habits keep history. A
/// recurring Task rolls its date forward and forgets, which is right for a
/// task and useless for a habit, so the log below is the whole point.
///
/// Two keys:
///  * `habits_v1`     — a String list of Habit JSON, exactly like tasks_v1.
///  * `habit_logs_v1` — one JSON object, `{habitId: {"2026-08-31": 3}}`.
///
/// The nested map is chosen over a flat list of entries because every read
/// is either a point lookup (today's count) or a contiguous date scan
/// (streaks, heatmap); both are cheap against a map and awkward against a
/// list. At roughly 10 habits over a year it's tens of kilobytes, which
/// SharedPreferences handles comfortably.
class HabitService {
  static const _habitsKey = 'habits_v1';
  static const _logsKey = 'habit_logs_v1';
  static const _uuid = Uuid();

  // ── Low-level persistence ──────────────────────────────────────────────

  Future<List<Habit>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_habitsKey) ?? [];
    return raw.map((s) => Habit.fromJsonString(s)).toList();
  }

  Future<void> _saveAll(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _habitsKey,
      habits.map((h) => h.toJsonString()).toList(),
    );
  }

  /// The whole log, `{habitId: {dateKey: count}}`. Returns a mutable copy.
  Future<Map<String, Map<String, int>>> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_logsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((habitId, days) => MapEntry(
            habitId,
            (days as Map<String, dynamic>).map(
              (day, count) => MapEntry(day, (count as num).toInt()),
            ),
          ));
    } catch (_) {
      // A corrupt log shouldn't take the habits with it — better to lose
      // history than to make the tab unopenable.
      return {};
    }
  }

  Future<void> _saveLogs(Map<String, Map<String, int>> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logsKey, jsonEncode(logs));
  }

  // ── Habits ─────────────────────────────────────────────────────────────

  /// Active habits, oldest first. Archived ones are excluded unless
  /// [includeArchived] is set.
  Future<List<Habit>> getHabits({bool includeArchived = false}) async {
    final all = await _loadAll();
    final visible =
        includeArchived ? all : all.where((h) => !h.archived).toList();
    return visible
      ..sort((a, b) {
        // Where the user dragged it. Only dragged habits carry an index and
        // they lead, so an untouched list stays in creation order and a
        // habit added after a reorder joins the end.
        final ai = a.sortIndex;
        final bi = b.sortIndex;
        if (ai != null && bi != null && ai != bi) return ai.compareTo(bi);
        if (ai == null && bi != null) return 1;
        if (ai != null && bi == null) return -1;
        return a.createdDate.compareTo(b.createdDate);
      });
  }

  /// The habits expected today — what the Habits tab lists.
  Future<List<Habit>> getTodayHabits({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final habits = await getHabits();
    return habits.where((h) => h.isActiveOn(today)).toList();
  }

  Future<Habit?> getHabitById(String id) async {
    final all = await _loadAll();
    for (final h in all) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<Habit> addHabit({
    required String name,
    String? note,
    int iconIndex = 0,
    int colorIndex = 0,
    int targetCount = 1,
    String? unit,
    Set<int>? activeWeekdays,
    int? reminderHour,
    int? reminderMinute,
  }) async {
    final habits = await _loadAll();
    final habit = Habit(
      id: _uuid.v4(),
      name: name,
      createdDate: DateTime.now(),
      note: note,
      iconIndex: iconIndex,
      colorIndex: colorIndex,
      targetCount: targetCount,
      unit: unit,
      activeWeekdays: activeWeekdays,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
    habits.add(habit);
    await _saveAll(habits);
    HabitChangeNotifier.instance.notifyChanged();
    await NotificationService.instance.scheduleForHabit(habit);
    return habit;
  }

  Future<void> updateHabit(Habit updated) async {
    final habits = await _loadAll();
    final idx = habits.indexWhere((h) => h.id == updated.id);
    if (idx == -1) return;
    habits[idx] = updated;
    await _saveAll(habits);
    HabitChangeNotifier.instance.notifyChanged();
    // Always reschedule rather than diffing: the reminder time, the active
    // days and the archived flag all change what should be armed, and
    // scheduleForHabit is cancel-then-add anyway.
    await NotificationService.instance.scheduleForHabit(updated);
  }

  /// Hides a habit from the daily list while keeping every logged day, so
  /// stopping something doesn't erase the record of having done it.
  Future<void> setArchived(String id, bool archived) async {
    final habit = await getHabitById(id);
    if (habit == null) return;
    await updateHabit(habit.copyWith(archived: archived));
  }

  /// Removes the habit and its history. Archiving is the non-destructive
  /// option; this is the one that actually forgets.
  Future<void> deleteHabit(String id) async {
    final habits = await _loadAll();
    habits.removeWhere((h) => h.id == id);
    await _saveAll(habits);
    final logs = await _loadLogs();
    logs.remove(id);
    await _saveLogs(logs);
    HabitChangeNotifier.instance.notifyChanged();
    await NotificationService.instance.cancelForHabit(id);
  }

  /// Writes a new manual order for [orderedIds], in the order the user just
  /// dragged them into. Ids that no longer exist are skipped, since the list
  /// may have been rebuilt while a drag was in flight.
  Future<void> reorderHabits(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final habits = await _loadAll();
    final byId = {for (final h in habits) h.id: h};
    final moving =
        orderedIds.map((id) => byId[id]).whereType<Habit>().toList();
    if (moving.isEmpty) return;

    for (var i = 0; i < moving.length; i++) {
      moving[i].sortIndex = i;
    }
    await _saveAll(habits);
    HabitChangeNotifier.instance.notifyChanged();
  }

  // ── Log ────────────────────────────────────────────────────────────────

  /// Every logged day for one habit, `{"2026-08-31": 3}`.
  Future<Map<String, int>> logFor(String habitId) async {
    final logs = await _loadLogs();
    return logs[habitId] ?? {};
  }

  /// Today's count for every habit, keyed by habit id — one read for the
  /// whole list rather than one per row.
  Future<Map<String, int>> getTodayCounts({DateTime? now}) async {
    final key = habitDateKey(now ?? DateTime.now());
    final logs = await _loadLogs();
    return {
      for (final entry in logs.entries)
        if (entry.value[key] != null) entry.key: entry.value[key]!,
    };
  }

  /// Sets an exact count for a day, clamped at zero. Zero removes the entry
  /// rather than storing it, keeping the log free of meaningless noise.
  Future<void> setCount(String habitId, DateTime date, int count) async {
    final logs = await _loadLogs();
    final key = habitDateKey(date);
    final forHabit = logs.putIfAbsent(habitId, () => {});
    if (count <= 0) {
      forHabit.remove(key);
      if (forHabit.isEmpty) logs.remove(habitId);
    } else {
      forHabit[key] = count;
    }
    await _saveLogs(logs);
    HabitChangeNotifier.instance.notifyChanged();
  }

  Future<int> countOn(String habitId, DateTime date) async {
    final log = await logFor(habitId);
    return log[habitDateKey(date)] ?? 0;
  }

  /// One more for the day, capped at the habit's target so the number can't
  /// drift past what "done" means.
  Future<void> increment(Habit habit, {DateTime? date}) async {
    final day = date ?? DateTime.now();
    final current = await countOn(habit.id, day);
    final target = habit.targetCount < 1 ? 1 : habit.targetCount;
    await setCount(habit.id, day, (current + 1).clamp(0, target));
  }

  Future<void> decrement(Habit habit, {DateTime? date}) async {
    final day = date ?? DateTime.now();
    final current = await countOn(habit.id, day);
    await setCount(habit.id, day, current - 1);
  }

  /// Flips a simple (target 1) habit between done and not done.
  Future<void> toggle(Habit habit, {DateTime? date}) async {
    final day = date ?? DateTime.now();
    final current = await countOn(habit.id, day);
    final target = habit.targetCount < 1 ? 1 : habit.targetCount;
    await setCount(habit.id, day, current >= target ? 0 : target);
  }
}
