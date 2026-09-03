import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/main.dart';

/// The theme setting used to be a two-way switch storing 'light' or 'dark'.
/// Adding System must not reset what anyone already chose.
void main() {
  test('stored values from the old switch still mean what they did', () {
    expect(themeModeFromStored('light'), ThemeMode.light);
    expect(themeModeFromStored('dark'), ThemeMode.dark);
  });

  test('system is readable back', () {
    expect(themeModeFromStored('system'), ThemeMode.system);
  });

  test('a fresh install, or anything unrecognised, means dark', () {
    // Dark is what the app defaulted to before System existed.
    expect(themeModeFromStored(null), ThemeMode.dark);
    expect(themeModeFromStored(''), ThemeMode.dark);
    expect(themeModeFromStored('midnight'), ThemeMode.dark);
  });

  test('every mode round-trips through storage', () {
    for (final mode in ThemeMode.values) {
      expect(themeModeFromStored(storedFromThemeMode(mode)), mode);
    }
  });
}
