import 'package:cached_network_image/cached_network_image.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/signed_url_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.catch_});

  final Catch catch_;

  String? _weightText() {
    final kg = catch_.weightKg;
    if (kg == null) return null;
    final lbs = kg * 2.20462;
    return '${lbs.toStringAsFixed(1)} lbs';
  }

  String? _lengthText() {
    final cm = catch_.lengthCm;
    if (cm == null) return null;
    final inches = cm / 2.54;
    return '${inches.toStringAsFixed(1)}"';
  }

  @override
  Widget build(BuildContext context) {
    final weight = _weightText();
    final length = _lengthText();
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
