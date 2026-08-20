import 'package:flutter/material.dart';
import '../main.dart';
import '../services/category_service.dart';
import '../services/expense_service.dart';
import 'expense_widgets.dart';

class KpiDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final DateTime startDate;
  final DateTime endDate;
  final ExpenseService expenseService;

  const KpiDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.startDate,
    required this.endDate,
    required this.expenseService,
  });

  @override
  State<KpiDetailScreen> createState() => _KpiDetailScreenState();
}

class _KpiDetailScreenState extends State<KpiDetailScreen> {
  late Future<List<CategoryStat>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.expenseService.getCategoryBreakdown(
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: FutureBuilder<List<CategoryStat>>(
          future: _statsFuture,
          builder: (context, snap) {
            final stats = snap.data ?? [];
            final total = stats.fold<double>(0, (sum, s) => sum + s.amount);
            final maxAmount = stats.isEmpty
                ? 0.0
                : stats.map((s) => s.amount).reduce((a, b) => a > b ? a : b);

            return ListView(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                                color: context.mutedColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (snap.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (stats.isEmpty)
                  EmptyExpenseState(
                    title: 'No expenses in this period',
                    subtitle: 'Nothing logged for ${widget.subtitle.toLowerCase()}',
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL SPEND',
                            style: TextStyle(
                              color: context.mutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            )),
                        const SizedBox(height: 6),
                        Text(
                          formatCurrency(total, decimals: true),
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('BY CATEGORY',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      )),
                  const SizedBox(height: 12),
                  for (final stat in stats) ...[
                    _CategoryStatRow(
                      stat: stat,
                      total: total,
                      maxAmount: maxAmount,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryStatRow extends StatelessWidget {
  final CategoryStat stat;
  final double total;
  final double maxAmount;

  const _CategoryStatRow({
    required this.stat,
    required this.total,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final cat = CategoryService.instance.getById(stat.categoryId);
    final pct = total == 0 ? 0.0 : stat.amount / total;
    final barFraction = maxAmount == 0 ? 0.0 : stat.amount / maxAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cat.icon, size: 16, color: cat.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cat.label,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatCurrency(stat.amount, decimals: true),
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 6,
              backgroundColor: context.subtleColor,
              valueColor: AlwaysStoppedAnimation<Color>(cat.color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(pct * 100).toStringAsFixed(0)}% · ${stat.count} expense${stat.count == 1 ? '' : 's'}',
            style: TextStyle(color: context.mutedColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
