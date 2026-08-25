import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/category_service.dart';
import '../services/currency_settings.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/task_service.dart';
import 'expenses_home_tab.dart';
import 'settings_screen.dart';

/// Top-level shell that switches between the unmodified TaskFlow task list
/// and the new Expenses tab via a segmented pill at the top of the screen,
/// or by swiping left/right on the content itself.
class RootShell extends StatefulWidget {
  final ThemeNotifier notifier;
  const RootShell({super.key, required this.notifier});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  // Which screen (0 = Tasks, 1 = Expenses) is "primary" — shown on the left
  // of the toggle, and the one the app opens on. Backed by the same
  // Settings > "default start tab" choice; default is Tasks.
  int _primary = 0;
  // Current PageView page (0 or 1) — a position, not a screen identity: the
  // screen it maps to depends on _primary via _screenOrder.
  int _page = 0;
  late final PageController _pageController;
  final _settingsService = SettingsService();

  /// Screen identities (0 = Tasks, 1 = Expenses) in left-to-right / page
  /// order — index 0 is whichever is primary.
  List<int> get _screenOrder => _primary == 0 ? const [0, 1] : const [1, 0];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    CurrencySettings.instance.load();
    CategoryService.instance.load();
    _settingsService.getDefaultTab().then((tab) {
      if (mounted && tab != _primary) setState(() => _primary = tab);
    });
    // Re-arm every upcoming task reminder on app start — covers device
    // reboots or reinstalls clearing previously scheduled alarms.
    NotificationService.instance.init().then((_) async {
      final tasks = await TaskService().getAllTasks();
      await NotificationService.instance.rescheduleAll(tasks);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                    screenId == 0
                        ? HomeScreen(notifier: widget.notifier)
                        : const ExpensesHomeTab(),
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
  /// Screen identities (0 = Tasks, 1 = Expenses) in left-to-right order.
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
                order[pageIndex] == 0 ? 'Tasks' : 'Expenses',
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
