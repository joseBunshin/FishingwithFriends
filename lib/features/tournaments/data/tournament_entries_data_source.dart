import 'package:supabase_flutter/supabase_flutter.dart';

abstract class TournamentEntriesDataSource {
  Future<Map<String, dynamic>> insertEntry(Map<String, dynamic> row);
  Future<Map<String, dynamic>> updateStatus({
    required String entryId,
    required String status,
    required String approvedBy,
  });
  Future<List<Map<String, dynamic>>> selectForTournament(String tournamentId);

  /// Side pots for a tournament, ordered by created_at.
  Future<List<Map<String, dynamic>>> selectSidePots(String tournamentId);
  Future<Map<String, dynamic>> insertSidePot(Map<String, dynamic> row);
}

class SupabaseTournamentEntriesDataSource
    implements TournamentEntriesDataSource {
  SupabaseTournamentEntriesDataSource(this._client);

  final SupabaseClient _client;

  static const _entryColumns = '*';
  static const _sidePotColumns = '*';

  @override
  Future<Map<String, dynamic>> insertEntry(Map<String, dynamic> row) async {
    return _client
        .from('tournament_entries')
        .insert(row)
        .select(_entryColumns)
        .single();
  }

  @override
  Future<Map<String, dynamic>> updateStatus({
    required String entryId,
    required String status,
    required String approvedBy,
  }) async {
    return _client
        .from('tournament_entries')
        .update({
          'status': status,
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', entryId)
        .select(_entryColumns)
        .single();
  }

  @override
  Future<List<Map<String, dynamic>>> selectForTournament(
    String tournamentId,
  ) async {
    final rows = await _client
        .from('tournament_entries')
        .select(_entryColumns)
        .eq('tournament_id', tournamentId)
        .order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectSidePots(
    String tournamentId,
  ) async {
    final rows = await _client
        .from('tournament_side_pots')
        .select(_sidePotColumns)
        .eq('tournament_id', tournamentId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> insertSidePot(Map<String, dynamic> row) async {
    return _client
        .from('tournament_side_pots')
        .insert(row)
        .select(_sidePotColumns)
        .single();
  }
}
