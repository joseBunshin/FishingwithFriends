import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CatchDateRange { all, last7Days, last30Days, last90Days, thisYear }

extension CatchDateRangeLabel on CatchDateRange {
  String get label => switch (this) {
        CatchDateRange.all => 'Any date',
        CatchDateRange.last7Days => 'Last 7 days',
        CatchDateRange.last30Days => 'Last 30 days',
        CatchDateRange.last90Days => 'Last 90 days',
        CatchDateRange.thisYear => 'This year',
      };
}

@immutable
class CatchesFilter {
  const CatchesFilter({
    this.query = '',
    this.speciesLabel,
    this.dateRange = CatchDateRange.all,
  });

  final String query;
  final String? speciesLabel;
  final CatchDateRange dateRange;

  bool get isActive =>
      query.isNotEmpty ||
      speciesLabel != null ||
      dateRange != CatchDateRange.all;

  CatchesFilter copyWith({
    String? query,
    Object? speciesLabel = _sentinel,
    CatchDateRange? dateRange,
  }) {
    return CatchesFilter(
      query: query ?? this.query,
      speciesLabel: identical(speciesLabel, _sentinel)
          ? this.speciesLabel
          : speciesLabel as String?,
      dateRange: dateRange ?? this.dateRange,
    );
  }

  static const _sentinel = Object();
}

final catchesFilterProvider =
    StateProvider<CatchesFilter>((ref) => const CatchesFilter());

/// Distinct species labels seen in the user's catches, sorted alphabetically.
/// Used to populate the species filter dropdown.
final myCatchesSpeciesProvider = Provider<List<String>>((ref) {
  final catches = ref.watch(myCatchesProvider).valueOrNull ?? const <Catch>[];
  final labels = <String>{};
  for (final c in catches) {
    final l = c.speciesLabel;
    if (l != null && l.trim().isNotEmpty) labels.add(l.trim());
  }
  final sorted = labels.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return sorted;
});

/// Catches with the active filter applied. Search matches species label
/// and notes substring (case-insensitive).
final filteredMyCatchesProvider = Provider<AsyncValue<List<Catch>>>((ref) {
  final asyncCatches = ref.watch(myCatchesProvider);
  final filter = ref.watch(catchesFilterProvider);

  return asyncCatches.whenData((catches) {
    if (!filter.isActive) return catches;

    final q = filter.query.trim().toLowerCase();
    final cutoff = _cutoffFor(filter.dateRange);

    return catches.where((c) {
      if (filter.speciesLabel != null &&
          (c.speciesLabel?.trim() ?? '') != filter.speciesLabel) {
        return false;
      }
      if (cutoff != null && c.caughtAt.isBefore(cutoff)) return false;
      if (q.isNotEmpty) {
        final hay = '${c.speciesLabel ?? ''} ${c.notes ?? ''}';
        if (!hay.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  });
});

DateTime? _cutoffFor(CatchDateRange r) {
  final now = DateTime.now();
  return switch (r) {
    CatchDateRange.all => null,
    CatchDateRange.last7Days => now.subtract(const Duration(days: 7)),
    CatchDateRange.last30Days => now.subtract(const Duration(days: 30)),
    CatchDateRange.last90Days => now.subtract(const Duration(days: 90)),
    CatchDateRange.thisYear => DateTime(now.year),
  };
}
