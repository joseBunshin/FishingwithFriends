import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/notifications/data/notification_preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
  return NotificationPreferencesRepository(ref.watch(supabaseClientProvider));
});

final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const NotificationPreferences.defaults();
  return ref
      .watch(notificationPreferencesRepositoryProvider)
      .load(user.id);
});
