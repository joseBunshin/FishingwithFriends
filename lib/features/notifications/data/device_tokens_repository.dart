import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceTokensRepository {
  DeviceTokensRepository(this._client);

  final SupabaseClient _client;

  /// Upsert (user_id, token) — refreshes last_seen_at when the same row
  /// already exists. Platform is one of 'ios' | 'android' | 'web'.
  Future<void> upsert({
    required String userId,
    required String token,
    required String platform,
  }) async {
    if (userId.isEmpty || token.isEmpty) return;
    try {
      await _client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to register device token: ${e.message}',
        cause: e,
      );
    }
  }

  /// Removes a token (on logout, or when FCM tells us it's stale).
  Future<void> delete({
    required String userId,
    required String token,
  }) async {
    try {
      await _client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to remove device token: ${e.message}',
        cause: e,
      );
    }
  }
}
