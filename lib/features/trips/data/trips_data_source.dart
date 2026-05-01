import 'package:supabase_flutter/supabase_flutter.dart';

abstract class TripsDataSource {
  Future<Map<String, dynamic>> insertTrip(Map<String, dynamic> row);
  Future<Map<String, dynamic>> endActiveTrip(String tripId);
  Future<Map<String, dynamic>?> selectActiveTrip(String anglerId);
  Future<Map<String, dynamic>?> selectById(String id);
  Future<List<Map<String, dynamic>>> selectMine(String anglerId);
}

class SupabaseTripsDataSource implements TripsDataSource {
  SupabaseTripsDataSource(this._client);

  final SupabaseClient _client;

  static const _columns = '*';

  @override
  Future<Map<String, dynamic>> insertTrip(Map<String, dynamic> row) async {
    return _client.from('trips').insert(row).select(_columns).single();
  }

  @override
  Future<Map<String, dynamic>> endActiveTrip(String tripId) async {
    return _client
        .from('trips')
        .update({
          'is_active': false,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tripId)
        .select(_columns)
        .single();
  }

  @override
  Future<Map<String, dynamic>?> selectActiveTrip(String anglerId) {
    return _client
        .from('trips')
        .select(_columns)
        .eq('angler_id', anglerId)
        .eq('is_active', true)
        .maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> selectById(String id) {
    return _client.from('trips').select(_columns).eq('id', id).maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> selectMine(String anglerId) async {
    final rows = await _client
        .from('trips')
        .select(_columns)
        .eq('angler_id', anglerId)
        .order('started_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
