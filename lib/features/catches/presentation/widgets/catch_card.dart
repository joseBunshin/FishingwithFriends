import 'package:cached_network_image/cached_network_image.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/features/catches/data/signed_url_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/sync/data/pending_catches_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Photo-first catch tile used in the Catches grid + Recent Catches feed.
/// Hero-tagged with `catch-photo-<id>` so the detail screen transitions
/// from the same image.
class CatchCard extends ConsumerWidget {
  const CatchCard({required this.catch_, this.onTap, super.key});

  final Catch catch_;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingIds = ref.watch(pendingCatchIdsProvider);
    final isPending = pendingIds.contains(catch_.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: 'catch-photo-${catch_.id}',
                      child: _CoverPhoto(catch_: catch_),
                    ),
                  ),
                  if (catch_.speciesLabel != null)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: _SpeciesPill(label: catch_.speciesLabel!),
                    ),
                  if (isPending)
                    const Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: _UploadBadge(),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _MetaRow(catch_: catch_),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadBadge extends StatelessWidget {
  const _UploadBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.orange,
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _CoverPhoto extends ConsumerWidget {
  const _CoverPhoto({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (catch_.photoPaths.isEmpty) {
      return const _PlaceholderTile();
    }
    final urlAsync = ref.watch(signedUrlProvider(catch_.photoPaths.first));
    return urlAsync.when(
      data: (url) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => const _PlaceholderTile(),
        errorWidget: (_, __, ___) => const _PlaceholderTile(),
      ),
      loading: () => const _PlaceholderTile(),
      error: (_, __) => const _PlaceholderTile(),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.mist.withValues(alpha: 0.6),
      child: Center(
        child: Icon(
          Icons.set_meal_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _SpeciesPill extends StatelessWidget {
  const _SpeciesPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaRow extends ConsumerWidget {
  const _MetaRow({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(displayUnitsProvider);
    final weight = formatWeight(catch_.weightKg, units);
    final length = formatLength(catch_.lengthCm, units);
    final parts = <String>[
      if (weight != null) weight,
      if (length != null) length,
    ];
    return Row(
      children: [
        if (catch_.catchAndRelease)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Icon(
              Icons.water_drop_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        Expanded(
          child: Text(
            parts.join(' · '),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
