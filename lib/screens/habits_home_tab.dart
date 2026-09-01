import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/habit.dart';
import '../models/habit_stats.dart';
import '../services/habit_change_notifier.dart';
import '../services/habit_service.dart';
import 'habit_detail_screen.dart';
import 'habit_form_screen.dart';

/// Today's habits: what's expected today, how far through each one you are,
/// and the streak you'd break by skipping it.
///
/// Deliberately not styled like the Tasks list even though it looks similar.
/// A habit that hasn't been done yet is neutral, never overdue-red — the
/// whole point of separating habits from tasks is that missing one isn't a
/// failure state.
class HabitsHomeTab extends StatefulWidget {
  const HabitsHomeTab({super.key});

  @override
  State<HabitsHomeTab> createState() => _HabitsHomeTabState();
}

class _HabitsHomeTabState extends State<HabitsHomeTab> {
  final _service = HabitService();

  List<Habit> _habits = [];
  Map<String, int> _counts = {};
  Map<String, Map<String, int>> _logs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HabitChangeNotifier.instance.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    HabitChangeNotifier.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final habits = await _service.getTodayHabits();
    final counts = await _service.getTodayCounts();
    // Streaks need each habit's full log; fetched once here rather than per
    // row so the list doesn't do N reads on every rebuild.
    final logs = <String, Map<String, int>>{};
    for (final h in habits) {
      logs[h.id] = await _service.logFor(h.id);
    }
    if (!mounted) return;
    setState(() {
      _habits = habits;
      _counts = counts;
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _openForm({Habit? edit}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HabitFormScreen(editHabit: edit)),
    );
    await _refresh();
  }

  Future<void> _openDetail(Habit habit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habit.id)),
    );
    await _refresh();
  }

  Future<void> _onTick(Habit habit) async {
    HapticFeedback.lightImpact();
    if (habit.isSimple) {
      await _service.toggle(habit);
    } else {
      await _service.increment(habit);
    }
    await _refresh();
  }

  Future<void> _onUntick(Habit habit) async {
    HapticFeedback.selectionClick();
    await _service.decrement(habit);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());
    final doneToday = _habits
        .where((h) => isDoneOn(h, _logs[h.id] ?? const {}, DateTime.now()))
        .length;

    return Scaffold(
      backgroundColor: context.bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Habits',
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_habits.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '$doneToday/${_habits.length}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (_habits.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyHabits(onAdd: () => _openForm()),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final habit = _habits[i];
                          return _HabitTile(
                            key: ValueKey(habit.id),
                            habit: habit,
                            count: _counts[habit.id] ?? 0,
                            streak: currentStreak(
                                habit, _logs[habit.id] ?? const {}),
                            onTick: () => _onTick(habit),
                            onUntick: () => _onUntick(habit),
                            onOpen: () => _openDetail(habit),
                          );
                        },
                        childCount: _habits.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  final Habit habit;
  final int count;
  final int streak;
  final VoidCallback onTick;
  final VoidCallback onUntick;
  final VoidCallback onOpen;

  const _HabitTile({
    super.key,
    required this.habit,
    required this.count,
    required this.streak,
    required this.onTick,
    required this.onUntick,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final target = habit.targetCount < 1 ? 1 : habit.targetCount;
    final done = count >= target;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: habit.color.withValues(alpha: done ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(habit.icon, size: 19, color: habit.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (streak > 0) ...[
                            Icon(Icons.local_fire_department_rounded,
                                size: 13, color: habit.color),
                            const SizedBox(width: 3),
                            Text(
                              '$streak day${streak == 1 ? '' : 's'}',
                              style: TextStyle(
                                  color: habit.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ] else
                            Text(
                              done ? 'Done today' : 'Not yet today',
                              style: TextStyle(
                                  color: context.mutedColor, fontSize: 12),
                            ),
                          if (!habit.isSimple) ...[
                            const SizedBox(width: 8),
                            Text(
                              '$count/$target${habit.unit != null ? ' ${habit.unit}' : ''}',
                              style: TextStyle(
                                  color: context.mutedColor, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Counted habits get a −/+ pair; simple ones a single tick.
                // Both stop the tap from reaching the row's InkWell.
                if (!habit.isSimple && count > 0) ...[
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    onTap: onUntick,
                    color: context.mutedColor,
                    background: context.inputBg,
                  ),
                  const SizedBox(width: 6),
                ],
                _RoundButton(
                  icon: done ? Icons.check_rounded : Icons.add_rounded,
                  onTap: onTick,
                  color: done ? Colors.white : habit.color,
                  background:
                      done ? habit.color : habit.color.withValues(alpha: 0.12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color background;

  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyHabits({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement_rounded,
                size: 52, color: context.subtleColor),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: TextStyle(
                color: context.textColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Habits are for things you want to do regularly. Unlike tasks, '
              'missing one never counts against you — it just breaks the streak.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.mutedColor, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Add a habit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
