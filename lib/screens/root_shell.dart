import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'expenses_home_tab.dart';

/// Top-level shell that switches between the unmodified TaskFlow task list
/// and the new Expenses tab via a segmented pill at the top of the screen.
class RootShell extends StatefulWidget {
  final ThemeNotifier notifier;
  const RootShell({super.key, required this.notifier});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: _TopTabBar(
                index: _index,
                onChanged: (i) {
                  if (i == _index) return;
                  HapticFeedback.selectionClick();
                  setState(() => _index = i);
                },
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  HomeScreen(notifier: widget.notifier),
                  const ExpensesHomeTab(),
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
  final int index;
  final ValueChanged<int> onChanged;
  const _TopTabBar({required this.index, required this.onChanged});

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
          Expanded(child: _segment(context, 'Tasks', 0)),
          Expanded(child: _segment(context, 'Expenses', 1)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, int i) {
    final selected = index == i;
    return GestureDetector(
      onTap: () => onChanged(i),
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
