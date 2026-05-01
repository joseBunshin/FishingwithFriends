import 'package:fishing_with_friends/features/map/data/mpa_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Singleton [MpaService] backed by the bundled GeoJSON asset.
/// Construction is cheap; the asset load is lazy and triggered by the
/// first `isInMpa` / `shift` call.
final mpaServiceProvider = Provider<MpaService>((ref) {
  return MpaService.fromAssetBundle();
});
