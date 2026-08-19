import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's language choice (defaults to the system locale when
/// nothing is saved). Passed to MaterialApp.locale to also flip Directionality
/// (Arabic -> RTL, English -> LTR).
class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_lang';

  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      _locale = Locale(saved);
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  /// Revert to the system language.
  Future<void> clearLocale() async {
    _locale = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}