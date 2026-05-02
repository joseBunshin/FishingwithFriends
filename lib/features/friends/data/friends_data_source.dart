import 'package:supabase_flutter/supabase_flutter.dart';

abstract class FriendsDataSource {
  Future<List<Map<String, dynamic>>> searchProfiles({
    required String query,
    required String currentUserId,
    int limit,
  });

  Future<List<Map<String, dynamic>>> selectProfilesByIds(List<String> ids);

  Future<Map<String, dynamic>> insertFriendship({
    required String requesterId,
    required String addresseeId,
  });

  Future<Map<String, dynamic>> updateStatus({
    required String requesterId,
    required String addresseeId,
    required String status,
  });

  Future<void> deleteFriendship({
    required String userA,
    required String userB,
  });

  Future<List<Map<String, dynamic>>> selectFriendshipsForUser(String userId);
}

class SupabaseFriendsDataSource implements FriendsDataSource {
  SupabaseFriendsDataSource(this._client);

  final SupabaseClient _client;

  static const _profileColumns =
      'id, username, display_name, avatar_path, bio, home_water, '
      'onboarding_completed_at';

  @override
  Future<List<Map<String, dynamic>>> searchProfiles({
    required String query,
    required String currentUserId,
    int limit = 25,
  }) async {
    // ilike substring match on username, exclude current user, cap limit.
    final rows = await _client
        .from('profiles')
        .select(_profileColumns)
        .ilike('username', '%$query%')
        .neq('id', currentUserId)
        .order('username')
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectProfilesByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('profiles')
        .select(_profileColumns)
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> insertFriendship({
    required String requesterId,
    required String addresseeId,
  }) async {
    return _client
        .from('friendships')
        .insert({
          'requester_id': requesterId,
          'addressee_id': addresseeId,
          'status': 'pending',
        })
        .select('*')
        .single();
  }

  @override
  Future<Map<String, dynamic>> updateStatus({
    required String requesterId,
    required String addresseeId,
    required String status,
  }) async {
    return _client
        .from('friendships')
        .update({'status': status})
        .eq('requester_id', requesterId)
        .eq('addressee_id', addresseeId)
        .select('*')
        .single();
  }

  @override
  Future<void> deleteFriendship({
    required String userA,
    required String userB,
  }) async {
    await _client.from('friendships').delete().or(
          'and(requester_id.eq.$userA,addressee_id.eq.$userB),'
          'and(requester_id.eq.$userB,addressee_id.eq.$userA)',
        );
  }

  @override
  Future<List<Map<String, dynamic>>> selectFriendshipsForUser(
    String userId,
  ) async {
    final rows = await _client
        .from('friendships')
        .select('*')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId');
    return List<Map<String, dynamic>>.from(rows);
  }
}
