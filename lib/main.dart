import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/task.dart';
import 'services/task_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode');
  final initialMode =
      savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
  runApp(ThemeNotifierWrapper(initialMode: initialMode));
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode;
  ThemeNotifier(this._mode);
  ThemeMode get mode => _mode;

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'theme_mode', _mode == ThemeMode.light ? 'light' : 'dark');
  }
}

class ThemeNotifierWrapper extends StatefulWidget {
  final ThemeMode initialMode;
  const ThemeNotifierWrapper({super.key, required this.initialMode});
  @override
  State<ThemeNotifierWrapper> createState() => _ThemeNotifierWrapperState();
}

class _ThemeNotifierWrapperState extends State<ThemeNotifierWrapper> {
  late final ThemeNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ThemeNotifier(widget.initialMode);
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) => TaskFlowApp(notifier: _notifier),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App & Themes
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const danger = Color(0xFFFF6584);
  static const overdueColor = Color(0xFFFF6B6B);
  static const dueTodayColor = Color(0xFFFFD166);

  static const darkBg = Color(0xFF0E0E10);
  static const darkSurface = Color(0xFF1A1A1F);
  static const darkCard = Color(0xFF1A1A1F);
  static const darkSubtle = Color(0xFF3A3A4A);
  static const darkMuted = Color(0xFF555568);
  static const darkSecondaryText = Color(0xFF9090A8);
  static const darkText = Color(0xFFE8E8F0);

  static const lightBg = Color(0xFFF5F5FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSubtle = Color(0xFFDDDDE8);
  static const lightMuted = Color(0xFFAAAAAE);
  static const lightSecondaryText = Color(0xFF7878A0);
  static const lightText = Color(0xFF18181C);
}

ThemeData _darkTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.danger,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
      ),
      useMaterial3: true,
    );

ThemeData _lightTheme() => ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.danger,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
      ),
      useMaterial3: true,
    );

