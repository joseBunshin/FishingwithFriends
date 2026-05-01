import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Pure-placeholder card. Conditions correlation requires the M6
/// weather + tide auto-fill edge function; until then we frame the
/// shape so users know it's coming.
class ConditionsCorrelationCard extends StatelessWidget {
  const ConditionsCorrelationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.thermostat_outlined, color: AppColors.navy),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Conditions correlation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Coming with auto-fill weather + tide',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                'We\'ll surface things like "your top catches: falling tide '
                '+ 65–72°F water" once weather + tide auto-fill ships.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Chip(
              avatar: Icon(Icons.schedule, size: 14),
              label: Text('Available in M6'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            ),
          ],
        ),
      ),
    );
  }
}
