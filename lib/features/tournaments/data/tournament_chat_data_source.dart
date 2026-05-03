import 'package:supabase_flutter/supabase_flutter.dart';

abstract class TournamentChatDataSource {
  Future<List<Map<String, dynamic>>> selectForTournament(String tournamentId);
  Future<Map<String, dynamic>> insertMessage(Map<String, dynamic> row);
  Future<void> softDelete(String messageId);
}

class SupabaseTournamentChatDataSource implements TournamentChatDataSource {
  SupabaseTournamentChatDataSource(this._client);

  final SupabaseClient _client;

  static const _columns = '*';

  @override
  Future<List<Map<String, dynamic>>> selectForTournament(
    String tournamentId,
  ) async {
    final rows = await _client
        .from('tournament_chat_messages')
        .select(_columns)
        .eq('tournament_id', tournamentId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> insertMessage(
    Map<String, dynamic> row,
  ) async {
    return _client
        .from('tournament_chat_messages')
        .insert(row)
        .select(_columns)
        .single();
  }

  @override
  Future<void> softDelete(String messageId) async {
    await _client
        .from('tournament_chat_messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId);
  }
}
