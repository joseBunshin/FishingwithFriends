import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/stats/application/conditions_correlation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Catch _catch({
  required String id,
  required String species,
  double weight = 4,
  Map<String, dynamic> conditions = const {},
}) {
  final ts = DateTime.utc(2026, 4, 1);
  return Catch(
    id: id,
    anglerId: 'u1',
    speciesLabel: species,
    weightKg: weight,
    caughtAt: ts,
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: const [],
    createdAt: ts,
    updatedAt: ts,
    conditions: conditions,
  );
}

ProviderContainer _container(List<Catch> mine) {
  return ProviderContainer(
    overrides: [myCatchesProvider.overrideWith((_) async => mine)],
  );
}

void main() {
  test('returns empty when fewer than 10 catches with conditions', () async {
    final c = _container([
      for (var i = 0; i < 5; i++)
        _catch(
          id: 'c$i',
          species: 'Bass',
          conditions: {'temp_c': 18, 'tide_state': 'falling'},
        ),
    ]);
    addTearDown(c.dispose);
    final result =
        await c.read(conditionsCorrelationProvider.future);
    expect(result, isEmpty);
  });

  test('surfaces dominant tide + temp bucket once threshold met',
      () async {
    final c = _container([
      for (var i = 0; i < 12; i++)
        _catch(
          id: 'b$i',
          species: 'Bass',
          weight: 5.0 + i,
          conditions: {
            'temp_c': 20.0,
            'tide_state': i.isEven ? 'falling' : 'rising',
          },
        ),
    ]);
    addTearDown(c.dispose);
    final result =
        await c.read(conditionsCorrelationProvider.future);
    expect(result, isNotEmpty);
    expect(result.first.species, 'Bass');
    // DisplayUnits defaults to imperial (51f4bb7) — bucket is rendered
    // in °F regardless of the °C input on the catch row.
    expect(result.first.tempBucket, contains('°F water'));
  });

  test('catches without conditions are ignored', () async {
    final c = _container([
      for (var i = 0; i < 12; i++)
        _catch(id: 'c$i', species: 'Bass'), // no conditions
    ]);
    addTearDown(c.dispose);
    final result =
        await c.read(conditionsCorrelationProvider.future);
    expect(result, isEmpty);
  });
}
