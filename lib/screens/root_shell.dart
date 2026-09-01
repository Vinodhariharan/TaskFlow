import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
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
/// screens via a segmented pill at the top, or by swiping left/right on the
/// content itself.
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

class _RootShellState extends State<RootShell> {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _TopTabBar(
                      order: order,
                      current: _page,
                      onChanged: _goToPage,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.settings_rounded,
                          size: 20, color: context.mutedColor),
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
    );
  }
}

class _TopTabBar extends StatelessWidget {
  /// Screen identities in left-to-right order.
  final List<int> order;
  final int current;
  final ValueChanged<int> onChanged;
  const _TopTabBar(
      {required this.order, required this.current, required this.onChanged});

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
          for (var pageIndex = 0; pageIndex < order.length; pageIndex++)
            Expanded(
              child: _segment(
                context,
                screenLabel(order[pageIndex]),
                pageIndex,
              ),
            ),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, int pageIndex) {
    final selected = current == pageIndex;
    return GestureDetector(
      onTap: () => onChanged(pageIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.mutedColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
