import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/services/expense_service.dart';

/// Multi-select delete has to remove exactly what was picked in one write,
/// and report it back so a single Undo can restore the whole set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ExpenseService> seeded(List<String> titles) async {
    final service = ExpenseService();
    for (final t in titles) {
      await service.addExpense(
        title: t,
        amount: 100,
        categoryId: 'food',
        date: DateTime(2026, 9, 1),
      );
    }
    return service;
  }

  test('deleteExpenses removes every id given and reports them', () async {
    final service = await seeded(['Coffee', 'Rent', 'Bus']);
    final all = await service.getRecentExpenses(limit: 10);
    final coffee = all.items.firstWhere((e) => e.title == 'Coffee');
    final bus = all.items.firstWhere((e) => e.title == 'Bus');

    final removed = await service.deleteExpenses([coffee.id, bus.id]);
    expect(removed.map((e) => e.title).toSet(), {'Coffee', 'Bus'});

    final left = await service.getRecentExpenses(limit: 10);
    expect(left.items.map((e) => e.title).toList(), ['Rent']);
  });

  test('an empty selection is a no-op', () async {
    final service = await seeded(['Coffee']);
    expect(await service.deleteExpenses(const []), isEmpty);
    expect((await service.getRecentExpenses(limit: 10)).items.length, 1);
  });

  test('ids that no longer exist are skipped rather than throwing', () async {
    final service = await seeded(['Coffee']);
    final removed = await service.deleteExpenses(['does-not-exist']);
    expect(removed, isEmpty);
    expect((await service.getRecentExpenses(limit: 10)).items.length, 1);
  });

  test('getExpenseById finds one, and returns null once it is gone',
      () async {
    final service = await seeded(['Coffee']);
    final coffee = (await service.getRecentExpenses(limit: 10)).items.single;

    expect((await service.getExpenseById(coffee.id))?.title, 'Coffee');
    await service.deleteExpense(coffee.id);
    // The detail page can outlive the thing it is showing.
    expect(await service.getExpenseById(coffee.id), isNull);
  });
}
