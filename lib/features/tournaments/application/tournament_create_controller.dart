import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_input.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TournamentCreateController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<Tournament?> submit(TournamentInput input) async {
    if (state.isLoading) return null;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const AuthFailure('Sign in to create a tournament.'),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    try {
      final tournament = await ref
          .read(tournamentsRepositoryProvider)
          .create(input, creatorId: user.id);
      ref.invalidate(myTournamentsProvider);
      state = const AsyncData(null);
      return tournament;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

final tournamentCreateControllerProvider =
    AsyncNotifierProvider<TournamentCreateController, void>(
  TournamentCreateController.new,
);
