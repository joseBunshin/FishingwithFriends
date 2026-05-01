import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/friends/domain/friendship.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives mutations on the friend graph from the Friends screen.
/// State semantics: AsyncData(null) idle, AsyncLoading during a mutation,
/// AsyncError on failure (UI shows snackbar with `error.message`).
class FriendsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> sendRequest(String addresseeId) async {
    return _run(() async {
      final user = ref.read(currentUserProvider);
      if (user == null) throw const AuthFailure('Sign in to send a request.');
      await ref.read(friendsRepositoryProvider).sendRequest(
            currentUserId: user.id,
            addresseeId: addresseeId,
          );
      ref.invalidate(friendsBundleProvider);
    });
  }

  Future<bool> accept(Friendship friendship) async {
    return _run(() async {
      await ref.read(friendsRepositoryProvider).accept(friendship);
      ref.invalidate(friendsBundleProvider);
    });
  }

  Future<bool> reject(Friendship friendship) async {
    return _run(() async {
      await ref.read(friendsRepositoryProvider).reject(friendship);
      ref.invalidate(friendsBundleProvider);
    });
  }

  Future<bool> removeFriend(String otherUserId) async {
    return _run(() async {
      final user = ref.read(currentUserProvider);
      if (user == null) throw const AuthFailure('Sign in.');
      await ref.read(friendsRepositoryProvider).removeFriend(
            currentUserId: user.id,
            otherUserId: otherUserId,
          );
      ref.invalidate(friendsBundleProvider);
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final friendsControllerProvider =
    AsyncNotifierProvider<FriendsController, void>(FriendsController.new);
