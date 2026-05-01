import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/feed/data/feed_data_source.dart';
import 'package:fishing_with_friends/features/feed/data/feed_repository.dart';
import 'package:fishing_with_friends/features/feed/domain/feed_item.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedDataSourceProvider = Provider<FeedDataSource>((ref) {
  return SupabaseFeedDataSource(ref.watch(supabaseClientProvider));
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(dataSource: ref.watch(feedDataSourceProvider));
});

final activityFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  // Wait for the friend ids to settle before issuing the feed query.
  final friendIdsAsync = ref.watch(friendIdsProvider);
  final friendIds = friendIdsAsync.valueOrNull ?? const [];
  return ref.watch(feedRepositoryProvider).getFeed(
        currentUserId: user.id,
        friendIds: friendIds,
      );
});
