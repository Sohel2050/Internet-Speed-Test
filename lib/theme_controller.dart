import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's theme choice. Default is dark (black).
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();
  static const _key = 'theme_mode';

  ThemeMode mode = ThemeMode.dark;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      switch (p.getString(_key)) {
        case 'light':
          mode = ThemeMode.light;
          break;
        case 'system':
          mode = ThemeMode.system;
          break;
        default:
          mode = ThemeMode.dark;
      }
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key,
          m == ThemeMode.light ? 'light' : (m == ThemeMode.system ? 'system' : 'dark'));
    } catch (_) {}
  }
}
