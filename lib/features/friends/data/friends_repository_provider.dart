import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/friends/data/friends_data_source.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final friendsDataSourceProvider = Provider<FriendsDataSource>((ref) {
  return SupabaseFriendsDataSource(ref.watch(supabaseClientProvider));
});

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(dataSource: ref.watch(friendsDataSourceProvider));
});

final friendsBundleProvider = FutureProvider<FriendsBundle>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const FriendsBundle(
      accepted: [],
      pendingIncoming: [],
      pendingOutgoing: [],
      profilesById: {},
    );
  }
  return ref.watch(friendsRepositoryProvider).loadFor(user.id);
});

/// Accepted-friend uids relative to the current user. The Activity Feed
/// query in U6 watches this.
final friendIdsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(friendsBundleProvider).whenData((b) {
    return user == null ? const <String>[] : b.acceptedFriendIds(user.id);
  });
});
