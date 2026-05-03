import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Branded share card. Renders at a fixed 1080×1920 logical pixel canvas.
/// Caller wraps in a RepaintBoundary and captures via toImage(pixelRatio: 1).
class ShareCard extends StatelessWidget {
  const ShareCard({
    required this.catch_,
    required this.photoUrl,
    this.photoBytes,
    super.key,
  });

  final Catch catch_;

  /// Signed URL for the cover photo, or null when unavailable.
  /// When null the card renders a navy fallback panel in place of the photo.
  final String? photoUrl;

  /// Pre-fetched photo bytes. When set, the card renders synchronously
  /// from memory instead of racing the network. The exporter pre-warms
  /// this so the offscreen capture isn't a blank navy panel.
  final Uint8List? photoBytes;

  static const double width = 1080;
  static const double height = 1920;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: AppColors.navy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: _Photo(photoUrl: photoUrl, photoBytes: photoBytes),
            ),
            Expanded(
              flex: 4,
              child: _Footer(catch_: catch_),
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({this.photoUrl, this.photoBytes});
  final String? photoUrl;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    // Prefer pre-fetched bytes (offscreen capture path) — synchronous
    // and avoids the placeholder race against `toImage()`.
    if (photoBytes != null) {
      return Image.memory(
        photoBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PhotoFallback(),
      );
    }
    if (photoUrl == null) {
      return const _PhotoFallback();
    }
    return CachedNetworkImage(
      imageUrl: photoUrl!,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: AppColors.navyDeep),
      errorWidget: (_, __, ___) => const _PhotoFallback(),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.navyDeep,
      child: Center(
        child: Icon(Icons.set_meal, size: 200, color: AppColors.orange),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.catch_});
  final Catch catch_;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SpeciesPill(label: catch_.speciesLabel ?? 'Catch'),
              const SizedBox(height: AppSpacing.lg),
              _MeasurementsRow(catch_: catch_),
              const SizedBox(height: AppSpacing.md),
              _LocationLabel(catch_: catch_),
            ],
          ),
          const _Wordmark(),
        ],
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
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 64,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _MeasurementsRow extends StatelessWidget {
  const _MeasurementsRow({required this.catch_});
  final Catch catch_;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];
    if (catch_.weightKg != null) {
      pills.add(_MeasurementChip(
        label: '${(catch_.weightKg! * 2.20462).toStringAsFixed(1)} lbs',
      ));
    }
    if (catch_.lengthCm != null) {
      pills.add(_MeasurementChip(
        label: '${(catch_.lengthCm! / 2.54).toStringAsFixed(1)} in',
      ));
    }
    if (catch_.catchAndRelease) {
      pills.add(const _MeasurementChip(label: 'Catch & release'));
    }
    if (pills.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: pills,
    );
  }
}

class _MeasurementChip extends StatelessWidget {
  const _MeasurementChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LocationLabel extends StatelessWidget {
  const _LocationLabel({required this.catch_});
  final Catch catch_;

  String get _label {
    if (catch_.secretSpot) return 'Secret spot';
    if (!catch_.hasLocation) return 'Location not set';
    return '${catch_.latitude!.toStringAsFixed(2)}, '
        '${catch_.longitude!.toStringAsFixed(2)}';
  }

  IconData get _icon =>
      catch_.secretSpot ? Icons.lock_outline : Icons.location_on_outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_icon, color: AppColors.mist, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _label,
            style: const TextStyle(
              color: AppColors.mist,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          DateFormat.yMMMd().format(catch_.caughtAt.toLocal()),
          style: const TextStyle(
            color: AppColors.mist,
            fontSize: 28,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.set_meal, color: AppColors.orange, size: 32),
        SizedBox(width: AppSpacing.sm),
        Text(
          'Fishing with Friends',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
