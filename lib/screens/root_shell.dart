import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_info.dart';
import '../app_mark.dart';
import '../main.dart';
import '../services/category_service.dart';
import '../services/currency_settings.dart';
import '../services/expense_change_notifier.dart';
import '../services/expense_service.dart';
import '../services/habit_change_notifier.dart';
import '../services/habit_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/task_change_notifier.dart';
import '../services/task_service.dart';
import '../services/widget_service.dart';
import 'add_edit_expense_sheet.dart';
import 'expenses_home_tab.dart';
import 'habit_detail_screen.dart';
import 'habits_home_tab.dart';
import 'settings_screen.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

/// Top-level shell that switches between the Tasks, Expenses and Habits
/// screens via the bottom bar, or by swiping left/right on the content
/// itself.
class RootShell extends StatefulWidget {
  final ThemeNotifier notifier;
  const RootShell({super.key, required this.notifier});

  @override
  State<RootShell> createState() => _RootShellState();
}

/// The screens the shell can show, in their natural order. Identities are
/// stable (they're persisted as the "default start tab" setting), so new
/// screens must be appended rather than inserted.
const int kTasksScreen = 0;
const int kExpensesScreen = 1;
const int kHabitsScreen = 2;
const List<int> kAllScreens = [kTasksScreen, kExpensesScreen, kHabitsScreen];

String screenLabel(int screenId) => switch (screenId) {
      kTasksScreen => 'Tasks',
      kExpensesScreen => 'Expenses',
      _ => 'Habits',
    };

