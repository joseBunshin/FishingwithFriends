/// Persistence is canonical metric (kg, cm). Display + entry support per-input
/// imperial/metric toggle. These helpers keep conversion in one place.
class Units {
  const Units._();

  static const double _lbPerKg = 2.20462;
  static const double _cmPerIn = 2.54;

  static double lbToKg(double lb) => lb / _lbPerKg;
  static double kgToLb(double kg) => kg * _lbPerKg;

  static double inToCm(double inches) => inches * _cmPerIn;
  static double cmToIn(double cm) => cm / _cmPerIn;
}

enum WeightUnit { kg, lb }

enum LengthUnit { cm, inch }
