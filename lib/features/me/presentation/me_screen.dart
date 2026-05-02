import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/notifications/data/notifications_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/badge_wall.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/streak_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Renders the unread-count badge + chevron for the Notifications tile.
class _NotificationsTrailing extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unread > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              unread > 99 ? '99+' : '$unread',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.xs),
        const Icon(Icons.chevron_right),
      ],
    );
  }
}

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final asyncProfile = ref.watch(myProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    final profile = asyncProfile.valueOrNull;
    final displayName = (profile?.displayName?.isNotEmpty ?? false)
        ? profile!.displayName!
        : (user?.email ?? 'Signed out');
    final handle = profile?.handle ?? '@you';

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                AvatarPicker(
                  currentAvatarPath: profile?.avatarPath,
                  radius: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  handle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (profile?.homeWater != null &&
                    profile!.homeWater!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.water_outlined, size: 14),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        profile.homeWater!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const StreakChip(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const BadgeWall(),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.deepOrange),
              title: const Text('Year in Review'),
              subtitle: const Text('Last 365 days as a story'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/year-in-review'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/me/edit'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: _NotificationsTrailing(),
                  onTap: () => context.push('/me/notifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/me/settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: scheme.error),
                  title: Text(
                    'Sign out',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () =>
                      ref.read(supabaseClientProvider).auth.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
