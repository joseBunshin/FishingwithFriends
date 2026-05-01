import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debounced search across `profiles.username`. Re-runs ~300ms after the
/// most recent change.
class FriendSearchController extends AutoDisposeAsyncNotifier<List<Profile>> {
  Timer? _debounce;
  String _query = '';

  @override
  FutureOr<List<Profile>> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return const [];
  }

  void setQuery(String query) {
    _query = query;
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading<List<Profile>>().copyWithPrevious(state);
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncData([]);
      return;
    }
    try {
      final results = await ref
          .read(friendsRepositoryProvider)
          .search(query: _query, currentUserId: user.id);
      state = AsyncData(results);
    } on ValidationFailure {
      state = const AsyncData([]);
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final friendSearchControllerProvider = AutoDisposeAsyncNotifierProvider<
    FriendSearchController, List<Profile>>(FriendSearchController.new);
