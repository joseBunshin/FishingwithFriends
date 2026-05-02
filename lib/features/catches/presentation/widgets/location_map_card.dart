import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

/// Inline map card for a single coordinate. Replaces "lat, lng" text
/// with a tappable mini-map. Tap → opens a fullscreen LocationDetailScreen
/// with the same point.
class LocationMapCard extends StatelessWidget {
  const LocationMapCard({
    required this.latitude,
    required this.longitude,
    this.title = 'Location',
    this.height = 160,
    super.key,
  });

  final double latitude;
  final double longitude;
  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => _open(context, point),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AbsorbPointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 12,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.bunshin.fishingwithfriends',
                          tileProvider: CancellableNetworkTileProvider(),
                          maxNativeZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 32,
                              height: 32,
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.orange,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom gradient + coordinate readout
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.85),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '${latitude.toStringAsFixed(4)}, '
                            '${longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const Text(
                          'View',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, LatLng point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocationDetailScreen(
          latitude: latitude,
          longitude: longitude,
          title: title,
        ),
      ),
    );
  }
}

/// Fullscreen map zoomed to a single coordinate. Push via
/// MaterialPageRoute — uses native back-button navigation.
///
/// Layout matches MapScreen: Column → Expanded → Stack → FlutterMap.
/// Direct FlutterMap-as-Scaffold-body has flaky sizing on Flutter web
/// (renders an empty viewport), Stack-wrapped is reliable.
class LocationDetailScreen extends StatelessWidget {
  const LocationDetailScreen({
    required this.latitude,
    required this.longitude,
    this.title = 'Location',
    super.key,
  });

  final double latitude;
  final double longitude;
  final String title;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.bunshin.fishingwithfriends',
                      tileProvider: CancellableNetworkTileProvider(),
                      maxNativeZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.orange,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: _CoordinatePanel(
                    latitude: latitude,
                    longitude: longitude,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinatePanel extends StatelessWidget {
  const _CoordinatePanel({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.my_location,
              size: 18,
              color: AppColors.orange,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COORDINATES',
                    style: TextStyle(
                      color: AppColors.mist.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    '${latitude.toStringAsFixed(6)}, '
                    '${longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
