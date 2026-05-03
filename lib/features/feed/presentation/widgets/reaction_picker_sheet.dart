import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/feed/domain/reaction.dart';
import 'package:flutter/material.dart';

class ReactionPickerSheet extends StatelessWidget {
  const ReactionPickerSheet({required this.currentKind, super.key});

  final ReactionKind? currentKind;

  static Future<ReactionKind?> show(
    BuildContext context, {
    ReactionKind? currentKind,
  }) {
    return showModalBottomSheet<ReactionKind?>(
      context: context,
      builder: (_) => ReactionPickerSheet(currentKind: currentKind),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('React',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: [
                for (final kind in ReactionKind.values)
                  _PickerTile(
                    kind: kind,
                    selected: kind == currentKind,
                    onTap: () => Navigator.pop(context, kind),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ReactionKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Text(kind.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              kind.label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
