import 'package:shared_preferences/shared_preferences.dart';

/// Which tab the app opens to on launch: 0 = Tasks, 1 = Expenses.
class SettingsService {
  static const _defaultTabKey = 'default_start_tab';

  Future<int> getDefaultTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultTabKey) ?? 0;
  }

  Future<void> setDefaultTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultTabKey, index);
  }
}
