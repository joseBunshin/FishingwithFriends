import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read + write operations for the signed-in user's own profile.
/// Friends-side reads stay in the friends feature — this layer is only
/// for "me" surfaces (onboarding, edit profile, Me tab header).
class MyProfileRepository {
  MyProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, username, display_name, avatar_path, bio, home_water, '
      'onboarding_completed_at';

  Future<Profile?> myProfile(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final row = await _client
          .from('profiles')
          .select(_columns)
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load profile: ${e.message}', cause: e);
    }
  }

  /// Updates one or more profile fields. `null` means "leave unchanged"
  /// — pass an empty string to explicitly clear a text field.
  Future<Profile> updateMyProfile({
    required String userId,
    String? username,
    String? displayName,
    String? bio,
    String? homeWater,
    String? avatarPath,
  }) async {
    if (userId.isEmpty) {
      throw const AuthFailure('You must be signed in.');
    }
    final patch = <String, dynamic>{};
    if (username != null) patch['username'] = username;
    if (displayName != null) {
      patch['display_name'] = displayName.isEmpty ? null : displayName;
    }
    if (bio != null) patch['bio'] = bio.isEmpty ? null : bio;
    if (homeWater != null) {
      patch['home_water'] = homeWater.isEmpty ? null : homeWater;
    }
    if (avatarPath != null) {
      patch['avatar_path'] = avatarPath.isEmpty ? null : avatarPath;
    }
    if (patch.isEmpty) {
      final p = await myProfile(userId);
      if (p == null) throw const NetworkFailure('Profile not found.');
      return p;
    }

    try {
      final row = await _client
          .from('profiles')
          .update(patch)
          .eq('id', userId)
          .select(_columns)
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ValidationFailure('That username is already taken.');
      }
      throw NetworkFailure('Failed to save profile: ${e.message}', cause: e);
    }
  }

  /// Stamp `onboarding_completed_at = now()`. Idempotent — re-running
  /// after onboarding is a no-op as far as the user is concerned.
  Future<Profile> markOnboardingComplete(String userId) async {
    if (userId.isEmpty) {
      throw const AuthFailure('You must be signed in.');
    }
    try {
      final row = await _client
          .from('profiles')
          .update({'onboarding_completed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId)
          .select(_columns)
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to finish onboarding: ${e.message}',
        cause: e,
      );
    }
  }

  Profile _fromRow(Map<String, dynamic> row) {
    final completedRaw = row['onboarding_completed_at'] as String?;
    return Profile(
      id: row['id'] as String,
      username: row['username'] as String,
      displayName: row['display_name'] as String?,
      avatarPath: row['avatar_path'] as String?,
      bio: row['bio'] as String?,
      homeWater: row['home_water'] as String?,
      onboardingCompletedAt:
          completedRaw == null ? null : DateTime.parse(completedRaw).toUtc(),
    );
  }
}
