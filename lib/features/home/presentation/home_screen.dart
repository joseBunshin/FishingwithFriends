import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/feed/data/feed_repository_provider.dart';
import 'package:fishing_with_friends/features/feed/domain/feed_item.dart';
import 'package:fishing_with_friends/features/feed/presentation/feed_item_card.dart';
import 'package:fishing_with_friends/features/home/data/home_metrics_provider.dart';
import 'package:fishing_with_friends/features/home/domain/home_metrics.dart';
import 'package:fishing_with_friends/features/home/presentation/widgets/action_chips.dart';
import 'package:fishing_with_friends/features/home/presentation/widgets/stat_tile.dart';
import 'package:fishing_with_friends/features/notifications/data/notifications_repository_provider.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/sync/presentation/widgets/sync_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMetrics = ref.watch(homeMetricsProvider);
    final metrics = asyncMetrics.valueOrNull ?? const HomeMetrics.empty();
    final asyncFeed = ref.watch(activityFeedProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [_NotificationsBell(), SyncPill()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(homeMetricsProvider)
            ..invalidate(activityFeedProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const HomeActionChips(),
            const SizedBox(height: AppSpacing.xl),
            InkWell(
              onTap: () => context.push(AppRoutes.stats),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: SectionLabel('Stats', trailing: 'See all  ›'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StatGrid(metrics: metrics),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Activity'),
            const SizedBox(height: AppSpacing.md),
            ..._activitySection(asyncFeed, user?.id ?? ''),
          ],
        ),
      ),
    );
  }

  List<Widget> _activitySection(
    AsyncValue<List<FeedItem>> async,
    String currentUserId,
  ) {
    return async.when(
      data: (feed) {
        if (feed.isEmpty) {
          return const [_EmptyActivity()];
        }
        return [
          for (final item in feed) ...[
            FeedItemCard(
              item: item,
              isMine: item.catch_.anglerId == currentUserId,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ];
      },
      loading: () => const [_LoadingActivity()],
      error: (_, __) => const [_ActivityError()],
    );
  }
}

class _StatGrid extends ConsumerWidget {
  const _StatGrid({required this.metrics});

  final HomeMetrics metrics;

  String? get _biggestSubtitle => metrics.biggestSpecies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(displayUnitsProvider);
    final totalWeightDisplay =
        formatWeight(metrics.totalWeightKg, units) ?? '—';
    final biggestValue =
        formatWeight(metrics.biggestWeightKg, units, compact: true) ?? '—';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Total Catches',
                value: '${metrics.totalCatches}',
                icon: Icons.set_meal_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Total Weight',
                value: totalWeightDisplay,
                icon: Icons.scale_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Species',
                value: '${metrics.uniqueSpecies}',
                icon: Icons.water_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Biggest',
                value: biggestValue,
                caption: _biggestSubtitle,
                icon: Icons.workspace_premium_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.dynamic_feed_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No catches in your feed yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Log a catch — or add a friend so you can see theirs.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.logCatch),
                  icon: const Icon(Icons.add),
                  label: const Text('Log a catch'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.friends),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Find anglers'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingActivity extends StatelessWidget {
  const _LoadingActivity();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityError extends ConsumerWidget {
  const _ActivityError();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "Couldn't load your activity feed.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(activityFeedProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar bell with an orange-dot indicator when there are unread
/// notifications. Tap routes to the existing /me/notifications screen.
/// `unreadNotificationCountProvider` is a synchronous `Provider<int>` that
/// returns 0 during loading or error of the underlying notifications
/// stream — so the dot only renders when AsyncData has confirmed a
/// non-zero count, no special UI handling needed for transient states.
class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final hasUnread = unread > 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: hasUnread
              ? 'Notifications ($unread unread)'
              : 'Notifications',
          onPressed: () => context.push('/me/notifications'),
        ),
        if (hasUnread)
          const Positioned(
            top: 10,
            right: 10,
            child: IgnorePointer(
              child: _OrangeDot(key: Key('home-notifications-dot')),
            ),
          ),
      ],
    );
  }
}

class _OrangeDot extends StatelessWidget {
  const _OrangeDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.orange,
        shape: BoxShape.circle,
      ),
    );
  }
}
