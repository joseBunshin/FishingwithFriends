import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_chat_data_source.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_chat_message_dto.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentChatRepository {
  TournamentChatRepository({required this.dataSource});

  final TournamentChatDataSource dataSource;

  static const int maxLength = 2000;

  Future<List<TournamentChatMessage>> getForTournament(
    String tournamentId,
  ) async {
    try {
      final rows = await dataSource.selectForTournament(tournamentId);
      return rows
          .map(TournamentChatMessageDto.fromRow)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load chat: ${e.message}', cause: e);
    }
  }

  Future<TournamentChatMessage> post({
    required String tournamentId,
    required String authorId,
    required String body,
  }) async {
    if (authorId.isEmpty) {
      throw const AuthFailure('Sign in to comment.');
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Write something first.');
    }
    if (trimmed.length > maxLength) {
      throw const ValidationFailure(
        'Messages must be 2000 characters or fewer.',
      );
    }
    try {
      final row = await dataSource.insertMessage(
        TournamentChatMessageDto.toInsertRow(
          tournamentId: tournamentId,
          authorId: authorId,
          body: trimmed,
        ),
      );
      return TournamentChatMessageDto.fromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Comment failed: ${e.message}', cause: e);
    }
  }

  Future<void> softDelete(String messageId) async {
    try {
      await dataSource.softDelete(messageId);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not delete: ${e.message}', cause: e);
    }
  }
}
