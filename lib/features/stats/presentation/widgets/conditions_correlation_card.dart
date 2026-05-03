import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/stats/application/conditions_correlation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lights up with real correlations once the user has 10+ catches with
/// non-empty conditions (M6 auto-fill running). Otherwise stays in
/// placeholder mode.
class ConditionsCorrelationCard extends ConsumerWidget {
  const ConditionsCorrelationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCorrelations = ref.watch(conditionsCorrelationProvider);
    final correlations = asyncCorrelations.valueOrNull ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.thermostat_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Conditions correlation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              correlations.isEmpty
                  ? 'Coming with auto-fill weather + tide'
                  : 'Your top catches by species',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (correlations.isEmpty)
              const _Placeholder()
            else
              _Body(correlations: correlations),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.correlations});
  final List<ConditionsCorrelation> correlations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in correlations.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${c.species} — ${c.headline}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Text(
            'We\'ll surface things like "your top largemouth: '
            'falling tide + 18–22°C water" once you have 10+ catches '
            'with auto-filled conditions.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Chip(
          avatar: Icon(Icons.schedule, size: 14),
          label: Text('Need 10+ catches with conditions'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
      ],
    );
  }
}
