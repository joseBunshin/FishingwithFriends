import 'package:fishing_with_friends/features/tournaments/application/tournament_live_state.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_realtime_service.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  required String id,
  String status = 'pending',
}) {
  return {
    'id': id,
    'tournament_id': 't',
    'catch_id': 'c-$id',
    'angler_id': 'a',
    'status': status,
    'species_label': null,
    'weight_kg': null,
    'length_cm': null,
    'photo_path': null,
    'caught_at': null,
    'submitted_at': '2026-04-12T14:00:00.000Z',
    'approved_at': null,
    'approved_by': null,
  };
}

TournamentEntry _entryFromRow(String id) {
  return const EntriesLiveState([]).apply(
    RealtimeRowChange(
      type: RealtimeChangeType.insert,
      row: _row(id: id),
    ),
  ).entries.first;
}

void main() {
  group('EntriesLiveState.apply', () {
    test('insert appends a new entry', () {
      final initial = EntriesLiveState([_entryFromRow('1')]);
      final next = initial.apply(
        RealtimeRowChange(
          type: RealtimeChangeType.insert,
          row: _row(id: '2'),
        ),
      );
      expect(next.entries.map((e) => e.id), ['1', '2']);
    });

    test('insert echo of existing id is ignored', () {
      final initial = EntriesLiveState([_entryFromRow('1')]);
      final next = initial.apply(
        RealtimeRowChange(
          type: RealtimeChangeType.insert,
          row: _row(id: '1'),
        ),
      );
      expect(next.entries, hasLength(1));
    });

    test('update replaces the matching entry by id', () {
      final initial = EntriesLiveState([_entryFromRow('1')]);
      expect(
        initial.entries.first.status,
        TournamentEntryStatus.pending,
      );
      final next = initial.apply(
        RealtimeRowChange(
          type: RealtimeChangeType.update,
          row: _row(id: '1', status: 'approved'),
        ),
      );
      expect(next.entries, hasLength(1));
      expect(next.entries.first.status, TournamentEntryStatus.approved);
    });

    test('update for unknown id falls through to insert', () {
      final initial = EntriesLiveState([_entryFromRow('1')]);
      final next = initial.apply(
        RealtimeRowChange(
          type: RealtimeChangeType.update,
          row: _row(id: '2', status: 'approved'),
        ),
      );
      expect(next.entries.map((e) => e.id), ['1', '2']);
    });

    test('delete removes by id', () {
      final initial = EntriesLiveState(
        [_entryFromRow('1'), _entryFromRow('2')],
      );
      final next = initial.apply(
        const RealtimeRowChange(
          type: RealtimeChangeType.delete,
          row: {'id': '1'},
        ),
      );
      expect(next.entries.map((e) => e.id), ['2']);
    });

    test('replaying a long sequence converges', () {
      var state = const EntriesLiveState(<TournamentEntry>[]);
      for (var i = 1; i <= 50; i++) {
        state = state.apply(RealtimeRowChange(
          type: RealtimeChangeType.insert,
          row: _row(id: '$i'),
        ));
      }
      // Approve every other one.
      for (var i = 1; i <= 50; i += 2) {
        state = state.apply(RealtimeRowChange(
          type: RealtimeChangeType.update,
          row: _row(id: '$i', status: 'approved'),
        ));
      }
      expect(state.entries, hasLength(50));
      final approved = state.entries
          .where((e) => e.status == TournamentEntryStatus.approved)
          .length;
      expect(approved, 25);
    });
  });
}
