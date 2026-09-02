import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/services/habit_service.dart';
import 'package:taskflow/services/task_service.dart';

/// Manual ordering has to survive a reload and has to beat priority, or a
/// dragged task snaps back and the whole gesture reads as broken.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('task ordering', () {
    test('new tasks land at the end, not the top', () async {
      final service = TaskService();
      await service.addTask(title: 'First');
      await service.addTask(title: 'Second');
      await service.addTask(title: 'Third');

      final titles =
          (await service.getTodayTasks()).map((t) => t.title).toList();
      expect(titles, ['First', 'Second', 'Third']);
    });

    test('a drag outranks priority within the group', () async {
      final service = TaskService();
      final low = await service.addTask(title: 'Low');
      final high =
          await service.addTask(title: 'High', priority: TaskPriority.high);

      // Priority alone puts High first.
      expect((await service.getTodayTasks()).first.title, 'High');

      // Dragging Low above it has to stick.
      await service.reorderTasks([low.id, high.id]);
      expect(
        (await service.getTodayTasks()).map((t) => t.title).toList(),
        ['Low', 'High'],
      );
    });

    test('the order survives a reload', () async {
      final service = TaskService();
      final a = await service.addTask(title: 'A');
      final b = await service.addTask(title: 'B');
      final c = await service.addTask(title: 'C');
      await service.reorderTasks([c.id, a.id, b.id]);

      // A fresh service reads the same stored tasks back.
      final reloaded =
          (await TaskService().getTodayTasks()).map((t) => t.title).toList();
      expect(reloaded, ['C', 'A', 'B']);
    });

    test('reordering never lifts a completed task above a pending one',
        () async {
      final service = TaskService();
      final done = await service.addTask(title: 'Done');
      final todo = await service.addTask(title: 'Todo');
      await service.toggleComplete(done.id);

      // Even asked to put the completed one first, the grouping wins — it
      // is settled before sortIndex is ever consulted.
      await service.reorderTasks([done.id, todo.id]);
      final titles =
          (await service.getTodayTasks()).map((t) => t.title).toList();
      expect(titles, ['Todo', 'Done']);
    });

    test('a task added after a reorder still goes last', () async {
      final service = TaskService();
      final a = await service.addTask(title: 'A');
      final b = await service.addTask(title: 'B');
      await service.reorderTasks([b.id, a.id]);
      await service.addTask(title: 'C');

      expect(
        (await service.getTodayTasks()).map((t) => t.title).toList(),
        ['B', 'A', 'C'],
      );
    });

    test('ids that no longer exist are skipped rather than throwing',
        () async {
      final service = TaskService();
      final a = await service.addTask(title: 'A');
      final b = await service.addTask(title: 'B');
      await service.deleteTask(b.id);

      await service.reorderTasks([b.id, a.id]);
      expect((await service.getTodayTasks()).single.title, 'A');
    });
  });

  group('multi-delete', () {
    test('removes every id given and reports what it removed', () async {
      final service = TaskService();
      final a = await service.addTask(title: 'A');
      final b = await service.addTask(title: 'B');
      await service.addTask(title: 'C');

      final removed = await service.deleteTasks([a.id, b.id]);
      expect(removed.map((t) => t.title).toSet(), {'A', 'B'});
      expect((await service.getTodayTasks()).single.title, 'C');
    });

    test('an empty selection is a no-op', () async {
      final service = TaskService();
      await service.addTask(title: 'A');
      expect(await service.deleteTasks(const []), isEmpty);
      expect((await service.getTodayTasks()).length, 1);
    });
  });

  group('habit ordering', () {
    test('new habits land at the end and a drag survives a reload', () async {
      final service = HabitService();
      final a = await service.addHabit(name: 'A');
      final b = await service.addHabit(name: 'B');
      final c = await service.addHabit(name: 'C');
      expect((await service.getHabits()).map((h) => h.name).toList(),
          ['A', 'B', 'C']);

      await service.reorderHabits([c.id, b.id, a.id]);
      expect((await HabitService().getHabits()).map((h) => h.name).toList(),
          ['C', 'B', 'A']);
    });
  });
}
