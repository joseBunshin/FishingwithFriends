import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/stats/application/stats_time_of_day_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 24-cell strip showing own catch counts per local hour-of-day.
/// Cells colored navy with alpha proportional to count / max.
class HourHeatmapCard extends ConsumerWidget {
  const HourHeatmapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBuckets = ref.watch(statsTimeOfDayProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.navy),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Time of day',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'When you catch the most',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            asyncBuckets.when(
              loading: () => const _Loading(),
              error: (_, __) => const _Error(),
              data: _HourStrip.new,
            ),
          ],
        ),
      ),
    );
  }
}

class _HourStrip extends StatelessWidget {
  const _HourStrip(this.buckets);

  final List<int> buckets;

  @override
  Widget build(BuildContext context) {
    final max = buckets.fold<int>(0, (a, b) => a > b ? a : b);
    if (max == 0) return const _Empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < 24; i++)
                Expanded(
                  child: _HourCell(count: buckets[i], maxCount: max),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const _TickLabels(),
      ],
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({required this.count, required this.maxCount});

  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;
    final alpha = count == 0 ? 0.05 : 0.2 + 0.7 * ratio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm / 2),
          border: count == 0
              ? Border.all(color: AppColors.mist, width: 0.5)
              : null,
        ),
      ),
    );
  }
}

class _TickLabels extends StatelessWidget {
  const _TickLabels();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('12a', style: style),
        Text('6a', style: style),
        Text('12p', style: style),
        Text('6p', style: style),
        Text('12a', style: style),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: Text(
          "Couldn't load hours",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: Text(
          'Log catches to see your hours',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
