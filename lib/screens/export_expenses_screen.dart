import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/csv_export_service.dart';
import '../services/expense_service.dart';
import 'expense_widgets.dart';

enum _ExportScope { all, range }

class ExportExpensesScreen extends StatefulWidget {
  final ExpenseService expenseService;
  const ExportExpensesScreen({super.key, required this.expenseService});

  @override
  State<ExportExpensesScreen> createState() => _ExportExpensesScreenState();
}

class _ExportExpensesScreenState extends State<ExportExpensesScreen> {
  _ExportScope _scope = _ExportScope.all;
  DateTimeRange? _range;
  bool _busy = false;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _range,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: kExpenseAccent,
                  onPrimary: Colors.white,
                  surface: context.sheetBg,
                  onSurface: context.textColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _export() async {
    if (_scope == _ExportScope.range && _range == null) {
      _showSnack('Pick a date range first.');
      return;
    }
    setState(() => _busy = true);
    final content = await exportExpensesCsv(
      expenseService: widget.expenseService,
      startDate: _scope == _ExportScope.range ? _range!.start : null,
      endDate: _scope == _ExportScope.range ? _range!.end : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    final suffix = _scope == _ExportScope.range
        ? '_${DateFormat('yyyyMMdd').format(_range!.start)}-${DateFormat('yyyyMMdd').format(_range!.end)}'
        : '';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save expense export',
        fileName: 'taskflow_expenses$suffix.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: csvBytes(content),
      );
      if (!mounted || path == null) return;
      _showSnack('Export saved. Opens in Excel, Sheets, or any spreadsheet app.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not save the export: $e');
    }
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
                  'Export Expenses',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
              child: Text(
                'RANGE',
                style: TextStyle(
                  color: context.mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _ScopeRow(
                    title: 'All expenses',
                    selected: _scope == _ExportScope.all,
                    onTap: () => setState(() => _scope = _ExportScope.all),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1, color: context.subtleColor),
                  ),
                  _ScopeRow(
                    title: 'Selected date range',
                    selected: _scope == _ExportScope.range,
                    onTap: () => setState(() => _scope = _ExportScope.range),
                    subtitle: _scope == _ExportScope.range
                        ? GestureDetector(
                            onTap: _pickRange,
                            child: Text(
                              _range != null
                                  ? '${DateFormat('MMM d, yyyy').format(_range!.start)} – ${DateFormat('MMM d, yyyy').format(_range!.end)}'
                                  : 'Tap to choose a range',
                              style: const TextStyle(
                                color: kExpenseAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _busy ? null : _export,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kExpenseAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_busy) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                    ] else ...[
                      const Icon(Icons.download_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    const Text(
                      'Export to CSV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Saved as a .csv file that opens in Excel, Google Sheets, or any spreadsheet app.',
              style: TextStyle(color: context.mutedColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget? subtitle;

  const _ScopeRow(
      {required this.title, required this.selected, required this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? kExpenseAccent : context.mutedColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(color: context.textColor, fontSize: 14)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      subtitle!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
