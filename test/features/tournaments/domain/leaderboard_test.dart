import 'package:fishing_with_friends/features/tournaments/domain/leaderboard.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:flutter_test/flutter_test.dart';

TournamentEntry _entry({
  required String anglerId,
  required double? weightKg,
  required DateTime submittedAt,
  String id = 'e',
  String? speciesLabel,
  double? lengthCm,
  TournamentEntryStatus status = TournamentEntryStatus.approved,
}) {
  return TournamentEntry(
    id: id,
    tournamentId: 't',
    catchId: 'c',
    anglerId: anglerId,
    status: status,
    speciesLabel: speciesLabel,
    weightKg: weightKg,
    lengthCm: lengthCm,
    photoPath: null,
    caughtAt: submittedAt,
    submittedAt: submittedAt,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 4, 12, 10);

  group('Leaderboard.compute', () {
    test('approved-only — pending entries excluded', () {
      final entries = [
        _entry(
          id: '1',
          anglerId: 'a',
          weightKg: 5,
          submittedAt: t0,
        ),
        _entry(
          id: '2',
          anglerId: 'b',
          weightKg: 3,
          submittedAt: t0,
          status: TournamentEntryStatus.pending,
        ),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.weight,
      );
      expect(rows, hasLength(1));
      expect(rows.first.anglerId, 'a');
    });

    test('total weight sums per angler descending', () {
      final entries = [
        _entry(id: '1', anglerId: 'a', weightKg: 2, submittedAt: t0),
        _entry(
          id: '2',
          anglerId: 'a',
          weightKg: 3,
          submittedAt: t0.add(const Duration(minutes: 10)),
        ),
        _entry(id: '3', anglerId: 'b', weightKg: 4, submittedAt: t0),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.weight,
      );
      expect(rows.map((r) => r.anglerId), ['a', 'b']);
      expect(rows[0].value, 5);
      expect(rows[1].value, 4);
    });

    test('biggest_fish returns max per angler', () {
      final entries = [
        _entry(id: '1', anglerId: 'a', weightKg: 2, submittedAt: t0),
        _entry(id: '2', anglerId: 'a', weightKg: 5, submittedAt: t0),
        _entry(id: '3', anglerId: 'b', weightKg: 4, submittedAt: t0),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.biggestFish,
      );
      expect(rows[0].anglerId, 'a');
      expect(rows[0].value, 5);
      expect(rows[1].anglerId, 'b');
      expect(rows[1].value, 4);
    });

    test('most_catches counts entries regardless of weight', () {
      final entries = [
        _entry(id: '1', anglerId: 'a', weightKg: null, submittedAt: t0),
        _entry(id: '2', anglerId: 'a', weightKg: 3, submittedAt: t0),
        _entry(id: '3', anglerId: 'b', weightKg: 10, submittedAt: t0),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.mostCatches,
      );
      // most_catches uses valueFor=1, so null weight is counted
      // (it's not a weight metric).
      expect(rows.first.anglerId, 'a');
      expect(rows.first.value, 2);
    });

    test('biggest_single returns one row per top entry across anglers', () {
      final entries = [
        _entry(id: '1', anglerId: 'a', weightKg: 2, submittedAt: t0),
        _entry(id: '2', anglerId: 'b', weightKg: 5, submittedAt: t0),
        _entry(id: '3', anglerId: 'c', weightKg: 4, submittedAt: t0),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.biggestSingle,
      );
      expect(rows.map((r) => r.anglerId), ['b', 'c', 'a']);
      expect(rows[0].value, 5);
    });

    test('species filter excludes mismatched entries', () {
      final entries = [
        _entry(
          id: '1',
          anglerId: 'a',
          weightKg: 5,
          submittedAt: t0,
          speciesLabel: 'Bass',
        ),
        _entry(
          id: '2',
          anglerId: 'b',
          weightKg: 10,
          submittedAt: t0,
          speciesLabel: 'Trout',
        ),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.weight,
        speciesFilter: 'Bass',
      );
      expect(rows, hasLength(1));
      expect(rows.first.anglerId, 'a');
    });

    test('null weight excluded from weight metrics', () {
      final entries = [
        _entry(id: '1', anglerId: 'a', weightKg: null, submittedAt: t0),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.weight,
      );
      expect(rows, isEmpty);
    });

    test('ties: equal totals → tied rank, sub-sorted by earliest first entry',
        () {
      final entries = [
        _entry(
          id: '1',
          anglerId: 'a',
          weightKg: 5,
          submittedAt: t0.add(const Duration(minutes: 5)),
        ),
        _entry(
          id: '2',
          anglerId: 'b',
          weightKg: 5,
          submittedAt: t0,
        ),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.weight,
      );
      // b submitted earlier among ties → ranks ahead.
      expect(rows.map((r) => r.anglerId), ['b', 'a']);
    });

    test('empty list returns empty leaderboard', () {
      final rows = Leaderboard.compute(
        entries: const [],
        metric: TournamentMetric.weight,
      );
      expect(rows, isEmpty);
    });

    test('featured entry is the max-weight one for total-weight metric', () {
      final entries = [
        _entry(id: '1', anglerId: 'a', weightKg: 2, submittedAt: t0),
        _entry(id: '2', anglerId: 'a', weightKg: 5, submittedAt: t0),
        _entry(id: '3', anglerId: 'a', weightKg: 3, submittedAt: t0),
      ];
      final rows = Leaderboard.compute(
        entries: entries,
        metric: TournamentMetric.weight,
      );
      expect(rows.first.featuredEntry?.id, '2');
    });
  });
}
