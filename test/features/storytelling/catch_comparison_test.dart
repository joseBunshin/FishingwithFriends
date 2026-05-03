import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/storytelling/application/catch_comparison_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _ts(int year, int month, int day) => DateTime(year, month, day, 12);

Catch _catch({
  required String id,
  required String? speciesId,
  required String? speciesLabel,
  required double? weightKg,
  required DateTime caughtAt,
  double? lengthCm,
}) {
  return Catch(
    id: id,
    anglerId: 'u1',
    speciesId: speciesId,
    speciesLabel: speciesLabel,
    weightKg: weightKg,
    lengthCm: lengthCm,
    caughtAt: caughtAt,
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: const [],
    createdAt: caughtAt,
    updatedAt: caughtAt,
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
  test('rank=1 with single largemouth — interesting + all-time best', () async {
    final c = _catch(
      id: 'c1',
      speciesId: 's-bass',
      speciesLabel: 'Largemouth',
      weightKg: 4,
      caughtAt: _ts(2026, 4, 1),
    );
    final container = _container([c]);
    addTearDown(container.dispose);

    final cmp = await container.read(catchComparisonProvider('c1').future);
    expect(cmp, isNotNull);
    expect(cmp!.rank, 1);
    expect(cmp.isInteresting, isTrue);
    expect(cmp.isAllTimeBest, isTrue);
  });

  test('three same-species catches in a year — middle ranks 2', () async {
    final catches = [
      _catch(id: 'c1', speciesId: 's', speciesLabel: 'Trout',
          weightKg: 1, caughtAt: _ts(2026, 1, 1)),
      _catch(id: 'c2', speciesId: 's', speciesLabel: 'Trout',
          weightKg: 3, caughtAt: _ts(2026, 2, 1)),
      _catch(id: 'c3', speciesId: 's', speciesLabel: 'Trout',
          weightKg: 5, caughtAt: _ts(2026, 3, 1)),
    ];
    final container = _container(catches);
    addTearDown(container.dispose);

    final cmp = await container.read(catchComparisonProvider('c2').future);
    expect(cmp!.rank, 2);
    expect(cmp.total, 3);
    expect(cmp.isInteresting, isTrue);
    expect(cmp.isAllTimeBest, isFalse);
  });

  test('rank > 3 is not interesting', () async {
    final catches = [
      for (var i = 0; i < 5; i++)
        _catch(id: 'c$i', speciesId: 's', speciesLabel: 'Bass',
            weightKg: (i + 1).toDouble(), caughtAt: _ts(2026, 1, 1)),
    ];
    final container = _container(catches);
    addTearDown(container.dispose);

    // The smallest (c0) ranks last — 5th of 5.
    final cmp = await container.read(catchComparisonProvider('c0').future);
    expect(cmp!.rank, 5);
    expect(cmp.isInteresting, isFalse);
  });

  test('catch with null weight + null length returns null', () async {
    final c = _catch(
      id: 'c1', speciesId: 's', speciesLabel: 'Bass',
      weightKg: null, caughtAt: _ts(2026, 1, 1),
    );
    final container = _container([c]);
    addTearDown(container.dispose);

    final cmp = await container.read(catchComparisonProvider('c1').future);
    expect(cmp, isNull);
  });

  test('catch with null species returns null', () async {
    final c = _catch(
      id: 'c1', speciesId: null, speciesLabel: null,
      weightKg: 4, caughtAt: _ts(2026, 1, 1),
    );
    final container = _container([c]);
    addTearDown(container.dispose);

    final cmp = await container.read(catchComparisonProvider('c1').future);
    expect(cmp, isNull);
  });

  test('only same-year catches are compared', () async {
    final catches = [
      _catch(id: 'old', speciesId: 's', speciesLabel: 'Bass',
          weightKg: 10, caughtAt: _ts(2025, 1, 1)),
      _catch(id: 'new', speciesId: 's', speciesLabel: 'Bass',
          weightKg: 5, caughtAt: _ts(2026, 1, 1)),
    ];
    final container = _container(catches);
    addTearDown(container.dispose);

    // 'new' is rank 1 within 2026 even though 2025 had a heavier fish.
    final cmp = await container.read(catchComparisonProvider('new').future);
    expect(cmp!.rank, 1);
    expect(cmp.isAllTimeBest, isFalse); // because the older one is heavier
  });
}
