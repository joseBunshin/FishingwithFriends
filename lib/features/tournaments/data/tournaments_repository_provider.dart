import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_data_source.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tournamentsDataSourceProvider = Provider<TournamentsDataSource>((ref) {
  return SupabaseTournamentsDataSource(ref.watch(supabaseClientProvider));
});

final tournamentsRepositoryProvider = Provider<TournamentsRepository>((ref) {
  return TournamentsRepository(
    dataSource: ref.watch(tournamentsDataSourceProvider),
  );
});

/// All tournaments visible to the current user (creator OR accepted member).
/// RLS handles the visibility filter; this provider just orders by start desc.
final myTournamentsProvider = FutureProvider<List<Tournament>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(tournamentsRepositoryProvider).getMine(user.id);
});

final tournamentByIdProvider =
    FutureProvider.family<Tournament?, String>((ref, id) {
  return ref.watch(tournamentsRepositoryProvider).getById(id);
});

final tournamentMembersProvider =
    FutureProvider.family<List<TournamentMember>, String>((ref, id) {
  return ref.watch(tournamentsRepositoryProvider).getMembers(id);
});
