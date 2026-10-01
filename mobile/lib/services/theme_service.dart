import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final darkRefreshApplied = prefs.getBool('darkRefreshAppliedV1') ?? false;
    if (!darkRefreshApplied) {
      _mode = ThemeMode.dark;
      await prefs.setString('themeMode', ThemeMode.dark.name);
      await prefs.setBool('darkRefreshAppliedV1', true);
      notifyListeners();
      return;
    }
    _mode = switch (prefs.getString('themeMode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    notifyListeners();
  }
}
