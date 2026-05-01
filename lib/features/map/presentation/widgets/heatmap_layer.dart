import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/features/map/domain/map_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Bins points into ~0.01° cells (~1km at the equator) and renders each
/// non-empty bin as a semi-transparent square. Density (cells with more
/// points) reads as more saturated alpha; intentionally chunky so a
/// secret-spot-suppressed catch can never be inferred from a single
/// pixel.
class HeatmapLayer extends StatelessWidget {
  const HeatmapLayer({
    required this.points,
    required this.source,
    super.key,
  });

  final List<MapPoint> points;
  final MapPointSource source;

  static const double _binSizeDeg = 0.01;

  @override
  Widget build(BuildContext context) {
    final filtered = points.where((p) => p.source == source).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    final bins = <_BinKey, int>{};
    for (final p in filtered) {
      final key = _BinKey.from(p.displayLatLng);
      bins[key] = (bins[key] ?? 0) + 1;
    }

    final maxCount = bins.values.fold<int>(1, (a, b) => a > b ? a : b);
    final fill = source == MapPointSource.own
        ? AppColors.navy
        : AppColors.success;

    final polygons = <Polygon>[];
    for (final entry in bins.entries) {
      final ratio = (entry.value / maxCount).clamp(0.25, 1.0);
      polygons.add(
        Polygon(
          points: entry.key.cornerLatLngs(),
          color: fill.withValues(alpha: 0.15 + 0.35 * ratio),
          borderColor: fill.withValues(alpha: 0.5),
          borderStrokeWidth: 1,
        ),
      );
    }

    return PolygonLayer(polygons: polygons);
  }
}

@immutable
class _BinKey {
  const _BinKey(this.latIdx, this.lngIdx);

  factory _BinKey.from(LatLng p) {
    final latIdx = (p.latitude / HeatmapLayer._binSizeDeg).floor();
    final lngIdx = (p.longitude / HeatmapLayer._binSizeDeg).floor();
    return _BinKey(latIdx, lngIdx);
  }

  final int latIdx;
  final int lngIdx;

  List<LatLng> cornerLatLngs() {
    final south = latIdx * HeatmapLayer._binSizeDeg;
    final north = south + HeatmapLayer._binSizeDeg;
    final west = lngIdx * HeatmapLayer._binSizeDeg;
    final east = west + HeatmapLayer._binSizeDeg;
    return [
      LatLng(south, west),
      LatLng(south, east),
      LatLng(north, east),
      LatLng(north, west),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is _BinKey && other.latIdx == latIdx && other.lngIdx == lngIdx;

  @override
  int get hashCode => Object.hash(latIdx, lngIdx);
}
