import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/models/task.dart';

/// Long-press multi-select replaced swipe-to-delete, so the gestures that
/// enter and leave it are the whole feature — a tap that opens a task when
/// the user meant to select it is the failure mode worth guarding.
///
/// Tasks are seeded straight into storage rather than through
/// TaskService.addTask: that call also schedules a reminder, and a platform
/// channel never replies inside testWidgets' fake-async zone, so awaiting it
/// hangs the test. What multi-delete does to storage is covered directly in
/// reorder_test.dart, where there's no widget binding in the way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void seed(List<String> titles) {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'tasks_v1': [
        for (var i = 0; i < titles.length; i++)
          Task(
            id: 'task-$i',
            title: titles[i],
            createdDate: now,
          ).toJsonString(),
      ],
    });
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(notifier: ThemeNotifier(ThemeMode.dark))),
    );
    // Bounded pumps rather than pumpAndSettle: the screen carries animations
    // that never come to rest, so settling would spin forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('the list opens tasks until a long-press starts a selection',
      (tester) async {
    seed(['Alpha', 'Beta']);
    await pumpHome(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.textContaining('selected'), findsNothing);

    await tester.longPress(find.text('Alpha'));
    await settle(tester);
    expect(find.text('1 selected'), findsOneWidget);

    // A plain tap now picks rather than opening the task's page — no route
    // was pushed, so the list is still what's on screen.
    await tester.tap(find.text('Beta'));
    await settle(tester);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);

    // Tapping a selected task takes it back out.
    await tester.tap(find.text('Beta'));
    await settle(tester);
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('the selection bar offers delete and reorder', (tester) async {
    seed(['Alpha']);
    await pumpHome(tester);

    await tester.longPress(find.text('Alpha'));
    await settle(tester);

    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Reorder'), findsOneWidget);
  });

  testWidgets('closing the bar leaves selection mode', (tester) async {
    seed(['Alpha']);
    await pumpHome(tester);

    await tester.longPress(find.text('Alpha'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await settle(tester);

    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('the add button steps aside while selecting', (tester) async {
    seed(['Alpha']);
    await pumpHome(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.longPress(find.text('Alpha'));
    await settle(tester);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
