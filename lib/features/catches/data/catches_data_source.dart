import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase Postgrest wrapper for the `catches` table and
/// `catches_friend_view`. Abstracted so the repository orchestrator can be
/// unit-tested with a recording fake instead of a live Supabase backend.
abstract class CatchesDataSource {
  Future<Map<String, dynamic>> insertCatch(Map<String, dynamic> row);

  Future<List<Map<String, dynamic>>> selectMine(String anglerId);

  Future<List<Map<String, dynamic>>> selectFriendsView({
    required List<String> friendIds,
  });

  /// Read a single catch — first via `catches` (owner path), falling back
  /// to `catches_friend_view` (friend path). Returns `null` when neither
  /// row is visible under RLS.
  Future<Map<String, dynamic>?> selectById(String id);

  /// Delete a catch by id. RLS restricts this to the owner; non-owners
  /// silently see zero rows affected.
  Future<void> deleteCatch(String id);
}

class SupabaseCatchesDataSource implements CatchesDataSource {
  SupabaseCatchesDataSource(this._client);

  final SupabaseClient _client;

  static const _ownerColumns = '*';
  static const _friendViewColumns =
      'id, angler_id, species_id, species_label, length_cm, weight_kg, '
      'caught_at, location, latitude, longitude, secret_spot, '
      'catch_and_release, rig, notes, photo_paths, conditions, '
      'created_at, updated_at';

  @override
  Future<Map<String, dynamic>> insertCatch(Map<String, dynamic> row) async {
    final result = await _client
        .from('catches')
        .insert(row)
        .select(_ownerColumns)
        .single();
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> selectMine(String anglerId) async {
    final rows = await _client
        .from('catches')
        .select(_ownerColumns)
        .eq('angler_id', anglerId)
        .order('caught_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectFriendsView({
    required List<String> friendIds,
  }) async {
    if (friendIds.isEmpty) return const [];
    final rows = await _client
        .from('catches_friend_view')
        .select(_friendViewColumns)
        .inFilter('angler_id', friendIds)
        .order('caught_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>?> selectById(String id) async {
    try {
      final row = await _client
          .from('catches')
          .select(_ownerColumns)
          .eq('id', id)
          .maybeSingle();
      if (row != null) return row;
    } on PostgrestException {
      // Fall through to friend-view read.
    }

    final friendRow = await _client
        .from('catches_friend_view')
        .select(_friendViewColumns)
        .eq('id', id)
        .maybeSingle();
    return friendRow;
  }

  @override
  Future<void> deleteCatch(String id) async {
    await _client.from('catches').delete().eq('id', id);
  }
}
