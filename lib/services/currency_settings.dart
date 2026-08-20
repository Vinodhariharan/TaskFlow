import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyOption {
  final String code;
  final String symbol;
  final String locale;
  final String label;
  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.locale,
    required this.label,
  });
}

const List<CurrencyOption> kCurrencyOptions = [
  CurrencyOption(
      code: 'INR', symbol: '₹', locale: 'en_IN', label: 'Indian Rupee (₹)'),
  CurrencyOption(
      code: 'USD', symbol: '\$', locale: 'en_US', label: 'US Dollar (\$)'),
  CurrencyOption(
      code: 'EUR', symbol: '€', locale: 'en_IE', label: 'Euro (€)'),
  CurrencyOption(
      code: 'GBP', symbol: '£', locale: 'en_GB', label: 'British Pound (£)'),
  CurrencyOption(
      code: 'JPY', symbol: '¥', locale: 'ja_JP', label: 'Japanese Yen (¥)'),
  CurrencyOption(
      code: 'AUD',
      symbol: 'A\$',
      locale: 'en_AU',
      label: 'Australian Dollar (A\$)'),
];

/// App-wide currency selection, persisted to SharedPreferences.
class CurrencySettings extends ChangeNotifier {
  CurrencySettings._();
  static final CurrencySettings instance = CurrencySettings._();

  static const _currencyKey = 'currency_code';

  CurrencyOption _current = kCurrencyOptions.first;
  CurrencyOption get current => _current;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_currencyKey);
    if (code == null) return;
    final match = kCurrencyOptions.where((c) => c.code == code);
    if (match.isEmpty) return;
    _current = match.first;
    notifyListeners();
  }

  Future<void> setCurrency(CurrencyOption option) async {
    _current = option;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, option.code);
  }
}
