import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/services/task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('completing an overdue scheduled task keeps it visible today', () async {
    final service = TaskService();
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    final task = await service.addTask(
      title: 'Overdue thing',
      scheduledDate: yesterday,
    );

    var today = await service.getTodayTasks();
    expect(today.any((t) => t.id == task.id), isTrue,
        reason: 'overdue incomplete task should show today');

    await service.toggleComplete(task.id);

    today = await service.getTodayTasks();
    final found = today.where((t) => t.id == task.id);
    expect(found, isNotEmpty,
        reason:
            'completing an overdue task today must not remove it from the list');
    expect(found.first.isCompleted, isTrue);
  });

  test('completing a carried-over general task keeps it visible today',
      () async {
    final service = TaskService();

    final task = await service.addTask(title: 'Carried over thing');
    // Simulate it having been created yesterday (carried over to today).
    final all = await service.getAllTasks();
    final idx = all.indexWhere((t) => t.id == task.id);
    final now = DateTime.now();
    all[idx].createdDate = DateTime(now.year, now.month, now.day - 1);
    await SharedPreferences.getInstance().then((prefs) => prefs.setStringList(
        'tasks_v1', all.map((t) => t.toJsonString()).toList()));

    await service.toggleComplete(task.id);

    final today = await service.getTodayTasks();
    final found = today.where((t) => t.id == task.id);
    expect(found, isNotEmpty,
        reason:
            'completing a carried-over task today must not remove it from the list');
    expect(found.first.isCompleted, isTrue);
  });

  test('a task completed on a previous day drops off today\'s list',
      () async {
    final service = TaskService();
    final now = DateTime.now();
    final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    final task = await service.addTask(
      title: 'Old completed thing',
      scheduledDate: twoDaysAgo,
    );
    final all = await service.getAllTasks();
    final idx = all.indexWhere((t) => t.id == task.id);
    all[idx].isCompleted = true;
    all[idx].completedDate = yesterday;
    await SharedPreferences.getInstance().then((prefs) => prefs.setStringList(
        'tasks_v1', all.map((t) => t.toJsonString()).toList()));

    final today = await service.getTodayTasks();
    expect(today.any((t) => t.id == task.id), isFalse,
        reason:
            'a task completed on a prior day should not linger in today\'s list');
  });
}
