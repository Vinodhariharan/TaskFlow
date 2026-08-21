import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/category_service.dart';
import '../services/expense_service.dart';
import 'expense_widgets.dart';

enum _ChartMode { category, trend }

enum _DurationPreset { last7, last30, thisMonth, last3m, last6m, thisYear, custom }

const _presetOrder = [
  _DurationPreset.last7,
  _DurationPreset.last30,
  _DurationPreset.thisMonth,
  _DurationPreset.last3m,
  _DurationPreset.last6m,
  _DurationPreset.thisYear,
  _DurationPreset.custom,
];

String _presetLabel(_DurationPreset p) {
  switch (p) {
    case _DurationPreset.last7:
      return '7D';
    case _DurationPreset.last30:
      return '30D';
    case _DurationPreset.thisMonth:
      return 'This month';
    case _DurationPreset.last3m:
      return '3M';
    case _DurationPreset.last6m:
      return '6M';
    case _DurationPreset.thisYear:
      return 'This year';
    case _DurationPreset.custom:
      return 'Custom';
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Range for a preset, relative to [now]. Returns null for [_DurationPreset.custom]
/// since that range comes from the date-range picker, not a formula.
({DateTime start, DateTime end})? _presetRange(_DurationPreset p, DateTime now) {
  final today = _dateOnly(now);
  switch (p) {
    case _DurationPreset.last7:
      return (start: today.subtract(const Duration(days: 6)), end: today);
    case _DurationPreset.last30:
      return (start: today.subtract(const Duration(days: 29)), end: today);
    case _DurationPreset.thisMonth:
      return (start: DateTime(today.year, today.month, 1), end: today);
    case _DurationPreset.last3m:
      return (start: DateTime(today.year, today.month - 2, 1), end: today);
    case _DurationPreset.last6m:
      return (start: DateTime(today.year, today.month - 5, 1), end: today);
    case _DurationPreset.thisYear:
      return (start: DateTime(today.year, 1, 1), end: today);
    case _DurationPreset.custom:
      return null;
  }
}

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
  _ChartMode _mode = _ChartMode.category;
  late _DurationPreset _preset;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  bool _compare = false;

  late Future<List<CategoryStat>> _statsFuture;
  Future<TrendResult>? _trendFuture;
  Future<TrendResult>? _prevTrendFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = _dateOnly(widget.startDate);
    _rangeEnd = _dateOnly(widget.endDate);
    _preset = _DurationPreset.custom;
    for (final p in _presetOrder) {
      final r = _presetRange(p, now);
      if (r != null && r.start == _rangeStart && r.end == _rangeEnd) {
        _preset = p;
        break;
      }
    }
    _reload();
  }

  void _reload() {
    setState(() {
      _statsFuture = widget.expenseService
          .getCategoryBreakdown(startDate: _rangeStart, endDate: _rangeEnd);
      if (_mode == _ChartMode.trend) {
        _trendFuture = widget.expenseService
            .getTrend(startDate: _rangeStart, endDate: _rangeEnd);
        if (_compare) {
          final spanDays = _rangeEnd.difference(_rangeStart).inDays + 1;
          final prevEnd = _rangeStart.subtract(const Duration(days: 1));
          final prevStart = prevEnd.subtract(Duration(days: spanDays - 1));
          _prevTrendFuture = widget.expenseService
              .getTrend(startDate: prevStart, endDate: prevEnd);
        } else {
          _prevTrendFuture = null;
        }
      } else {
        _trendFuture = null;
        _prevTrendFuture = null;
      }
    });
  }

  void _selectPreset(_DurationPreset p) {
    if (p == _DurationPreset.custom) {
      _pickCustomRange();
      return;
    }
    final r = _presetRange(p, DateTime.now())!;
    setState(() {
      _preset = p;
      _rangeStart = r.start;
      _rangeEnd = r.end;
    });
    _reload();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
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
    if (picked == null) return;
    setState(() {
      _preset = _DurationPreset.custom;
      _rangeStart = _dateOnly(picked.start);
      _rangeEnd = _dateOnly(picked.end);
    });
    _reload();
  }

  void _setMode(_ChartMode m) {
    if (m == _mode) return;
    setState(() => _mode = m);
    _reload();
  }

  void _setCompare(bool value) {
    setState(() => _compare = value);
    _reload();
  }

  String get _rangeLabel {
    if (_preset != _DurationPreset.custom) return _presetLabel(_preset);
    final fmt = DateFormat('MMM d, yyyy');
    return '${fmt.format(_rangeStart)} – ${fmt.format(_rangeEnd)}';
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A fixed "Stats" title rather than repeating whichever
                      // KPI card was tapped (which just showed the same name
                      // twice) — the specific KPI and its range move to the
                      // subtitle below.
                      Text(
                        'Stats',
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${widget.title} • $_rangeLabel',
                        style: TextStyle(color: context.mutedColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Chart mode toggle
            _ModeToggle(mode: _mode, onChanged: _setMode),
            const SizedBox(height: 12),

            // Duration presets
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in _presetOrder) ...[
                    _PresetChip(
                      label: p == _DurationPreset.custom && _preset == p
                          ? _rangeLabel
                          : _presetLabel(p),
                      selected: _preset == p,
                      icon: p == _DurationPreset.custom
                          ? Icons.calendar_today_rounded
                          : null,
                      onTap: () => _selectPreset(p),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),

            if (_mode == _ChartMode.trend) ...[
              const SizedBox(height: 12),
              _ComparisonToggle(enabled: _compare, onChanged: _setCompare),
            ],

            const SizedBox(height: 20),

            FutureBuilder<List<CategoryStat>>(
              future: _statsFuture,
              builder: (context, statsSnap) {
                final stats = statsSnap.data ?? [];
                final total = stats.fold<double>(0, (sum, s) => sum + s.amount);
                final loading = statsSnap.connectionState != ConnectionState.done;

                if (loading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (stats.isEmpty) {
                  return EmptyExpenseState(
                    title: 'No expenses in this period',
                    subtitle: 'Nothing logged for ${_rangeLabel.toLowerCase()}',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_mode == _ChartMode.category) ...[
                      _CategoryDonutCard(stats: stats, total: total),
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
                        _CategoryStatRow(stat: stat, total: total),
                        const SizedBox(height: 10),
                      ],
                    ] else
                      _TrendSection(
                        total: total,
                        trendFuture: _trendFuture!,
                        prevTrendFuture: _prevTrendFuture,
                        compare: _compare,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode toggle / duration chips / comparison toggle
// ─────────────────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final _ChartMode mode;
  final ValueChanged<_ChartMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(context, 'Category', _ChartMode.category, Icons.donut_large_rounded)),
          Expanded(child: _segment(context, 'Trend', _ChartMode.trend, Icons.show_chart_rounded)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, _ChartMode value, IconData icon) {
    final selected = mode == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kExpenseAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : context.mutedColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.mutedColor,
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

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  const _PresetChip(
      {required this.label, required this.selected, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kExpenseAccent.withValues(alpha: 0.14) : context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? kExpenseAccent : context.subtleColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? kExpenseAccent : context.mutedColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? kExpenseAccent : context.mutedColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _ComparisonToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _option(context, 'No comparison', !enabled, () => onChanged(false)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _option(context, 'Vs. previous period', enabled, () => onChanged(true)),
        ),
      ],
    );
  }

  Widget _option(BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kExpenseAccent.withValues(alpha: 0.14) : context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? kExpenseAccent : context.subtleColor, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? kExpenseAccent : context.mutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category mode: donut chart + total
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryDonutCard extends StatelessWidget {
  final List<CategoryStat> stats;
  final double total;
  const _CategoryDonutCard({required this.stats, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _DonutChartPainter(stats: stats, total: total),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TOTAL',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        )),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatCurrency(total, decimals: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategoryStat> stats;
  final double total;
  const _DonutChartPainter({required this.stats, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    const strokeWidth = 24.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final gap = stats.length > 1 ? 0.035 : 0.0;
    var startAngle = -pi / 2;
    for (final s in stats) {
      final rawSweep = (s.amount / total) * 2 * pi;
      final sweep = max(0.0, rawSweep - gap);
      final paint = Paint()
        ..color = CategoryService.instance.getById(s.categoryId).color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.stats != stats || oldDelegate.total != total;
}

/// Compact per-category row: icon, label, amount, and a percentage/count
/// caption. Deliberately has no bar of its own — the donut chart above
/// already shows share-of-total visually, so a second bar per row here
/// would just repeat the same proportion twice.
class _CategoryStatRow extends StatelessWidget {
  final CategoryStat stat;
  final double total;

  const _CategoryStatRow({required this.stat, required this.total});

  @override
  Widget build(BuildContext context) {
    final cat = CategoryService.instance.getById(stat.categoryId);
    final pct = total == 0 ? 0.0 : stat.amount / total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.label,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}% · ${stat.count} expense${stat.count == 1 ? '' : 's'}',
                  style: TextStyle(color: context.mutedColor, fontSize: 12),
                ),
              ],
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend mode: bar chart + optional previous-period comparison
// ─────────────────────────────────────────────────────────────────────────────

class _TrendSection extends StatelessWidget {
  final double total;
  final Future<TrendResult> trendFuture;
  final Future<TrendResult>? prevTrendFuture;
  final bool compare;

  const _TrendSection({
    required this.total,
    required this.trendFuture,
    required this.prevTrendFuture,
    required this.compare,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrendResult>(
      future: trendFuture,
      builder: (context, trendSnap) {
        final points = trendSnap.data?.points ?? [];
        final granularity = trendSnap.data?.granularity ?? TrendGranularity.day;
        if (trendSnap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return FutureBuilder<TrendResult>(
          future: prevTrendFuture,
          builder: (context, prevSnap) {
            final prevPoints = compare ? prevSnap.data?.points : null;
            final prevTotal =
                prevPoints?.fold<double>(0, (s, p) => s + p.amount);

            return Container(
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
                  if (compare && prevTotal != null) ...[
                    const SizedBox(height: 8),
                    _DeltaRow(current: total, previous: prevTotal),
                  ],
                  const SizedBox(height: 20),
                  _TrendChart(
                    points: points,
                    comparePoints: compare ? prevPoints : null,
                    granularity: granularity,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DeltaRow extends StatelessWidget {
  final double current;
  final double previous;
  const _DeltaRow({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    final diff = current - previous;
    final pct = previous == 0 ? (current == 0 ? 0.0 : 1.0) : diff / previous;
    final up = diff > 0;
    final color = diff == 0
        ? context.mutedColor
        : (up ? AppColors.danger : kExpenseAccent);
    return Row(
      children: [
        Icon(
          diff == 0
              ? Icons.remove_rounded
              : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${(pct.abs() * 100).toStringAsFixed(0)}% vs previous period (${formatCurrency(previous, decimals: true)})',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final List<TrendPoint>? comparePoints;
  final TrendGranularity granularity;

  const _TrendChart({
    required this.points,
    required this.comparePoints,
    required this.granularity,
  });

  String _label(DateTime d) {
    switch (granularity) {
      case TrendGranularity.day:
      case TrendGranularity.week:
        return DateFormat('d/M').format(d);
      case TrendGranularity.month:
        return DateFormat('MMM').format(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxVal = [
      ...points.map((p) => p.amount),
      ...?comparePoints?.map((p) => p.amount),
    ].fold<double>(0, (m, v) => v > m ? v : m);

    return SizedBox(
      height: 170,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < points.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _BarColumn(
                  point: points[i],
                  comparePoint: comparePoints != null && i < comparePoints!.length
                      ? comparePoints![i]
                      : null,
                  maxVal: maxVal,
                  label: _label(points[i].bucketStart),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final TrendPoint point;
  final TrendPoint? comparePoint;
  final double maxVal;
  final String label;

  const _BarColumn({
    required this.point,
    required this.comparePoint,
    required this.maxVal,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    const barAreaHeight = 130.0;
    final factor = maxVal == 0 ? 0.0 : (point.amount / maxVal).clamp(0.0, 1.0);
    final compareFactor = comparePoint == null || maxVal == 0
        ? 0.0
        : (comparePoint!.amount / maxVal).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: barAreaHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (comparePoint != null) ...[
                _bar(context, compareFactor, barAreaHeight,
                    color: context.subtleColor, width: 8),
                const SizedBox(width: 3),
              ],
              _bar(context, factor, barAreaHeight, color: kExpenseAccent, width: 8),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(color: context.mutedColor, fontSize: 9)),
      ],
    );
  }

  Widget _bar(BuildContext context, double factor, double areaHeight,
      {required Color color, required double width}) {
    return Container(
      width: width,
      height: max(2.0, areaHeight * factor),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
