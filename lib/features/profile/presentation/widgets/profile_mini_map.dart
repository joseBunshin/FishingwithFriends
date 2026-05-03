import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

/// Fixed-height map showing pins for a single angler's catches. Used on
/// the public ProfileScreen so visitors can see where the visited
/// angler fishes without leaving the profile.
///
/// Uses `catchesForAnglerProvider` (friend-view, secret-spot GPS masked)
/// so secret-spot rows simply don't render a pin. Empty list → tasteful
/// empty state, never a blank tile field.
class ProfileMiniMap extends ConsumerWidget {
  const ProfileMiniMap({
    required this.anglerId,
    this.height = 200,
    super.key,
  });

  final String anglerId;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCatches = ref.watch(catchesForAnglerProvider(anglerId));
    final catches = asyncCatches.valueOrNull ?? const <Catch>[];
    final geo = catches
        .where((c) => c.latitude != null && c.longitude != null)
        .toList(growable: false);

    if (asyncCatches.isLoading && catches.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (geo.isEmpty) {
      return _Empty(height: height);
    }

    final center = LatLng(
      geo.map((c) => c.latitude!).reduce((a, b) => a + b) / geo.length,
      geo.map((c) => c.longitude!).reduce((a, b) => a + b) / geo.length,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 6,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.doubleTapZoom,
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
            MarkerLayer(
              markers: [
                for (final c in geo)
                  Marker(
                    point: LatLng(c.latitude!, c.longitude!),
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () => context.push('/catches/${c.id}'),
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.orange,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 32,
                color: AppColors.slate.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No mapped catches yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
