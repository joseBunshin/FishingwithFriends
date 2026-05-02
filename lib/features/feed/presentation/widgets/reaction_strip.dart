import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/feed/application/reaction_controller.dart';
import 'package:fishing_with_friends/features/feed/domain/feed_item.dart';
import 'package:fishing_with_friends/features/feed/domain/reaction.dart';
import 'package:fishing_with_friends/features/feed/presentation/widgets/reaction_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact reaction row for feed cards + the bottom of catch detail.
/// Shows the top-3 active kinds inline plus a "+" tile that opens the
/// full picker. Tap an active chip to toggle that kind for the user.
class ReactionStrip extends ConsumerWidget {
  const ReactionStrip({required this.item, super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeKinds = item.reactionCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = activeKinds.take(3).toList();

    Future<void> onTapKind(ReactionKind kind) async {
      await ref.read(reactionControllerProvider.notifier).toggle(
            catchId: item.catch_.id,
            kind: kind,
            currentKind: item.myReaction,
          );
    }

    Future<void> onTapPicker() async {
      final picked = await ReactionPickerSheet.show(
        context,
        currentKind: item.myReaction,
      );
      if (picked != null) {
        await onTapKind(picked);
      }
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in shown)
          _Chip(
            label: '${entry.key.emoji} ${entry.value}',
            highlighted: entry.key == item.myReaction,
            onTap: () => onTapKind(entry.key),
          ),
        // Empty state: a "React" CTA with a smiley-plus icon. Once
        // reactions exist the picker collapses to an icon-only chip
        // (`Icons.add_reaction_outlined`) so we don't double-mark with
        // both an icon AND a "+" glyph.
        _Chip(
          label: shown.isEmpty ? 'React' : null,
          icon: Icons.add_reaction_outlined,
          onTap: onTapPicker,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.onTap,
    this.label,
    this.icon,
    this.highlighted = false,
  });

  final String? label;
  final IconData? icon;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLabel = label != null && label!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: hasLabel ? AppSpacing.sm : AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: highlighted
              ? Border.all(color: scheme.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: highlighted
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.7),
              ),
              if (hasLabel) const SizedBox(width: AppSpacing.xxs),
            ],
            if (hasLabel)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: highlighted
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
