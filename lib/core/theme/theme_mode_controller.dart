import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's light/dark theme choice across app restarts.
///
/// Backed by [SharedPreferences] under [_prefsKey]. Defaults to
/// [ThemeMode.light] until a preference has been saved — the app's design is
/// pink-on-white and is meant to be seen in light mode by default, so it
/// deliberately does NOT follow the OS theme on first launch (unlike a
/// typical app default of [ThemeMode.system]).
class ThemeModeController extends Notifier<ThemeMode> {
  static const _prefsKey = 'app.theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = switch (saved) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  /// Called by the Settings "Dark Mode" switch: true → dark, false → light.
  Future<void> setDarkMode(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, enabled ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
