// Recurrence rule tests. (This file previously held the stock Flutter
// counter-app template test, which referenced a `MyApp` class this project
// has never had and so failed on every run.)

import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task_recurrence.dart';

void main() {
  group('nextRecurrenceDate', () {
    test('daily advances one day, across a month boundary', () {
      expect(
        nextRecurrenceDate(DateTime(2026, 1, 31),
            const TaskRecurrence(frequency: RecurrenceFrequency.daily)),
        DateTime(2026, 2, 1),
      );
    });

    test('weekly with no weekdays keeps the same weekday a week later', () {
      final from = DateTime(2026, 3, 4); // a Wednesday
      final next = nextRecurrenceDate(
          from, const TaskRecurrence(frequency: RecurrenceFrequency.weekly));
      expect(next, DateTime(2026, 3, 11));
      expect(next.weekday, from.weekday);
    });

    test('weekly with weekdays picks the next selected day', () {
      // Wed Mar 4 2026, repeating Mon/Wed/Fri -> next is Fri Mar 6.
      expect(
        nextRecurrenceDate(
          DateTime(2026, 3, 4),
          const TaskRecurrence(
              frequency: RecurrenceFrequency.weekly, weekdays: {1, 3, 5}),
        ),
        DateTime(2026, 3, 6),
      );
    });

    test('weekly with weekdays wraps around to the next week', () {
      // Fri Mar 6 2026, repeating Mon/Wed/Fri -> next is Mon Mar 9.
      expect(
        nextRecurrenceDate(
          DateTime(2026, 3, 6),
          const TaskRecurrence(
              frequency: RecurrenceFrequency.weekly, weekdays: {1, 3, 5}),
        ),
        DateTime(2026, 3, 9),
      );
    });

    test('monthly clamps to the last day of a shorter month', () {
      expect(
        nextRecurrenceDate(DateTime(2026, 1, 31),
            const TaskRecurrence(frequency: RecurrenceFrequency.monthly)),
        DateTime(2026, 2, 28),
      );
    });

    test('monthly rolls December into January of the next year', () {
      expect(
        nextRecurrenceDate(DateTime(2026, 12, 15),
            const TaskRecurrence(frequency: RecurrenceFrequency.monthly)),
        DateTime(2027, 1, 15),
      );
    });

    test('yearly clamps Feb 29 onto a non-leap year', () {
      expect(
        nextRecurrenceDate(DateTime(2028, 2, 29),
            const TaskRecurrence(frequency: RecurrenceFrequency.yearly)),
        DateTime(2029, 2, 28),
      );
    });

    test('every frequency returns a date strictly after the input', () {
      final from = DateTime(2026, 5, 20, 13, 45);
      for (final f in RecurrenceFrequency.values) {
        final next = nextRecurrenceDate(from, TaskRecurrence(frequency: f));
        expect(next.isAfter(DateTime(2026, 5, 20)), isTrue,
            reason: '$f should advance past the current scheduled date');
      }
    });
  });

  group('TaskRecurrence serialization', () {
    test('round-trips through JSON, weekdays included', () {
      const r = TaskRecurrence(
          frequency: RecurrenceFrequency.weekly, weekdays: {2, 4, 7});
      expect(TaskRecurrence.fromJsonString(r.toJsonString()), r);
    });

    test('tolerates missing weekdays', () {
      expect(
        TaskRecurrence.fromJson({'frequency': RecurrenceFrequency.daily.index}),
        const TaskRecurrence(frequency: RecurrenceFrequency.daily),
      );
    });
  });
}
