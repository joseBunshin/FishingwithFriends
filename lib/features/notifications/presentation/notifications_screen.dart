import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/notifications/data/notifications_repository_provider.dart';
import 'package:fishing_with_friends/features/notifications/domain/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifs = ref.watch(myNotificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification preferences',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/me/notifications/preferences'),
          ),
          if (unread > 0)
            TextButton(
              onPressed: () async {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                try {
                  await ref
                      .read(notificationsRepositoryProvider)
                      .markAllRead(user.id);
                  ref.invalidate(myNotificationsProvider);
                } on AppException catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myNotificationsProvider),
        child: asyncNotifs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: '$e'),
          data: (list) {
            if (list.isEmpty) return const _Empty();
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _NotificationTile(notification: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification.isRead;
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('notif-${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      onDismissed: (_) async {
        try {
          await ref
              .read(notificationsRepositoryProvider)
              .delete(notification.id);
          ref.invalidate(myNotificationsProvider);
        } on AppException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
          // Re-fetch so the dismissed-locally row reappears since the
          // delete didn't actually land.
          ref.invalidate(myNotificationsProvider);
        }
      },
      child: ListTile(
        onTap: () async {
          // Mark read in the background; navigate immediately.
          if (!isRead) {
            unawaited(
              ref
                  .read(notificationsRepositoryProvider)
                  .markRead(notification.id)
                  .then((_) => ref.invalidate(myNotificationsProvider)),
            );
          }
          final path = notification.deeplinkPath;
          if (path != null && context.mounted) {
            unawaited(context.push(path));
          }
        },
        leading: CircleAvatar(
          backgroundColor: isRead
              ? scheme.surfaceContainerHighest
              : AppColors.orange.withValues(alpha: 0.15),
          child: Icon(
            _iconFor(notification.kind),
            color: isRead ? scheme.onSurfaceVariant : AppColors.orange,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: notification.body == null
            ? Text(_relative(notification.createdAt))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.body!),
                  Text(
                    _relative(notification.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
        trailing: isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: AppColors.slate.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "You're all caught up.",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Friend requests, tournament invites, and entry '
                    'verifications will land here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            "Couldn't load notifications: $message",
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

IconData _iconFor(NotificationKind kind) => switch (kind) {
  NotificationKind.friendRequest => Icons.person_add_alt,
  NotificationKind.friendAccepted => Icons.handshake_outlined,
  NotificationKind.tournamentInvite => Icons.emoji_events_outlined,
  NotificationKind.tournamentMemberApproved => Icons.check_circle_outline,
  NotificationKind.tournamentMemberRejected => Icons.cancel_outlined,
  NotificationKind.tournamentEntryApproved => Icons.verified_outlined,
  NotificationKind.tournamentEntryRejected => Icons.block_outlined,
  NotificationKind.system => Icons.info_outline,
};

String _relative(DateTime ts) {
  final now = DateTime.now();
  final d = now.difference(ts.toLocal());
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat.yMMMd().format(ts.toLocal());
}
