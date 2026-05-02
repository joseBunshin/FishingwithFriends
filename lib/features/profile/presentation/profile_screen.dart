import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/catch_card.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/badge_wall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Public profile view for any user (yourself, an accepted friend, or — if
/// you ever land here for a non-friend — an empty stat shell). Mirrors the
/// shape of `MeScreen` minus the editing affordances.
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
      appBar: AppBar(
        title: Text(asyncProfile.value?.handle ?? 'Profile'),
      ),
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
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _Header(profile: profile),
                const SizedBox(height: AppSpacing.xl),
                _StatStrip(catches: catches, loading: asyncCatches.isLoading),
                const SizedBox(height: AppSpacing.xl),
                BadgeWall(anglerId: userId),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  isMe ? 'My catches' : 'Recent catches',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                _RecentCatches(
                  catches: catches,
                  loading: asyncCatches.isLoading,
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

    return Center(
      child: Column(
        children: [
          AvatarView(avatarPath: profile.avatarPath, radius: 56),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasDisplayName ? profile.displayName! : profile.handle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            profile.handle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (hasHomeWater) ...[
            const SizedBox(height: AppSpacing.xs),
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
          if (hasBio) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Text(
                profile.bio!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.slate,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
        height: 64,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        child: Row(
          children: [
            _StatTile(label: 'Catches', value: '$total'),
            _Divider(),
            _StatTile(label: 'Biggest', value: biggestLabel),
            _Divider(),
            _StatTile(label: 'Species', value: '$speciesCount'),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate,
                ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.mist,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

class _RecentCatches extends StatelessWidget {
  const _RecentCatches({required this.catches, required this.loading});

  final List<Catch> catches;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && catches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (catches.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.82,
      ),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final c = visible[i];
        return CatchCard(
          catch_: c,
          onTap: () => context.push('/catches/${c.id}'),
        );
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          "Couldn't find that angler.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          "Couldn't load this profile. Pull down to retry.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
