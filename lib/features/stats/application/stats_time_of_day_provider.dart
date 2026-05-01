import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 24-element list — count of own catches per local hour-of-day.
/// `result[0]` = midnight–1am local, `result[23]` = 11pm–midnight local.
final statsTimeOfDayProvider = FutureProvider<List<int>>((ref) async {
  final mine = await ref.watch(myCatchesProvider.future);
  final buckets = List<int>.filled(24, 0);
  for (final c in mine) {
    final hour = c.caughtAt.toLocal().hour;
    buckets[hour] += 1;
  }
  return buckets;
});
