import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/feed/data/feed_repository_provider.dart';
import 'package:fishing_with_friends/features/feed/data/feed_writers_provider.dart';
import 'package:fishing_with_friends/features/feed/domain/comment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommentController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<Comment?> post({
    required String catchId,
    required String body,
  }) async {
    if (state.isLoading) return null;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const AuthFailure('Sign in to comment.'),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    try {
      final comment = await ref.read(commentsRepositoryProvider).post(
            catchId: catchId,
            authorId: user.id,
            body: body,
          );
      ref
        ..invalidate(catchCommentsProvider(catchId))
        ..invalidate(activityFeedProvider);
      state = const AsyncData(null);
      return comment;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<bool> softDelete({
    required String commentId,
    required String catchId,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await ref.read(commentsRepositoryProvider).softDelete(commentId);
      ref
        ..invalidate(catchCommentsProvider(catchId))
        ..invalidate(activityFeedProvider);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final commentControllerProvider =
    AsyncNotifierProvider<CommentController, void>(CommentController.new);