class TaskFlowApp extends StatelessWidget {
  final ThemeNotifier notifier;
  const TaskFlowApp({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      themeMode: notifier.mode,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: HomeScreen(notifier: notifier),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme helpers
// ─────────────────────────────────────────────────────────────────────────────

extension AppTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bgColor => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get cardColor => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get subtleColor =>
      isDark ? AppColors.darkSubtle : AppColors.lightSubtle;
  Color get mutedColor => isDark ? AppColors.darkMuted : AppColors.lightMuted;
  Color get secondaryTextColor =>
      isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
  Color get textColor => isDark ? AppColors.darkText : AppColors.lightText;
  Color get inputBg => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get sheetBg =>
      isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get handleColor =>
      isDark ? AppColors.darkSubtle : AppColors.lightSubtle;
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final ThemeNotifier notifier;
  const HomeScreen({super.key, required this.notifier});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _taskService = TaskService();
  late Future<List<Task>> _todayFuture;
  late Future<Map<DateTime, List<Task>>> _scheduledFuture;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _refresh();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _todayFuture = _taskService.getTodayTasks();
      _scheduledFuture = _taskService.getScheduledTasks();
    });
  }

  Future<void> _showAddTask({Task? editTask}) async {
    if (editTask == null) {
      _fabController.forward().then((_) => _fabController.reverse());
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AddTaskSheet(taskService: _taskService, editTask: editTask),
    );
    _refresh();
  }

  Future<void> _toggleTask(Task task) async {
    HapticFeedback.lightImpact();
    await _taskService.toggleComplete(task.id);
    _refresh();
  }

  Future<void> _deleteTask(Task task) async {
    HapticFeedback.mediumImpact();
    await _taskService.deleteTask(task.id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task deleted',
              style: TextStyle(color: context.textColor)),
          backgroundColor: context.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primary,
            onPressed: () async {
              await _taskService.addTask(
                title: task.title,
                note: task.note,
                priority: task.priority,
                scheduledDate: task.scheduledDate,
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
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: FutureBuilder<List<Task>>(
          future: _todayFuture,
          builder: (context, todaySnap) {
            return FutureBuilder<Map<DateTime, List<Task>>>(
              future: _scheduledFuture,
              builder: (context, scheduledSnap) {
                final todayTasks = todaySnap.data ?? [];
                final scheduledMap = scheduledSnap.data ?? {};
                final pending =
                    todayTasks.where((t) => !t.isCompleted).toList();
                final completed =
                    todayTasks.where((t) => t.isCompleted).toList();
                final carriedOver =
                    pending.where((t) => t.isCarriedOver).length;
                final overdueCount =
                    pending.where((t) => t.isOverdue).length;
                final totalScheduledFuture = scheduledMap.values
                    .fold(0, (sum, list) => sum + list.length);

                final isEmpty =
                    todayTasks.isEmpty && scheduledMap.isEmpty;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Header ──────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'My Tasks',
                                      style: TextStyle(
                                        color: context.textColor,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (todayTasks.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: context.cardColor,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${completed.length}/${todayTasks.length}',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        widget.notifier.toggle();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 300),
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: context.cardColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                              milliseconds: 300),
                                          transitionBuilder:
                                              (child, anim) =>
                                                  RotationTransition(
                                            turns: anim,
                                            child: FadeTransition(
                                                opacity: anim,
                                                child: child),
                                          ),
                                          child: Icon(
                                            isDark
                                                ? Icons.light_mode_rounded
                                                : Icons.dark_mode_rounded,
                                            key: ValueKey(isDark),
                                            color: context.mutedColor,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Carry-over badge
                            if (carriedOver > 0) ...[
                              const SizedBox(height: 10),
                              _CarryoverBadge(count: carriedOver),
                            ],
                            // Overdue badge
                            if (overdueCount > 0) ...[
                              const SizedBox(height: 6),
                              _OverdueBadge(count: overdueCount),
                            ],
                            const SizedBox(height: 8),
                            if (todayTasks.isNotEmpty)
                              _ProgressBar(tasks: todayTasks),
                          ],
                        ),
                      ),
                    ),

                    // ── Empty State ──────────────────────────────────────
                    if (isEmpty)
                      SliverFillRemaining(
                        child: _EmptyState(onAdd: _showAddTask),
                      )
                    else ...[
                      // ── Today Pending ────────────────────────────────
                      if (pending.isNotEmpty) ...[
                        _SectionHeader(
                            label: 'To Do', count: pending.length),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _TaskTile(
                              key: ValueKey(pending[i].id),
                              task: pending[i],
                              onToggle: () => _toggleTask(pending[i]),
                              onDelete: () => _deleteTask(pending[i]),
                              onEdit: () =>
                                  _showAddTask(editTask: pending[i]),
                            ),
                            childCount: pending.length,
                          ),
                        ),
                      ],

                      // ── Completed ────────────────────────────────────
                      if (completed.isNotEmpty) ...[
                        _SectionHeader(
                          label: 'Done',
                          count: completed.length,
                          trailing: TextButton(
                            onPressed: () async {
                              await _taskService.clearCompleted();
                              _refresh();
                            },
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                  color: context.mutedColor, fontSize: 13),
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _TaskTile(
                              key: ValueKey(completed[i].id),
                              task: completed[i],
                              onToggle: () => _toggleTask(completed[i]),
                              onDelete: () => _deleteTask(completed[i]),
                              onEdit: () {},
                            ),
                            childCount: completed.length,
                          ),
                        ),
                      ],

                      // ── Upcoming Scheduled ───────────────────────────
                      if (scheduledMap.isNotEmpty) ...[
                        for (final entry in scheduledMap.entries) ...[
                          _DateDivider(
                            date: entry.key,
                            count: entry.value.length,
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _TaskTile(
                                key: ValueKey(entry.value[i].id),
                                task: entry.value[i],
                                onToggle: () =>
                                    _toggleTask(entry.value[i]),
                                onDelete: () =>
                                    _deleteTask(entry.value[i]),
                                onEdit: () => _showAddTask(
                                    editTask: entry.value[i]),
                              ),
                              childCount: entry.value.length,
                            ),
                          ),
                        ],
                        // Upcoming summary chip
                        if (totalScheduledFuture > 0)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 8, 24, 0),
                              child: Text(
                                '$totalScheduledFuture upcoming task${totalScheduledFuture > 1 ? 's' : ''} scheduled',
                                style: TextStyle(
                                  color: context.mutedColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],

                      const SliverToBoxAdapter(
                          child: SizedBox(height: 100)),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(
          CurvedAnimation(
              parent: _fabController, curve: Curves.easeInOut),
        ),
        child: FloatingActionButton(
          onPressed: _showAddTask,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final List<Task> tasks;
  const _ProgressBar({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isCompleted).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    return Column(
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: context.cardColor,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}

class _CarryoverBadge extends StatelessWidget {
  final int count;
  const _CarryoverBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.replay_rounded,
              size: 13, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$count task${count > 1 ? 's' : ''} carried over',
            style: TextStyle(
              color: context.secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueBadge extends StatelessWidget {
  final int count;
  const _OverdueBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.overdueColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.overdueColor.withValues(alpha: 0.35),
            width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 13, color: AppColors.overdueColor),
          const SizedBox(width: 6),
          Text(
            '$count overdue task${count > 1 ? 's' : ''} carried over',
            style: const TextStyle(
              color: AppColors.overdueColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Widget? trailing;
  const _SectionHeader(
      {required this.label, required this.count, this.trailing});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                  color: context.mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                )),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  final int count;
  const _DateDivider({required this.date, required this.count});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == tomorrow) return 'TOMORROW  •  ${DateFormat('MMM d').format(date)}';
    return '${DateFormat('EEE').format(date).toUpperCase()}  •  ${DateFormat('MMM d').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 11, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    _label(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _checkScale = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(
            parent: _checkController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  void _onTap() {
    _checkController.forward().then((_) => _checkController.reverse());
    widget.onToggle();
  }

  Color? _borderColor() {
    if (widget.task.isCompleted) return null;
    if (widget.task.isOverdue) return AppColors.overdueColor;
    if (widget.task.isScheduledToday) return AppColors.dueTodayColor;
    return null;
  }

  Color? _tintColor() {
    if (widget.task.isCompleted) return null;
    if (widget.task.isOverdue) {
      return AppColors.overdueColor.withValues(alpha: 0.05);
    }
    if (widget.task.isScheduledToday) {
      return AppColors.dueTodayColor.withValues(alpha: 0.05);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isHigh = task.priority == TaskPriority.high;
    final borderColor = _borderColor();
    final tint = _tintColor();

    return Dismissible(
      key: ValueKey('dismiss_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 22),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: GestureDetector(
        onLongPress: task.isCompleted ? null : widget.onEdit,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          decoration: BoxDecoration(
            color: tint ?? context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: borderColor != null
                ? Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.5)
                : (isHigh && !task.isCompleted
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1)
                    : null),
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _onTap,
              splashColor: AppColors.primary.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Checkbox
                    ScaleTransition(
                      scale: _checkScale,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: task.isCompleted
                              ? AppColors.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: task.isCompleted
                                ? AppColors.primary
                                : context.subtleColor,
                            width: 1.5,
                          ),
                        ),
                        child: task.isCompleted
                            ? const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (task.isCarriedOver) ...[
                                const Icon(Icons.replay_rounded,
                                    size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                              ],
                              if (task.isOverdue) ...[
                                const Icon(Icons.warning_amber_rounded,
                                    size: 12,
                                    color: AppColors.overdueColor),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    color: task.isCompleted
                                        ? context.mutedColor
                                        : context.textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: context.mutedColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Note
                          if (task.note != null &&
                              task.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              task.note!,
                              style: TextStyle(
                                  color: context.mutedColor, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          // Scheduled date chip (for overdue tasks showing in today)
                          if (!task.isCompleted &&
                              task.isOverdue &&
                              task.scheduledDate != null) ...[
                            const SizedBox(height: 4),
                            _DateChip(
                              date: task.scheduledDate!,
                              isOverdue: true,
                            ),
                          ] else if (!task.isCompleted &&
                              task.isScheduledToday) ...[
                            const SizedBox(height: 4),
                            _DateChip(
                              date: task.scheduledDate!,
                              isToday: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Right side: priority dot + edit
                    if (!task.isCompleted) ...[
                      if (isHigh && borderColor == null)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      GestureDetector(
                        onTap: widget.onEdit,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: context.inputBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit_rounded,
                              size: 15, color: context.mutedColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool isOverdue;
  final bool isToday;
  const _DateChip(
      {required this.date, this.isOverdue = false, this.isToday = false});

  @override
  Widget build(BuildContext context) {
    final baseColor = isOverdue ? AppColors.overdueColor : AppColors.dueTodayColor;
    final textColor = context.isDark 
        ? baseColor 
        : (isOverdue ? const Color(0xFFD32F2F) : const Color(0xFFD97706));
    final bgColor = baseColor.withValues(alpha: context.isDark ? 0.12 : 0.18);
    final label = isOverdue
        ? 'Was due ${DateFormat('MMM d').format(date)}'
        : 'Scheduled today';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue
                ? Icons.warning_amber_rounded
                : Icons.schedule_rounded,
            size: 10,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

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
            child: Icon(Icons.check_circle_outline_rounded,
                size: 32, color: context.subtleColor),
          ),
          const SizedBox(height: 20),
          Text('All clear',
              style: TextStyle(
                  color: context.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Add your first task for today',
              style: TextStyle(color: context.mutedColor, fontSize: 14)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Add task',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Task Sheet
// ─────────────────────────────────────────────────────────────────────────────

class AddTaskSheet extends StatefulWidget {
  final TaskService taskService;
  final Task? editTask;

  const AddTaskSheet(
      {super.key, required this.taskService, this.editTask});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late TaskPriority _priority;
  DateTime? _scheduledDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.editTask;
    _titleController = TextEditingController(text: t?.title ?? '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _priority = t?.priority ?? TaskPriority.normal;
    _scheduledDate = t?.scheduledDate;
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    if (widget.editTask != null) {
      final updated = widget.editTask!.copyWith(
        title: title,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        priority: _priority,
        scheduledDate: _scheduledDate,
        clearScheduledDate: _scheduledDate == null,
      );
      await widget.taskService.updateTask(updated);
    } else {
      await widget.taskService.addTask(
        title: title,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        priority: _priority,
        scheduledDate: _scheduledDate,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editTask != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canSave = _titleController.text.trim().isNotEmpty && !_saving;
    final hasDate = _scheduledDate != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            isEdit ? 'Edit task' : 'New task',
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
                color: context.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              hintStyle:
                  TextStyle(color: context.mutedColor, fontSize: 16),
              filled: true,
              fillColor: context.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),

          // Note
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
                color: context.secondaryTextColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              hintStyle: TextStyle(
                  color: context.subtleColor, fontSize: 14),
              filled: true,
              fillColor: context.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Schedule date row
          Row(
            children: [
              GestureDetector(
                onTap: _pickDate,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: hasDate
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : context.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasDate
                          ? AppColors.primary
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
                        color: hasDate
                            ? AppColors.primary
                            : context.mutedColor,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        hasDate
                            ? DateFormat('EEE, MMM d')
                                .format(_scheduledDate!)
                            : 'Schedule',
                        style: TextStyle(
                          color: hasDate
                              ? AppColors.primary
                              : context.mutedColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasDate) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _scheduledDate = null),
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
          const SizedBox(height: 14),

          // Priority
          Row(
            children: [
              Text('Priority',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(width: 12),
              _PriorityChip(
                label: 'Normal',
                selected: _priority == TaskPriority.normal,
                onTap: () =>
                    setState(() => _priority = TaskPriority.normal),
              ),
              const SizedBox(width: 8),
              _PriorityChip(
                label: '● High',
                selected: _priority == TaskPriority.high,
                onTap: () =>
                    setState(() => _priority = TaskPriority.high),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Save
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: canSave ? _save : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: canSave
                      ? AppColors.primary
                      : context.subtleColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEdit ? 'Save changes' : 'Add task',
                          style: TextStyle(
                            color: canSave
                                ? Colors.white
                                : context.mutedColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : context.subtleColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? AppColors.primary : context.mutedColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
