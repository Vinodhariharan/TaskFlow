import 'package:flutter/foundation.dart';

/// Fired after any add/update/delete/complete-toggle/category-reassignment,
/// from any screen. HomeScreen listens so a mutation that happens outside
/// it — e.g. reassigning a task's category from Settings > Manage task
/// categories, after deleting the category it was on — is reflected once
/// you're back on the Tasks screen, instead of it still showing stale
/// cached data until some other action happens to force a reload.
class TaskChangeNotifier extends ChangeNotifier {
  TaskChangeNotifier._();
  static final TaskChangeNotifier instance = TaskChangeNotifier._();

  void notifyChanged() => notifyListeners();
}
