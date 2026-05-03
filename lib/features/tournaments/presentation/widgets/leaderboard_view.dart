import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/leaderboard.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Renders a sorted leaderboard for [entries] under [metric].
/// Reused by the main board + each side pot.
class LeaderboardView extends ConsumerWidget {
  const LeaderboardView({
    required this.entries,
    required this.metric,
    required this.tournamentId,
    this.speciesFilter,
    super.key,
  });

  final List<TournamentEntry> entries;
  final TournamentMetric metric;
  final String tournamentId;
  final String? speciesFilter;

  String _formatValue(double v, TournamentMetric m) {
    switch (m) {
      case TournamentMetric.weight:
      case TournamentMetric.biggestFish:
      case TournamentMetric.biggestSingle:
        return '${(v * 2.20462).toStringAsFixed(1)} lbs';
      case TournamentMetric.length:
      case TournamentMetric.longestCatch:
        return '${(v / 2.54).toStringAsFixed(1)}"';
      case TournamentMetric.mostCatches:
        return v.toInt().toString();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = Leaderboard.compute(
      entries: entries,
      metric: metric,
      speciesFilter: speciesFilter,
    );
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'Be the first to submit.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    final bundle = ref.watch(friendsBundleProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          _LeaderboardRowTile(
            rank: i + 1,
            row: rows[i],
            handle: bundle?.profilesById[rows[i].anglerId]?.handle ??
                '@angler',
            value: _formatValue(rows[i].value, metric),
            tournamentId: tournamentId,
          ),
      ],
    );
  }
}

class _LeaderboardRowTile extends StatelessWidget {
  const _LeaderboardRowTile({
    required this.rank,
    required this.row,
    required this.handle,
    required this.value,
    required this.tournamentId,
  });

  final int rank;
  final LeaderboardRow row;
  final String handle;
  final String value;
  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFirst = rank == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: isFirst
            ? AppColors.orange.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Tap an angler row → their tournament-scoped entries view, not
          // their full social profile. Cheaper detour for the "what did
          // they catch *here*?" question that brought you to the row.
          onTap: () => context.push(
            '/tournaments/$tournamentId/anglers/${row.anglerId}',
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: isFirst
                  ? Border.all(color: AppColors.orange.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '#$rank',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isFirst
                              ? AppColors.orangeDeep
                              : scheme.onSurface,
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        handle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (row.entryCount > 1)
                        Text(
                          '${row.entryCount} entries',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color:
                            isFirst ? AppColors.orangeDeep : scheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
