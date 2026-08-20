import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/expense.dart';
import 'category_service.dart';
import 'expense_service.dart';

/// The CSV template offered to the user, pre-filled with a couple of
/// example rows so the expected shape is obvious when opened in a
/// spreadsheet app. Column order doesn't matter on import — headers are
/// matched by name — but this is the order the template ships in.
const String csvTemplateContent =
    'Title,Amount,Date,Category,Note\n'
    'Coffee,4.50,2026-08-01,Food,Morning coffee\n'
    'Uber ride,12.00,2026-08-02,Transport,\n'
    'Groceries,45.30,2026-08-03,Shopping,Weekly shop\n';

Uint8List csvTemplateBytes() => Uint8List.fromList(utf8.encode(csvTemplateContent));

/// One data row parsed out of an imported CSV, validated but not yet turned
/// into an [Expense] (category names are only resolved to ids at commit
/// time, once the user has confirmed the import).
class ImportRow {
  final int lineNumber;
  final String? title;
  final double? amount;
  final DateTime? date;
  final String categoryLabel;
  final bool categoryIsNew;
  final String? note;
  final String? error;

  const ImportRow({
    required this.lineNumber,
    this.title,
    this.amount,
    this.date,
    required this.categoryLabel,
    required this.categoryIsNew,
    this.note,
    this.error,
  });

  bool get isValid => error == null;
}

class CsvParseResult {
  final List<ImportRow> rows;
  const CsvParseResult(this.rows);

  int get validCount => rows.where((r) => r.isValid).length;
  int get errorCount => rows.where((r) => !r.isValid).length;
  Set<String> get newCategoryLabels => {
        for (final r in rows)
          if (r.isValid && r.categoryIsNew) r.categoryLabel,
      };
}

/// Minimal RFC4180-style CSV parser: handles quoted fields, embedded
/// commas/newlines inside quotes, and "" as an escaped quote.
List<List<String>> parseCsvTable(String input) {
  var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.isEmpty) return const [];
  if (!text.endsWith('\n')) text += '\n';

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = [];
  }

  while (i < text.length) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (ch == ',') {
      endField();
      i++;
      continue;
    }
    if (ch == '\n') {
      endRow();
      i++;
      continue;
    }
    field.write(ch);
    i++;
  }

  return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
}

const List<String> _datePatterns = [
  'M/d/yyyy',
  'MM/dd/yyyy',
  'd/M/yyyy',
  'dd/MM/yyyy',
  'yyyy/MM/dd',
  'MMM d, yyyy',
  'd MMM yyyy',
];

DateTime? _parseDate(String raw) {
  if (raw.isEmpty) return null;
  final iso = DateTime.tryParse(raw);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  for (final pattern in _datePatterns) {
    try {
      final d = DateFormat(pattern).parseStrict(raw);
      return DateTime(d.year, d.month, d.day);
    } catch (_) {
      // try the next pattern
    }
  }
  return null;
}

/// Parses and validates a CSV file's contents against the template shape.
/// Pure/read-only: category names are only checked against the categories
/// that already exist, never created here.
CsvParseResult parseExpensesCsv(String content) {
  final table = parseCsvTable(content);
  if (table.isEmpty) return const CsvParseResult([]);

  var startIndex = 0;
  var titleCol = 0, amountCol = 1, dateCol = 2, categoryCol = 3, noteCol = 4;

  final headerRow = table.first.map((c) => c.trim().toLowerCase()).toList();
  if (headerRow.contains('title') && headerRow.contains('amount')) {
    startIndex = 1;
    titleCol = headerRow.indexOf('title');
    amountCol = headerRow.indexOf('amount');
    dateCol = headerRow.indexOf('date');
    categoryCol = headerRow.indexOf('category');
    noteCol = headerRow.indexOf('note');
  }

  final existingLabels = {
    for (final t in CategoryService.instance.all)
      t.label.trim().toLowerCase(): t.label,
  };

  final rows = <ImportRow>[];
  for (var i = startIndex; i < table.length; i++) {
    final cols = table[i];
    String col(int idx) => (idx >= 0 && idx < cols.length) ? cols[idx].trim() : '';

    final titleRaw = col(titleCol);
    final amountRaw = col(amountCol);
    final dateRaw = col(dateCol);
    final categoryRaw = col(categoryCol);
    final noteRaw = col(noteCol);

    final errors = <String>[];
    if (titleRaw.isEmpty) errors.add('Missing title');

    final cleanedAmount = amountRaw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final amount = amountRaw.isEmpty ? null : double.tryParse(cleanedAmount);
    if (amountRaw.isEmpty) {
      errors.add('Missing amount');
    } else if (amount == null) {
      errors.add('Invalid amount "$amountRaw"');
    } else if (amount <= 0) {
      errors.add('Amount must be greater than 0');
    }

    final date = _parseDate(dateRaw);
    if (dateRaw.isEmpty) {
      errors.add('Missing date');
    } else if (date == null) {
      errors.add('Unrecognized date "$dateRaw" (use YYYY-MM-DD)');
    } else if (date.isAfter(DateTime.now())) {
      errors.add('Date is in the future');
    }

    String categoryLabel;
    bool categoryIsNew;
    if (categoryRaw.isEmpty) {
      categoryLabel = kFallbackCategory.label;
      categoryIsNew = false;
    } else {
      final match = existingLabels[categoryRaw.toLowerCase()];
      if (match != null) {
        categoryLabel = match;
        categoryIsNew = false;
      } else {
        categoryLabel = categoryRaw;
        categoryIsNew = true;
      }
    }

    rows.add(ImportRow(
      lineNumber: i + 1,
      title: titleRaw.isEmpty ? null : titleRaw,
      amount: amount,
      date: date,
      categoryLabel: categoryLabel,
      categoryIsNew: categoryIsNew,
      note: noteRaw.isEmpty ? null : noteRaw,
      error: errors.isEmpty ? null : errors.join('; '),
    ));
  }
  return CsvParseResult(rows);
}

/// Turns the valid rows of a parsed CSV into real expenses: creates one new
/// custom tag per distinct unrecognized category name (never a duplicate,
/// even if several rows share that name), then bulk-saves the expenses.
/// Returns the number of expenses imported.
Future<int> commitCsvImport({
  required List<ImportRow> rows,
  required ExpenseService expenseService,
}) async {
  final validRows = rows.where((r) => r.isValid).toList();
  if (validRows.isEmpty) return 0;

  final labelToId = <String, String>{
    for (final t in CategoryService.instance.all)
      t.label.trim().toLowerCase(): t.id,
  };
  var newTagCount = CategoryService.instance.custom.length;

  const uuid = Uuid();
  final expenses = <Expense>[];
  for (final row in validRows) {
    final key = row.categoryLabel.trim().toLowerCase();
    var categoryId = labelToId[key];
    if (categoryId == null) {
      final created = await CategoryService.instance.addCustomCategory(
        label: row.categoryLabel.trim(),
        iconIndex: newTagCount % kCategoryIconChoices.length,
        colorIndex: newTagCount % kCategoryColorChoices.length,
      );
      newTagCount++;
      categoryId = created.id;
      labelToId[key] = categoryId;
    }
    expenses.add(Expense(
      id: uuid.v4(),
      title: row.title!,
      amount: row.amount!,
      categoryId: categoryId,
      date: row.date!,
      note: row.note,
    ));
  }

  await expenseService.importExpenses(expenses);
  return expenses.length;
}
