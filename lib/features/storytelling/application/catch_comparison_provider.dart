import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class CatchComparison {
  const CatchComparison({
    required this.rank,
    required this.total,
    required this.year,
    required this.speciesLabel,
    required this.isAllTimeBest,
  });

  /// 1-based rank, or null when this catch has no measurable value
  /// to rank against (no weight, no length, or no species).
  final int? rank;

  /// Total number of comparable catches in the same species + year cohort.
  final int total;

  final int year;
  final String? speciesLabel;
  final bool isAllTimeBest;

  /// Whether the rank is "interesting" enough to surface (top 3 by default).
  bool get isInteresting => rank != null && rank! <= 3;
}

final catchComparisonProvider =
    FutureProvider.family<CatchComparison?, String>((ref, catchId) async {
  final mine = await ref.watch(myCatchesProvider.future);
  if (mine.isEmpty) return null;

  Catch? target;
  for (final c in mine) {
    if (c.id == catchId) {
      target = c;
      break;
    }
  }
  if (target == null) return null;
  if (target.speciesId == null) return null;

  final value = target.weightKg ?? target.lengthCm;
  if (value == null) return null;

  final useWeight = target.weightKg != null;
  final year = target.caughtAt.toLocal().year;

  final cohort = mine
      .where((c) =>
          c.speciesId == target!.speciesId &&
          c.caughtAt.toLocal().year == year &&
          (useWeight ? c.weightKg != null : c.lengthCm != null))
      .toList()
    ..sort((a, b) {
      final av = useWeight ? a.weightKg! : a.lengthCm!;
      final bv = useWeight ? b.weightKg! : b.lengthCm!;
      return bv.compareTo(av);
    });

  final rank = cohort.indexWhere((c) => c.id == catchId) + 1;

  // All-time check: is this catch the biggest of its species ever?
  var isAllTimeBest = false;
  if (rank == 1) {
    final allTime = mine
        .where((c) =>
            c.speciesId == target!.speciesId &&
            (useWeight ? c.weightKg != null : c.lengthCm != null))
        .toList();
    if (allTime.isNotEmpty) {
      allTime.sort((a, b) {
        final av = useWeight ? a.weightKg! : a.lengthCm!;
        final bv = useWeight ? b.weightKg! : b.lengthCm!;
        return bv.compareTo(av);
      });
      isAllTimeBest = allTime.first.id == catchId;
    }
  }

  return CatchComparison(
    rank: rank,
    total: cohort.length,
    year: year,
    speciesLabel: target.speciesLabel,
    isAllTimeBest: isAllTimeBest,
  );
});
