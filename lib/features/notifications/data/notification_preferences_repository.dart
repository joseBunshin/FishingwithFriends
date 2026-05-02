import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    required this.friendRequests,
    required this.tournaments,
    required this.feed,
  });

  const NotificationPreferences.defaults()
      : friendRequests = true,
        tournaments = true,
        feed = true;

  final bool friendRequests;
  final bool tournaments;
  final bool feed;

  NotificationPreferences copyWith({
    bool? friendRequests,
    bool? tournaments,
    bool? feed,
  }) {
    return NotificationPreferences(
      friendRequests: friendRequests ?? this.friendRequests,
      tournaments: tournaments ?? this.tournaments,
      feed: feed ?? this.feed,
    );
  }
}

class NotificationPreferencesRepository {
  NotificationPreferencesRepository(this._client);

  final SupabaseClient _client;

  Future<NotificationPreferences> load(String userId) async {
    if (userId.isEmpty) return const NotificationPreferences.defaults();
    try {
      final row = await _client
          .from('notification_preferences')
          .select('friend_requests, tournaments, feed')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return const NotificationPreferences.defaults();
      return NotificationPreferences(
        friendRequests: row['friend_requests'] as bool? ?? true,
        tournaments: row['tournaments'] as bool? ?? true,
        feed: row['feed'] as bool? ?? true,
      );
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to load preferences: ${e.message}',
        cause: e,
      );
    }
  }

  Future<void> upsert({
    required String userId,
    required NotificationPreferences prefs,
  }) async {
    if (userId.isEmpty) {
      throw const AuthFailure('You must be signed in.');
    }
    try {
      await _client.from('notification_preferences').upsert({
        'user_id': userId,
        'friend_requests': prefs.friendRequests,
        'tournaments': prefs.tournaments,
        'feed': prefs.feed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to save preferences: ${e.message}',
        cause: e,
      );
    }
  }
}
