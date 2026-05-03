import 'package:fishing_with_friends/features/feed/data/reaction_dto.dart';
import 'package:fishing_with_friends/features/feed/domain/reaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReactionKind', () {
    test('canonical ids match the DB CHECK constraint', () {
      expect(ReactionKind.rod.id, 'rod');
      expect(ReactionKind.fire.id, 'fire');
      expect(ReactionKind.fist.id, 'fist');
      expect(ReactionKind.mind.id, 'mind');
      expect(ReactionKind.handshake.id, 'handshake');
    });

    test('fromId returns the kind for known strings', () {
      expect(ReactionKind.fromId('rod'), ReactionKind.rod);
      expect(ReactionKind.fromId('fire'), ReactionKind.fire);
    });

    test('fromId throws ArgumentError for unknown strings', () {
      expect(() => ReactionKind.fromId('thumbs_up'), throwsArgumentError);
    });

    test('every kind has a non-empty emoji + label for the picker', () {
      for (final k in ReactionKind.values) {
        expect(k.emoji, isNotEmpty);
        expect(k.label, isNotEmpty);
      }
    });
  });

  group('ReactionDto', () {
    test('fromRow round-trips a row', () {
      final r = ReactionDto.fromRow({
        'catch_id': 'c',
        'user_id': 'u',
        'kind': 'fire',
        'created_at': '2026-04-12T14:00:00.000Z',
      });
      expect(r.kind, ReactionKind.fire);
      expect(r.catchId, 'c');
      expect(r.userId, 'u');
      expect(r.createdAt, DateTime.utc(2026, 4, 12, 14));
    });

    test('toInsertRow builds the expected map', () {
      final row = ReactionDto.toInsertRow(
        catchId: 'c',
        userId: 'u',
        kind: ReactionKind.handshake,
      );
      expect(row['catch_id'], 'c');
      expect(row['user_id'], 'u');
      expect(row['kind'], 'handshake');
    });
  });
}
