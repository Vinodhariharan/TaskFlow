import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/task_recurrence.dart';
import 'notification_service.dart';
import 'task_change_notifier.dart';

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
  /// - Incomplete general tasks from previous days, which simply roll
  ///   forward: an undated task that isn't done yet is still just a task,
  ///   so nothing in the UI singles it out
  /// - Scheduled tasks for today
  /// - Overdue scheduled tasks (past date, incomplete) — the only ones
  ///   highlighted, since a missed due date is a real fact about the task
  Future<List<Task>> getTodayTasks({Set<String>? categoryIds}) async {
    final all = await _loadAll();
    final today = _dateOnly(DateTime.now());

    return all.where((t) {
      if (categoryIds != null &&
          categoryIds.isNotEmpty &&
          !categoryIds.contains(t.categoryId)) {
        return false;
      }
      // Completed just now (today), regardless of the task's original
      // scheduled/created day — otherwise checking off an overdue or
      // carried-over task makes it vanish instead of showing as done.
      final completedToday = t.isCompleted &&
          t.completedDate != null &&
          _dateOnly(t.completedDate!) == today;
      if (t.scheduledDate != null) {
        final sd = _dateOnly(t.scheduledDate!);
        // Scheduled for today OR overdue (past + incomplete)
        return sd == today ||
            (sd.isBefore(today) && !t.isCompleted) ||
            completedToday;
      } else {
        // General: created today OR incomplete from a previous day
        return _dateOnly(t.createdDate) == today ||
            (!t.isCompleted && _dateOnly(t.createdDate).isBefore(today)) ||
            completedToday;
      }
    }).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        // Scheduled today first among incomplete
        if (a.isScheduledToday != b.isScheduledToday) return a.isScheduledToday ? -1 : 1;
        // Overdue next among incomplete
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        // Where the user dragged it, ahead of priority: a task has to stay
        // where it was put, or dragging one above a higher-priority task
        // would snap back and read as broken. Only dragged tasks carry an
        // index, so priority still orders everything nobody has touched.
        final placed = _compareSortIndex(a, b);
        if (placed != 0) return placed;
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
  Future<Map<DateTime, List<Task>>> getScheduledTasks({Set<String>? categoryIds}) async {
    final all = await _loadAll();
    final today = _dateOnly(DateTime.now());

    final future = all.where((t) {
      if (categoryIds != null &&
          categoryIds.isNotEmpty &&
          !categoryIds.contains(t.categoryId)) {
        return false;
      }
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
        final placed = _compareSortIndex(a, b);
        if (placed != 0) return placed;
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

  /// Every task, unfiltered — used to re-arm reminder notifications on app
  /// start (rescheduleAll), not for display.
  Future<List<Task>> getAllTasks() => _loadAll();

  /// A single task by id, or null if it no longer exists — used by the task
  /// detail screen, including when it's opened from a tapped reminder for a
  /// task that has since been deleted.
  Future<Task?> getTaskById(String id) async {
    final all = await _loadAll();
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
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
    String? categoryId,
    TaskRecurrence? recurrence,
    int? reminderHour,
    int? reminderMinute,
  }) async {
    final tasks = await _loadAll();
    final task = Task(
      id: _uuid.v4(),
      title: title,
      createdDate: DateTime.now(),
      note: note,
      priority: priority,
      scheduledDate: scheduledDate,
      categoryId: categoryId,
      recurrence: recurrence,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
    tasks.add(task);
    await _saveAll(tasks);
    TaskChangeNotifier.instance.notifyChanged();
    await NotificationService.instance.scheduleForTask(task);
    return task;
  }

  /// Orders two tasks by where the user dragged them. A task that has been
  /// placed comes before one that hasn't, which is what puts anything added
  /// after a reorder at the end instead of in the middle. Returns 0 when
  /// neither has been placed, leaving the caller's remaining rules to
  /// decide.
  static int _compareSortIndex(Task a, Task b) {
    final ai = a.sortIndex;
    final bi = b.sortIndex;
    if (ai == null && bi == null) return 0;
    if (ai == null) return 1;
    if (bi == null) return -1;
    return ai.compareTo(bi);
  }

  /// Writes a new manual order for [orderedIds], which must be the ids of
  /// one group of tasks — today's outstanding list, say — in the order the
  /// user just dragged them into.
  ///
  /// Indices only ever compete within a group, since the sort settles the
  /// completed/scheduled/overdue grouping before consulting them, so
  /// numbering from zero each time is safe. Ids that no longer exist are
  /// skipped, since the list may have been rebuilt while a drag was in
  /// flight.
  Future<void> reorderTasks(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final tasks = await _loadAll();
    final byId = {for (final t in tasks) t.id: t};
    final moving =
        orderedIds.map((id) => byId[id]).whereType<Task>().toList();
    if (moving.isEmpty) return;

    for (var i = 0; i < moving.length; i++) {
      moving[i].sortIndex = i;
    }
    await _saveAll(tasks);
    TaskChangeNotifier.instance.notifyChanged();
  }

  /// Deletes several tasks in one load+save cycle, so a multi-select delete
  /// is a single write and a single undoable action rather than N of each.
  Future<List<Task>> deleteTasks(Iterable<String> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return const [];
    final tasks = await _loadAll();
    final removed = tasks.where((t) => idSet.contains(t.id)).toList();
    if (removed.isEmpty) return const [];
    tasks.removeWhere((t) => idSet.contains(t.id));
    await _saveAll(tasks);
    for (final task in removed) {
      await NotificationService.instance.cancelForTask(task.id);
    }
    TaskChangeNotifier.instance.notifyChanged();
    return removed;
  }

  /// How many tasks currently use [categoryId] — used before deleting a
  /// category, to decide whether a reassignment prompt is needed.
  Future<int> countByCategory(String categoryId) async {
    final all = await _loadAll();
    return all.where((t) => t.categoryId == categoryId).length;
  }

  /// Moves every task tagged [fromId] to [toId] in one load+save cycle —
  /// used when a category is deleted and its tasks need a new home.
  Future<void> reassignCategory({required String fromId, required String toId}) async {
    final all = await _loadAll();
    var changed = false;
    for (final t in all) {
      if (t.categoryId == fromId) {
        t.categoryId = toId;
        changed = true;
      }
    }
    if (changed) {
      await _saveAll(all);
      TaskChangeNotifier.instance.notifyChanged();
    }
  }

  /// Toggles completion. For a recurring task with a scheduled date,
  /// checking it off doesn't leave it sitting in the completed list — it
  /// rolls forward to the next occurrence date and un-checks itself, so
  /// there's one task row per recurring task rather than one per
  /// occurrence.
  Future<void> toggleComplete(String id) async {
    final tasks = await _loadAll();
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final t = tasks[idx];
    final completing = !t.isCompleted;

    final Task updated;
    if (completing && t.recurrence != null && t.scheduledDate != null) {
      updated = t.copyWith(
        scheduledDate: nextRecurrenceDate(t.scheduledDate!, t.recurrence!),
        isCompleted: false,
        completedDate: DateTime.now(),
      );
    } else {
      updated = t.copyWith(
        isCompleted: completing,
        completedDate: completing ? DateTime.now() : null,
      );
    }
    tasks[idx] = updated;
    await _saveAll(tasks);
    TaskChangeNotifier.instance.notifyChanged();
    await NotificationService.instance.scheduleForTask(updated);
  }

  Future<void> updateTask(Task updated) async {
    final tasks = await _loadAll();
    final idx = tasks.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;
    tasks[idx] = updated;
    await _saveAll(tasks);
    TaskChangeNotifier.instance.notifyChanged();
    await NotificationService.instance.scheduleForTask(updated);
  }

  Future<void> deleteTask(String id) async {
    final tasks = await _loadAll();
    tasks.removeWhere((t) => t.id == id);
    await _saveAll(tasks);
    TaskChangeNotifier.instance.notifyChanged();
    await NotificationService.instance.cancelForTask(id);
  }

  Future<void> clearCompleted() async {
    final tasks = await _loadAll();
    final removed = tasks.where((t) => t.isCompleted).toList();
    tasks.removeWhere((t) => t.isCompleted);
    await _saveAll(tasks);
    TaskChangeNotifier.instance.notifyChanged();
    for (final t in removed) {
      await NotificationService.instance.cancelForTask(t.id);
    }
  }
}
