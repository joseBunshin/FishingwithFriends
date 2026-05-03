import 'package:fishing_with_friends/features/tournaments/data/tournament_entry_dto.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_realtime_service.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';

/// Pure event-application logic shared by the realtime live state notifier
/// and its tests. Public so tests can drive it without a real Supabase
/// channel — the supabase_flutter Realtime layer is intentionally not in
/// this module's surface area.
class EntriesLiveState {
  const EntriesLiveState(this.entries);

  final List<TournamentEntry> entries;

  /// Apply an insert/update/delete row change against the current list,
  /// returning a new list (never mutates input).
  EntriesLiveState apply(RealtimeRowChange change) {
    final next = [...entries];
    switch (change.type) {
      case RealtimeChangeType.insert:
        final entry = TournamentEntryDto.fromRow(change.row);
        if (next.any((e) => e.id == entry.id)) {
          // Already present (e.g. echo of optimistic insert) — ignore.
          return this;
        }
        next.add(entry);
      case RealtimeChangeType.update:
        final updated = TournamentEntryDto.fromRow(change.row);
        final idx = next.indexWhere((e) => e.id == updated.id);
        if (idx == -1) {
          // Update for a row we don't have yet — promote to insert.
          next.add(updated);
        } else {
          next[idx] = updated;
        }
      case RealtimeChangeType.delete:
        final id = change.row['id'] as String?;
        if (id != null) next.removeWhere((e) => e.id == id);
    }
    return EntriesLiveState(next);
  }
}
