import 'dart:io';

import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Dashed-border photo upload area for the Log Catch form.
/// Empty: shows camera icon + "Add Photos / Tap to capture your catch".
/// Populated: horizontal carousel of thumbnails with a + tile and a remove
/// affordance per photo.
class PhotoDropTarget extends StatelessWidget {
  const PhotoDropTarget({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.maxPhotos = 5,
    super.key,
  });

  final List<XFile> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final int maxPhotos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return _EmptyTarget(onTap: onAdd);
    }
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (photos.length < maxPhotos ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == photos.length) {
            return _AddTile(onTap: onAdd);
          }
          return _ThumbnailTile(
            file: photos[i],
            onRemove: () => onRemove(i),
          );
        },
      ),
    );
  }
}

class _EmptyTarget extends StatelessWidget {
  const _EmptyTarget({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: DottedBorder(
        color: scheme.onSurface.withValues(alpha: 0.2),
        radius: AppSpacing.radiusLg,
        child: AspectRatio(
          aspectRatio: 5 / 3,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Add Photos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Tap to capture your catch',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
        ),
        child: Center(child: Icon(Icons.add, color: scheme.primary)),
      ),
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Stack(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: kIsWeb
                ? Image.network(file.path, fit: BoxFit.cover)
                : Image.file(File(file.path), fit: BoxFit.cover),
          ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal dashed-border container — Flutter has no built-in dashed border,
/// and pulling in `dotted_border` for one widget is overkill. This paints a
/// rounded rect with dashes via a custom painter.
class DottedBorder extends StatelessWidget {
  const DottedBorder({
    required this.color,
    required this.radius,
    required this.child,
    super.key,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  _DottedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);

    const dashLen = 6.0;
    const gapLen = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashLen),
          paint,
        );
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
