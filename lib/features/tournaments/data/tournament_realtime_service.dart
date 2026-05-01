import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight envelope for a Postgres-changes payload.
enum RealtimeChangeType { insert, update, delete }

class RealtimeRowChange {
  const RealtimeRowChange({
    required this.type,
    required this.row,
  });

  final RealtimeChangeType type;
  final Map<String, dynamic> row;
}

/// Subscribes to tournament_entries / tournament_chat_messages Postgres
/// changes filtered by tournament_id. Each call returns a Stream the
/// caller must clean up; ownership is via Riverpod's autoDispose +
/// `ref.onDispose(channel.unsubscribe)`.
class TournamentRealtimeService {
  TournamentRealtimeService(this._client);

  final SupabaseClient _client;

  RealtimeChannel entriesChannel(String tournamentId) {
    return _client
        .channel('tournament:$tournamentId:entries')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tournament_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tournament_id',
            value: tournamentId,
          ),
          callback: (_) {},
        );
  }

  RealtimeChannel chatChannel(String tournamentId) {
    return _client
        .channel('tournament:$tournamentId:chat')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tournament_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tournament_id',
            value: tournamentId,
          ),
          callback: (_) {},
        );
  }
}

/// Convert a supabase_flutter postgres-changes payload to the abstract
/// RealtimeRowChange. Visible for testing — the live state notifier reaches
/// for it directly so tests can simulate streams without touching Supabase.
RealtimeRowChange? rowChangeFromPayload(PostgresChangePayload payload) {
  RealtimeChangeType? type;
  Map<String, dynamic>? row;
  switch (payload.eventType) {
    case PostgresChangeEvent.insert:
      type = RealtimeChangeType.insert;
      row = payload.newRecord;
    case PostgresChangeEvent.update:
      type = RealtimeChangeType.update;
      row = payload.newRecord;
    case PostgresChangeEvent.delete:
      type = RealtimeChangeType.delete;
      row = payload.oldRecord;
    case PostgresChangeEvent.all:
      return null;
  }
  if (row.isEmpty) return null;
  return RealtimeRowChange(type: type, row: row);
}
