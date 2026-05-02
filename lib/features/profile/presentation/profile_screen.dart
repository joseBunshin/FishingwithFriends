import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/catch_card.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/profile_mini_map.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/badge_wall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Public profile view for any user (yourself, an accepted friend, or — if
/// you ever land here for a non-friend — an empty stat shell). Sharper
/// layout: navy hero strip with avatar + identity, big-number stat row,
/// section labels with orange accent, then content blocks edge-to-edge.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(profileByIdProvider(userId));
    final asyncCatches = ref.watch(catchesForAnglerProvider(userId));
    final me = ref.watch(currentUserProvider);
    final isMe = me?.id == userId;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(profileByIdProvider(userId))
            ..invalidate(catchesForAnglerProvider(userId));
        },
        child: asyncProfile.when(
          data: (profile) {
            if (profile == null) return const _NotFound();
            final catches = asyncCatches.valueOrNull ?? const <Catch>[];
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(profile: profile),
                ),
                SliverToBoxAdapter(
                  child: _StatStrip(
                    catches: catches,
                    loading: asyncCatches.isLoading,
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionLabel('Badges'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: BadgeWall(anglerId: userId),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child:
                        SectionLabel(isMe ? 'Where I fish' : 'Where they fish'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ProfileMiniMap(anglerId: userId),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionLabel(
                      isMe ? 'My catches' : 'Recent catches',
                      trailing: catches.isEmpty
                          ? null
                          : '${catches.length}',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
                  sliver: _RecentCatchesSliver(
                    catches: catches,
                    loading: asyncCatches.isLoading,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _LoadError(),
        ),
      ),
    );
  }
}

/// Navy hero strip with status-bar safe top padding, back button, avatar,
/// display name, handle, home water, and bio. Replaces the old centered
/// stack with a confident left-aligned identity card.
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final hasDisplayName =
        profile.displayName != null && profile.displayName!.isNotEmpty;
    final hasHomeWater =
        profile.homeWater != null && profile.homeWater!.isNotEmpty;
    final hasBio = profile.bio != null && profile.bio!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(color: AppColors.navy),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AvatarView(avatarPath: profile.avatarPath, radius: 44),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDisplayName ? profile.displayName! : profile.handle,
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
                      profile.handle,
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
                              profile.homeWater!,
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
              profile.bio!,
              style: TextStyle(
                color: AppColors.mist.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Big-number stat row, no card chrome — just numbers with thin separators.
class _StatStrip extends ConsumerWidget {
  const _StatStrip({required this.catches, required this.loading});

  final List<Catch> catches;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(displayUnitsProvider);
    final total = catches.length;
    final speciesCount = catches
        .map((c) => (c.speciesLabel ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .length;
    final maxWeight = catches
        .map((c) => c.weightKg ?? 0)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final biggestLabel = maxWeight > 0
        ? formatWeight(maxWeight, units, compact: true) ?? '—'
        : '—';

    if (loading && catches.isEmpty) {
      return const SizedBox(
        height: 92,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BigStat(label: 'Catches', value: '$total'),
          _VBar(),
          _BigStat(label: 'Biggest', value: biggestLabel),
          _VBar(),
          _BigStat(label: 'Species', value: '$speciesCount'),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
              letterSpacing: -1,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

class _VBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Theme.of(context).colorScheme.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    );
  }
}

class _RecentCatchesSliver extends StatelessWidget {
  const _RecentCatchesSliver({required this.catches, required this.loading});

  final List<Catch> catches;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && catches.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (catches.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Center(
            child: Text(
              'No catches logged yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final visible = catches.take(12).toList(growable: false);
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.82,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final c = visible[i];
          return CatchCard(
            catch_: c,
            onTap: () => context.push('/catches/${c.id}'),
          );
        },
        childCount: visible.length,
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            "Couldn't find that angler.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            "Couldn't load this profile. Pull down to retry.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
