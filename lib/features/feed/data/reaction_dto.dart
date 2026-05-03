import 'package:fishing_with_friends/features/feed/domain/reaction.dart';

class ReactionDto {
  const ReactionDto._();

  static Reaction fromRow(Map<String, dynamic> row) {
    return Reaction(
      catchId: row['catch_id'] as String,
      userId: row['user_id'] as String,
      kind: ReactionKind.fromId(row['kind'] as String),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }

  static Map<String, dynamic> toInsertRow({
    required String catchId,
    required String userId,
    required ReactionKind kind,
  }) {
    return {
      'catch_id': catchId,
      'user_id': userId,
      'kind': kind.id,
    };
  }
}
