import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'add_edit_expense_sheet.dart';
import 'all_expenses_screen.dart';
import 'expense_widgets.dart';
import 'kpi_detail_screen.dart';
import 'view_expense_sheet.dart';

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
  double _pullProgress = 0.0;

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
    final pixels = _scrollController.position.pixels;
    final progress = (pixels / threshold).clamp(0.0, 1.0);
    if ((progress - _pullProgress).abs() > 0.01) {
      setState(() => _pullProgress = progress);
    }
    if (pixels >= threshold) {
      _navigated = true;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AllExpensesScreen()))
          .then((_) {
        _navigated = false;
        if (mounted) {
          setState(() => _pullProgress = 0.0);
          _refresh();
        }
      });
    }
  }

  void _openKpiDetail(String title, String subtitle, DateTime start, DateTime end) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KpiDetailScreen(
          title: title,
          subtitle: subtitle,
          startDate: start,
          endDate: end,
          expenseService: _expenseService,
        ),
      ),
    );
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

  Future<void> _showViewExpense(Expense expense) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ViewExpenseSheet(
        expense: expense,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _showAddExpense(editExpense: expense);
        },
      ),
    );
    _refresh();
  }

  Future<void> _deleteExpense(Expense expense) async {
    HapticFeedback.mediumImpact();
    await _expenseService.deleteExpense(expense.id);
    _refresh();
    if (mounted) {
      // See the matching comment in all_expenses_screen.dart — the app-wide
      // scaffoldMessengerKey keeps this snackbar showing consistently across
      // both expense screens instead of depending on ScaffoldMessenger.of().
      scaffoldMessengerKey.currentState!
        ..clearSnackBars()
        ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
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
                categoryId: expense.categoryId,
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

            return Stack(
              children: [
                CustomScrollView(
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

                // ── KPI section ──────────────────────────────────────────
                // A single hero card (This month — the number people check
                // most) plus three compact secondary stats in a row, instead
                // of four equally-weighted cards in a 2x2 grid. The old grid
                // gave every stat the same visual priority and repeated
                // "amount + label" four times with nothing to anchor on.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Builder(builder: (context) {
                      final now = DateTime.now();
                      return HeroKpiCard(
                        label: DateFormat('MMMM yyyy').format(now),
                        value: kpis?.thisMonth ?? 0,
                        icon: Icons.today_rounded,
                        onTap: () => _openKpiDetail(
                            'This Month',
                            DateFormat('MMMM yyyy').format(now),
                            DateTime(now.year, now.month, 1),
                            now),
                      );
                    }),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Builder(builder: (context) {
                            final now = DateTime.now();
                            return KpiCard(
                              label: 'This year',
                              value: kpis?.yearly ?? 0,
                              icon: Icons.calendar_month_rounded,
                              onTap: () => _openKpiDetail('This Year',
                                  '${now.year}', DateTime(now.year, 1, 1), now),
                            );
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Builder(builder: (context) {
                            final now = DateTime.now();
                            final start = now.subtract(const Duration(days: 29));
                            return KpiCard(
                              label: 'Last 30 days',
                              value: kpis?.last30Days ?? 0,
                              icon: Icons.date_range_rounded,
                              onTap: () => _openKpiDetail(
                                  'Last 30 Days', 'Rolling window', start, now),
                            );
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Builder(builder: (context) {
                            final now = DateTime.now();
                            final start = DateTime(now.year, now.month - 11, 1);
                            return KpiCard(
                              label: 'Monthly avg',
                              value: kpis?.monthlyAverage ?? 0,
                              icon: Icons.bar_chart_rounded,
                              onTap: () => _openKpiDetail('Monthly Average',
                                  'Trailing 12 months', start, now),
                            );
                          }),
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
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const AllExpensesScreen()),
                              );
                              _refresh();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View all',
                                  style: TextStyle(
                                    color: kExpenseAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.chevron_right_rounded,
                                    size: 16, color: kExpenseAccent),
                              ],
                            ),
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
                        onTap: () => _showViewExpense(recent[i]),
                        onDelete: () => _deleteExpense(recent[i]),
                      ),
                      childCount: recent.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
                ),
                if (_pullProgress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: (_pullProgress * 2).clamp(0.0, 1.0),
                          child: _PullToNavigateIndicator(progress: _pullProgress),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Bottom-anchored progress ring that fills as the user scrolls past the
/// end of the recent list, mirroring a pull-to-refresh spinner (as seen in
/// Google Search or Threads) but upside down: anchored at the bottom
/// instead of the top, filling as you scroll further instead of pulling
/// down, and pointing up (toward where All Expenses will open) instead of
/// down. Switches to an indeterminate spin right as the threshold is
/// crossed, the same way a refresh spinner does the instant it commits.
class _PullToNavigateIndicator extends StatelessWidget {
  final double progress;
  const _PullToNavigateIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    final triggered = progress >= 1.0;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              value: triggered ? null : progress,
              strokeWidth: 2.5,
              backgroundColor: context.subtleColor,
              valueColor: const AlwaysStoppedAnimation<Color>(kExpenseAccent),
            ),
          ),
          const Icon(Icons.keyboard_arrow_up_rounded,
              size: 16, color: kExpenseAccent),
        ],
      ),
    );
  }
}
