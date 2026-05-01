import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/home/data/home_metrics_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Catch _c({
  String id = 'x',
  String? species,
  double? weight,
}) {
  return Catch(
    id: id,
    anglerId: 'a',
    speciesLabel: species,
    weightKg: weight,
    caughtAt: DateTime.utc(2026, 4, 12),
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: const [],
    createdAt: DateTime.utc(2026, 4, 12),
    updatedAt: DateTime.utc(2026, 4, 12),
  );
}

void main() {
  group('deriveHomeMetrics', () {
    test('empty catches list → HomeMetrics.empty()', () {
      final m = deriveHomeMetrics(const []);
      expect(m.isEmpty, isTrue);
      expect(m.totalCatches, 0);
      expect(m.uniqueSpecies, 0);
    });

    test('three catches with two species and weights aggregate correctly', () {
      final catches = [
        _c(id: '1', species: 'Bass', weight: 1),
        _c(id: '2', species: 'Bass', weight: 2),
        _c(id: '3', species: 'Trout', weight: 3),
      ];
      final m = deriveHomeMetrics(catches);
      expect(m.totalCatches, 3);
      expect(m.totalWeightKg, 6);
      expect(m.uniqueSpecies, 2);
      expect(m.biggestWeightKg, 3);
      expect(m.biggestSpecies, 'Trout');
    });

    test('catch with null weight contributes to count but not total', () {
      final catches = [
        _c(id: '1', species: 'Bass', weight: 2),
        _c(id: '2', species: 'Trout'),
      ];
      final m = deriveHomeMetrics(catches);
      expect(m.totalCatches, 2);
      expect(m.totalWeightKg, 2);
      expect(m.uniqueSpecies, 2);
      expect(m.biggestWeightKg, 2);
    });

    test('catch with null species does not bump uniqueSpecies', () {
      final catches = [
        _c(id: '1', weight: 1),
        _c(id: '2', species: 'Bass', weight: 2),
      ];
      final m = deriveHomeMetrics(catches);
      expect(m.uniqueSpecies, 1);
      expect(m.totalCatches, 2);
    });
  });
}
