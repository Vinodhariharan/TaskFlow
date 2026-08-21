import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';

class TaskService {
  static const _tasksKey = 'tasks_v1';
  static const _uuid = Uuid();

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  // ── Low-level persistence ──────────────────────────────────────────────────

  Future<List<Task>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_tasksKey) ?? [];
    return raw.map((s) => Task.fromJsonString(s)).toList();
  }

  Future<void> _saveAll(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _tasksKey,
      tasks.map((t) => t.toJsonString()).toList(),
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Today's list:
  /// - General tasks created today
  /// - Incomplete general tasks from previous days (carried over)
  /// - Scheduled tasks for today
  /// - Overdue scheduled tasks (past date, incomplete) — carried over with color
  Future<List<Task>> getTodayTasks() async {
    final all = await _loadAll();
    final today = _dateOnly(DateTime.now());

    return all.where((t) {
      if (t.scheduledDate != null) {
        final sd = _dateOnly(t.scheduledDate!);
        // Scheduled for today OR overdue (past + incomplete)
        return sd == today || (sd.isBefore(today) && !t.isCompleted);
      } else {
        // General: created today OR incomplete from a previous day
        final taskDay = _dateOnly(t.createdDate);
        return taskDay == today || (!t.isCompleted && taskDay.isBefore(today));
      }
    }).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        // Scheduled today first among incomplete
        if (a.isScheduledToday != b.isScheduledToday) return a.isScheduledToday ? -1 : 1;
        // Overdue next among incomplete
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        if (a.priority != b.priority) {
          return b.priority.index.compareTo(a.priority.index);
        }
        return a.createdDate.compareTo(b.createdDate);
      });
  }

  /// Future scheduled tasks grouped by date (sorted ascending). Includes
  /// completed ones too (sorted after pending within each date) — excluding
  /// them here meant completing a future-scheduled task made it vanish
  /// entirely, since it also never appears in getTodayTasks().
  Future<Map<DateTime, List<Task>>> getScheduledTasks() async {
    final all = await _loadAll();
    final today = _dateOnly(DateTime.now());

    final future = all.where((t) {
      if (t.scheduledDate == null) return false;
      final sd = _dateOnly(t.scheduledDate!);
      return sd.isAfter(today);
    }).toList();

    // Group by date
    final Map<DateTime, List<Task>> grouped = {};
    for (final task in future) {
      final key = _dateOnly(task.scheduledDate!);
      grouped.putIfAbsent(key, () => []).add(task);
    }

    // Sort tasks within each group: pending first, completed pushed down.
    for (final list in grouped.values) {
      list.sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return b.priority.index.compareTo(a.priority.index);
      });
    }

    // Return sorted by date
    final sorted = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
  }

  Future<List<Task>> getCompletedTasks() async {
    final all = await _loadAll();
    return all
        .where((t) => t.isCompleted)
        .toList()
      ..sort((a, b) =>
          (b.completedDate ?? b.createdDate)
              .compareTo(a.completedDate ?? a.createdDate));
  }

  Future<Task> addTask({
    required String title,
    String? note,
    TaskPriority priority = TaskPriority.normal,
    DateTime? scheduledDate,
  }) async {
    final tasks = await _loadAll();
    final task = Task(
      id: _uuid.v4(),
      title: title,
      createdDate: DateTime.now(),
      note: note,
      priority: priority,
      scheduledDate: scheduledDate,
    );
    tasks.add(task);
    await _saveAll(tasks);
    return task;
  }

  Future<void> toggleComplete(String id) async {
    final tasks = await _loadAll();
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final t = tasks[idx];
    tasks[idx] = t.copyWith(
      isCompleted: !t.isCompleted,
      completedDate: !t.isCompleted ? DateTime.now() : null,
    );
    await _saveAll(tasks);
  }

  Future<void> updateTask(Task updated) async {
    final tasks = await _loadAll();
    final idx = tasks.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;
    tasks[idx] = updated;
    await _saveAll(tasks);
  }

  Future<void> deleteTask(String id) async {
    final tasks = await _loadAll();
    tasks.removeWhere((t) => t.id == id);
    await _saveAll(tasks);
  }

  Future<void> clearCompleted() async {
    final tasks = await _loadAll();
    tasks.removeWhere((t) => t.isCompleted);
    await _saveAll(tasks);
  }
}
