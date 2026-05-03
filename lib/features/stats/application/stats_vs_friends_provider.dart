import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Aggregate result of comparing the user's recent activity against
/// each accepted friend's recent activity.
@immutable
class VsFriendsSnapshot {
  const VsFriendsSnapshot({
    required this.myCount,
    required this.friendCounts,
    required this.windowDays,
  });

  /// Catch count for the user in the rolling window.
  final int myCount;

  /// Per-friend catch counts in the same window, descending by count.
  /// Empty list when the user has no accepted friends.
  final List<FriendCount> friendCounts;

  final int windowDays;

  bool get hasFriends => friendCounts.isNotEmpty;

  /// 0..100 — proportion of friends the user beats (counts >=). Null when
  /// the user has no friends to compare against. The user's count tying a
  /// friend's count is treated as a beat (>=).
  double? get percentile {
    if (!hasFriends) return null;
    var beat = 0;
    for (final f in friendCounts) {
      if (myCount >= f.count) beat += 1;
    }
    return (beat / friendCounts.length) * 100;
  }
}

@immutable
class FriendCount {
  const FriendCount({required this.friendId, required this.count});
  final String friendId;
  final int count;
}

/// Rolling 30-day comparison of own catches vs friends' catches.
final statsVsFriendsProvider = FutureProvider<VsFriendsSnapshot>((ref) async {
  const windowDays = 30;
  final cutoff = DateTime.now().subtract(const Duration(days: windowDays));

  final mine = await ref.watch(myCatchesProvider.future);
  final myCount = mine
      .where((c) => c.caughtAt.isAfter(cutoff) && !c.caughtAt.isAfter(DateTime.now()))
      .length;

  final friendIdsAsync = ref.watch(friendIdsProvider);
  final friendIds = friendIdsAsync.valueOrNull ?? const <String>[];
  if (friendIds.isEmpty) {
    return VsFriendsSnapshot(
      myCount: myCount,
      friendCounts: const [],
      windowDays: windowDays,
    );
  }

  final friendCatches = await ref.watch(friendsCatchesProvider.future);
  final perFriend = <String, int>{for (final f in friendIds) f: 0};
  for (final c in friendCatches) {
    if (!perFriend.containsKey(c.anglerId)) continue;
    if (c.caughtAt.isAfter(cutoff) && !c.caughtAt.isAfter(DateTime.now())) {
      perFriend[c.anglerId] = perFriend[c.anglerId]! + 1;
    }
  }
  final ranked = perFriend.entries
      .map((e) => FriendCount(friendId: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  return VsFriendsSnapshot(
    myCount: myCount,
    friendCounts: ranked,
    windowDays: windowDays,
  );
});
