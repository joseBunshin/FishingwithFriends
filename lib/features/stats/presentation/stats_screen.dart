import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/stats/presentation/widgets/catches_over_time_card.dart';
import 'package:fishing_with_friends/features/stats/presentation/widgets/conditions_correlation_card.dart';
import 'package:fishing_with_friends/features/stats/presentation/widgets/hour_heatmap_card.dart';
import 'package:fishing_with_friends/features/stats/presentation/widgets/species_breakdown_card.dart';
import 'package:fishing_with_friends/features/stats/presentation/widgets/vs_friends_card.dart';
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
          SpeciesBreakdownCard(),
          SizedBox(height: AppSpacing.md),
          CatchesOverTimeCard(),
          SizedBox(height: AppSpacing.md),
          HourHeatmapCard(),
          SizedBox(height: AppSpacing.md),
          VsFriendsCard(),
          SizedBox(height: AppSpacing.md),
          ConditionsCorrelationCard(),
        ],
      ),
    );
  }
}
