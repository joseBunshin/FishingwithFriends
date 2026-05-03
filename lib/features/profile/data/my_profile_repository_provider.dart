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

/// Any profile by user id. Profiles RLS allows authenticated reads of every
/// row, so this works for friends and strangers — used by the public
/// ProfileScreen.
final profileByIdProvider =
    FutureProvider.family<Profile?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  return ref.watch(myProfileRepositoryProvider).myProfile(userId);
});
