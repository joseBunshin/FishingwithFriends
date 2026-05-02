import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/stats/application/catches_over_time_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Catch _catch({required String id, required DateTime at}) {
  return Catch(
    id: id,
    anglerId: 'u1',
    caughtAt: at,
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: const [],
    createdAt: at,
    updatedAt: at,
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
  test('always returns 12 buckets, even with no catches', () async {
    final c = _container(const []);
    addTearDown(c.dispose);
    final buckets = await c.read(catchesOverTimeProvider.future);
    expect(buckets, hasLength(12));
    expect(buckets.every((b) => b.count == 0), isTrue);
  });

  test('counts a recent catch into the current week bucket', () async {
    final now = DateTime.now();
    final c = _container([
      _catch(id: '1', at: now.subtract(const Duration(hours: 1))),
    ]);
    addTearDown(c.dispose);
    final buckets = await c.read(catchesOverTimeProvider.future);
    expect(buckets.last.count, 1);
  });

  test('catches older than 12 weeks fall outside the window', () async {
    final long = DateTime.now().subtract(const Duration(days: 365));
    final c = _container([_catch(id: '1', at: long)]);
    addTearDown(c.dispose);
    final buckets = await c.read(catchesOverTimeProvider.future);
    expect(buckets.fold<int>(0, (a, b) => a + b.count), 0);
  });

  test('buckets are sorted ascending by weekStart', () async {
    final c = _container(const []);
    addTearDown(c.dispose);
    final buckets = await c.read(catchesOverTimeProvider.future);
    for (var i = 1; i < buckets.length; i++) {
      expect(
        buckets[i].weekStart.isAfter(buckets[i - 1].weekStart),
        isTrue,
      );
    }
  });
}
