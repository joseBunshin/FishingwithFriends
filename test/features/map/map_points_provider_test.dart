import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/map/data/map_points_provider.dart';
import 'package:fishing_with_friends/features/map/data/mpa_service.dart';
import 'package:fishing_with_friends/features/map/data/mpa_service_provider.dart';
import 'package:fishing_with_friends/features/map/domain/map_point.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// MPA test fixture: a small square around (40.0, -80.0) extending ±0.005°.
const _mpaAround80W40N = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"name": "Test square"},
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [-80.005, 39.995],
          [-79.995, 39.995],
          [-79.995, 40.005],
          [-80.005, 40.005],
          [-80.005, 39.995]
        ]]
      }
    }
  ]
}
''';

const _emptyMpa = '''
{ "type": "FeatureCollection", "features": [] }
''';

DateTime _at(int hour) => DateTime(2026, 4, 1, hour);

Catch _catch({
  required String id,
  required String anglerId,
  double? lat,
  double? lng,
  bool secretSpot = false,
}) {
  return Catch(
    id: id,
    anglerId: anglerId,
    caughtAt: _at(8),
    secretSpot: secretSpot,
    catchAndRelease: false,
    photoPaths: const [],
    createdAt: _at(8),
    updatedAt: _at(8),
    latitude: lat,
    longitude: lng,
    speciesLabel: 'Largemouth Bass',
  );
}

ProviderContainer _container({
  required List<Catch> mine,
  required List<Catch> friends,
  required MpaService mpa,
}) {
  return ProviderContainer(
    overrides: [
      myCatchesProvider.overrideWith((_) async => mine),
      friendsCatchesProvider.overrideWith((_) async => friends),
      mpaServiceProvider.overrideWithValue(mpa),
    ],
  );
}

void main() {
  test('returns own + friend points when both have GPS and no MPA hits',
      () async {
    final container = _container(
      mine: [_catch(id: 'a', anglerId: 'u1', lat: 41, lng: -75)],
      friends: [_catch(id: 'b', anglerId: 'u2', lat: 42, lng: -76)],
      mpa: MpaService.fromGeoJson(_emptyMpa),
    );
    addTearDown(container.dispose);

    final result = await container.read(mapPointsProvider.future);
    expect(result, hasLength(2));
    expect(result[0].source, MapPointSource.own);
    expect(result[1].source, MapPointSource.friend);
    expect(result[0].isMpaShifted, isFalse);
  });

  test('drops friend catches with secret_spot=true defensively', () async {
    final container = _container(
      mine: const [],
      friends: [
        _catch(id: 'b', anglerId: 'u2', lat: 42, lng: -76, secretSpot: true),
      ],
      mpa: MpaService.fromGeoJson(_emptyMpa),
    );
    addTearDown(container.dispose);

    final result = await container.read(mapPointsProvider.future);
    expect(result, isEmpty);
  });

  test('drops own catches without GPS', () async {
    final container = _container(
      mine: [_catch(id: 'a', anglerId: 'u1')],
      friends: const [],
      mpa: MpaService.fromGeoJson(_emptyMpa),
    );
    addTearDown(container.dispose);

    final result = await container.read(mapPointsProvider.future);
    expect(result, isEmpty);
  });

  test('shifts own catches that fall inside an MPA polygon', () async {
    final container = _container(
      mine: [_catch(id: 'a', anglerId: 'u1', lat: 40, lng: -80)],
      friends: const [],
      mpa: MpaService.fromGeoJson(_mpaAround80W40N),
    );
    addTearDown(container.dispose);

    final result = await container.read(mapPointsProvider.future);
    expect(result, hasLength(1));
    expect(result[0].isInMpa, isTrue);
    expect(result[0].isMpaShifted, isTrue);
    expect(result[0].displayLatLng.latitude, isNot(equals(40)));
  });

  test('returns empty list with no friends and no own catches', () async {
    final container = _container(
      mine: const [],
      friends: const [],
      mpa: MpaService.fromGeoJson(_emptyMpa),
    );
    addTearDown(container.dispose);

    final result = await container.read(mapPointsProvider.future);
    expect(result, isEmpty);
  });

  test('surfaces AsyncError when myCatchesProvider throws', () async {
    final container = ProviderContainer(
      overrides: [
        myCatchesProvider
            .overrideWith((_) async => throw StateError('boom')),
        friendsCatchesProvider.overrideWith((_) async => const []),
        mpaServiceProvider.overrideWithValue(
          MpaService.fromGeoJson(_emptyMpa),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(mapPointsProvider.future),
      throwsA(isA<StateError>()),
    );
  });
}
