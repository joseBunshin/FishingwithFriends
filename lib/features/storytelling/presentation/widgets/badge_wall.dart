import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_repository_provider.dart';
import 'package:fishing_with_friends/features/storytelling/domain/badge.dart' as fwf;
import 'package:fishing_with_friends/features/storytelling/domain/user_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BadgeWall extends ConsumerWidget {
  const BadgeWall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBadges = ref.watch(allBadgesProvider);
    final asyncEarned = ref.watch(myUserBadgesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.military_tech_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Badges',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (asyncBadges.isLoading || asyncEarned.isLoading)
              const _Loading()
            else if (asyncBadges.hasError)
              const _Error()
            else
              _Grid(
                badges: asyncBadges.value ?? const [],
                earned: asyncEarned.value ?? const [],
              ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.badges, required this.earned});

  final List<fwf.Badge> badges;
  final List<UserBadge> earned;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const _Empty();
    final earnedByCode = {for (final ub in earned) ub.badgeCode: ub};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 0.85,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      children: [
        for (final b in badges)
          _BadgeTile(
            definition: b,
            earned: earnedByCode[b.code],
          ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.definition, this.earned});

  final fwf.Badge definition;
  final UserBadge? earned;

  bool get isEarned => earned != null;

  @override
  Widget build(BuildContext context) {
    final color =
        isEarned ? AppColors.orange : AppColors.slate.withValues(alpha: 0.4);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => _showSheet(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isEarned
                    ? AppColors.orange.withValues(alpha: 0.12)
                    : AppColors.mist,
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(definition.iconName), color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              definition.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight:
                        isEarned ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _DescriptionSheet(
        definition: definition,
        earned: earned,
      ),
    );
  }
}

class _DescriptionSheet extends StatelessWidget {
  const _DescriptionSheet({required this.definition, this.earned});

  final fwf.Badge definition;
  final UserBadge? earned;

  @override
  Widget build(BuildContext context) {
    final color = earned != null
        ? AppColors.orange
        : AppColors.slate.withValues(alpha: 0.6);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: earned != null
                    ? AppColors.orange.withValues(alpha: 0.12)
                    : AppColors.mist,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFor(definition.iconName),
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              definition.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              definition.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              earned != null
                  ? 'Earned ${DateFormat.yMMMd().format(earned!.earnedAt.toLocal())}'
                  : 'Locked',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 96,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Center(
        child: Text(
          "Couldn't load badges",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        'No badges defined yet.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

IconData _iconFor(String name) => switch (name) {
      'set_meal' => Icons.set_meal,
      'inventory_2' => Icons.inventory_2,
      'workspace_premium' => Icons.workspace_premium,
      'menu_book' => Icons.menu_book,
      'auto_awesome' => Icons.auto_awesome,
      _ => Icons.emoji_events_outlined,
    };
