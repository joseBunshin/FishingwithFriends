import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_chat_data_source.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_chat_repository.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_chat_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tournamentChatDataSourceProvider =
    Provider<TournamentChatDataSource>((ref) {
  return SupabaseTournamentChatDataSource(ref.watch(supabaseClientProvider));
});

final tournamentChatRepositoryProvider =
    Provider<TournamentChatRepository>((ref) {
  return TournamentChatRepository(
    dataSource: ref.watch(tournamentChatDataSourceProvider),
  );
});

final tournamentChatProvider =
    FutureProvider.family<List<TournamentChatMessage>, String>(
  (ref, id) =>
      ref.watch(tournamentChatRepositoryProvider).getForTournament(id),
);
