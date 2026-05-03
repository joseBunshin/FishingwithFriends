import 'package:fishing_with_friends/features/tournaments/data/tournament_dto.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_input.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  String metric = 'weight',
  bool isClosed = false,
}) {
  return {
    'id': 'tttttttt-tttt-tttt-tttt-tttttttttttt',
    'creator_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'name': 'Spring Bass Cup',
    'description': 'all welcome',
    'metric': metric,
    'starts_at': '2026-04-12T10:00:00.000Z',
    'ends_at': '2026-04-12T18:00:00.000Z',
    'join_code': 'abcd1234',
    'is_closed': isClosed,
    'is_public': false,
    'created_at': '2026-04-12T08:00:00.000Z',
    'updated_at': '2026-04-12T08:00:00.000Z',
  };
}

void main() {
  group('TournamentMetric', () {
    test('ids match the DB enum', () {
      expect(TournamentMetric.weight.id, 'weight');
      expect(TournamentMetric.length.id, 'length');
      expect(TournamentMetric.biggestFish.id, 'biggest_fish');
      expect(TournamentMetric.mostCatches.id, 'most_catches');
      expect(TournamentMetric.longestCatch.id, 'longest_catch');
      expect(TournamentMetric.biggestSingle.id, 'biggest_single');
    });

    test('tryFromId returns null on unknown', () {
      expect(TournamentMetric.tryFromId('nope'), isNull);
    });
  });

  group('TournamentDto', () {
    test('fromRow round-trips', () {
      final t = TournamentDto.fromRow(_row());
      expect(t.name, 'Spring Bass Cup');
      expect(t.metric, TournamentMetric.weight);
      expect(t.joinCode, 'abcd1234');
      expect(t.isClosed, isFalse);
      expect(t.startsAt.isUtc, isTrue);
    });

    test('toInsertRow strips server-side fields', () {
      final input = TournamentInput(
        name: 'Spring',
        metric: TournamentMetric.biggestFish,
        startsAt: DateTime.utc(2026, 4, 12, 10),
        endsAt: DateTime.utc(2026, 4, 12, 18),
        description: 'desc',
      );
      final row = TournamentDto.toInsertRow(input, creatorId: 'c1');
      expect(row['name'], 'Spring');
      expect(row['metric'], 'biggest_fish');
      expect(row['creator_id'], 'c1');
      expect(row.containsKey('id'), isFalse);
      expect(row.containsKey('created_at'), isFalse);
    });
  });

  group('Tournament.phaseAt', () {
    test('reflects the phase derivation function', () {
      final t = TournamentDto.fromRow(_row());
      expect(
        t.phaseAt(DateTime.utc(2026, 4, 12, 9)),
        TournamentPhase.registration,
      );
      expect(
        t.phaseAt(DateTime.utc(2026, 4, 12, 14)),
        TournamentPhase.live,
      );
      expect(
        t.phaseAt(DateTime.utc(2026, 4, 12, 19)),
        TournamentPhase.closed,
      );
    });

    test('isClosed override takes effect', () {
      final t = TournamentDto.fromRow(_row(isClosed: true));
      expect(
        t.phaseAt(DateTime.utc(2026, 4, 12, 14)),
        TournamentPhase.closed,
      );
    });
  });
}
