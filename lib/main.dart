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
import 'app_info.dart';

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
      builder: (context, _) => UpkeepApp(notifier: _notifier),
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

class UpkeepApp extends StatelessWidget {
  final ThemeNotifier notifier;
  const UpkeepApp({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
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

  /// Tasks picked by long-pressing. Non-empty means the list is in
  /// selection mode: taps pick rather than open. Only today's outstanding
  /// tasks can be picked — the done and upcoming sections aren't things you
  /// bulk-edit, and confining it keeps "reorder" unambiguous, since only
  /// this list carries a manual order.
  final Set<String> _selectedIds = {};

  /// A snapshot of today's outstanding list while it's being dragged into
  /// order, or null when it isn't. Held here rather than read from the
  /// future so a dragged row moves under the finger instead of waiting on a
  /// round trip through storage.
  List<Task>? _reorderList;

  bool get _selecting => _selectedIds.isNotEmpty;
  bool get _reordering => _reorderList != null;

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

  // ── Multi-select ───────────────────────────────────────────────────────

  void _beginSelection(Task task) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedIds.add(task.id));
  }

  void _toggleSelected(Task task) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.remove(task.id)) _selectedIds.add(task.id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  /// Deletes everything picked as one action, so undo restores the whole
  /// set rather than making the user tap Undo once per task.
  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    HapticFeedback.mediumImpact();
    final removed = await _taskService.deleteTasks(ids);
    setState(_selectedIds.clear);
    _refresh();
    if (!mounted || removed.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            removed.length == 1
                ? 'Task deleted'
                : '${removed.length} tasks deleted',
            style: TextStyle(color: context.textColor),
          ),
          backgroundColor: context.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primary,
            onPressed: () async {
              for (final task in removed) {
                await _taskService.addTask(
                  title: task.title,
                  note: task.note,
                  priority: task.priority,
                  scheduledDate: task.scheduledDate,
                  categoryId: task.categoryId,
                  recurrence: task.recurrence,
                  reminderHour: task.reminderHour,
                  reminderMinute: task.reminderMinute,
                );
              }
              _refresh();
            },
          ),
        ),
      );
  }

  // ── Reordering ─────────────────────────────────────────────────────────

  /// Takes its own snapshot rather than having the built list threaded out
  /// of the FutureBuilder.
  Future<void> _beginReorder() async {
    HapticFeedback.selectionClick();
    final today = await _taskService.getTodayTasks();
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _reorderList = today.where((t) => !t.isCompleted).toList();
    });
  }

  /// onReorderItem hands over a newIndex already adjusted for the removed
  /// row, so there's no off-by-one to apply.
  void _onReorderPending(int oldIndex, int newIndex) {
    setState(() {
      final task = _reorderList!.removeAt(oldIndex);
      _reorderList!.insert(newIndex, task);
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _finishReorder() async {
    final ids = _reorderList?.map((t) => t.id).toList() ?? const <String>[];
    setState(() => _reorderList = null);
    await _taskService.reorderTasks(ids);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);

    // Back gets out of picking or dragging before it gets out of the app —
    // otherwise the only way out of a mode entered by accident is to find
    // the small × in the bar.
    return PopScope(
      canPop: !_selecting && !_reordering,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_reordering) {
          // Keep the drags: they already happened on screen, and throwing
          // them away on a back press would be the surprising choice.
          _finishReorder();
        } else {
          _clearSelection();
        }
      },
      child: Scaffold(
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
                            // Overdue badge
                            if (overdueCount > 0) ...[
                              const SizedBox(height: 10),
                              _OverdueBadge(count: overdueCount),
                            ],
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
                      if (_reordering) ...[
                        _SectionHeader(
                            label: 'Reorder', count: _reorderList!.length),
                        SliverReorderableList(
                          itemCount: _reorderList!.length,
                          onReorderItem: _onReorderPending,
                          itemBuilder: (ctx, i) {
                            final task = _reorderList![i];
                            // Drag from anywhere on the row: this is a mode
                            // of its own, so there's nothing else a touch
                            // could have meant.
                            return ReorderableDragStartListener(
                              key: ValueKey(task.id),
                              index: i,
                              child: _TaskTile(
                                task: task,
                                reordering: true,
                                onToggle: () {},
                                onOpen: () {},
                              ),
                            );
                          },
                        ),
                      ] else if (pending.isNotEmpty) ...[
                        _SectionHeader(
                            label: 'To Do', count: pending.length),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _TaskTile(
                              key: ValueKey(pending[i].id),
                              task: pending[i],
                              selectionMode: _selecting,
                              selected: _selectedIds.contains(pending[i].id),
                              onLongPress: () => _beginSelection(pending[i]),
                              onSelectToggle: () =>
                                  _toggleSelected(pending[i]),
                              onToggle: () => _toggleTask(pending[i]),
                              onOpen: () => _openTask(pending[i]),
                            ),
                            childCount: pending.length,
                          ),
                        ),
                      ],

                      // ── Completed ────────────────────────────────────
                      // Hidden while reordering: only today's outstanding
                      // list carries a manual order, so showing the rest
                      // would invite dragging things that can't move.
                      if (completed.isNotEmpty && !_reordering) ...[
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
                              onOpen: () => _openTask(completed[i]),
                            ),
                            childCount: completed.length,
                          ),
                        ),
                      ],

                      // ── Upcoming Scheduled ───────────────────────────
                      if (scheduledMap.isNotEmpty && !_reordering) ...[
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
      // Adding is out of place mid-selection or mid-drag, and the action
      // bar wants that corner.
      floatingActionButton: (_selecting || _reordering)
          ? null
          : ScaleTransition(
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
      bottomNavigationBar: _buildActionBar(context),
      ),
    );
  }

  /// The bar along the bottom while picking tasks or dragging them into
  /// order. Null the rest of the time, so it costs no space.
  Widget? _buildActionBar(BuildContext context) {
    if (!_selecting && !_reordering) return null;

    final children = _reordering
        ? [
            Icon(Icons.drag_indicator_rounded,
                size: 18, color: context.mutedColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Drag to reorder',
                style: TextStyle(
                    color: context.secondaryTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            _BarAction(
                icon: Icons.check_rounded,
                label: 'Done',
                onTap: _finishReorder),
          ]
        : [
            GestureDetector(
              onTap: _clearSelection,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded,
                    size: 20, color: context.mutedColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_selectedIds.length} selected',
                style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            // Reordering a filtered list would number only the tasks on
            // screen and quietly shuffle the hidden ones, so it's offered
            // on the full list only.
            if (_selectedCategoryIds.isEmpty)
              _BarAction(
                icon: Icons.swap_vert_rounded,
                label: 'Reorder',
                onTap: _beginReorder,
              ),
            const SizedBox(width: 6),
            _BarAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              danger: true,
              onTap: _deleteSelected,
            ),
          ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(children: children),
      ),
    );
  }
}