/// Literal `Icons.*` references, never an IconData rebuilt from a stored
/// codePoint: Flutter's icon tree-shaker keeps only what it can see
/// statically, and anything else renders blank in a release build. Same
/// constraint as kHabitIconChoices and the task categories.
IconData screenIcon(int screenId) => switch (screenId) {
      kTasksScreen => Icons.check_circle_outline_rounded,
      kExpensesScreen => Icons.account_balance_wallet_outlined,
      _ => Icons.local_fire_department_outlined,
    };

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  // Which screen is "primary" — shown leftmost on the toggle, and the one
  // the app opens on. Backed by the Settings > "default start tab" choice.
  int _primary = kTasksScreen;
  // Current PageView page — a position, not a screen identity: the screen it
  // maps to depends on _primary via _screenOrder.
  int _page = 0;
  late final PageController _pageController;
  final _settingsService = SettingsService();
  StreamSubscription<Uri?>? _widgetClickSub;

  /// Screen identities in left-to-right / page order: the primary one first,
  /// then the rest in their natural order.
  List<int> get _screenOrder =>
      [_primary, ...kAllScreens.where((id) => id != _primary)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    CurrencySettings.instance.load();
    CategoryService.instance.load();
    _settingsService.getDefaultTab().then((tab) {
      if (mounted && tab != _primary) setState(() => _primary = tab);
    });
    // Ask for notification permission up front rather than only when a
    // reminder is first set — a reminder scheduled while permission is
    // still denied fires into nothing. Then re-arm every upcoming reminder,
    // which also catches up anything scheduled before permission was
    // granted, or lost to a reinstall.
    // Tapping a reminder opens that task's page. Wired before init() finishes
    // so a tap arriving mid-startup is handled rather than dropped.
    NotificationService.instance.onReminderTapped = _openReminder;
    NotificationService.instance.init().then((_) async {
      await NotificationService.instance.requestPermissions();
      final tasks = await TaskService().getAllTasks();
      await NotificationService.instance.rescheduleAll(tasks);
      // A reminder tapped while the app wasn't running launches it here
      // instead of going through onReminderTapped.
      final pending = await NotificationService.instance.consumePendingTap();
      if (pending != null) _openReminder(pending);
      // Habit reminders repeat, but Android drops pending alarms on reboot
      // and a newly-granted permission doesn't retroactively arm anything,
      // so re-arm them alongside the task ones.
      await NotificationService.instance
          .rescheduleAllHabits(await HabitService().getHabits());
    });

    // Keep the home screen widgets current: refresh once on start, then on
    // every task or expense change from anywhere in the app.
    WidgetService.instance.refresh();
    // Lets the Tasks widget's tick buttons run Dart in the background,
    // without opening the app.
    HomeWidget.registerInteractivityCallback(widgetInteractionCallback);
    TaskChangeNotifier.instance.addListener(_refreshWidgets);
    ExpenseChangeNotifier.instance.addListener(_refreshWidgets);
    HabitChangeNotifier.instance.addListener(_refreshWidgets);

    // Opening the app from a widget lands on that widget's tab.
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (NotificationService.instance.onReminderTapped == _openReminder) {
      NotificationService.instance.onReminderTapped = null;
    }
    TaskChangeNotifier.instance.removeListener(_refreshWidgets);
    ExpenseChangeNotifier.instance.removeListener(_refreshWidgets);
    HabitChangeNotifier.instance.removeListener(_refreshWidgets);
    _widgetClickSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _refreshWidgets() => WidgetService.instance.refresh();

  /// Picks up anything the home screen widgets changed while the app was in
  /// the background.
  ///
  /// Ticking a task from a widget runs in a background isolate that
  /// home_widget spins up, and that isolate writes through its own
  /// SharedPreferences instance. This isolate holds a separate in-memory
  /// cache of the same file and has no idea it moved, so without the
  /// reload() below every read here keeps serving what was on disk when the
  /// app started — the widget showed the task done while the app still
  /// listed it outstanding. The reverse direction always worked, because
  /// the app writes and then pushes to the widgets itself.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    _reloadFromDisk();
  }

  Future<void> _reloadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!mounted) return;
    // Every screen already rebuilds off these; the missing piece was only
    // that the store underneath them was stale.
    TaskChangeNotifier.instance.notifyChanged();
    ExpenseChangeNotifier.instance.notifyChanged();
    HabitChangeNotifier.instance.notifyChanged();
  }

  /// Acts on a tapped widget. The URIs are set in the widget providers;
  /// anything unrecognised just opens the app wherever it would normally
  /// land. Everything here is deferred to after the first frame — on a cold
  /// launch the PageView isn't laid out and there's no Navigator to push on
  /// yet.
  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    final host = uri.host;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      switch (host) {
        case 'tasks':
        case 'expenses':
          _showScreen(host == 'tasks' ? kTasksScreen : kExpensesScreen);
        case 'task':
          final id = uri.queryParameters['id'];
          if (id != null && id.isNotEmpty) _openTask(id);
        case 'habits':
          _showScreen(kHabitsScreen);
        case 'habitdetail':
          final habitId = uri.queryParameters['id'];
          if (habitId != null && habitId.isNotEmpty) {
            _showScreen(kHabitsScreen);
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HabitDetailScreen(habitId: habitId),
              ),
            );
          }
        case 'addtask':
          _showScreen(kTasksScreen);
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TaskFormScreen(taskService: TaskService()),
            ),
          );
        case 'addexpense':
          _showScreen(kExpensesScreen);
          if (!mounted) return;
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                AddEditExpenseSheet(expenseService: ExpenseService()),
          );
      }
    });
  }

  /// Jumps to a screen by identity, translating through whichever order the
  /// "primary tab" setting put them in.
  void _showScreen(int screenId) {
    final pageIndex = _screenOrder.indexOf(screenId);
    if (pageIndex < 0 || !_pageController.hasClients) return;
    _goToPage(pageIndex);
  }

  /// Routes a tapped reminder to whatever it belongs to. Habit reminders
  /// carry a "habit:" prefix in their payload; anything else is a bare task
  /// id, which is what task reminders have always sent.
  void _openReminder(String payload) {
    if (!mounted) return;
    const habitPrefix = 'habit:';
    if (payload.startsWith(habitPrefix)) {
      final id = payload.substring(habitPrefix.length);
      if (id.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: id)),
      );
      return;
    }
    _openTask(payload);
  }

  /// Opens a task's detail page. Uses the shell's own context so it works
  /// whatever is currently on screen.
  void _openTask(String taskId) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)),
    );
  }

  void _goToPage(int pageIndex) {
    if (pageIndex == _page) return;
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _screenOrder;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // The app's mark and name on the left, settings on the right.
            // Both are chrome: each screen prints its own 32sp title just
            // below, so the name here is kept small enough not to compete
            // with it. Settings stays out of the bottom bar — it isn't a
            // peer of the three sections, and giving it equal billing there
            // would squeeze the tabs you actually live in.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 20, 0),
              child: Row(
                children: [
                  AppMark(size: 21, color: AppColors.primary),
                  const SizedBox(width: 9),
                  Text(
                    kAppName,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(notifier: widget.notifier),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.settings_rounded,
                          size: 18, color: context.mutedColor),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final screenId in order)
                    switch (screenId) {
                      kTasksScreen => HomeScreen(notifier: widget.notifier),
                      kExpensesScreen => const ExpensesHomeTab(),
                      _ => const HabitsHomeTab(),
                    },
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        order: order,
        current: _page,
        onChanged: _goToPage,
      ),
    );
  }
}

/// Icon-only bottom bar. The selected tab also shows its name underneath,
/// so the current screen is always named while the others stay compact.
class _BottomNavBar extends StatelessWidget {
  /// Screen identities in left-to-right order.
  final List<int> order;
  final int current;
  final ValueChanged<int> onChanged;

  const _BottomNavBar({
    required this.order,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(
          top: BorderSide(color: context.subtleColor.withValues(alpha: 0.4)),
        ),
      ),
      // Bottom padding only: the bar has to clear the gesture bar without
      // the shell's own SafeArea (which sets bottom: false) fighting it.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var pageIndex = 0; pageIndex < order.length; pageIndex++)
                Expanded(
                  child: _NavItem(
                    icon: screenIcon(order[pageIndex]),
                    label: screenLabel(order[pageIndex]),
                    selected: current == pageIndex,
                    onTap: () => onChanged(pageIndex),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.mutedColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          // The label only exists for the selected tab, so it animates in
          // rather than appearing abruptly, and the icon shifts up to make
          // room instead of the row changing height.
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: selected
                ? Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.primary,
                        // Small, but not so small it stops being readable —
                        // 11sp is about the floor for a label people are
                        // meant to actually read rather than glance past.
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox(width: 0, height: 0),
          ),
        ],
      ),
    );
  }
}
