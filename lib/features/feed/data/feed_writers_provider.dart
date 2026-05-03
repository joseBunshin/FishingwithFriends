import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/feed/data/comments_repository.dart';
import 'package:fishing_with_friends/features/feed/data/reactions_repository.dart';
import 'package:fishing_with_friends/features/feed/domain/comment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reactionsDataSourceProvider = Provider<ReactionsDataSource>((ref) {
  return SupabaseReactionsDataSource(ref.watch(supabaseClientProvider));
});

final reactionsRepositoryProvider = Provider<ReactionsRepository>((ref) {
  return ReactionsRepository(
    dataSource: ref.watch(reactionsDataSourceProvider),
  );
});

final commentsDataSourceProvider = Provider<CommentsDataSource>((ref) {
  return SupabaseCommentsDataSource(ref.watch(supabaseClientProvider));
});

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  return CommentsRepository(
    dataSource: ref.watch(commentsDataSourceProvider),
  );
});

/// Comments for a single catch, ordered oldest-first.
final catchCommentsProvider =
    FutureProvider.family<List<Comment>, String>((ref, catchId) {
  return ref.watch(commentsRepositoryProvider).getForCatch(catchId);
});
