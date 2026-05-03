import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:meta/meta.dart';

/// One row on a leaderboard. `value` is the metric the leaderboard ranks by
/// (kg total, single-fish kg, count, etc.).
@immutable
class LeaderboardRow {
  const LeaderboardRow({
    required this.anglerId,
    required this.value,
    required this.entryCount,
    required this.firstEntryAt,
    this.featuredEntry,
  });

  final String anglerId;
  final double value;
  final int entryCount;
  final DateTime firstEntryAt;

  /// The single entry that "represents" this row — for biggest-fish style
  /// metrics this is the winning catch; for total metrics it's the most
  /// recent contributing entry. Used for the row's photo + species label.
  final TournamentEntry? featuredEntry;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardRow &&
          other.anglerId == anglerId &&
          other.value == value &&
          other.entryCount == entryCount &&
          other.firstEntryAt == firstEntryAt;

  @override
  int get hashCode =>
      Object.hash(anglerId, value, entryCount, firstEntryAt);
}

/// Pure leaderboard computation. Inputs come from the repository or a
/// realtime stream; output is a sorted, deterministic list of rows.
class Leaderboard {
  const Leaderboard._();

  /// Compute a leaderboard for [entries] under [metric]. Optional
  /// [speciesFilter] excludes entries whose `species_label` doesn't match.
  /// Only `approved` entries count.
  static List<LeaderboardRow> compute({
    required List<TournamentEntry> entries,
    required TournamentMetric metric,
    String? speciesFilter,
  }) {
    final approved = entries.where(
      (e) => e.status == TournamentEntryStatus.approved,
    );

    final filtered = speciesFilter == null || speciesFilter.isEmpty
        ? approved
        : approved.where((e) => e.speciesLabel == speciesFilter);

    switch (metric) {
      case TournamentMetric.weight:
        return _aggregate(
          filtered,
          valueFor: (e) => e.weightKg,
          combine: _sum,
        );
      case TournamentMetric.length:
        return _aggregate(
          filtered,
          valueFor: (e) => e.lengthCm,
          combine: _sum,
        );
      case TournamentMetric.mostCatches:
        return _aggregate(
          filtered,
          valueFor: (_) => 1,
          combine: _sum,
        );
      case TournamentMetric.biggestFish:
        return _aggregate(
          filtered,
          valueFor: (e) => e.weightKg,
          combine: _max,
        );
      case TournamentMetric.longestCatch:
        return _aggregate(
          filtered,
          valueFor: (e) => e.lengthCm,
          combine: _max,
        );
      case TournamentMetric.biggestSingle:
        // Single-row board: one row per top entry across all anglers.
        return _topSingle(filtered, valueFor: (e) => e.weightKg);
    }
  }

  static List<LeaderboardRow> _aggregate(
    Iterable<TournamentEntry> entries, {
    required double? Function(TournamentEntry) valueFor,
    required double Function(double, double) combine,
  }) {
    final byAngler = <String, _Bucket>{};
    for (final e in entries) {
      final v = valueFor(e);
      if (v == null) continue;
      byAngler
          .putIfAbsent(e.anglerId, () => _Bucket(anglerId: e.anglerId))
        ..acceptValue(v, combine)
        ..acceptEntry(e, valueFor);
    }
    final rows = byAngler.values
        .map(
          (b) => LeaderboardRow(
            anglerId: b.anglerId,
            value: b.value,
            entryCount: b.entryCount,
            firstEntryAt: b.firstEntryAt!,
            featuredEntry: b.featured,
          ),
        )
        .toList();
    _sortDescByValueThenFirstEntry(rows);
    return rows;
  }

  static List<LeaderboardRow> _topSingle(
    Iterable<TournamentEntry> entries, {
    required double? Function(TournamentEntry) valueFor,
  }) {
    final scored = entries
        .where((e) => valueFor(e) != null)
        .map((e) => MapEntry(e, valueFor(e)!))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored
        .map(
          (mapEntry) => LeaderboardRow(
            anglerId: mapEntry.key.anglerId,
            value: mapEntry.value,
            entryCount: 1,
            firstEntryAt: mapEntry.key.submittedAt,
            featuredEntry: mapEntry.key,
          ),
        )
        .toList();
  }

  static double _sum(double a, double b) => a + b;
  static double _max(double a, double b) => a > b ? a : b;

  static void _sortDescByValueThenFirstEntry(List<LeaderboardRow> rows) {
    rows.sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      if (byValue != 0) return byValue;
      return a.firstEntryAt.compareTo(b.firstEntryAt);
    });
  }
}

class _Bucket {
  _Bucket({required this.anglerId});

  final String anglerId;
  double value = 0;
  int entryCount = 0;
  DateTime? firstEntryAt;
  TournamentEntry? featured;
  double? featuredValue;

  void acceptValue(double v, double Function(double, double) combine) {
    value = entryCount == 0 ? v : combine(value, v);
    entryCount += 1;
  }

  void acceptEntry(
    TournamentEntry e,
    double? Function(TournamentEntry) valueFor,
  ) {
    if (firstEntryAt == null || e.submittedAt.isBefore(firstEntryAt!)) {
      firstEntryAt = e.submittedAt;
    }
    final v = valueFor(e);
    if (v != null && (featuredValue == null || v > featuredValue!)) {
      featured = e;
      featuredValue = v;
    }
  }
}
