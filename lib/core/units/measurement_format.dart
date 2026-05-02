import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';

/// Conversion factors. Persistence is metric (kg, cm); these only matter
/// when rendering for display.
const double _kgToLb = 2.20462;
const double _cmToInch = 1 / 2.54;

/// Format a weight value (stored in kg) for display per the user's
/// preferred units. Returns null when [kg] is null.
///
///   formatWeight(2.0, DisplayUnits.imperial) // -> '4.4 lbs'
///   formatWeight(2.0, DisplayUnits.metric)   // -> '2.0 kg'
///   formatWeight(2.0, DisplayUnits.imperial, compact: true) // -> '4 lbs'
String? formatWeight(
  double? kg,
  DisplayUnits units, {
  bool compact = false,
}) {
  if (kg == null) return null;
  final digits = compact ? 0 : 1;
  return switch (units) {
    DisplayUnits.imperial =>
      '${(kg * _kgToLb).toStringAsFixed(digits)} lbs',
    DisplayUnits.metric => '${kg.toStringAsFixed(digits)} kg',
  };
}

/// Format a length value (stored in cm) for display per the user's
/// preferred units. Returns null when [cm] is null.
///
///   formatLength(50.0, DisplayUnits.imperial) // -> '19.7 in'
///   formatLength(50.0, DisplayUnits.metric)   // -> '50.0 cm'
String? formatLength(double? cm, DisplayUnits units) {
  if (cm == null) return null;
  return switch (units) {
    DisplayUnits.imperial => '${(cm * _cmToInch).toStringAsFixed(1)} in',
    DisplayUnits.metric => '${cm.toStringAsFixed(1)} cm',
  };
}
