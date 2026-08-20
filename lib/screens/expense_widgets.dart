import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/expense.dart';
import '../services/currency_settings.dart';

/// Accent color for the expense tab (kept local — not added to `main.dart`'s
/// `AppColors` since that file is intentionally left untouched).
const kExpenseAccent = Color(0xFF4CAF93);

// ─────────────────────────────────────────────────────────────────────────────
// Formatting & category metadata
// ─────────────────────────────────────────────────────────────────────────────

String formatCurrency(double amount, {bool decimals = false}) {
  final currency = CurrencySettings.instance.current;
  final fmt = NumberFormat.currency(
    locale: currency.locale,
    symbol: currency.symbol,
    decimalDigits: decimals ? 2 : 0,
  );
  return fmt.format(amount);
}

extension ExpenseCategoryX on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.health:
        return 'Health';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_car_filled_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_long_rounded;
      case ExpenseCategory.entertainment:
        return Icons.movie_rounded;
      case ExpenseCategory.health:
        return Icons.favorite_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFFF9F5A);
      case ExpenseCategory.transport:
        return const Color(0xFF5AB4FF);
      case ExpenseCategory.shopping:
        return const Color(0xFFFF6584);
      case ExpenseCategory.bills:
        return const Color(0xFFFFD166);
      case ExpenseCategory.entertainment:
        return const Color(0xFFB388FF);
      case ExpenseCategory.health:
        return const Color(0xFF4CD9A0);
      case ExpenseCategory.other:
        return const Color(0xFF9090A8);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI card
// ─────────────────────────────────────────────────────────────────────────────

class KpiCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final VoidCallback? onTap;

  const KpiCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CurrencySettings.instance,
      builder: (context, _) => Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: kExpenseAccent),
          const SizedBox(height: 12),
          Text(
            formatCurrency(value),
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category chip (single or multi select)
// ─────────────────────────────────────────────────────────────────────────────

class CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip(
      {super.key,
      required this.category,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? category.color.withValues(alpha: 0.15)
              : context.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? category.color : context.subtleColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon,
                size: 14, color: selected ? category.color : context.mutedColor),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                color: selected ? category.color : context.mutedColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expense tile
// ─────────────────────────────────────────────────────────────────────────────

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = expense.category;
    return ListenableBuilder(
      listenable: CurrencySettings.instance,
      builder: (context, _) => Dismissible(
      key: ValueKey('dismiss_expense_${expense.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: context.sheetBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: Text('Delete expense?',
                style: TextStyle(color: context.textColor)),
            content: Text(
              'Delete "${expense.title}"? This can be undone right after.',
              style: TextStyle(color: context.secondaryTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancel',
                    style: TextStyle(color: context.mutedColor)),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: context.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cat.icon, size: 18, color: cat.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cat.label} • ${DateFormat('MMM d, yyyy').format(expense.date)}',
                          style: TextStyle(
                              color: context.mutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency(expense.amount, decimals: true),
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared autocomplete suggestions dropdown (title fields, search field)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildSuggestionsOptionsView(
  BuildContext context,
  AutocompleteOnSelected<String> onSelected,
  Iterable<String> options,
  double width,
) {
  return Align(
    alignment: Alignment.topLeft,
    child: Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: context.cardColor,
      child: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, i) {
              final option = options.elementAt(i);
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 15, color: context.mutedColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(option,
                            style: TextStyle(
                                color: context.textColor, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Month banner (groups the All Expenses list by month, total on the left)
// ─────────────────────────────────────────────────────────────────────────────

class MonthBanner extends StatelessWidget {
  final DateTime month;
  final double total;
  const MonthBanner({super.key, required this.month, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kExpenseAccent.withValues(alpha: context.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatCurrency(total, decimals: true),
            style: const TextStyle(
              color: kExpenseAccent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month).toUpperCase(),
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class EmptyExpenseState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyExpenseState({
    super.key,
    this.title = 'No expenses yet',
    this.subtitle = 'Add your first expense',
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 32, color: context.subtleColor),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  color: context.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(color: context.mutedColor, fontSize: 14)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: kExpenseAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(actionLabel!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
