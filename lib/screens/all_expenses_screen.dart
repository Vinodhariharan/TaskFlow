import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
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
  // Hoisted — see the matching comment in add_edit_expense_sheet.dart: a
  // FocusNode created inline in build() breaks mid-edit focus continuity.
  final _searchFocusNode = FocusNode();
  Timer? _debounce;

  final Set<String> _selectedCategoryIds = {};
  DateTimeRange? _dateRange;

  List<Expense> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _isLoadingPage = false;
  bool _initialLoad = true;
  Map<DateTime, double> _monthlyTotals = {};
  List<String> _titleSuggestions = [];

  static DateTime _monthKey(Expense e) =>
      DateTime(e.date.year, e.date.month, 1);

  bool get _filtersActive =>
      _selectedCategoryIds.isNotEmpty ||
      _dateRange != null ||
      _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    CategoryService.instance.load();
    _loadMore();
    _loadMonthlyTotals();
    _expenseService.getTitleSuggestions().then((titles) {
      if (mounted) setState(() => _titleSuggestions = titles);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds,
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
      categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds,
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
    _loadMonthlyTotals();
    if (mounted) {
      // Routed through the app-wide scaffoldMessengerKey (not
      // ScaffoldMessenger.of(context)) so the Undo snackbar reliably shows
      // up regardless of which expense screen triggered the delete and
      // which one is on top when it's shown.
      scaffoldMessengerKey.currentState!
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text('Expense deleted',
                style: TextStyle(color: context.textColor)),
            backgroundColor: context.cardColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                _resetAndReload();
              },
            ),
          ),
        );
    }
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

            // Search (with suggestions from previously used titles)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return RawAutocomplete<String>(
                    textEditingController: _searchController,
                    focusNode: _searchFocusNode,
                    optionsBuilder: (value) {
                      final q = value.text.trim().toLowerCase();
                      if (q.isEmpty) return const Iterable<String>.empty();
                      return _titleSuggestions
                          .where((t) => t.toLowerCase().contains(q))
                          .take(6);
                    },
                    onSelected: (_) => _resetAndReload(),
                    fieldViewBuilder: (context, controller, focusNode, _) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: _onSearchChanged,
                        style: TextStyle(
                            color: context.textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search expenses',
                          hintStyle: TextStyle(
                              color: context.mutedColor, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 20, color: context.mutedColor),
                          filled: true,
                          fillColor: context.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) =>
                        buildSuggestionsOptionsView(context, onSelected,
                            options, constraints.maxWidth),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Category chips
            SizedBox(
              height: 40,
              child: ListenableBuilder(
                listenable: CategoryService.instance,
                builder: (context, _) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final cat in CategoryService.instance.all) ...[
                      CategoryChip(
                        category: cat,
                        selected: _selectedCategoryIds.contains(cat.id),
                        onTap: () {
                          setState(() {
                            if (_selectedCategoryIds.contains(cat.id)) {
                              _selectedCategoryIds.remove(cat.id);
                            } else {
                              _selectedCategoryIds.add(cat.id);
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
                                    _selectedCategoryIds.clear();
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
