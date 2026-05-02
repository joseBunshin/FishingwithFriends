import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/map/data/map_points_provider.dart';
import 'package:fishing_with_friends/features/map/domain/map_point.dart';
import 'package:fishing_with_friends/features/map/presentation/widgets/conditions_chip_strip.dart';
import 'package:fishing_with_friends/features/map/presentation/widgets/heatmap_layer.dart';
import 'package:fishing_with_friends/features/map/presentation/widgets/map_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _showFriends = true;
  bool _heatmap = true; // Default ON per origin spec.

  /// Continental US fallback when the user has no GPS-tagged catches yet.
  static const LatLng _fallbackCenter = LatLng(39.5, -98.35);
  static const double _fallbackZoom = 4;
  static const double _focusedZoom = 6;

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(mapPointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catch Map'),
        actions: const [ConditionsChipStrip()],
      ),
      body: Column(
        children: [
          MapControls(
            showFriends: _showFriends,
            heatmap: _heatmap,
            onShowFriendsChanged: (v) => setState(() => _showFriends = v),
            onHeatmapChanged: (v) => setState(() => _heatmap = v),
          ),
          if (pointsAsync.isLoading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _MapBody(
              pointsAsync: pointsAsync,
              showFriends: _showFriends,
              heatmap: _heatmap,
              fallbackCenter: _fallbackCenter,
              fallbackZoom: _fallbackZoom,
              focusedZoom: _focusedZoom,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({
    required this.pointsAsync,
    required this.showFriends,
    required this.heatmap,
    required this.fallbackCenter,
    required this.fallbackZoom,
    required this.focusedZoom,
  });

  final AsyncValue<List<MapPoint>> pointsAsync;
  final bool showFriends;
  final bool heatmap;
  final LatLng fallbackCenter;
  final double fallbackZoom;
  final double focusedZoom;

  @override
  Widget build(BuildContext context) {
    final allPoints = pointsAsync.valueOrNull ?? const <MapPoint>[];
    final ownPoints = allPoints
        .where((p) => p.source == MapPointSource.own)
        .toList(growable: false);
    final friendPoints = allPoints
        .where((p) => p.source == MapPointSource.friend)
        .toList(growable: false);

    final initialCenter = ownPoints.isNotEmpty
        ? _averageOf(ownPoints)
        : friendPoints.isNotEmpty
            ? _averageOf(friendPoints)
            : fallbackCenter;
    final initialZoom = allPoints.isEmpty ? fallbackZoom : focusedZoom;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bunshin.fishingwithfriends',
              tileProvider: CancellableNetworkTileProvider(),
              maxNativeZoom: 19,
            ),
            if (heatmap && showFriends)
              HeatmapLayer(
                points: friendPoints,
                source: MapPointSource.friend,
              ),
            MarkerLayer(
              markers: [
                for (final p in ownPoints) _markerFor(context, p),
                if (showFriends && !heatmap)
                  for (final p in friendPoints) _markerFor(context, p),
              ],
            ),
          ],
        ),
        if (allPoints.isEmpty && !pointsAsync.isLoading)
          const Positioned(
            top: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _EmptyPill(),
          ),
        if (pointsAsync.hasError)
          const Positioned(
            top: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _ErrorPill(),
          ),
        const Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _LegendCard(),
        ),
      ],
    );
  }

  LatLng _averageOf(List<MapPoint> points) {
    var lat = 0.0;
    var lng = 0.0;
    for (final p in points) {
      lat += p.displayLatLng.latitude;
      lng += p.displayLatLng.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  Marker _markerFor(BuildContext context, MapPoint p) {
    final color = p.source == MapPointSource.own
        ? AppColors.navy
        : AppColors.success;
    return Marker(
      point: p.displayLatLng,
      width: 32,
      height: 32,
      child: GestureDetector(
        onTap: () => context.push('/catch/${p.catchId}'),
        child: _PinIcon(color: color, isInMpa: p.isInMpa),
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon({required this.color, required this.isInMpa});

  final Color color;
  final bool isInMpa;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.location_on, color: color, size: 32),
        if (isInMpa)
          const Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.lock_outline,
              size: 12,
              color: AppColors.white,
            ),
          ),
      ],
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(color: AppColors.navy, label: 'Yours'),
            SizedBox(width: AppSpacing.md),
            _LegendDot(color: AppColors.success, label: 'Friends'),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyPill extends StatelessWidget {
  const _EmptyPill();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, size: 18, color: AppColors.navy),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Log a catch with location to see your pins.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPill extends StatelessWidget {
  const _ErrorPill();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.error.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "Couldn't load some pins. Pull to retry.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
