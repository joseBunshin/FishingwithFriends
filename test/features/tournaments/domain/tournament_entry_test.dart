import 'package:fishing_with_friends/features/tournaments/data/tournament_entry_dto.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TournamentEntryDto', () {
    test('fromRow with full snapshot fields', () {
      final e = TournamentEntryDto.fromRow({
        'id': 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        'tournament_id': 't',
        'catch_id': 'c',
        'angler_id': 'a',
        'status': 'approved',
        'species_label': 'Largemouth Bass',
        'weight_kg': 2.04,
        'length_cm': 45.7,
        'photo_path': 'a/c/0.jpg',
        'caught_at': '2026-04-12T13:00:00.000Z',
        'submitted_at': '2026-04-12T14:00:00.000Z',
        'approved_at': '2026-04-12T14:05:00.000Z',
        'approved_by': 'creator',
      });
      expect(e.status, TournamentEntryStatus.approved);
      expect(e.speciesLabel, 'Largemouth Bass');
      expect(e.weightKg, 2.04);
      expect(e.lengthCm, 45.7);
      expect(e.photoPath, 'a/c/0.jpg');
      expect(e.caughtAt, DateTime.utc(2026, 4, 12, 13));
      expect(e.approvedBy, 'creator');
    });

    test('fromRow with NULL snapshot fields (catch with no weight)', () {
      final e = TournamentEntryDto.fromRow({
        'id': 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        'tournament_id': 't',
        'catch_id': 'c',
        'angler_id': 'a',
        'status': 'pending',
        'species_label': null,
        'weight_kg': null,
        'length_cm': null,
        'photo_path': null,
        'caught_at': null,
        'submitted_at': '2026-04-12T14:00:00.000Z',
        'approved_at': null,
        'approved_by': null,
      });
      expect(e.status, TournamentEntryStatus.pending);
      expect(e.weightKg, isNull);
      expect(e.caughtAt, isNull);
    });

    test('toInsertRow forwards only the supplied snapshot fields', () {
      final row = TournamentEntryDto.toInsertRow(
        tournamentId: 't',
        catchId: 'c',
        anglerId: 'a',
        speciesLabel: 'Snook',
        weightKg: 4.5,
        photoPath: 'a/c/0.jpg',
      );
      expect(row['tournament_id'], 't');
      expect(row['status'], 'pending');
      expect(row['species_label'], 'Snook');
      expect(row['weight_kg'], 4.5);
      expect(row.containsKey('length_cm'), isFalse);
      expect(row['photo_path'], 'a/c/0.jpg');
    });
  });

  group('parseTournamentEntryStatus', () {
    test('round-trips known values', () {
      expect(parseTournamentEntryStatus('pending'),
          TournamentEntryStatus.pending);
      expect(parseTournamentEntryStatus('approved'),
          TournamentEntryStatus.approved);
      expect(parseTournamentEntryStatus('rejected'),
          TournamentEntryStatus.rejected);
    });

    test('throws on unknown', () {
      expect(() => parseTournamentEntryStatus('nope'), throwsArgumentError);
    });
  });
}
