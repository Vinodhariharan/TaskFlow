import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/habit.dart';
import '../models/habit_stats.dart';
import '../services/habit_change_notifier.dart';
import '../services/habit_service.dart';
import 'habit_form_screen.dart';

/// One habit in full: how it's going, and the history that makes a habit
/// worth separating from a recurring task in the first place.
class HabitDetailScreen extends StatefulWidget {
  final String habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  static const _heatmapWeeks = 12;

  final _service = HabitService();
  Habit? _habit;
  Map<String, int> _log = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HabitChangeNotifier.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    HabitChangeNotifier.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final habit = await _service.getHabitById(widget.habitId);
    final log = await _service.logFor(widget.habitId);
    if (!mounted) return;
    setState(() {
      _habit = habit;
      _log = log;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final habit = _habit;
    if (habit == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HabitFormScreen(editHabit: habit)),
    );
    await _load();
  }

  Future<void> _toggleArchived() async {
    final habit = _habit;
    if (habit == null) return;
    HapticFeedback.selectionClick();
    await _service.setArchived(habit.id, !habit.archived);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(
          habit.archived
              ? '"${habit.name}" is back in your daily list'
              : '"${habit.name}" archived — its history is kept',
          style: TextStyle(color: context.textColor),
        ),
        backgroundColor: context.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _delete() async {
    final habit = _habit;
    if (habit == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.sheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title:
            Text('Delete this habit?', style: TextStyle(color: context.textColor)),
        content: Text(
          '"${habit.name}" and its entire history will be removed. '
          'Archiving keeps the record instead.',
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
    await _service.deleteHabit(habit.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Habit',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final habit = _habit;
    if (habit == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'This habit no longer exists.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedColor, fontSize: 15),
          ),
        ),
      );
    }

    final streak = currentStreak(habit, _log);
    final best = bestStreak(habit, _log);
    final rate = completionRate(habit, _log, days: 30);
    final target = habit.targetCount < 1 ? 1 : habit.targetCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: habit.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(habit.icon, size: 24, color: habit.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        target == 1 ? 'Once a day' : '$target× a day',
                        if (habit.activeWeekdays.isNotEmpty)
                          _weekdaySummary(habit.activeWeekdays),
                        if (habit.archived) 'Archived',
                      ].join(' · '),
                      style:
                          TextStyle(color: context.mutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Streak',
                value: '$streak',
                suffix: streak == 1 ? 'day' : 'days',
                color: habit.color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Best',
                value: '$best',
                suffix: best == 1 ? 'day' : 'days',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '30 days',
                value: '${(rate * 100).round()}',
                suffix: '%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text('LAST $_heatmapWeeks WEEKS',
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            )),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _Heatmap(habit: habit, log: _log, weeks: _heatmapWeeks),
        ),
        const SizedBox(height: 20),

        _ActionButton(
          icon: Icons.edit_rounded,
          label: 'Edit habit',
          onTap: _edit,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: habit.archived
              ? Icons.unarchive_outlined
              : Icons.archive_outlined,
          label: habit.archived ? 'Restore habit' : 'Archive habit',
          onTap: _toggleArchived,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.delete_outline_rounded,
          label: 'Delete habit',
          danger: true,
          onTap: _delete,
        ),
      ],
    );
  }

  static String _weekdaySummary(Set<int> days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = days.toList()..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }
}

/// A GitHub-style grid: one column per week, one square per day, shaded by
/// how much of that day's target was met. Days the habit isn't scheduled on
/// are drawn faintly so a weekdays-only habit reads as a pattern rather than
/// as a wall of misses.
class _Heatmap extends StatelessWidget {
  final Habit habit;
  final Map<String, int> log;
  final int weeks;

  const _Heatmap(
      {required this.habit, required this.log, required this.weeks});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    // Start on the Monday of the earliest week shown, so columns line up as
    // whole weeks with weekdays reading top to bottom.
    final startOfThisWeek =
        todayOnly.subtract(Duration(days: todayOnly.weekday - 1));
    final start = startOfThisWeek.subtract(Duration(days: (weeks - 1) * 7));
    final created = DateTime(habit.createdDate.year, habit.createdDate.month,
        habit.createdDate.day);
    final target = habit.targetCount < 1 ? 1 : habit.targetCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Size the squares to the available width rather than fixing them,
        // so the grid fits any phone without scrolling.
        const gap = 3.0;
        final cell = ((constraints.maxWidth - gap * (weeks - 1)) / weeks)
            .clamp(6.0, 18.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var w = 0; w < weeks; w++)
                  Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Builder(builder: (context) {
                          final day =
                              start.add(Duration(days: w * 7 + d));
                          final future = day.isAfter(todayOnly);
                          final beforeStart = day.isBefore(created);
                          final scheduled = habit.isActiveOn(day);
                          final count = log[habitDateKey(day)] ?? 0;

                          Color color;
                          if (future || beforeStart || !scheduled) {
                            // Nothing was expected — draw it as absent, not
                            // as a miss.
                            color =
                                context.subtleColor.withValues(alpha: 0.18);
                          } else if (count <= 0) {
                            color =
                                context.subtleColor.withValues(alpha: 0.45);
                          } else {
                            // Partial days shade towards the full colour so
                            // "3 of 8" is visibly different from both 0 and 8.
                            final progress =
                                (count / target).clamp(0.0, 1.0);
                            color = habit.color
                                .withValues(alpha: 0.3 + 0.7 * progress);
                          }

                          return Padding(
                            padding: EdgeInsets.only(bottom: gap),
                            child: Container(
                              width: cell,
                              height: cell,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(DateFormat('MMM d').format(start),
                    style:
                        TextStyle(color: context.mutedColor, fontSize: 10)),
                const Spacer(),
                Text('Today',
                    style:
                        TextStyle(color: context.mutedColor, fontSize: 10)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: context.mutedColor, fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color ?? context.textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Text(suffix,
                  style: TextStyle(color: context.mutedColor, fontSize: 11)),
            ],
          ),
        ],
      ),
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
