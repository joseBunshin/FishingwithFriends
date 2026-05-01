import 'package:fishing_with_friends/features/feed/data/comment_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommentDto.fromRow', () {
    test('round-trips a non-deleted comment', () {
      final c = CommentDto.fromRow({
        'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'catch_id': 'a',
        'author_id': 'u',
        'body': 'Nice fish @silentfisher100',
        'deleted_at': null,
        'created_at': '2026-04-12T14:00:00.000Z',
        'updated_at': '2026-04-12T14:00:00.000Z',
      });
      expect(c.body, 'Nice fish @silentfisher100');
      expect(c.isDeleted, isFalse);
    });

    test('round-trips a soft-deleted comment with deletedAt set', () {
      final c = CommentDto.fromRow({
        'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'catch_id': 'a',
        'author_id': 'u',
        'body': 'oops',
        'deleted_at': '2026-04-12T14:05:00.000Z',
        'created_at': '2026-04-12T14:00:00.000Z',
        'updated_at': '2026-04-12T14:05:00.000Z',
      });
      expect(c.isDeleted, isTrue);
      expect(c.deletedAt, DateTime.utc(2026, 4, 12, 14, 5));
      expect(c.body, 'oops', reason: 'soft-delete preserves body for tombstone');
    });
  });

  group('CommentDto.toInsertRow', () {
    test('strips id / timestamps from the insert payload', () {
      final row = CommentDto.toInsertRow(
        catchId: 'a',
        authorId: 'u',
        body: 'Sweet!',
      );
      expect(row, {
        'catch_id': 'a',
        'author_id': 'u',
        'body': 'Sweet!',
      });
    });
  });
}
