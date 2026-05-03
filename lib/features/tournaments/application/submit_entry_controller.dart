import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubmitEntryController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<TournamentEntry?> submit({
    required Tournament tournament,
    required Catch source,
  }) async {
    if (state.isLoading) return null;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const AuthFailure('Sign in to submit a catch.'),
        StackTrace.current,
      );
      return null;
    }
    final phase = tournament.phaseAt(DateTime.now());
    if (phase != TournamentPhase.live) {
      state = AsyncError(
        const ValidationFailure(
          'Tournament is not accepting entries right now.',
        ),
        StackTrace.current,
      );
      return null;
    }
    if (source.caughtAt.isBefore(tournament.startsAt) ||
        source.caughtAt.isAfter(tournament.endsAt)) {
      state = AsyncError(
        const ValidationFailure(
          "This catch is outside the tournament's window.",
        ),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    try {
      final entry = await ref
          .read(tournamentEntriesRepositoryProvider)
          .submitEntry(
            tournamentId: tournament.id,
            source: source,
            anglerId: user.id,
          );
      ref
        ..invalidate(tournamentEntriesProvider(tournament.id))
        ..invalidate(myCatchesProvider);
      state = const AsyncData(null);
      return entry;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

final submitEntryControllerProvider =
    AsyncNotifierProvider<SubmitEntryController, void>(
  SubmitEntryController.new,
);
