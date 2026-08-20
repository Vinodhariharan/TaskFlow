import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';

class RecentExpensesResult {
  final List<Expense> items;
  final bool hasMore;
  const RecentExpensesResult({required this.items, required this.hasMore});
}

class ExpensePage {
  final List<Expense> items;
  final bool hasMore;
  const ExpensePage({required this.items, required this.hasMore});
}

class CategoryStat {
  final String categoryId;
  final double amount;
  final int count;
  const CategoryStat(
      {required this.categoryId, required this.amount, required this.count});
}

class ExpenseKpis {
  final double yearly;
  final double last30Days;
  final double monthlyAverage;
  final double thisMonth;
  const ExpenseKpis({
    required this.yearly,
    required this.last30Days,
    required this.monthlyAverage,
    required this.thisMonth,
  });
}

class ExpenseService {
  static const _expensesKey = 'expenses_v1';
  static const _uuid = Uuid();

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  // ── Low-level persistence ──────────────────────────────────────────────────

  Future<List<Expense>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_expensesKey) ?? [];
    return raw.map((s) => Expense.fromJsonString(s)).toList();
  }

  Future<void> _saveAll(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _expensesKey,
      expenses.map((e) => e.toJsonString()).toList(),
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<Expense> addExpense({
    required String title,
    required double amount,
    required String categoryId,
    required DateTime date,
    String? note,
  }) async {
    final all = await _loadAll();
    final expense = Expense(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    all.add(expense);
    await _saveAll(all);
    return expense;
  }

  Future<void> updateExpense(Expense updated) async {
    final all = await _loadAll();
    final idx = all.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    all[idx] = updated;
    await _saveAll(all);
  }

  Future<void> deleteExpense(String id) async {
    final all = await _loadAll();
    all.removeWhere((e) => e.id == id);
    await _saveAll(all);
  }

  /// Bulk-append pre-built expenses (e.g. from a CSV import) in one save,
  /// instead of one load+save cycle per expense.
  Future<void> importExpenses(List<Expense> expenses) async {
    if (expenses.isEmpty) return;
    final all = await _loadAll();
    all.addAll(expenses);
    await _saveAll(all);
  }

  /// Most recent expenses (newest first), capped at [limit].
  Future<RecentExpensesResult> getRecentExpenses({int limit = 12}) async {
    final all = await _loadAll();
    all.sort((a, b) => b.date.compareTo(a.date));
    return RecentExpensesResult(
      items: all.take(limit).toList(),
      hasMore: all.length > limit,
    );
  }

  /// Filtered + paginated query, newest first, for the All Expenses screen.
  Future<ExpensePage> queryExpenses({
    int page = 0,
    int pageSize = 20,
    Set<String>? categoryIds,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final all = await _loadAll();
    final start = startDate != null ? _dateOnly(startDate) : null;
    final end = endDate != null ? _dateOnly(endDate) : null;
    final query = searchQuery?.trim().toLowerCase();

    final filtered = all.where((e) {
      if (categoryIds != null &&
          categoryIds.isNotEmpty &&
          !categoryIds.contains(e.categoryId)) {
        return false;
      }
      final d = _dateOnly(e.date);
      if (start != null && d.isBefore(start)) return false;
      if (end != null && d.isAfter(end)) return false;
      if (query != null && query.isNotEmpty) {
        final inTitle = e.title.toLowerCase().contains(query);
        final inNote = (e.note ?? '').toLowerCase().contains(query);
        if (!inTitle && !inNote) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final from = page * pageSize;
    final to = (from + pageSize).clamp(0, filtered.length);
    final items = from < filtered.length ? filtered.sublist(from, to) : <Expense>[];
    return ExpensePage(items: items, hasMore: to < filtered.length);
  }

  /// Per-category spend + count within an optional date range, sorted by
  /// amount descending — for the KPI detail breakdown.
  Future<List<CategoryStat>> getCategoryBreakdown({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final all = await _loadAll();
    final start = startDate != null ? _dateOnly(startDate) : null;
    final end = endDate != null ? _dateOnly(endDate) : null;

    final amounts = <String, double>{};
    final counts = <String, int>{};
    for (final e in all) {
      final d = _dateOnly(e.date);
      if (start != null && d.isBefore(start)) continue;
      if (end != null && d.isAfter(end)) continue;
      amounts[e.categoryId] = (amounts[e.categoryId] ?? 0) + e.amount;
      counts[e.categoryId] = (counts[e.categoryId] ?? 0) + 1;
    }

    final stats = amounts.entries
        .map((e) => CategoryStat(
            categoryId: e.key, amount: e.value, count: counts[e.key] ?? 0))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return stats;
  }

  /// Distinct past expense titles, ranked by how often they've been used
  /// (ties broken by most recent use), for autocomplete suggestions.
  Future<List<String>> getTitleSuggestions() async {
    final all = await _loadAll();
    final freq = <String, int>{};
    final lastUsed = <String, DateTime>{};
    final display = <String, String>{};
    for (final e in all) {
      final key = e.title.trim().toLowerCase();
      if (key.isEmpty) continue;
      freq[key] = (freq[key] ?? 0) + 1;
      final existing = lastUsed[key];
      if (existing == null || e.date.isAfter(existing)) {
        lastUsed[key] = e.date;
        display[key] = e.title.trim();
      }
    }
    final keys = freq.keys.toList()
      ..sort((a, b) {
        final byFreq = freq[b]!.compareTo(freq[a]!);
        if (byFreq != 0) return byFreq;
        return lastUsed[b]!.compareTo(lastUsed[a]!);
      });
    return keys.map((k) => display[k]!).toList();
  }

  /// Total spend per calendar month (key = first-of-month DateTime), for
  /// whatever set of expenses matches the given filters — independent of
  /// pagination, so a month's total is always correct even if only part of
  /// that month's items have been paged in on screen.
  Future<Map<DateTime, double>> getMonthlyTotals({
    Set<String>? categoryIds,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final all = await _loadAll();
    final start = startDate != null ? _dateOnly(startDate) : null;
    final end = endDate != null ? _dateOnly(endDate) : null;
    final query = searchQuery?.trim().toLowerCase();

    final Map<DateTime, double> totals = {};
    for (final e in all) {
      if (categoryIds != null &&
          categoryIds.isNotEmpty &&
          !categoryIds.contains(e.categoryId)) {
        continue;
      }
      final d = _dateOnly(e.date);
      if (start != null && d.isBefore(start)) continue;
      if (end != null && d.isAfter(end)) continue;
      if (query != null && query.isNotEmpty) {
        final inTitle = e.title.toLowerCase().contains(query);
        final inNote = (e.note ?? '').toLowerCase().contains(query);
        if (!inTitle && !inNote) continue;
      }
      final key = DateTime(d.year, d.month, 1);
      totals[key] = (totals[key] ?? 0) + e.amount;
    }
    return totals;
  }

  /// Yearly / last-30-days / trailing-12-month monthly average / this-month totals.
  Future<ExpenseKpis> getKpis({DateTime? now}) async {
    final n = _dateOnly(now ?? DateTime.now());
    final all = await _loadAll();
    if (all.isEmpty) {
      return const ExpenseKpis(
          yearly: 0, last30Days: 0, monthlyAverage: 0, thisMonth: 0);
    }

    final yearStart = DateTime(n.year, 1, 1);
    final last30Start = n.subtract(const Duration(days: 29));
    final monthStart = DateTime(n.year, n.month, 1);
    final trailingWindowStart = DateTime(n.year, n.month - 11, 1);

    double yearly = 0, last30 = 0, thisMonth = 0, trailingSum = 0;
    DateTime? earliestMonth;

    for (final e in all) {
      final d = _dateOnly(e.date);
      if (!d.isAfter(n)) {
        if (!d.isBefore(yearStart)) yearly += e.amount;
        if (!d.isBefore(last30Start)) last30 += e.amount;
        if (!d.isBefore(monthStart)) thisMonth += e.amount;
        if (!d.isBefore(trailingWindowStart)) trailingSum += e.amount;
      }
      final em = DateTime(d.year, d.month, 1);
      if (earliestMonth == null || em.isBefore(earliestMonth)) {
        earliestMonth = em;
      }
    }

    final effectiveStart = earliestMonth!.isAfter(trailingWindowStart)
        ? earliestMonth
        : trailingWindowStart;
    final monthsCount =
        ((n.year - effectiveStart.year) * 12 + (n.month - effectiveStart.month) + 1)
            .clamp(1, 12);

    return ExpenseKpis(
      yearly: yearly,
      last30Days: last30,
      monthlyAverage: trailingSum / monthsCount,
      thisMonth: thisMonth,
    );
  }
}
