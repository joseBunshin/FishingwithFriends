import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/notifications/data/notifications_repository.dart';
import 'package:fishing_with_friends/features/notifications/domain/app_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});

final myNotificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref
      .watch(notificationsRepositoryProvider)
      .myNotifications(user.id);
});

/// Count of unread notifications. Drives the badge on the Me tab tile.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(myNotificationsProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});
