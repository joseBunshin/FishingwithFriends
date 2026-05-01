import 'package:fishing_with_friends/features/map/data/mpa_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// A simple square polygon centered at (0,0) extending ±0.01° in lat/lng.
/// Sized so the 8-step escape budget (max ~0.04°) can find a way out.
const _squareAroundOrigin = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"name": "Test square"},
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [-0.01, -0.01],
          [0.01, -0.01],
          [0.01, 0.01],
          [-0.01, 0.01],
          [-0.01, -0.01]
        ]]
      }
    }
  ]
}
''';

/// Two adjacent squares with no gap between them — used to test the
/// "no escape" path.
const _adjacentSquares = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"name": "Left half"},
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [-1.0, -1.0],
          [0.0, -1.0],
          [0.0, 1.0],
          [-1.0, 1.0],
          [-1.0, -1.0]
        ]]
      }
    },
    {
      "type": "Feature",
      "properties": {"name": "Right half"},
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [0.0, -1.0],
          [1.0, -1.0],
          [1.0, 1.0],
          [0.0, 1.0],
          [0.0, -1.0]
        ]]
      }
    }
  ]
}
''';

void main() {
  group('MpaService.isInMpa', () {
    test('returns false for a point clearly outside any polygon', () async {
      final svc = MpaService.fromGeoJson(_squareAroundOrigin);
      expect(await svc.isInMpa(const LatLng(40, -80)), isFalse);
    });

    test('returns true for a point clearly inside the polygon', () async {
      final svc = MpaService.fromGeoJson(_squareAroundOrigin);
      expect(await svc.isInMpa(const LatLng(0, 0)), isTrue);
    });

    test('handles an edge-adjacent point deterministically', () async {
      final svc = MpaService.fromGeoJson(_squareAroundOrigin);
      // Right on the eastern edge — must not throw, must return some bool.
      final result = await svc.isInMpa(const LatLng(0, 0.01));
      expect(result, isA<bool>());
    });
  });

  group('MpaService.shift', () {
    test('passes a non-MPA point through unchanged', () async {
      final svc = MpaService.fromGeoJson(_squareAroundOrigin);
      const input = LatLng(40.7128, -74.0060); // New York City
      final result = await svc.shift(input);
      expect(result.wasInMpa, isFalse);
      expect(result.wasShifted, isFalse);
      expect(result.displayLatLng, input);
    });

    test('shifts an in-MPA point to outside the polygon', () async {
      final svc = MpaService.fromGeoJson(_squareAroundOrigin);
      const input = LatLng(0, 0);
      final result = await svc.shift(input);
      expect(result.wasInMpa, isTrue);
      expect(result.wasShifted, isTrue);
      expect(result.displayLatLng, isNot(equals(input)));
      // The shifted point must itself be outside the polygon.
      expect(await svc.isInMpa(result.displayLatLng), isFalse);
    });

    test('returns wasShifted=false when no escape is found', () async {
      // 8 steps × 0.005° ≈ 0.04°. The combined polygon spans 2°×2°, so
      // a point at the center cannot escape in 8 iterations.
      final svc = MpaService.fromGeoJson(_adjacentSquares);
      const input = LatLng(0, 0);
      final result = await svc.shift(input);
      expect(result.wasInMpa, isTrue);
      expect(result.wasShifted, isFalse);
      // When escape fails, displayLatLng falls back to the input — the
      // caller is expected to suppress the exact pin in this case.
      expect(result.displayLatLng, input);
    });
  });

  group('MpaService asset parsing', () {
    test('throws FormatException on malformed JSON', () async {
      final svc = MpaService.fromGeoJson('not json at all');
      expect(svc.isInMpa(const LatLng(0, 0)), throwsFormatException);
    });

    test('throws FormatException when "features" is missing', () async {
      final svc = MpaService.fromGeoJson('{"type": "FeatureCollection"}');
      expect(svc.isInMpa(const LatLng(0, 0)), throwsFormatException);
    });

    test('skips non-Polygon features without throwing', () async {
      const mixed = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [0, 0]}
          },
          {
            "type": "Feature",
            "geometry": {
              "type": "Polygon",
              "coordinates": [[
                [-0.01, -0.01],
                [0.01, -0.01],
                [0.01, 0.01],
                [-0.01, 0.01],
                [-0.01, -0.01]
              ]]
            }
          }
        ]
      }
      ''';
      final svc = MpaService.fromGeoJson(mixed);
      expect(await svc.isInMpa(const LatLng(0, 0)), isTrue);
    });

    test('handles concurrent first-load calls without throwing', () async {
      final svc = MpaService.fromGeoJson(_squareAroundOrigin);
      // Fire two concurrent calls before either completes — both must
      // resolve to the same cached polygon set.
      final results = await Future.wait([
        svc.isInMpa(const LatLng(0, 0)),
        svc.isInMpa(const LatLng(40, -80)),
      ]);
      expect(results, [true, false]);
    });
  });
}
