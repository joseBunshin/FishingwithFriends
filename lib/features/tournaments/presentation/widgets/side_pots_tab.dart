import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/leaderboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SidePotsTab extends ConsumerWidget {
  const SidePotsTab({
    required this.tournamentId,
    required this.entries,
    super.key,
  });

  final String tournamentId;
  final List<TournamentEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPots =
        ref.watch(tournamentSidePotsProvider(tournamentId));
    return asyncPots.when(
      data: (pots) {
        if (pots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'No side pots configured.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final pot in pots) ...[
              Text(
                pot.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                pot.metric.label +
                    (pot.speciesFilter == null
                        ? ''
                        : ' · ${pot.speciesFilter}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              LeaderboardView(
                entries: entries,
                metric: pot.metric,
                tournamentId: tournamentId,
                speciesFilter: pot.speciesFilter,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text("Couldn't load side pots.")),
    );
  }
}
