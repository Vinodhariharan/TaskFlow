import 'dart:convert';

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

/// A task's repeat rule. Only meaningful on tasks that also have a
/// [scheduledDate] — recurrence advances that date each time the task is
/// completed (see TaskService.toggleComplete), rather than spawning a new
/// task per occurrence.
class TaskRecurrence {
  final RecurrenceFrequency frequency;
  /// Weekday numbers (1 = Monday .. 7 = Sunday), only used when
  /// [frequency] is weekly. Empty means "repeat on the same weekday as the
  /// task's current scheduled date" — the simple weekly-anniversary case.
  final Set<int> weekdays;

  const TaskRecurrence({required this.frequency, this.weekdays = const {}});

  Map<String, dynamic> toJson() => {
        'frequency': frequency.index,
        'weekdays': weekdays.toList(),
      };

  factory TaskRecurrence.fromJson(Map<String, dynamic> json) => TaskRecurrence(
        frequency: RecurrenceFrequency.values[json['frequency'] as int],
        weekdays:
            ((json['weekdays'] as List?)?.cast<int>() ?? const <int>[]).toSet(),
      );

  String toJsonString() => jsonEncode(toJson());
  factory TaskRecurrence.fromJsonString(String s) =>
      TaskRecurrence.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String get label {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        if (weekdays.isEmpty) return 'Weekly';
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final sorted = weekdays.toList()..sort();
        return sorted.map((d) => names[d - 1]).join(', ');
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TaskRecurrence &&
      other.frequency == frequency &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hash(frequency, weekdays.length);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The next date this recurrence should land on, strictly after [from]
/// (which is normally the task's current scheduled date). Handles
/// short-month/leap-year clamping for monthly/yearly (e.g. Jan 31 -> Feb 28).
DateTime nextRecurrenceDate(DateTime from, TaskRecurrence r) {
  final base = _dateOnly(from);
  switch (r.frequency) {
    case RecurrenceFrequency.daily:
      return base.add(const Duration(days: 1));

    case RecurrenceFrequency.weekly:
      if (r.weekdays.isEmpty) {
        return base.add(const Duration(days: 7));
      }
      var d = base.add(const Duration(days: 1));
      for (var i = 0; i < 8; i++) {
        if (r.weekdays.contains(d.weekday)) return d;
        d = d.add(const Duration(days: 1));
      }
      return base.add(const Duration(days: 7));

    case RecurrenceFrequency.monthly:
      var y = base.year;
      var m = base.month + 1;
      if (m > 12) {
        m = 1;
        y++;
      }
      final daysInMonth = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, base.day > daysInMonth ? daysInMonth : base.day);

    case RecurrenceFrequency.yearly:
      final y = base.year + 1;
      final daysInMonth = DateTime(y, base.month + 1, 0).day;
      return DateTime(y, base.month, base.day > daysInMonth ? daysInMonth : base.day);
  }
}