/// One button in the selection/reorder bar.
class _BarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

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
            '$count overdue task${count > 1 ? 's' : ''}',
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

  /// Opens the task's own page — where it can be edited.
  final VoidCallback onOpen;

  /// Starts multi-select on this task. Null on rows that can't take part,
  /// which is everything outside today's outstanding list.
  final VoidCallback? onLongPress;

  /// Adds or removes this task from an in-progress selection.
  final VoidCallback? onSelectToggle;

  /// True once any task is selected: the whole list switches to picking
  /// rather than opening, so a stray tap can't navigate away mid-selection.
  final bool selectionMode;
  final bool selected;

  /// Reorder mode strips the row back to something being dragged: no tap
  /// targets, no chevron, just the title and a handle.
  final bool reordering;

  const _TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onOpen,
    this.onLongPress,
    this.onSelectToggle,
    this.selectionMode = false,
    this.selected = false,
    this.reordering = false,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> with TickerProviderStateMixin {
  // Deleting used to live behind a left swipe on this tile. It moved to
  // multi-select — long-press a task, pick as many as you like, delete the
  // lot in one undoable go — which also frees the horizontal drag the
  // swipe was eating.
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

  /// Tapping the row opens the task's page — except while picking, when it
  /// adds or removes this one instead. Completing is the checkbox's job
  /// (see [_onToggle]).
  void _onTap() {
    if (widget.reordering) return;
    if (widget.selectionMode) {
      widget.onSelectToggle?.call();
      return;
    }
    widget.onOpen();
  }

  /// While picking, the leading circle selects rather than completes —
  /// otherwise the obvious place to tap would silently finish a task the
  /// user was only trying to select.
  void _onToggle() {
    if (widget.reordering) return;
    if (widget.selectionMode) {
      widget.onSelectToggle?.call();
      return;
    }
    _checkController.forward().then((_) => _checkController.reverse());
    widget.onToggle();
  }


  /// The tile's own surface colour.
  ///
  /// Due state used to tint this and draw a border and a warning icon and a
  /// date chip — four signals for one fact, of which the outline was the
  /// loudest and the least attractive. The chip carries it alone now, so the
  /// only thing left here is the multi-select highlight. It's composited
  /// over the card colour rather than used on its own: a bare 16%-alpha fill
  /// would leave the tile mostly transparent, showing the page background
  /// through what should be a card.
  Color _surfaceColor(BuildContext context) {
    if (widget.selected) {
      return Color.alphaBlend(
          AppColors.primary.withValues(alpha: 0.16), context.cardColor);
    }
    return context.cardColor;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isHigh = task.priority == TaskPriority.high;
    final surface = _surfaceColor(context);
    // While picking, the leading circle reports selection rather than
    // completion — same shape, different question.
    final filled =
        widget.selectionMode ? widget.selected : task.isCompleted;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // The only border left means high priority, so it now says exactly
        // one thing.
        border: isHigh && !task.isCompleted
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.35), width: 1)
            : null,
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
        child: Material(
                  color: surface,
                  child: InkWell(
                    onTap: _onTap,
                    onLongPress:
                        widget.reordering ? null : widget.onLongPress,
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
                          color: filled
                              ? AppColors.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: filled
                                ? AppColors.primary
                                : context.subtleColor,
                            width: 1.5,
                          ),
                        ),
                        child: filled
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
                            _DateChip(date: task.scheduledDate!),
                          ],
                        ],
                      ),
                    ),
                    // Right side: priority dot + edit
                    if (!task.isCompleted) ...[
                      if (isHigh)
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
                    // A drag handle while reordering, the "opens its own
                    // page" chevron otherwise, and nothing while picking —
                    // where the leading circle already says what a tap does.
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        widget.reordering
                            ? Icons.drag_handle_rounded
                            : Icons.chevron_right_rounded,
                        size: 20,
                        color: widget.selectionMode && !widget.reordering
                            ? Colors.transparent
                            : context.subtleColor,
                      ),
                    ),
                  ],
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

  /// Overdue when true, due today when false — the two states this chip
  /// exists to mark. Anything else doesn't get one.
  final bool isOverdue;

  const _DateChip({required this.date, this.isOverdue = false});

  @override
  Widget build(BuildContext context) {
    // Filled, not a faint wash behind coloured text: this chip is now the
    // only thing marking a task as due or overdue, so it has to carry the
    // state on its own rather than corroborate a border that no longer
    // exists.
    final fill =
        isOverdue ? AppColors.overdueColor : AppColors.dueTodayColor;
    // Both fills are light — #FF6B6B and #FFD166 — so the label is dark
    // rather than white, which would sit at about 1.7:1 on the amber.
    final label = isOverdue
        ? 'OVERDUE · ${DateFormat('MMM d').format(date).toUpperCase()}'
        : 'TODAY';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.darkBg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
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

