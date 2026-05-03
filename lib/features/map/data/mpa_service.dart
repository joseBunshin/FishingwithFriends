import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Result of asking [MpaService] whether a point is inside a Marine
/// Protected Area, and what should be displayed in its place.
class MpaShiftResult {
  const MpaShiftResult({
    required this.displayLatLng,
    required this.wasInMpa,
    required this.wasShifted,
  });

  /// The lat/lng to render. Equal to the input when the point is outside
  /// any MPA, or when the input was inside but no escape direction could
  /// be found within the search budget. Otherwise a nearby non-MPA point.
  final LatLng displayLatLng;

  /// True when the input fell inside any MPA polygon.
  final bool wasInMpa;

  /// True when [displayLatLng] differs from the input. Always false when
  /// [wasInMpa] is false. Can be false when [wasInMpa] is true and the
  /// search budget exhausted without finding an escape — callers should
  /// suppress the exact pin in that case (heatmap density only).
  final bool wasShifted;
}

/// Loads a bundled GeoJSON of Marine Protected Area polygons and answers
/// two questions about a lat/lng:
///   * is it inside an MPA?
///   * if yes, what's the nearest non-MPA point we can display instead?
///
/// The dataset ships under `assets/geo/mpa_simplified.geojson`. See the
/// asset's README for source, simplification rules, and refresh procedure.
///
/// All asset parsing is lazy; the first method call triggers the load and
/// subsequent calls return synchronously off the cached polygon list.
class MpaService {
  MpaService._({required Future<String> Function() loader}) : _loader = loader;

  /// Production constructor — loads from `rootBundle`.
  factory MpaService.fromAssetBundle({
    String assetKey = 'assets/geo/mpa_simplified.geojson',
  }) {
    return MpaService._(
      loader: () => rootBundle.loadString(assetKey),
    );
  }

  /// Test constructor — bypasses the asset bundle.
  factory MpaService.fromGeoJson(String geoJson) {
    return MpaService._(loader: () async => geoJson);
  }

  final Future<String> Function() _loader;
  Future<List<List<LatLng>>>? _polygons;

  /// Step size when searching for a nearest non-MPA point. ~0.005° ≈ 500m.
  static const double _stepDeg = 0.005;

  /// Maximum search iterations (each iteration tries 8 compass directions).
  /// 8 iterations × 0.005° ≈ 4km maximum offset before we give up.
  static const int _maxSteps = 8;

  Future<List<List<LatLng>>> _loadPolygons() {
    return _polygons ??= _parse();
  }

  Future<List<List<LatLng>>> _parse() async {
    final raw = await _loader();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('GeoJSON root must be a JSON object.');
    }
    final features = decoded['features'];
    if (features is! List) {
      throw const FormatException('GeoJSON missing "features" array.');
    }

    final out = <List<LatLng>>[];
    for (final feature in features) {
      if (feature is! Map<String, dynamic>) continue;
      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) continue;
      if (geometry['type'] != 'Polygon') continue;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.isEmpty) continue;
      final outerRing = coordinates.first;
      if (outerRing is! List) continue;

      final ring = <LatLng>[];
      for (final pair in outerRing) {
        if (pair is! List || pair.length < 2) {
          throw const FormatException(
            'Polygon coordinate must be a [lng, lat] pair.',
          );
        }
        final lng = (pair[0] as num).toDouble();
        final lat = (pair[1] as num).toDouble();
        ring.add(LatLng(lat, lng));
      }
      if (ring.length >= 3) {
        out.add(ring);
      }
    }
    return out;
  }

  /// True when [point] falls inside any loaded MPA polygon.
  Future<bool> isInMpa(LatLng point) async {
    final polygons = await _loadPolygons();
    return _anyContains(polygons, point);
  }

  /// Convenience: returns the input unchanged when outside any MPA,
  /// otherwise returns the nearest-non-MPA shift result.
  Future<MpaShiftResult> shift(LatLng point) async {
    final polygons = await _loadPolygons();
    if (!_anyContains(polygons, point)) {
      return MpaShiftResult(
        displayLatLng: point,
        wasInMpa: false,
        wasShifted: false,
      );
    }
    final escaped = _findEscape(polygons, point);
    return MpaShiftResult(
      displayLatLng: escaped ?? point,
      wasInMpa: true,
      wasShifted: escaped != null,
    );
  }

  static bool _anyContains(List<List<LatLng>> polygons, LatLng p) {
    for (final ring in polygons) {
      if (_pointInRing(ring, p)) return true;
    }
    return false;
  }

  /// Ray-casting point-in-polygon. Standard algorithm — counts how many
  /// horizontal rays from `p` to +∞ cross polygon edges; odd = inside.
  static bool _pointInRing(List<LatLng> ring, LatLng p) {
    var inside = false;
    final n = ring.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;
      final crosses = (yi > p.latitude) != (yj > p.latitude) &&
          p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi;
      if (crosses) inside = !inside;
    }
    return inside;
  }

  /// Walks 8 compass directions in expanding ~500m steps. Returns the
  /// first lat/lng that escapes every polygon, or null after [_maxSteps]
  /// iterations.
  static LatLng? _findEscape(List<List<LatLng>> polygons, LatLng start) {
    const sqrt2 = math.sqrt2;
    // Order: N, NE, E, SE, S, SW, W, NW. Components scaled so diagonals
    // cover the same Euclidean distance per step.
    final directions = <List<double>>[
      [0, 1],
      [1 / sqrt2, 1 / sqrt2],
      [1, 0],
      [1 / sqrt2, -1 / sqrt2],
      [0, -1],
      [-1 / sqrt2, -1 / sqrt2],
      [-1, 0],
      [-1 / sqrt2, 1 / sqrt2],
    ];

    for (var step = 1; step <= _maxSteps; step++) {
      for (final dir in directions) {
        final candidate = LatLng(
          start.latitude + dir[1] * _stepDeg * step,
          start.longitude + dir[0] * _stepDeg * step,
        );
        if (!_anyContains(polygons, candidate)) return candidate;
      }
    }
    return null;
  }
}
