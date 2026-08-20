import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'add_edit_expense_sheet.dart';
import 'expense_widgets.dart';
import 'view_expense_sheet.dart';

class AllExpensesScreen extends StatefulWidget {
  const AllExpensesScreen({super.key});

  @override
  State<AllExpensesScreen> createState() => _AllExpensesScreenState();
}

class _AllExpensesScreenState extends State<AllExpensesScreen> {
  final _expenseService = ExpenseService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  final Set<ExpenseCategory> _selectedCategories = {};
  DateTimeRange? _dateRange;

  List<Expense> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _isLoadingPage = false;
  bool _initialLoad = true;
  Map<DateTime, double> _monthlyTotals = {};

  static DateTime _monthKey(Expense e) =>
      DateTime(e.date.year, e.date.month, 1);

  bool get _filtersActive =>
      _selectedCategories.isNotEmpty ||
      _dateRange != null ||
      _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
    _loadMonthlyTotals();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _resetAndReload);
  }

  void _resetAndReload() {
    setState(() {
      _items = [];
      _page = 0;
      _hasMore = true;
      _initialLoad = true;
    });
    _loadMore();
    _loadMonthlyTotals();
  }

  Future<void> _loadMonthlyTotals() async {
    final totals = await _expenseService.getMonthlyTotals(
      categories: _selectedCategories.isEmpty ? null : _selectedCategories,
      startDate: _dateRange?.start,
      endDate: _dateRange?.end,
      searchQuery: _searchController.text,
    );
    if (!mounted) return;
    setState(() => _monthlyTotals = totals);
  }

  Future<void> _loadMore() async {
    if (_isLoadingPage || !_hasMore) return;
    setState(() => _isLoadingPage = true);
    final result = await _expenseService.queryExpenses(
      page: _page,
      pageSize: 20,
      categories: _selectedCategories.isEmpty ? null : _selectedCategories,
      startDate: _dateRange?.start,
      endDate: _dateRange?.end,
      searchQuery: _searchController.text,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(result.items);
      _hasMore = result.hasMore;
      _page += 1;
      _isLoadingPage = false;
      _initialLoad = false;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: context.sheetBg,
                  onSurface: context.textColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _resetAndReload();
    }
  }

  Future<void> _showEditExpense(Expense expense) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditExpenseSheet(
          expenseService: _expenseService, editExpense: expense),
    );
    _resetAndReload();
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
          _showEditExpense(expense);
        },
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    HapticFeedback.mediumImpact();
    await _expenseService.deleteExpense(expense.id);
    setState(() => _items.removeWhere((e) => e.id == expense.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    'All Expenses',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(color: context.textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search expenses',
                  hintStyle: TextStyle(color: context.mutedColor, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 20, color: context.mutedColor),
                  filled: true,
                  fillColor: context.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final cat in ExpenseCategory.values) ...[
                    CategoryChip(
                      category: cat,
                      selected: _selectedCategories.contains(cat),
                      onTap: () {
                        setState(() {
                          if (_selectedCategories.contains(cat)) {
                            _selectedCategories.remove(cat);
                          } else {
                            _selectedCategories.add(cat);
                          }
                        });
                        _resetAndReload();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Date range
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickDateRange,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _dateRange != null
                            ? kExpenseAccent.withValues(alpha: 0.12)
                            : context.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _dateRange != null
                              ? kExpenseAccent
                              : context.subtleColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: _dateRange != null
                                ? kExpenseAccent
                                : context.mutedColor,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _dateRange != null
                                ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
                                : 'Date range',
                            style: TextStyle(
                              color: _dateRange != null
                                  ? kExpenseAccent
                                  : context.mutedColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_dateRange != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() => _dateRange = null);
                        _resetAndReload();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: context.inputBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: context.mutedColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: _initialLoad
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? EmptyExpenseState(
                          title: _filtersActive
                              ? 'No expenses match your filters'
                              : 'No expenses yet',
                          subtitle: _filtersActive
                              ? 'Try a different search or clear filters'
                              : 'Add your first expense',
                          actionLabel: _filtersActive ? 'Clear filters' : null,
                          onAction: _filtersActive
                              ? () {
                                  setState(() {
                                    _selectedCategories.clear();
                                    _dateRange = null;
                                    _searchController.clear();
                                  });
                                  _resetAndReload();
                                }
                              : null,
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            }
                            final e = _items[i];
                            final key = _monthKey(e);
                            final isNewMonth =
                                i == 0 || _monthKey(_items[i - 1]) != key;
                            final tile = ExpenseTile(
                              key: ValueKey(e.id),
                              expense: e,
                              onTap: () => _showViewExpense(e),
                              onDelete: () => _deleteExpense(e),
                            );
                            if (!isNewMonth) return tile;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MonthBanner(
                                  month: key,
                                  total: _monthlyTotals[key] ?? 0,
                                ),
                                tile,
                              ],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
