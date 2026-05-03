import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/stats/application/species_breakdown_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Catch _catch({required String id, String? species}) {
  final ts = DateTime.utc(2026, 4, 1);
  return Catch(
    id: id,
    anglerId: 'u1',
    speciesLabel: species,
    caughtAt: ts,
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: const [],
    createdAt: ts,
    updatedAt: ts,
  );
}

ProviderContainer _container(List<Catch> mine) {
  return ProviderContainer(
    overrides: [
      myCatchesProvider.overrideWith((_) async => mine),
    ],
  );
}

void main() {
  test('returns empty list with no catches', () async {
    final c = _container(const []);
    addTearDown(c.dispose);
    final slices = await c.read(speciesBreakdownProvider.future);
    expect(slices, isEmpty);
  });

  test('groups by species label and sorts descending', () async {
    final c = _container([
      _catch(id: '1', species: 'Bass'),
      _catch(id: '2', species: 'Bass'),
      _catch(id: '3', species: 'Trout'),
      _catch(id: '4', species: 'Bass'),
      _catch(id: '5', species: 'Pike'),
    ]);
    addTearDown(c.dispose);
    final slices = await c.read(speciesBreakdownProvider.future);
    expect(slices.first.label, 'Bass');
    expect(slices.first.count, 3);
    expect(slices[1].label, 'Trout');
    expect(slices[1].count, 1);
    expect(slices[2].label, 'Pike');
  });

  test('null/empty species labels bucket into Unknown', () async {
    final c = _container([
      _catch(id: '1', species: null),
      _catch(id: '2', species: ''),
      _catch(id: '3', species: 'Bass'),
    ]);
    addTearDown(c.dispose);
    final slices = await c.read(speciesBreakdownProvider.future);
    expect(slices.first.label, 'Unknown');
    expect(slices.first.count, 2);
  });
}
