import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/task.dart';
import 'services/task_category_service.dart';
import 'services/task_change_notifier.dart';
import 'services/task_service.dart';
import 'screens/root_shell.dart';
import 'screens/task_category_widgets.dart';
import 'screens/task_detail_screen.dart';
import 'screens/task_form_screen.dart';

/// A single, persistent ScaffoldMessenger used for snackbars that need to
/// survive a route push (e.g. deleting an expense right before navigating
/// to another expense screen). `ScaffoldMessenger.of(context)` resolves to
/// whichever Scaffold happens to be topmost, which is unreliable mid-
/// navigation; routing every expense snackbar through this fixed key avoids
/// that.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      themeMode: notifier.mode,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: RootShell(notifier: notifier),
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
  final Set<String> _selectedCategoryIds = {};

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    TaskCategoryService.instance.load();
    // Any add/update/delete/toggle/category-reassignment from ANY screen
    // fires this, so this screen stays in sync even when the change
    // happened elsewhere — e.g. reassigning a task's category from
    // Settings > Manage task categories after deleting the category it was
    // on used to leave this screen showing stale data until some other
    // action forced a reload.
    TaskChangeNotifier.instance.addListener(_refresh);
    TaskCategoryService.instance.addListener(_pruneStaleFilters);
    _refresh();
  }

  @override
  void dispose() {
    _fabController.dispose();
    TaskChangeNotifier.instance.removeListener(_refresh);
    TaskCategoryService.instance.removeListener(_pruneStaleFilters);
    super.dispose();
  }

  void _refresh() {
    final categoryIds = _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds;
    setState(() {
      _todayFuture = _taskService.getTodayTasks(categoryIds: categoryIds);
      _scheduledFuture = _taskService.getScheduledTasks(categoryIds: categoryIds);
    });
  }

  /// Drops any selected filter chip whose category no longer exists (e.g.
  /// it was just deleted) so a stale filter doesn't silently keep showing
  /// an empty list with no visible chip left to explain why.
  void _pruneStaleFilters() {
    if (_selectedCategoryIds.isEmpty) return;
    final validIds = TaskCategoryService.instance.all.map((c) => c.id).toSet();
    final hadInvalid = _selectedCategoryIds.any((id) => !validIds.contains(id));
    if (!hadInvalid) return;
    setState(() => _selectedCategoryIds.removeWhere((id) => !validIds.contains(id)));
    _refresh();
  }

  void _toggleCategoryFilter(String id) {
    setState(() {
      if (_selectedCategoryIds.contains(id)) {
        _selectedCategoryIds.remove(id);
      } else {
        _selectedCategoryIds.add(id);
      }
    });
    _refresh();
  }

  /// Opens the full-page task form. It moved off a bottom sheet once a task
  /// grew a note, category, reminder time and repeat rule — too much to show
  /// in a sheet without hiding most of it.
  Future<void> _showAddTask({Task? editTask}) async {
    if (editTask == null) {
      _fabController.forward().then((_) => _fabController.reverse());
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TaskFormScreen(taskService: _taskService, editTask: editTask),
      ),
    );
    _refresh();
  }

  /// Opens a task's own page — the same page a tapped reminder lands on,
  /// and the only place a task can be edited.
  Future<void> _openTask(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
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
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
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

                    // ── Category filter chips ─────────────────────────────
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 36,
                        child: ListenableBuilder(
                          listenable: TaskCategoryService.instance,
                          builder: (context, _) => ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            children: [
                              for (final cat in TaskCategoryService.instance.all) ...[
                                TaskCategoryChip(
                                  category: cat,
                                  selected: _selectedCategoryIds.contains(cat.id),
                                  onTap: () => _toggleCategoryFilter(cat.id),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // ── Empty State ──────────────────────────────────────
                    if (isEmpty)
                      SliverFillRemaining(
                        child: _EmptyState(
                          onAdd: _showAddTask,
                          title: _selectedCategoryIds.isNotEmpty
                              ? 'No tasks here'
                              : 'All clear',
                          subtitle: _selectedCategoryIds.isNotEmpty
                              ? 'Nothing in this category right now'
                              : 'Add your first task for today',
                        ),
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
                              onOpen: () => _openTask(pending[i]),
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
                              onOpen: () => _openTask(completed[i]),
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
                                onOpen: () => _openTask(entry.value[i]),
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
  /// Opens the task's own page — where it can be edited.
  final VoidCallback onOpen;

  const _TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> with TickerProviderStateMixin {
  // Same swipe-reveal-then-tap-icon delete pattern as ExpenseTile: swipe
  // left caps at a fixed reveal width showing a delete icon behind the
  // tile; tapping that icon deletes with no confirmation dialog.
  static const _revealWidth = 72.0;

  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late final AnimationController _dragController;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _checkScale = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(
            parent: _checkController, curve: Curves.easeInOut));
    _dragController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _checkController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  void _closeReveal() => _dragController.animateTo(0.0, curve: Curves.easeOut);

  /// Tapping the row opens the task's page. Completing is the checkbox's job
  /// (see [_onToggle]) — the row itself is navigation now that a task has a
  /// page of its own.
  void _onTap() {
    if (_dragController.value > 0) {
      _closeReveal();
      return;
    }
    widget.onOpen();
  }

  void _onToggle() {
    if (_dragController.value > 0) {
      _closeReveal();
      return;
    }
    _checkController.forward().then((_) => _checkController.reverse());
    widget.onToggle();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _dragController.value =
        (_dragController.value - delta / _revealWidth).clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity < -300 || (velocity <= 300 && _dragController.value > 0.5);
    _dragController.animateTo(open ? 1.0 : 0.0, curve: Curves.easeOut);
  }

  void _handleDelete() {
    HapticFeedback.mediumImpact();
    widget.onDelete();
  }

  Color? _borderColor() {
    if (widget.task.isCompleted) return null;
    if (widget.task.isOverdue) return AppColors.overdueColor;
    if (widget.task.isScheduledToday) return AppColors.dueTodayColor;
    return null;
  }

  /// The tile's own surface colour. Any overdue/due-today tint must be
  /// composited *over* the card colour rather than used on its own — a bare
  /// 5%-alpha tint left the tile 95% transparent, so the red delete strip
  /// sitting behind it in the Stack bled through on the right edge and the
  /// rest of the tile showed the page background instead of the card.
  Color _surfaceColor(BuildContext context) {
    final task = widget.task;
    if (task.isCompleted) return context.cardColor;
    final Color? tint = task.isOverdue
        ? AppColors.overdueColor.withValues(alpha: 0.05)
        : (task.isScheduledToday
            ? AppColors.dueTodayColor.withValues(alpha: 0.05)
            : null);
    if (tint == null) return context.cardColor;
    return Color.alphaBlend(tint, context.cardColor);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isHigh = task.priority == TaskPriority.high;
    final borderColor = _borderColor();
    final surface = _surfaceColor(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null
            ? Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.5)
            : (isHigh && !task.isCompleted
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35), width: 1)
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  GestureDetector(
                    onTap: _handleDelete,
                    child: Container(
                      width: _revealWidth,
                      color: AppColors.danger,
                      alignment: Alignment.center,
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _dragController,
              builder: (context, child) => Transform.translate(
                offset: Offset(-_revealWidth * _dragController.value, 0),
                child: child,
              ),
              child: GestureDetector(
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: Material(
                  color: surface,
                  child: InkWell(
                    onTap: _onTap,
                    splashColor: AppColors.primary.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 12, 16, 12),
                      child: Row(
                    children: [
                    // Checkbox — its own tap target now that tapping the row
                    // opens the task instead of completing it. The padding
                    // gives a full-size touch area around a small dot.
                    GestureDetector(
                      onTap: _onToggle,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ScaleTransition(
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
                      ),
                    ),
                    const SizedBox(width: 4),
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
                          // Category
                          if (task.categoryId != null) ...[
                            const SizedBox(height: 3),
                            ListenableBuilder(
                              listenable: TaskCategoryService.instance,
                              builder: (context, _) {
                                final cat = TaskCategoryService.instance
                                    .getById(task.categoryId!);
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(cat.icon, size: 11, color: cat.color),
                                    const SizedBox(width: 4),
                                    Text(
                                      cat.label,
                                      style: TextStyle(
                                        color: cat.color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
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
                    ],
                    // Points at the task's own page, where it can be edited.
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 20, color: context.subtleColor),
                    ),
                  ],
                      ),
                    ),
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
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.onAdd,
    this.title = 'All clear',
    this.subtitle = 'Add your first task for today',
  });

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
          Text(title,
              style: TextStyle(
                  color: context.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle,
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

