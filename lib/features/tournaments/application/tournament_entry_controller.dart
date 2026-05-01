import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TournamentEntryController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> approve({
    required String entryId,
    required String tournamentId,
  }) async => _run(tournamentId, () async {
        final user = ref.read(currentUserProvider);
        if (user == null) throw const AuthFailure('Sign in.');
        await ref
            .read(tournamentEntriesRepositoryProvider)
            .approve(entryId: entryId, creatorId: user.id);
      });

  Future<bool> reject({
    required String entryId,
    required String tournamentId,
  }) async => _run(tournamentId, () async {
        final user = ref.read(currentUserProvider);
        if (user == null) throw const AuthFailure('Sign in.');
        await ref
            .read(tournamentEntriesRepositoryProvider)
            .reject(entryId: entryId, creatorId: user.id);
      });

  Future<bool> _run(String tournamentId, Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(tournamentEntriesProvider(tournamentId));
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final tournamentEntryControllerProvider =
    AsyncNotifierProvider<TournamentEntryController, void>(
  TournamentEntryController.new,
);
