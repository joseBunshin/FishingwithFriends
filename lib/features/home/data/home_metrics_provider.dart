import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/home/domain/home_metrics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Derived from `myCatchesProvider`. Wrapped in `AsyncValue` so the Home
/// screen renders loading / error states cleanly while the catches list
/// fetches.
final homeMetricsProvider = Provider<AsyncValue<HomeMetrics>>((ref) {
  return ref.watch(myCatchesProvider).whenData(deriveHomeMetrics);
});

@visibleForTesting
HomeMetrics deriveHomeMetrics(List<Catch> catches) {
  if (catches.isEmpty) return const HomeMetrics.empty();

  final speciesSet = <String>{};
  var totalWeightKg = 0.0;
  Catch? biggest;

  for (final c in catches) {
    final species = c.speciesLabel ?? c.speciesId;
    if (species != null && species.isNotEmpty) speciesSet.add(species);
    if (c.weightKg != null) totalWeightKg += c.weightKg!;
    if (c.weightKg != null &&
        (biggest == null || (biggest.weightKg ?? 0) < c.weightKg!)) {
      biggest = c;
    }
  }

  return HomeMetrics(
    totalCatches: catches.length,
    totalWeightKg: totalWeightKg,
    uniqueSpecies: speciesSet.length,
    biggestWeightKg: biggest?.weightKg,
    biggestSpecies: biggest?.speciesLabel ?? biggest?.speciesId,
  );
}
