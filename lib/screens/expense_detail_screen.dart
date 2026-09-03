import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
import '../services/expense_change_notifier.dart';
import '../services/expense_service.dart';
import 'add_edit_expense_sheet.dart';
import 'expense_widgets.dart';

/// One expense in full, with Edit and Delete on it.
///
/// A page rather than the bottom sheet this replaces: the sheet had to stay
/// short enough not to swallow the screen, which left no room for the
/// actions to sit anywhere sensible. Mirrors TaskDetailScreen, including
/// re-reading on every change so an edit made here is reflected before the
/// page rebuilds.
class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _service = ExpenseService();
  Expense? _expense;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ExpenseChangeNotifier.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ExpenseChangeNotifier.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final found = await _service.getExpenseById(widget.expenseId);
    if (!mounted) return;
    setState(() {
      _expense = found;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final expense = _expense;
    if (expense == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditExpenseSheet(
        expenseService: _service,
        editExpense: expense,
      ),
    );
    await _load();
  }

  Future<void> _delete() async {
    final expense = _expense;
    if (expense == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.sheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete this expense?',
            style: TextStyle(color: context.textColor)),
        content: Text(
          '"${expense.title}" will be removed.',
          style: TextStyle(color: context.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: context.mutedColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
    await _service.deleteExpense(expense.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final expense = _expense;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
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
                    'Expense',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : expense == null
                      ? Center(
                          child: Text(
                            'This expense no longer exists.',
                            style: TextStyle(color: context.mutedColor),
                          ),
                        )
                      : _body(context, expense),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Expense expense) {
    final cat = CategoryService.instance.getById(expense.categoryId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(cat.icon, size: 24, color: cat.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cat.label,
                    style: TextStyle(
                        color: cat.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          formatCurrency(expense.amount, decimals: true),
          style: TextStyle(
            color: context.textColor,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        _DetailRow(
          icon: Icons.calendar_today_rounded,
          label: 'Date',
          value: DateFormat('EEEE, MMM d, yyyy').format(expense.date),
        ),
        if (expense.note != null && expense.note!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.notes_rounded,
            label: 'Note',
            value: expense.note!,
          ),
        ],
        const SizedBox(height: 28),
        _ActionButton(
          icon: Icons.edit_rounded,
          label: 'Edit expense',
          onTap: _edit,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.delete_outline_rounded,
          label: 'Delete expense',
          danger: true,
          onTap: _delete,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.mutedColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(color: context.textColor, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : context.textColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: danger
              ? Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
