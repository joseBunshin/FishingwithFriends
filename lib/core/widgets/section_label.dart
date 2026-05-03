import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Section label — small all-caps text with an orange accent bar before
/// it. Used across modernized surfaces (profile, friends, catch detail)
/// to mark sections without leaning on Card chrome. Optional [trailing]
/// renders a small count or status indicator on the right.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {this.trailing, super.key});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.slate,
            ),
          ),
      ],
    );
  }
}
