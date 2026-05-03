import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TournamentMemberController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> approve({
    required String tournamentId,
    required String anglerId,
  }) async => _run(tournamentId, () async {
        final user = ref.read(currentUserProvider);
        if (user == null) {
          throw const AuthFailure('Sign in.');
        }
        await ref.read(tournamentsRepositoryProvider).approveMember(
              tournamentId: tournamentId,
              anglerId: anglerId,
              creatorId: user.id,
            );
      });

  Future<bool> reject({
    required String tournamentId,
    required String anglerId,
  }) async => _run(tournamentId, () async {
        final user = ref.read(currentUserProvider);
        if (user == null) {
          throw const AuthFailure('Sign in.');
        }
        await ref.read(tournamentsRepositoryProvider).rejectMember(
              tournamentId: tournamentId,
              anglerId: anglerId,
              creatorId: user.id,
            );
      });

  Future<bool> _run(String tournamentId, Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(tournamentMembersProvider(tournamentId));
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final tournamentMemberControllerProvider =
    AsyncNotifierProvider<TournamentMemberController, void>(
  TournamentMemberController.new,
);
