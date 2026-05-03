import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/notifications/data/notifications_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/badge_wall.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/streak_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Me-tab — owner-perspective profile with editing affordances. Shares
/// the navy-hero pattern with ProfileScreen so the visual language stays
/// consistent across the social surfaces.
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
    final homeWater = profile?.homeWater;
    final hasHomeWater = homeWater != null && homeWater.isNotEmpty;
    final bio = profile?.bio;
    final hasBio = bio != null && bio.isNotEmpty;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Navy hero strip — same pattern as ProfileScreen but with the
          // editable AvatarPicker (tap-to-change) instead of read-only.
          Container(
            decoration: const BoxDecoration(color: AppColors.navy),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              MediaQuery.of(context).padding.top + AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AvatarPicker(
                      currentAvatarPath: profile?.avatarPath,
                      radius: 44,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            handle,
                            style: const TextStyle(
                              color: AppColors.mist,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (hasHomeWater) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                const Icon(
                                  Icons.water_outlined,
                                  size: 14,
                                  color: AppColors.orange,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                Flexible(
                                  child: Text(
                                    homeWater,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasBio) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    bio,
                    style: TextStyle(
                      color: AppColors.mist.withValues(alpha: 0.9),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const StreakChip(),
              ],
            ),
          ),
          // Badges
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: SectionLabel('Badges'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: BadgeWall(anglerId: user?.id ?? ''),
          ),
          // Year in Review
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: SectionLabel('Storytelling'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Card(
              child: ListTile(
                leading: const Icon(
                  Icons.auto_awesome,
                  color: Colors.deepOrange,
                ),
                title: const Text('Year in Review'),
                subtitle: const Text('Last 365 days as a story'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/year-in-review'),
              ),
            ),
          ),
          // Account
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: SectionLabel('Account'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Card(
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
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

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
