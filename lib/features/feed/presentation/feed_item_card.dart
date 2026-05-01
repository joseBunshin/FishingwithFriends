import 'package:cached_network_image/cached_network_image.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/signed_url_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/feed/domain/feed_item.dart';
import 'package:fishing_with_friends/features/feed/presentation/widgets/feed_item_header.dart';
import 'package:fishing_with_friends/features/feed/presentation/widgets/reaction_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Feed-tab card. Composition: header + photo + meta row + footer (counts).
/// The reaction *picker* + comment *composer* land in U9 — this card just
/// surfaces the aggregated counts so you can see your friends are alive.
class FeedItemCard extends ConsumerWidget {
  const FeedItemCard({
    required this.item,
    required this.isMine,
    super.key,
  });

  final FeedItem item;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/catches/${item.catch_.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FeedItemHeader(
              anglerId: item.catch_.anglerId,
              caughtAt: item.catch_.caughtAt,
              isMine: isMine,
            ),
            _CoverPhoto(catch_: item.catch_),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaRow(catch_: item.catch_),
                  const SizedBox(height: AppSpacing.sm),
                  ReactionStrip(item: item),
                  if (item.commentCount > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _CommentSummary(item: item),
                  ],
                ],
              ),
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
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Hero(
        tag: 'catch-photo-${catch_.id}',
        child: urlAsync.when(
          data: (url) => CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => const _PlaceholderTile(),
            errorWidget: (_, __, ___) => const _PlaceholderTile(),
          ),
          loading: () => const _PlaceholderTile(),
          error: (_, __) => const _PlaceholderTile(),
        ),
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ColoredBox(
        color: AppColors.mist.withValues(alpha: 0.6),
        child: Center(
          child: Icon(
            Icons.set_meal_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.catch_});

  final Catch catch_;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    final species = catch_.speciesLabel ?? catch_.speciesId;
    if (species != null && species.isNotEmpty) parts.add(species);
    if (catch_.weightKg != null) {
      final lbs = (catch_.weightKg! * 2.20462).toStringAsFixed(1);
      parts.add('$lbs lbs');
    }
    if (catch_.lengthCm != null) {
      final inches = (catch_.lengthCm! / 2.54).toStringAsFixed(1);
      parts.add('$inches"');
    }
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _CommentSummary extends StatelessWidget {
  const _CommentSummary({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.chat_bubble_outline, size: 14, color: scheme.primary),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          item.commentCount == 1
              ? '1 comment'
              : '${item.commentCount} comments',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
