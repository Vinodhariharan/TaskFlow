import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/screens/habit_form_screen.dart';
import 'package:taskflow/screens/task_form_screen.dart';
import 'package:taskflow/services/task_service.dart';

/// The form screens pin their save button to the bottom of a Scaffold, which
/// already shrinks its body by the keyboard height. Adding the inset a second
/// time collapsed the scrollable area to nothing, leaving the save button as
/// the only visible thing on the page.
void main() {
  Future<void> pumpWithKeyboard(WidgetTester tester, Widget screen) async {
    // copyWith rather than a fabricated MediaQueryData: the test surface is
    // 800x600 and the reported size has to match it, or the assertions below
    // are measuring against a size the layout never had.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(viewInsets: const EdgeInsets.only(bottom: 250)),
            child: screen,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('habit form keeps its fields visible with the keyboard up',
      (tester) async {
    await pumpWithKeyboard(tester, const HabitFormScreen());

    // 600 tall minus a 250px keyboard leaves 350 for the page; the header
    // and save button take well under half of that, so the scrollable body
    // must still have real height. Double-counting the inset drove this to 0.
    final listHeight = tester.getSize(find.byType(ListView)).height;
    expect(listHeight, greaterThan(150));

    // And the thing you came here to type in is actually on screen.
    final nameField = find.byType(TextField).first;
    expect(tester.getBottomLeft(nameField).dy, lessThan(350));
  });

  testWidgets('task form keeps its fields visible with the keyboard up',
      (tester) async {
    await pumpWithKeyboard(
        tester, TaskFormScreen(taskService: TaskService()));

    expect(tester.getSize(find.byType(ListView)).height, greaterThan(150));
  });
}
