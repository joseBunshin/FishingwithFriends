import 'package:fishing_with_friends/features/feed/domain/comment.dart';

class CommentDto {
  const CommentDto._();

  static Comment fromRow(Map<String, dynamic> row) {
    return Comment(
      id: row['id'] as String,
      catchId: row['catch_id'] as String,
      authorId: row['author_id'] as String,
      body: row['body'] as String,
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String).toUtc(),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  }

  static Map<String, dynamic> toInsertRow({
    required String catchId,
    required String authorId,
    required String body,
  }) {
    return {
      'catch_id': catchId,
      'author_id': authorId,
      'body': body,
    };
  }
}
