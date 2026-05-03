import 'package:fishing_with_friends/features/tournaments/domain/tournament_chat_message.dart';

class TournamentChatMessageDto {
  const TournamentChatMessageDto._();

  static TournamentChatMessage fromRow(Map<String, dynamic> row) {
    return TournamentChatMessage(
      id: row['id'] as String,
      tournamentId: row['tournament_id'] as String,
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
    required String tournamentId,
    required String authorId,
    required String body,
  }) {
    return {
      'tournament_id': tournamentId,
      'author_id': authorId,
      'body': body,
    };
  }
}
