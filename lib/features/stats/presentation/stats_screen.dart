import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/stats/presentation/widgets/hour_heatmap_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          _StatsPlaceholderCard(
            title: 'Species Breakdown',
            subtitle: 'Your catch composition',
            icon: Icons.donut_large_outlined,
          ),
          SizedBox(height: AppSpacing.md),
          _StatsPlaceholderCard(
            title: 'Catches Over Time',
            subtitle: 'Activity by week',
            icon: Icons.bar_chart_outlined,
          ),
          SizedBox(height: AppSpacing.md),
          HourHeatmapCard(),
        ],
      ),
    );
  }
}

class _StatsPlaceholderCard extends StatelessWidget {
  const _StatsPlaceholderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

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
                Icon(icon, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              alignment: Alignment.center,
              child: Text(
                'Charts arrive in M4',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
