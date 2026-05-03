import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/feed/domain/reaction.dart';
import 'package:meta/meta.dart';

/// One row in the Activity Feed: the catch + aggregated counts + the
/// current user's own reaction (if any).
@immutable
class FeedItem {
  const FeedItem({
    required this.catch_,
    required this.reactionCounts,
    required this.commentCount,
    this.myReaction,
  });

  final Catch catch_;
  final Map<ReactionKind, int> reactionCounts;
  final int commentCount;
  final ReactionKind? myReaction;

  int get totalReactions =>
      reactionCounts.values.fold(0, (sum, n) => sum + n);

  FeedItem copyWith({
    Catch? catch_,
    Map<ReactionKind, int>? reactionCounts,
    int? commentCount,
    ReactionKind? myReaction,
    bool clearMyReaction = false,
  }) {
    return FeedItem(
      catch_: catch_ ?? this.catch_,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      commentCount: commentCount ?? this.commentCount,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
    );
  }
}
