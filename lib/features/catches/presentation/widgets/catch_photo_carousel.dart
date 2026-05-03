import 'package:cached_network_image/cached_network_image.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/signed_url_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-bleed swipeable carousel for the catch detail screen. The first
/// page is hero-tagged `catch-photo-<id>` so it transitions from the grid.
class CatchPhotoCarousel extends ConsumerStatefulWidget {
  const CatchPhotoCarousel({
    required this.catchId,
    required this.photoPaths,
    super.key,
  });

  final String catchId;
  final List<String> photoPaths;

  @override
  ConsumerState<CatchPhotoCarousel> createState() =>
      _CatchPhotoCarouselState();
}

class _CatchPhotoCarouselState extends ConsumerState<CatchPhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The carousel intentionally fills whatever space its parent gives
    // it (the SliverAppBar's expandedHeight on the catch detail screen).
    // Earlier versions wrapped in AspectRatio(4/3) which under-filled
    // a 320pt SliverAppBar at typical iPhone widths and exposed the
    // navy backgroundColor as a gutter. BoxFit.cover already handles
    // landscape vs. portrait photos correctly.
    if (widget.photoPaths.isEmpty) {
      return Hero(
        tag: 'catch-photo-${widget.catchId}',
        child: ColoredBox(
          color: AppColors.mist.withValues(alpha: 0.6),
          child: Center(
            child: Icon(
              Icons.set_meal_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.photoPaths.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final path = widget.photoPaths[i];
              final urlAsync = ref.watch(signedUrlProvider(path));
              final image = urlAsync.when(
                data: (url) => CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const _PageLoading(),
                  errorWidget: (_, __, ___) => const _PageError(),
                ),
                loading: () => const _PageLoading(),
                error: (_, __) => const _PageError(),
              );
              if (i == 0) {
                return Hero(
                  tag: 'catch-photo-${widget.catchId}',
                  child: image,
                );
              }
              return image;
            },
          ),
        ),
        if (widget.photoPaths.length > 1)
          Positioned(
            bottom: AppSpacing.md,
            left: 0,
            right: 0,
            child: Center(
              child: _PageDots(count: widget.photoPaths.length, index: _index),
            ),
          ),
      ],
    );
  }
}

class _PageLoading extends StatelessWidget {
  const _PageLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.mist.withValues(alpha: 0.4),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.mist.withValues(alpha: 0.6),
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
