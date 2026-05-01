import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/feed/data/feed_repository_provider.dart';
import 'package:fishing_with_friends/features/feed/data/feed_writers_provider.dart';
import 'package:fishing_with_friends/features/feed/domain/reaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReactionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> toggle({
    required String catchId,
    required ReactionKind kind,
    required ReactionKind? currentKind,
  }) async {
    if (state.isLoading) return false;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const AuthFailure('Sign in to react.'),
        StackTrace.current,
      );
      return false;
    }
    state = const AsyncLoading();
    try {
      await ref.read(reactionsRepositoryProvider).toggle(
            catchId: catchId,
            userId: user.id,
            kind: kind,
            currentKind: currentKind,
          );
      ref.invalidate(activityFeedProvider);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final reactionControllerProvider =
    AsyncNotifierProvider<ReactionController, void>(
  ReactionController.new,
);
