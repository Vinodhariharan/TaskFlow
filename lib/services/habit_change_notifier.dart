import 'package:flutter/foundation.dart';

/// Fired by every HabitService mutation so any screen showing habits can
/// refresh, wherever the change originated. Same shape as
/// TaskChangeNotifier / ExpenseChangeNotifier — those exist because
/// screens that cached their own copy went stale when something changed
/// elsewhere, and habits appear in at least three places (today's list,
/// the detail screen, and later the widget).
class HabitChangeNotifier extends ChangeNotifier {
  HabitChangeNotifier._();
  static final HabitChangeNotifier instance = HabitChangeNotifier._();

  void notifyChanged() => notifyListeners();
}
