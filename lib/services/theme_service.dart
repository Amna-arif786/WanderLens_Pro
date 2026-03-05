import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeService handles persisting the user's theme preference (Light/Dark).
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeService() {
    _loadTheme();
  }

  /// Toggles the theme between light and dark..
  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
    notifyListeners(); // Updates the entire app UI..
  }

  /// Loads the saved theme preference from local storage..
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }
}
