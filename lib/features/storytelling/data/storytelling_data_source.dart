import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Postgrest wrapper for the storytelling tables. Abstracted so the
/// repository can be unit-tested with a recording fake.
abstract class StorytellingDataSource {
  Future<List<Map<String, dynamic>>> selectMyPersonalRecords(String anglerId);
  Future<List<Map<String, dynamic>>> selectAllBadges();
  Future<List<Map<String, dynamic>>> selectMyUserBadges(String anglerId);

  /// Personal records whose `catch_id = catchId`.
  Future<List<Map<String, dynamic>>> selectPRsForCatch(String catchId);

  /// User-badge rows whose `source_catch_id = catchId` (joined with badges).
  Future<List<Map<String, dynamic>>> selectUserBadgesForCatch(
    String anglerId,
    String catchId,
  );
}

class SupabaseStorytellingDataSource implements StorytellingDataSource {
  SupabaseStorytellingDataSource(this._client);

  final SupabaseClient _client;

  static const _prSelect =
      'id, angler_id, species_id, metric, value, catch_id, achieved_at, '
      'species:species_id (common_name)';

  static const _userBadgeSelect =
      'id, angler_id, badge_code, earned_at, source_catch_id, '
      'badges:badge_code (*)';

  @override
  Future<List<Map<String, dynamic>>> selectMyPersonalRecords(
    String anglerId,
  ) async {
    final rows = await _client
        .from('personal_records')
        .select(_prSelect)
        .eq('angler_id', anglerId)
        .order('achieved_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectAllBadges() async {
    final rows = await _client
        .from('badges')
        .select('*')
        .order('code', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectMyUserBadges(
    String anglerId,
  ) async {
    final rows = await _client
        .from('user_badges')
        .select(_userBadgeSelect)
        .eq('angler_id', anglerId)
        .order('earned_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectPRsForCatch(String catchId) async {
    final rows = await _client
        .from('personal_records')
        .select(_prSelect)
        .eq('catch_id', catchId);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectUserBadgesForCatch(
    String anglerId,
    String catchId,
  ) async {
    final rows = await _client
        .from('user_badges')
        .select(_userBadgeSelect)
        .eq('angler_id', anglerId)
        .eq('source_catch_id', catchId);
    return List<Map<String, dynamic>>.from(rows);
  }
}
