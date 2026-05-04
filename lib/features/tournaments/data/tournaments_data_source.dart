import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class TournamentsDataSource {
  Future<Map<String, dynamic>> insertTournament(Map<String, dynamic> row);
  Future<Map<String, dynamic>?> selectByIdOrJoinCode({
    String? id,
    String? joinCode,
  });
  Future<Map<String, dynamic>?> selectById(String id);
  Future<List<Map<String, dynamic>>> selectMine(String anglerId);
  Future<Map<String, dynamic>> updateClose(String tournamentId);
  Future<void> deleteTournament(String tournamentId);

  Future<List<Map<String, dynamic>>> insertMembers(
    List<Map<String, dynamic>> rows,
  );
  Future<Map<String, dynamic>> upsertMemberJoin({
    required String tournamentId,
    required String anglerId,
  });
  Future<Map<String, dynamic>> updateMemberStatus({
    required String tournamentId,
    required String anglerId,
    required String status,
    required String approvedBy,
  });
  Future<List<Map<String, dynamic>>> selectMembers(String tournamentId);
}

class SupabaseTournamentsDataSource implements TournamentsDataSource {
  SupabaseTournamentsDataSource(this._client);

  final SupabaseClient _client;

  static const _tournamentColumns = '*';
  static const _memberColumns = '*';

  @override
  Future<Map<String, dynamic>> insertTournament(
    Map<String, dynamic> row,
  ) async {
    return _client
        .from('tournaments')
        .insert(row)
        .select(_tournamentColumns)
        .single();
  }

  @override
  Future<Map<String, dynamic>?> selectByIdOrJoinCode({
    String? id,
    String? joinCode,
  }) {
    var query = _client.from('tournaments').select(_tournamentColumns);
    if (id != null) {
      query = query.eq('id', id);
    } else if (joinCode != null) {
      query = query.eq('join_code', joinCode);
    } else {
      throw ArgumentError('Either id or joinCode must be supplied');
    }
    return query.maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> selectById(String id) {
    return _client
        .from('tournaments')
        .select(_tournamentColumns)
        .eq('id', id)
        .maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> selectMine(String anglerId) async {
    // Tournaments where the user is the creator OR an accepted member.
    // RLS already filters; this query is permissive.
    final rows = await _client
        .from('tournaments')
        .select(_tournamentColumns)
        .order('starts_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> updateClose(String tournamentId) async {
    return _client
        .from('tournaments')
        .update({'is_closed': true})
        .eq('id', tournamentId)
        .select(_tournamentColumns)
        .single();
  }

  @override
  Future<void> deleteTournament(String tournamentId) async {
    // .select('id') chained so a silently-denied delete (RLS returns
    // zero affected rows with no exception) surfaces as a thrown
    // NetworkFailure rather than a fake-success that leaves the
    // tournament live for participants. Scoped to the id column.
    final rows = await _client
        .from('tournaments')
        .delete()
        .eq('id', tournamentId)
        .select('id');
    if (rows.isEmpty) {
      debugPrint(
        'tournaments-delete: zero rows affected for id=$tournamentId; '
        'RLS denial or stale session',
      );
      throw const NetworkFailure(
        "Couldn't delete that tournament. Try again.",
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> insertMembers(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final inserted =
        await _client.from('tournament_members').insert(rows).select();
    return List<Map<String, dynamic>>.from(inserted);
  }

  @override
  Future<Map<String, dynamic>> upsertMemberJoin({
    required String tournamentId,
    required String anglerId,
  }) async {
    return _client
        .from('tournament_members')
        .upsert(
          {
            'tournament_id': tournamentId,
            'angler_id': anglerId,
            'status': 'pending',
          },
          onConflict: 'tournament_id,angler_id',
          ignoreDuplicates: false,
        )
        .select(_memberColumns)
        .single();
  }

  @override
  Future<Map<String, dynamic>> updateMemberStatus({
    required String tournamentId,
    required String anglerId,
    required String status,
    required String approvedBy,
  }) async {
    return _client
        .from('tournament_members')
        .update({
          'status': status,
          'approved_by': approvedBy,
        })
        .eq('tournament_id', tournamentId)
        .eq('angler_id', anglerId)
        .select(_memberColumns)
        .single();
  }

  @override
  Future<List<Map<String, dynamic>>> selectMembers(
    String tournamentId,
  ) async {
    final rows = await _client
        .from('tournament_members')
        .select(_memberColumns)
        .eq('tournament_id', tournamentId);
    return List<Map<String, dynamic>>.from(rows);
  }
}
