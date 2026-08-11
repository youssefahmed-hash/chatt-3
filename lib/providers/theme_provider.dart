import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {

    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getString("themeMode");

    switch (value) {

      case "light":
        _themeMode = ThemeMode.light;
        break;

      case "dark":
        _themeMode = ThemeMode.dark;
        break;

      default:
        _themeMode = ThemeMode.system;
    }

    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {

    _themeMode = mode;

    final prefs = await SharedPreferences.getInstance();

    switch (mode) {

      case ThemeMode.light:
        await prefs.setString("themeMode", "light");
        break;

      case ThemeMode.dark:
        await prefs.setString("themeMode", "dark");
        break;

      case ThemeMode.system:
        await prefs.setString("themeMode", "system");
        break;
    }

    notifyListeners();
  }
}