import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'add_edit_expense_sheet.dart';
import 'all_expenses_screen.dart';
import 'expense_widgets.dart';

class ExpensesHomeTab extends StatefulWidget {
  const ExpensesHomeTab({super.key});

  @override
  State<ExpensesHomeTab> createState() => _ExpensesHomeTabState();
}

class _ExpensesHomeTabState extends State<ExpensesHomeTab> {
  final _expenseService = ExpenseService();
  final _scrollController = ScrollController();

  late Future<ExpenseKpis> _kpisFuture;
  late Future<RecentExpensesResult> _recentFuture;
  bool _hasMoreRecent = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _kpisFuture = _expenseService.getKpis();
      _recentFuture = _expenseService.getRecentExpenses(limit: 12);
    });
    _recentFuture.then((r) {
      if (mounted) setState(() => _hasMoreRecent = r.hasMore);
    });
  }

  void _onScroll() {
    if (_navigated || !_hasMoreRecent) return;
    if (!_scrollController.hasClients) return;
    final threshold = MediaQuery.of(context).size.height * 0.9;
    if (_scrollController.position.pixels >= threshold) {
      _navigated = true;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AllExpensesScreen()))
          .then((_) {
        _navigated = false;
        if (mounted) _refresh();
      });
    }
  }

  Future<void> _showAddExpense({Expense? editExpense}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditExpenseSheet(
          expenseService: _expenseService, editExpense: editExpense),
    );
    _refresh();
  }

  Future<void> _deleteExpense(Expense expense) async {
    HapticFeedback.mediumImpact();
    await _expenseService.deleteExpense(expense.id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense deleted',
              style: TextStyle(color: context.textColor)),
          backgroundColor: context.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Undo',
            textColor: kExpenseAccent,
            onPressed: () async {
              await _expenseService.addExpense(
                title: expense.title,
                amount: expense.amount,
                category: expense.category,
                date: expense.date,
                note: expense.note,
              );
              _refresh();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExpenseKpis>(
      future: _kpisFuture,
      builder: (context, kpiSnap) {
        return FutureBuilder<RecentExpensesResult>(
          future: _recentFuture,
          builder: (context, recentSnap) {
            final kpis = kpiSnap.data;
            final recent = recentSnap.data?.items ?? [];
            final isEmpty = recentSnap.connectionState == ConnectionState.done &&
                recent.isEmpty;

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Text(
                      'Expenses',
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),

                // ── KPI grid ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        KpiCard(
                          label: 'This year',
                          value: kpis?.yearly ?? 0,
                          icon: Icons.calendar_month_rounded,
                        ),
                        KpiCard(
                          label: 'Last 30 days',
                          value: kpis?.last30Days ?? 0,
                          icon: Icons.date_range_rounded,
                        ),
                        KpiCard(
                          label: 'Monthly avg (12mo)',
                          value: kpis?.monthlyAverage ?? 0,
                          icon: Icons.bar_chart_rounded,
                        ),
                        KpiCard(
                          label: 'This month',
                          value: kpis?.thisMonth ?? 0,
                          icon: Icons.today_rounded,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Add expense button ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: GestureDetector(
                      onTap: () => _showAddExpense(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: kExpenseAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Add expense',
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
                  ),
                ),

                if (isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: EmptyExpenseState(
                        title: 'No expenses yet',
                        subtitle: 'Tap "Add expense" to log your first spend',
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                      child: Row(
                        children: [
                          Text('RECENT',
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              )),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${recent.length}',
                                style: TextStyle(
                                  color: context.mutedColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => ExpenseTile(
                        key: ValueKey(recent[i].id),
                        expense: recent[i],
                        onTap: () => _showAddExpense(editExpense: recent[i]),
                        onDelete: () => _deleteExpense(recent[i]),
                      ),
                      childCount: recent.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
