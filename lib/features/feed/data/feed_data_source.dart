import 'package:supabase_flutter/supabase_flutter.dart';

abstract class FeedDataSource {
  Future<List<Map<String, dynamic>>> selectFeedCatches({
    required String currentUserId,
    required List<String> friendIds,
    int limit,
  });

  Future<List<Map<String, dynamic>>> selectReactionAggregates(
    List<String> catchIds,
  );

  Future<List<Map<String, dynamic>>> selectCommentCounts(
    List<String> catchIds,
  );

  Future<List<Map<String, dynamic>>> selectMyReactions({
    required String userId,
    required List<String> catchIds,
  });
}

class SupabaseFeedDataSource implements FeedDataSource {
  SupabaseFeedDataSource(this._client);

  final SupabaseClient _client;

  static const _viewColumns =
      'id, angler_id, species_id, species_label, length_cm, weight_kg, '
      'caught_at, location, secret_spot, catch_and_release, rig, trip_id, '
      'notes, photo_paths, conditions, created_at, updated_at';

  @override
  Future<List<Map<String, dynamic>>> selectFeedCatches({
    required String currentUserId,
    required List<String> friendIds,
    int limit = 50,
  }) async {
    // Build a single query against catches_friend_view that includes
    // either friend rows OR own rows. RLS already restricts visibility
    // to friends-of-self plus self.
    final ids = {...friendIds, currentUserId}.toList();
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('catches_friend_view')
        .select(_viewColumns)
        .inFilter('angler_id', ids)
        .order('caught_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectReactionAggregates(
    List<String> catchIds,
  ) async {
    if (catchIds.isEmpty) return const [];
    final rows = await _client
        .from('feed_reactions')
        .select('catch_id, kind')
        .inFilter('catch_id', catchIds);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectCommentCounts(
    List<String> catchIds,
  ) async {
    if (catchIds.isEmpty) return const [];
    final rows = await _client
        .from('comments')
        .select('catch_id, deleted_at')
        .inFilter('catch_id', catchIds)
        .filter('deleted_at', 'is', null);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectMyReactions({
    required String userId,
    required List<String> catchIds,
  }) async {
    if (catchIds.isEmpty) return const [];
    final rows = await _client
        .from('feed_reactions')
        .select('catch_id, kind')
        .eq('user_id', userId)
        .inFilter('catch_id', catchIds);
    return List<Map<String, dynamic>>.from(rows);
  }
}
