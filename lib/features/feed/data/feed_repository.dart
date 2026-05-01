import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/catches/data/catch_dto.dart';
import 'package:fishing_with_friends/features/feed/data/feed_data_source.dart';
import 'package:fishing_with_friends/features/feed/domain/feed_item.dart';
import 'package:fishing_with_friends/features/feed/domain/reaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedRepository {
  FeedRepository({required this.dataSource});

  final FeedDataSource dataSource;

  Future<List<FeedItem>> getFeed({
    required String currentUserId,
    required List<String> friendIds,
    int limit = 50,
  }) async {
    if (currentUserId.isEmpty) return const [];
    try {
      final rows = await dataSource.selectFeedCatches(
        currentUserId: currentUserId,
        friendIds: friendIds,
        limit: limit,
      );
      if (rows.isEmpty) return const [];

      final catches = rows.map(CatchDto.fromRow).toList(growable: false);
      final ids = catches.map((c) => c.id).toList(growable: false);

      final reactionRows =
          await dataSource.selectReactionAggregates(ids);
      final commentRows = await dataSource.selectCommentCounts(ids);
      final myReactionRows = await dataSource.selectMyReactions(
        userId: currentUserId,
        catchIds: ids,
      );

      final reactionCounts = _buildReactionCounts(reactionRows);
      final commentCounts = _buildCommentCounts(commentRows);
      final myReactions = _buildMyReactions(myReactionRows);

      return catches.map((c) {
        return FeedItem(
          catch_: c,
          reactionCounts: reactionCounts[c.id] ?? const {},
          commentCount: commentCounts[c.id] ?? 0,
          myReaction: myReactions[c.id],
        );
      }).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load feed: ${e.message}', cause: e);
    }
  }

  Map<String, Map<ReactionKind, int>> _buildReactionCounts(
    List<Map<String, dynamic>> rows,
  ) {
    final out = <String, Map<ReactionKind, int>>{};
    for (final r in rows) {
      final id = r['catch_id'] as String;
      final kind = ReactionKind.tryFromId(r['kind'] as String);
      if (kind == null) continue; // unknown kind from a future schema
      final bucket = out.putIfAbsent(id, () => <ReactionKind, int>{});
      bucket[kind] = (bucket[kind] ?? 0) + 1;
    }
    return out;
  }

  Map<String, int> _buildCommentCounts(List<Map<String, dynamic>> rows) {
    final out = <String, int>{};
    for (final r in rows) {
      final id = r['catch_id'] as String;
      out[id] = (out[id] ?? 0) + 1;
    }
    return out;
  }

  Map<String, ReactionKind> _buildMyReactions(
    List<Map<String, dynamic>> rows,
  ) {
    final out = <String, ReactionKind>{};
    for (final r in rows) {
      final id = r['catch_id'] as String;
      final kind = ReactionKind.tryFromId(r['kind'] as String);
      if (kind != null) out[id] = kind;
    }
    return out;
  }
}
