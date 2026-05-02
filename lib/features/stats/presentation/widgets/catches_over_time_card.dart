import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/stats/application/catches_over_time_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CatchesOverTimeCard extends ConsumerWidget {
  const CatchesOverTimeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBuckets = ref.watch(catchesOverTimeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Catches over time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Last 12 weeks',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            asyncBuckets.when(
              loading: () => const _Loading(),
              error: (_, __) => const _Error(),
              data: _Body.new,
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.buckets);
  final List<WeekBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final max = buckets.fold<int>(0, (a, b) => a > b.count ? a : b.count);
    if (max == 0) return const _Empty();

    final dateFmt = DateFormat.MMMd();
    final firstLabel = dateFmt.format(buckets.first.weekStart);
    final lastLabel = dateFmt.format(buckets.last.weekStart);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in buckets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: _Bar(count: b.count, max: max),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(firstLabel,
                style: Theme.of(context).textTheme.labelSmall),
            Text(lastLabel,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.count, required this.max});
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : count / max;
    return LayoutBuilder(
      builder: (_, c) => Stack(
        children: [
          Container(
            height: c.maxHeight,
            decoration: BoxDecoration(
              color: AppColors.mist.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm / 2),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: c.maxHeight * ratio,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSm / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _Error extends StatelessWidget {
  const _Error();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 96,
        child: Center(
          child: Text("Couldn't load activity",
              style: Theme.of(context).textTheme.bodySmall),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 96,
        child: Center(
          child: Text('Log catches to see your weekly activity',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      );
}
