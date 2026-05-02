import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DisplayUnits { imperial, metric }

extension DisplayUnitsX on DisplayUnits {
  String get label => switch (this) {
        DisplayUnits.imperial => 'Imperial (lbs · in)',
        DisplayUnits.metric => 'Metric (kg · cm)',
      };
}

const _kThemeKey = 'app.theme_mode';
const _kUnitsKey = 'app.display_units';

/// Loaded once on app boot. Holds the SharedPreferences singleton + the
/// initial values to seed the providers.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  ThemeMode get themeMode {
    final raw = _prefs.getString(_kThemeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(
      _kThemeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  DisplayUnits get displayUnits {
    final raw = _prefs.getString(_kUnitsKey);
    return raw == 'metric' ? DisplayUnits.metric : DisplayUnits.imperial;
  }

  Future<void> setDisplayUnits(DisplayUnits units) async {
    await _prefs.setString(
      _kUnitsKey,
      units == DisplayUnits.metric ? 'metric' : 'imperial',
    );
  }
}

/// Initialized in `main.dart` via `appPreferencesProvider.overrideWithValue`.
/// Throws when read before initialization to surface bootstrap-order bugs.
final appPreferencesProvider = Provider<AppPreferences>((ref) {
  throw StateError(
    'appPreferencesProvider must be overridden at app boot. '
    'See main.dart.',
  );
});

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(appPreferencesProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    await ref.read(appPreferencesProvider).setThemeMode(mode);
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class DisplayUnitsController extends Notifier<DisplayUnits> {
  @override
  DisplayUnits build() => ref.watch(appPreferencesProvider).displayUnits;

  Future<void> set(DisplayUnits units) async {
    await ref.read(appPreferencesProvider).setDisplayUnits(units);
    state = units;
  }
}

final displayUnitsProvider =
    NotifierProvider<DisplayUnitsController, DisplayUnits>(
        DisplayUnitsController.new);
