import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final myProfileRepositoryProvider = Provider<MyProfileRepository>((ref) {
  return MyProfileRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's own profile row, or null when signed out.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(myProfileRepositoryProvider).myProfile(user.id);
});
