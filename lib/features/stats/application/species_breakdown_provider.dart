import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class SpeciesSlice {
  const SpeciesSlice({required this.label, required this.count});
  final String label;
  final int count;
}

/// Counts of own catches per species label, descending. "Unknown" bucket
/// for catches with no species set.
final speciesBreakdownProvider =
    FutureProvider<List<SpeciesSlice>>((ref) async {
  final mine = await ref.watch(myCatchesProvider.future);
  if (mine.isEmpty) return const [];

  final counts = <String, int>{};
  for (final c in mine) {
    final label =
        (c.speciesLabel == null || c.speciesLabel!.isEmpty)
            ? 'Unknown'
            : c.speciesLabel!;
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final slices = counts.entries
      .map((e) => SpeciesSlice(label: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return slices;
});
