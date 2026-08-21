import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
import '../services/currency_settings.dart';

/// Accent color for the expense tab (kept local — not added to `main.dart`'s
/// `AppColors` since that file is intentionally left untouched).
const kExpenseAccent = Color(0xFF4CAF93);

// ─────────────────────────────────────────────────────────────────────────────
// Formatting
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

/// A larger, full-width KPI card used as the single "hero" stat on the
/// Expenses home tab, with the remaining KPIs shown as smaller [KpiCard]s
/// beneath it — replaces an earlier 2x2 grid of four equally-weighted cards.
class HeroKpiCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final VoidCallback? onTap;

  const HeroKpiCard(
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
        color: kExpenseAccent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCurrency(value, decimals: true),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
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
  final Tag category;
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

/// A dashed "add new" chip, styled to sit alongside CategoryChip in a Wrap.
class AddCategoryChip extends StatelessWidget {
  final VoidCallback onTap;
  const AddCategoryChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.subtleColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: context.mutedColor),
            const SizedBox(width: 4),
            Text(
              'New tag',
              style: TextStyle(
                color: context.mutedColor,
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

/// Opens a dialog to create a custom category (name + icon + color), and
/// returns the created Category, or null if cancelled.
Future<Tag?> showAddCategoryDialog(BuildContext context) {
  return _showCategoryFormDialog(context, existing: null);
}

/// Opens a dialog to edit an existing category's name/icon/color (built-in
/// or custom) and returns the updated Tag, or null if cancelled.
Future<Tag?> showEditCategoryDialog(BuildContext context, Tag existing) {
  return _showCategoryFormDialog(context, existing: existing);
}

Future<Tag?> _showCategoryFormDialog(BuildContext context, {Tag? existing}) {
  final isEdit = existing != null;
  final controller = TextEditingController(text: existing?.label ?? '');
  int iconIndex = existing?.iconIndex ?? 0;
  int colorIndex = existing?.colorIndex ?? 0;

  return showDialog<Tag>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        backgroundColor: context.sheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isEdit ? 'Edit tag' : 'New tag',
            style: TextStyle(color: context.textColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: context.textColor),
                decoration: InputDecoration(
                  hintText: 'Tag name',
                  hintStyle: TextStyle(color: context.mutedColor),
                  filled: true,
                  fillColor: context.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Icon',
                  style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < kCategoryIconChoices.length; i++)
                    GestureDetector(
                      onTap: () => setDialogState(() => iconIndex = i),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: iconIndex == i
                              ? kCategoryColorChoices[colorIndex]
                                  .withValues(alpha: 0.2)
                              : context.inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: iconIndex == i
                              ? Border.all(
                                  color: kCategoryColorChoices[colorIndex],
                                  width: 1.5)
                              : null,
                        ),
                        child: Icon(kCategoryIconChoices[i],
                            size: 17,
                            color: iconIndex == i
                                ? kCategoryColorChoices[colorIndex]
                                : context.mutedColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Color',
                  style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (int i = 0; i < kCategoryColorChoices.length; i++)
                    GestureDetector(
                      onTap: () => setDialogState(() => colorIndex = i),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: kCategoryColorChoices[i],
                          shape: BoxShape.circle,
                          border: colorIndex == i
                              ? Border.all(color: context.textColor, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: context.mutedColor)),
          ),
          TextButton(
            onPressed: () async {
              final label = controller.text.trim();
              if (label.isEmpty) return;
              final Tag category;
              if (isEdit) {
                category = Tag(
                  id: existing.id,
                  label: label,
                  iconIndex: iconIndex,
                  colorIndex: colorIndex,
                  isBuiltIn: existing.isBuiltIn,
                );
                await CategoryService.instance.updateCategory(category);
              } else {
                category = await CategoryService.instance.addCustomCategory(
                    label: label, iconIndex: iconIndex, colorIndex: colorIndex);
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(category);
              }
            },
            child: Text(isEdit ? 'Save' : 'Create',
                style: const TextStyle(color: kExpenseAccent)),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Expense tile
// ─────────────────────────────────────────────────────────────────────────────

class ExpenseTile extends StatefulWidget {
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
  State<ExpenseTile> createState() => _ExpenseTileState();
}

/// Swipe-left reveals a fixed-width delete icon behind the tile (capped at
/// [_revealWidth] — the swipe itself never deletes); tapping that icon
/// deletes immediately, with no confirmation dialog. This replaces a
/// full-swipe-to-dismiss gesture that was too easy to trigger by accident
/// while scrolling.
class _ExpenseTileState extends State<ExpenseTile>
    with SingleTickerProviderStateMixin {
  static const _revealWidth = 72.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => _controller.animateTo(0.0, curve: Curves.easeOut);

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _controller.value = (_controller.value - delta / _revealWidth).clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity < -300 || (velocity <= 300 && _controller.value > 0.5);
    _controller.animateTo(open ? 1.0 : 0.0, curve: Curves.easeOut);
  }

  void _handleTap() {
    if (_controller.value > 0) {
      _close();
      return;
    }
    widget.onTap();
  }

  void _handleDelete() {
    HapticFeedback.mediumImpact();
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([CurrencySettings.instance, CategoryService.instance]),
      builder: (context, _) {
        final cat = CategoryService.instance.getById(widget.expense.categoryId);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          decoration: BoxDecoration(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      GestureDetector(
                        onTap: _handleDelete,
                        child: Container(
                          width: _revealWidth,
                          color: AppColors.danger,
                          alignment: Alignment.center,
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(-_revealWidth * _controller.value, 0),
                    child: child,
                  ),
                  child: GestureDetector(
                    onHorizontalDragUpdate: _handleDragUpdate,
                    onHorizontalDragEnd: _handleDragEnd,
                    child: Material(
                      color: context.cardColor,
                      child: InkWell(
                        onTap: _handleTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
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
                                      widget.expense.title,
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
                                      '${cat.label} • ${DateFormat('MMM d, yyyy').format(widget.expense.date)}',
                                      style: TextStyle(
                                          color: context.mutedColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatCurrency(widget.expense.amount, decimals: true),
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
              ],
            ),
          ),
        );
      },
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
