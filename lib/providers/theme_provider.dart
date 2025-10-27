import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'theme_mode';

  // Default to light unless user selected otherwise
  ThemeMode _themeMode = ThemeMode.light;
  ThemeProvider() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      switch (saved) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'system':
          _themeMode = ThemeMode.system;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          // If no preference saved, stay on light by default
          _themeMode = ThemeMode.light;
      }
      notifyListeners();
    } catch (_) {
      // Ignore read errors
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.system
              ? 'system'
              : 'dark';
      await prefs.setString(_prefKey, value);
    } catch (_) {
      // Ignore write errors
    }
  }

  Future<void> toggle() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

