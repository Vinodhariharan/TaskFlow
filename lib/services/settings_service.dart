import 'package:shared_preferences/shared_preferences.dart';

/// Which tab the app opens to on launch: 0 = Tasks, 1 = Expenses,
/// 2 = Habits. Values are persisted, so identities must stay stable.
class SettingsService {
  static const _defaultTabKey = 'default_start_tab';
  static const _widgetHabitKey = 'widget_habit_id';

  Future<int> getDefaultTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultTabKey) ?? 0;
  }

  Future<void> setDefaultTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultTabKey, index);
  }

  /// Which habit the home screen habit widget tracks.
  ///
  /// One choice for the app rather than one per widget instance: picking
  /// per-instance needs an Android configuration activity, which would put
  /// habit-loading logic on the native side where none of the rest of the
  /// widget code lives. Null means "not chosen" — the widget then falls back
  /// to the first active habit, so it says something useful before anyone
  /// has picked.
  Future<String?> getWidgetHabitId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_widgetHabitKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> setWidgetHabitId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_widgetHabitKey);
    } else {
      await prefs.setString(_widgetHabitKey, id);
    }
  }
}
