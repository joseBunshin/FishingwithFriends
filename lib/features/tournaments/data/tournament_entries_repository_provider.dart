import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_data_source.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_repository.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_side_pot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tournamentEntriesDataSourceProvider =
    Provider<TournamentEntriesDataSource>((ref) {
  return SupabaseTournamentEntriesDataSource(
    ref.watch(supabaseClientProvider),
  );
});

final tournamentEntriesRepositoryProvider =
    Provider<TournamentEntriesRepository>((ref) {
  return TournamentEntriesRepository(
    dataSource: ref.watch(tournamentEntriesDataSourceProvider),
  );
});

final tournamentEntriesProvider =
    FutureProvider.family<List<TournamentEntry>, String>((ref, id) {
  return ref.watch(tournamentEntriesRepositoryProvider).listForTournament(id);
});

final tournamentSidePotsProvider =
    FutureProvider.family<List<TournamentSidePot>, String>((ref, id) {
  return ref.watch(tournamentEntriesRepositoryProvider).listSidePots(id);
});
