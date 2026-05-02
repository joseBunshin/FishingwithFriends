import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/stats/application/species_breakdown_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SpeciesBreakdownCard extends ConsumerWidget {
  const SpeciesBreakdownCard({super.key});

  static const _palette = <Color>[
    AppColors.navy,
    AppColors.orange,
    AppColors.success,
    AppColors.navySoft,
    AppColors.warning,
    AppColors.slate,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSlices = ref.watch(speciesBreakdownProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.donut_large_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Species breakdown',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your catch composition',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            asyncSlices.when(
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
  const _Body(this.slices);

  final List<SpeciesSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const _Empty();
    final total = slices.fold<int>(0, (a, b) => a + b.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 16,
          child: Row(
            children: [
              for (var i = 0; i < slices.length; i++)
                Flexible(
                  flex: slices[i].count,
                  child: Container(
                    color: SpeciesBreakdownCard
                        ._palette[i % SpeciesBreakdownCard._palette.length],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: SpeciesBreakdownCard._palette[
                        i % SpeciesBreakdownCard._palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    slices[i].label,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${slices[i].count} · ${((slices[i].count / total) * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _Error extends StatelessWidget {
  const _Error();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: Center(
          child: Text(
            "Couldn't load species",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: Center(
          child: Text(
            'Log catches to see your species breakdown',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
}
