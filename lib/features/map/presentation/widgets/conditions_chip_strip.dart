import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Three placeholder chips for Wind / Tide / Temp shown in the map app
/// bar. Live values arrive in M6 with the conditions auto-fill edge
/// function; until then we surface em-dashes to communicate "coming"
/// without faking data.
class ConditionsChipStrip extends StatelessWidget {
  const ConditionsChipStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ConditionPill(icon: Icons.air, label: 'Wind —'),
          SizedBox(width: AppSpacing.xs),
          _ConditionPill(icon: Icons.waves, label: 'Tide —'),
          SizedBox(width: AppSpacing.xs),
          _ConditionPill(icon: Icons.thermostat_outlined, label: 'Temp —'),
        ],
      ),
    );
  }
}

class _ConditionPill extends StatelessWidget {
  const _ConditionPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
