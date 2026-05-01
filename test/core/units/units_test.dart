import 'package:fishing_with_friends/core/units/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Units', () {
    test('round-trips weight kg <-> lb within 0.001', () {
      const kg = 4.2;
      final lb = Units.kgToLb(kg);
      expect(Units.lbToKg(lb), closeTo(kg, 0.001));
    });

    test('round-trips length cm <-> in within 0.001', () {
      const cm = 45.7;
      final inches = Units.cmToIn(cm);
      expect(Units.inToCm(inches), closeTo(cm, 0.001));
    });

    test('1 kg ≈ 2.20462 lb', () {
      expect(Units.kgToLb(1), closeTo(2.20462, 0.0001));
    });

    test('1 in == 2.54 cm exactly', () {
      expect(Units.inToCm(1), 2.54);
    });
  });
}
