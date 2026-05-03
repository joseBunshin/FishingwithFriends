import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/stats/application/stats_time_of_day_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Catch _catchAt(DateTime ts) {
  return Catch(
    id: 'c-${ts.millisecondsSinceEpoch}',
    anglerId: 'u1',
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
  test('returns 24 zeros when no catches', () async {
    final container = _container(const []);
    addTearDown(container.dispose);
    final result = await container.read(statsTimeOfDayProvider.future);
    expect(result, hasLength(24));
    expect(result.every((b) => b == 0), isTrue);
  });

  test('buckets catches into the correct local hour', () async {
    final container = _container([
      _catchAt(DateTime(2026, 4, 1, 6)),
      _catchAt(DateTime(2026, 4, 1, 6, 45)),
      _catchAt(DateTime(2026, 4, 1, 18, 30)),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(statsTimeOfDayProvider.future);
    expect(result[6], 2);
    expect(result[18], 1);
    expect(result[0], 0);
  });

  test('uses local timezone (toLocal) when bucketizing UTC timestamps',
      () async {
    // A catch at 2026-04-01T03:00:00Z. Whatever the local TZ is, the
    // bucket index must equal the .toLocal().hour of that DateTime.
    final ts = DateTime.utc(2026, 4, 1, 3);
    final expectedHour = ts.toLocal().hour;
    final container = _container([_catchAt(ts)]);
    addTearDown(container.dispose);

    final result = await container.read(statsTimeOfDayProvider.future);
    expect(result[expectedHour], 1);
  });
}
