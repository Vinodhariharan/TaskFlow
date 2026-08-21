import 'package:flutter/foundation.dart';

/// Fired after any add/update/delete/import/undo-restore, from any screen
/// or service call site. The Expenses home tab and All Expenses screen each
/// keep their own local cache (recent list + KPIs, paginated results) and
/// used to only refresh the screen that made the change — so e.g. deleting
/// on Home then hitting Undo from a snackbar still showing on top of All
/// Expenses left All Expenses stale until you navigated back to Home.
/// Both screens listen here instead, so any mutation from anywhere
/// refreshes every currently-mounted expense screen.
class ExpenseChangeNotifier extends ChangeNotifier {
  ExpenseChangeNotifier._();
  static final ExpenseChangeNotifier instance = ExpenseChangeNotifier._();

  void notifyChanged() => notifyListeners();
}
