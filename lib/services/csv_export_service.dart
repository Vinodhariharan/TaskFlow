import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import 'category_service.dart';
import 'expense_service.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');

/// Quotes a CSV field only when needed (contains a comma, quote, or
/// newline), escaping embedded quotes as "" per RFC4180 — matches what
/// [parseCsvTable] in csv_import_service.dart expects to read back.
String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _row(List<String> fields) => fields.map(_csvField).join(',');

/// Builds CSV content for [expenses] using the same column shape as the
/// import template (Title,Amount,Date,Category,Note), so an exported file
/// can be re-imported unchanged.
String buildExpensesCsv(List<Expense> expenses) {
  final buffer = StringBuffer('Title,Amount,Date,Category,Note\n');
  for (final e in expenses) {
    final category = CategoryService.instance.getById(e.categoryId).label;
    buffer.writeln(_row([
      e.title,
      e.amount.toStringAsFixed(2),
      _dateFmt.format(e.date),
      category,
      e.note ?? '',
    ]));
  }
  return buffer.toString();
}

Uint8List csvBytes(String content) => Uint8List.fromList(utf8.encode(content));

/// Loads and exports either all expenses or those within [startDate,
/// endDate] (inclusive), newest first.
Future<String> exportExpensesCsv({
  required ExpenseService expenseService,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  final page = await expenseService.queryExpenses(
    page: 0,
    pageSize: 1 << 30,
    startDate: startDate,
    endDate: endDate,
  );
  return buildExpensesCsv(page.items);
}
