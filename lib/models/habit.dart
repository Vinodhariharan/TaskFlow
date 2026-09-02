import 'dart:convert';
import 'package:flutter/material.dart';

/// Curated, fixed icon choices for habits — literal `Icons.*` references so
/// Flutter's icon tree-shaker keeps them in release builds (an IconData
/// rebuilt at runtime from a stored codePoint gets shaken out and renders
/// blank). Its own list rather than the task-category one, since these lean
/// towards things you do repeatedly: exercise, reading, water, sleep.
const List<IconData> kHabitIconChoices = [
  Icons.fitness_center_rounded,
  Icons.directions_run_rounded,
  Icons.self_improvement_rounded,
  Icons.book_outlined,
  Icons.water_drop_outlined,
  Icons.bedtime_outlined,
  Icons.restaurant_outlined,
  Icons.spa_outlined,
  Icons.favorite_border_rounded,
  Icons.school_outlined,
  Icons.edit_note_rounded,
  Icons.music_note_outlined,
  Icons.language_rounded,
  Icons.code_rounded,
  Icons.brush_outlined,
  Icons.pedal_bike_rounded,
  Icons.pool_outlined,
  Icons.smoke_free_rounded,
  Icons.savings_outlined,
  Icons.wb_sunny_outlined,
];

const List<Color> kHabitColorChoices = [
  Color(0xFF6C63FF),
  Color(0xFF4CD9A0),
  Color(0xFF5AB4FF),
  Color(0xFFFF9F5A),
  Color(0xFFFF6584),
  Color(0xFFFFD166),
  Color(0xFFB388FF),
  Color(0xFF4CAF93),
  Color(0xFFFF7A7A),
  Color(0xFF9090A8),
];

/// Something you want to do regularly, as opposed to a Task, which is
/// something that has to get done once.
///
/// The difference that drives the whole model: a task that slips becomes
/// overdue and demands attention, while a missed habit is simply a gap in
/// the record. Habits therefore keep a full per-day log (see HabitService)
/// where a recurring Task deliberately keeps none.
class Habit {
  final String id;
  String name;
  String? note;
  int iconIndex;
  int colorIndex;

  /// How many times a day counts as done. 1 means a plain tick; anything
  /// higher turns the row into a counter ("6 / 8 glasses").
  int targetCount;

  /// What's being counted — "glasses", "pages". Only meaningful when
  /// [targetCount] > 1, and only ever used as a label.
  String? unit;

  /// Weekdays the habit is expected on, 1 = Monday .. 7 = Sunday. Empty
  /// means every day. Days not in this set are skipped entirely: they don't
  /// show in today's list and they never count as a miss against a streak.
  Set<int> activeWeekdays;

  int? reminderHour; // 0-23, local time; null = no reminder
  int? reminderMinute;

  DateTime createdDate;

  /// Where the user dragged this habit in the list, ascending, or null if
  /// it has never been dragged. Habits carrying one sort ahead of those
  /// that don't, so an untouched list stays in creation order and a habit
  /// added after a reorder joins the end.
  int? sortIndex;

  /// Archived habits keep their history but drop out of the daily list —
  /// the alternative to deleting something you'd rather stop doing without
  /// throwing away the record of having done it.
  bool archived;

  Habit({
    required this.id,
    required this.name,
    required this.createdDate,
    this.note,
    this.iconIndex = 0,
    this.colorIndex = 0,
    this.targetCount = 1,
    this.unit,
    Set<int>? activeWeekdays,
    this.reminderHour,
    this.reminderMinute,
    this.archived = false,
    this.sortIndex,
  }) : activeWeekdays = activeWeekdays ?? <int>{};

  IconData get icon =>
      kHabitIconChoices[iconIndex.clamp(0, kHabitIconChoices.length - 1)];
  Color get color =>
      kHabitColorChoices[colorIndex.clamp(0, kHabitColorChoices.length - 1)];

  bool get hasReminder => reminderHour != null && reminderMinute != null;

  /// True when a plain tick is enough, rather than a counter.
  bool get isSimple => targetCount <= 1;

  /// Whether the habit is expected on [date]'s weekday. An empty
  /// [activeWeekdays] means every day.
  bool isActiveOn(DateTime date) =>
      activeWeekdays.isEmpty || activeWeekdays.contains(date.weekday);

  Habit copyWith({
    String? name,
    String? note,
    bool clearNote = false,
    int? iconIndex,
    int? colorIndex,
    int? targetCount,
    String? unit,
    bool clearUnit = false,
    Set<int>? activeWeekdays,
    int? reminderHour,
    int? reminderMinute,
    bool clearReminder = false,
    DateTime? createdDate,
    bool? archived,
    int? sortIndex,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      note: clearNote ? null : (note ?? this.note),
      iconIndex: iconIndex ?? this.iconIndex,
      colorIndex: colorIndex ?? this.colorIndex,
      targetCount: targetCount ?? this.targetCount,
      unit: clearUnit ? null : (unit ?? this.unit),
      activeWeekdays: activeWeekdays ?? {...this.activeWeekdays},
      reminderHour: clearReminder ? null : (reminderHour ?? this.reminderHour),
      reminderMinute:
          clearReminder ? null : (reminderMinute ?? this.reminderMinute),
      createdDate: createdDate ?? this.createdDate,
      archived: archived ?? this.archived,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'note': note,
        'iconIndex': iconIndex,
        'colorIndex': colorIndex,
        'targetCount': targetCount,
        'unit': unit,
        'activeWeekdays': activeWeekdays.toList(),
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'createdDate': createdDate.toIso8601String(),
        'archived': archived,
        'sortIndex': sortIndex,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        name: json['name'] as String,
        note: json['note'] as String?,
        iconIndex: json['iconIndex'] as int? ?? 0,
        colorIndex: json['colorIndex'] as int? ?? 0,
        targetCount: json['targetCount'] as int? ?? 1,
        unit: json['unit'] as String?,
        activeWeekdays:
            ((json['activeWeekdays'] as List?)?.cast<int>() ?? const <int>[])
                .toSet(),
        reminderHour: json['reminderHour'] as int?,
        reminderMinute: json['reminderMinute'] as int?,
        createdDate: DateTime.parse(json['createdDate'] as String),
        archived: json['archived'] as bool? ?? false,
        // Absent for habits stored before ordering existed, which is
        // exactly what "never dragged" means.
        sortIndex: json['sortIndex'] as int?,
      );

  String toJsonString() => jsonEncode(toJson());
  factory Habit.fromJsonString(String s) =>
      Habit.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
