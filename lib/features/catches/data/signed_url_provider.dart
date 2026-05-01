import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signed URL for a private storage path, cached per path.
///
/// TTL = 1 hour from Supabase. We refresh ~10 minutes before that to absorb
/// clock skew. The provider uses `keepAlive: true` so concurrent listeners
/// (Home recent card + Catches grid + Catch detail) share one URL per path.
final signedUrlProvider = FutureProvider.family<String, String>((ref, path) async {
  final url = await ref.watch(photoStorageProvider).signedUrl(path);
  // Auto-refresh just before the 60-minute Supabase TTL.
  final refreshTimer = Future<void>.delayed(
    const Duration(minutes: 50),
    ref.invalidateSelf,
  );
  // The timer is best-effort — if listeners disappear before it fires,
  // the cancellation cost is just a no-op invalidate on a disposed ref.
  ref.onDispose(refreshTimer.ignore);
  return url;
});
