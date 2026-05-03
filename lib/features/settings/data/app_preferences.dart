import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single unified preference for every physical measurement in the app:
/// weight, length, AND temperature. Imperial → lbs / in / °F. Metric →
/// kg / cm / °C. This is intentional — splitting weight from temperature
/// led to the surprise of users picking "metric" but still seeing °F.
enum DisplayUnits { imperial, metric }

extension DisplayUnitsX on DisplayUnits {
  String get label => switch (this) {
        DisplayUnits.imperial => 'Imperial (lbs · in · °F)',
        DisplayUnits.metric => 'Metric (kg · cm · °C)',
      };
  String get tempShort => switch (this) {
        DisplayUnits.imperial => '°F',
        DisplayUnits.metric => '°C',
      };
}

const _kThemeKey = 'app.theme_mode';
const _kUnitsKey = 'app.display_units';

/// Loaded once on app boot. Holds the SharedPreferences singleton + the
/// initial values to seed the providers.
///
/// Tests don't have to override the provider — the default is an
/// in-memory implementation backed by a plain `Map<String, String>`,
/// which gives them imperial-units + system-theme defaults without any
/// platform plugin setup.
class AppPreferences {
  /// Production constructor — wraps SharedPreferences.
  factory AppPreferences(SharedPreferences prefs) =>
      AppPreferences._(prefs: prefs);

  AppPreferences._({
    SharedPreferences? prefs,
    Map<String, String>? memory,
  })  : _prefs = prefs,
        _memory = memory;

  /// Test / fallback constructor — pure in-memory map.
  factory AppPreferences.inMemory([
    Map<String, String> seed = const {},
  ]) =>
      AppPreferences._(memory: Map<String, String>.from(seed));

  final SharedPreferences? _prefs;
  final Map<String, String>? _memory;

  String? _read(String key) =>
      _prefs != null ? _prefs.getString(key) : _memory?[key];

  Future<void> _write(String key, String value) async {
    if (_prefs != null) {
      await _prefs.setString(key, value);
    } else {
      _memory![key] = value;
    }
  }

  ThemeMode get themeMode {
    return switch (_read(_kThemeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _write(
      _kThemeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  DisplayUnits get displayUnits {
    return _read(_kUnitsKey) == 'metric'
        ? DisplayUnits.metric
        : DisplayUnits.imperial;
  }

  Future<void> setDisplayUnits(DisplayUnits units) {
    return _write(
      _kUnitsKey,
      units == DisplayUnits.metric ? 'metric' : 'imperial',
    );
  }
}

/// Initialized in `main.dart` via `appPreferencesProvider.overrideWithValue`.
/// Defaults to an in-memory implementation so widget tests that don't
/// care about preferences don't have to override anything.
final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences.inMemory();
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
