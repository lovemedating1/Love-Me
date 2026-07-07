import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's light/dark/system theme choice across app restarts.
///
/// Backed by [SharedPreferences] under [_prefsKey]. Defaults to
/// [ThemeMode.system] until a preference has been saved, matching the
/// "Dark Mode" switch semantics used in Settings (off = light, on = dark —
/// system is only the initial/unset state, never re-selectable from the UI).
class ThemeModeController extends Notifier<ThemeMode> {
  static const _prefsKey = 'app.theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
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

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
