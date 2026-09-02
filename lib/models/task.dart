import 'dart:convert';
import 'task_recurrence.dart';

class Task {
  final String id;
  String title;
  bool isCompleted;
  DateTime createdDate;
  DateTime? completedDate;
  String? note;
  TaskPriority priority;
  DateTime? scheduledDate; // null = general/today task
  String? categoryId; // null = uncategorized
  TaskRecurrence? recurrence; // only meaningful alongside scheduledDate
  int? reminderHour; // 0-23, local time; null = no reminder
  int? reminderMinute; // 0-59

  /// Where the user dragged this task within its group, ascending, or null
  /// if it has never been dragged.
  ///
  /// Null rather than a default number on purpose: an index on every task
  /// would silently retire priority as a sort key, since creation order
  /// would always decide first. Only tasks the user has actually placed
  /// carry one, and they sort ahead of the ones that don't — so an
  /// untouched list still reads high-priority-first exactly as before, and
  /// a task added after a reorder joins the end rather than the middle.
  ///
  /// Only ever compared against tasks in the same group (today's, a given
  /// future date, done) — the sort settles the grouping first — so indices
  /// are free to collide across groups.
  int? sortIndex;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdDate,
    this.completedDate,
    this.note,
    this.priority = TaskPriority.normal,
    this.scheduledDate,
    this.categoryId,
    this.recurrence,
    this.reminderHour,
    this.reminderMinute,
    this.sortIndex,
  });

  bool get hasReminder => reminderHour != null && reminderMinute != null;

  /// Returns true if this is a general task (no scheduled date)
  bool get isGeneral => scheduledDate == null;

  /// Returns true if task is scheduled for a future date
  bool get isFuture {
    if (scheduledDate == null) return false;
    final today = _dateOnly(DateTime.now());
    final sd = _dateOnly(scheduledDate!);
    return sd.isAfter(today);
  }

  /// Returns true if task is scheduled for today
  bool get isScheduledToday {
    if (scheduledDate == null) return false;
    final today = _dateOnly(DateTime.now());
    final sd = _dateOnly(scheduledDate!);
    return sd == today;
  }

  /// Returns true if task is overdue (scheduled date is in the past, incomplete)
  bool get isOverdue {
    if (scheduledDate == null || isCompleted) return false;
    final today = _dateOnly(DateTime.now());
    final sd = _dateOnly(scheduledDate!);
    return sd.isBefore(today);
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdDate,
    DateTime? completedDate,
    String? note,
    TaskPriority? priority,
    DateTime? scheduledDate,
    bool clearScheduledDate = false,
    String? categoryId,
    bool clearCategoryId = false,
    TaskRecurrence? recurrence,
    bool clearRecurrence = false,
    int? reminderHour,
    int? reminderMinute,
    bool clearReminder = false,
    int? sortIndex,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdDate: createdDate ?? this.createdDate,
      completedDate: completedDate ?? this.completedDate,
      note: note ?? this.note,
      priority: priority ?? this.priority,
      scheduledDate:
          clearScheduledDate ? null : (scheduledDate ?? this.scheduledDate),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      reminderHour:
          clearReminder ? null : (reminderHour ?? this.reminderHour),
      reminderMinute:
          clearReminder ? null : (reminderMinute ?? this.reminderMinute),
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdDate': createdDate.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
      'note': note,
      'priority': priority.index,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'categoryId': categoryId,
      'recurrence': recurrence?.toJson(),
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'sortIndex': sortIndex,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool,
      createdDate: DateTime.parse(json['createdDate'] as String),
      completedDate: json['completedDate'] != null
          ? DateTime.parse(json['completedDate'] as String)
          : null,
      note: json['note'] as String?,
      priority: TaskPriority.values[json['priority'] as int? ?? 0],
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'] as String)
          : null,
      categoryId: json['categoryId'] as String?,
      recurrence: json['recurrence'] != null
          ? TaskRecurrence.fromJson(json['recurrence'] as Map<String, dynamic>)
          : null,
      reminderHour: json['reminderHour'] as int?,
      reminderMinute: json['reminderMinute'] as int?,
      // Absent for every task stored before ordering existed, which is
      // exactly what "never dragged" means.
      sortIndex: json['sortIndex'] as int?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory Task.fromJsonString(String jsonStr) =>
      Task.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}

enum TaskPriority { normal, high }
