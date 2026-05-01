import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/home/data/home_metrics_provider.dart';
import 'package:fishing_with_friends/features/home/domain/home_metrics.dart';
import 'package:fishing_with_friends/features/home/presentation/widgets/action_chips.dart';
import 'package:fishing_with_friends/features/home/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMetrics = ref.watch(homeMetricsProvider);
    final metrics = asyncMetrics.valueOrNull ?? const HomeMetrics.empty();

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(homeMetricsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const HomeActionChips(),
            const SizedBox(height: AppSpacing.lg),
            _StatGrid(metrics: metrics),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Recent Catches',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (asyncMetrics.isLoading && asyncMetrics.value == null)
              const _LoadingRecentCatches()
            else if (asyncMetrics.hasError)
              const _RecentCatchesError()
            else if (metrics.isEmpty)
              const _EmptyRecentCatches()
            else
              const _RecentCatchesPlaceholder(),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.metrics});

  final HomeMetrics metrics;

  String get _totalWeightDisplay {
    final lbs = metrics.totalWeightKg * 2.20462;
    return '${lbs.toStringAsFixed(1)} lbs';
  }

  String? get _biggestSubtitle => metrics.biggestSpecies;

  String get _biggestValue {
    final kg = metrics.biggestWeightKg;
    if (kg == null) return '—';
    final lbs = kg * 2.20462;
    return '${lbs.toStringAsFixed(0)} lbs';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Total Catches',
                value: '${metrics.totalCatches}',
                icon: Icons.set_meal_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Total Weight',
                value: _totalWeightDisplay,
                icon: Icons.scale_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Species',
                value: '${metrics.uniqueSpecies}',
                icon: Icons.water_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Biggest',
                value: _biggestValue,
                caption: _biggestSubtitle,
                icon: Icons.workspace_premium_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyRecentCatches extends StatelessWidget {
  const _EmptyRecentCatches();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.set_meal_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No catches yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Log your first catch to start your story.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.logCatch),
              icon: const Icon(Icons.add),
              label: const Text('Log your first catch'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCatchesPlaceholder extends StatelessWidget {
  const _RecentCatchesPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Real recent-catch cards land in M1/U6 (CatchCard) — until then this
    // placeholder card holds the layout while the data is non-empty.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ColoredBox(
              color: AppColors.mist.withValues(alpha: 0.5),
              child: const Center(
                child: Text('Tap Catches tab to see your full list'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your most recent catch is logged',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Photo previews join the feed in a coming milestone.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingRecentCatches extends StatelessWidget {
  const _LoadingRecentCatches();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentCatchesError extends ConsumerWidget {
  const _RecentCatchesError();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "Couldn't load your catches.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(homeMetricsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
