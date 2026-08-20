import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/csv_import_service.dart';
import '../services/expense_service.dart';
import 'expense_widgets.dart';

class ImportExpensesScreen extends StatefulWidget {
  final ExpenseService expenseService;
  const ImportExpensesScreen({super.key, required this.expenseService});

  @override
  State<ImportExpensesScreen> createState() => _ImportExpensesScreenState();
}

class _ImportExpensesScreenState extends State<ImportExpensesScreen> {
  String? _fileName;
  CsvParseResult? _result;
  bool _busy = false;
  int? _importedCount;

  Future<void> _saveTemplate() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save expense import template',
        fileName: 'taskflow_expenses_template.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: csvTemplateBytes(),
      );
      if (!mounted || path == null) return;
      _showSnack(
          'Template saved. Open it in Excel/Sheets, fill in your expenses, then import below.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not save the template: $e');
    }
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(const ClipboardData(text: csvTemplateContent));
    if (!mounted) return;
    _showSnack('Template copied — paste into a spreadsheet app to start filling it in.');
  }

  Future<void> _pickFile() async {
    setState(() {
      _result = null;
      _importedCount = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      _showSnack('Could not read that file.');
      return;
    }
    final content = utf8.decode(bytes, allowMalformed: true);
    final parsed = parseExpensesCsv(content);
    if (!mounted) return;
    setState(() {
      _fileName = result.files.first.name;
      _result = parsed;
    });
  }

  Future<void> _confirmImport() async {
    final result = _result;
    if (result == null || result.validCount == 0) return;
    setState(() => _busy = true);
    final count = await commitCsvImport(
      rows: result.rows,
      expenseService: widget.expenseService,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _importedCount = count;
      _result = null;
      _fileName = null;
    });
    _showSnack('Imported $count expense${count == 1 ? '' : 's'}.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 18, color: context.textColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Import Expenses',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _label(context, 'TEMPLATE'),
            _card(
              context,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Columns: Title, Amount, Date, Category, Note',
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep the header row. Date uses YYYY-MM-DD (e.g. 2026-08-15). '
                      'Category matches an existing tag by name (case-insensitive) — '
                      'unrecognized names automatically become new tags. Category and '
                      'Note are optional.',
                      style: TextStyle(
                          color: context.mutedColor, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(context, 'Save template file',
                              Icons.download_rounded, _saveTemplate),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionButton(context, 'Copy template',
                              Icons.copy_rounded, _copyTemplate,
                              filled: false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label(context, 'IMPORT'),
            _card(
              context,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _actionButton(context, 'Choose CSV file',
                        Icons.upload_file_rounded, _busy ? null : _pickFile),
                    if (_fileName != null) ...[
                      const SizedBox(height: 10),
                      Text(_fileName!,
                          style: TextStyle(
                              color: context.mutedColor, fontSize: 12)),
                    ],
                    if (_importedCount != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: kExpenseAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Imported $_importedCount expense${_importedCount == 1 ? '' : 's'}.',
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 20),
              _label(context, 'PREVIEW'),
              _card(
                context,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _statChip(
                              context, '${result.validCount} valid', kExpenseAccent),
                          if (result.errorCount > 0) ...[
                            const SizedBox(width: 8),
                            _statChip(context, '${result.errorCount} skipped',
                                AppColors.danger),
                          ],
                        ],
                      ),
                      if (result.newCategoryLabels.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'New tags will be created: ${result.newCategoryLabels.join(', ')}',
                          style: TextStyle(
                              color: context.mutedColor, fontSize: 12),
                        ),
                      ],
                      if (result.errorCount > 0) ...[
                        const SizedBox(height: 12),
                        ...result.rows.where((r) => !r.isValid).take(20).map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Row ${r.lineNumber}: ${r.error}',
                                  style: const TextStyle(
                                      color: AppColors.danger, fontSize: 12),
                                ),
                              ),
                            ),
                        if (result.errorCount > 20)
                          Text('+ ${result.errorCount - 20} more',
                              style: TextStyle(
                                  color: context.mutedColor, fontSize: 12)),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: _actionButton(
                          context,
                          _busy
                              ? 'Importing…'
                              : 'Import ${result.validCount} expense${result.validCount == 1 ? '' : 's'}',
                          Icons.check_rounded,
                          result.validCount > 0 && !_busy
                              ? _confirmImport
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Text(
          text,
          style: TextStyle(
            color: context.mutedColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      );

  Widget _card(BuildContext context, {required Widget child}) => Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _statChip(BuildContext context, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style:
                TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _actionButton(
      BuildContext context, String label, IconData icon, VoidCallback? onTap,
      {bool filled = true}) {
    final enabled = onTap != null;
    final fg = filled
        ? Colors.white
        : (enabled ? context.textColor : context.mutedColor);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled
              ? (enabled ? kExpenseAccent : context.subtleColor)
              : context.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: context.subtleColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
