import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/chat_tab.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/entries_tab.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/leaderboard_view.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/members_tab.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/side_pots_tab.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/tournament_phase_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({required this.tournamentId, super.key});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTournament = ref.watch(tournamentByIdProvider(tournamentId));
    return asyncTournament.when(
      data: (t) => t == null
          ? const _NotFound()
          : _Body(tournament: t),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _NotFound(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final asyncEntries =
        ref.watch(tournamentEntriesProvider(tournament.id));
    final entries = asyncEntries.valueOrNull ?? const [];
    final isCreator = user?.id == tournament.creatorId;
    final phase = tournament.phaseAt(DateTime.now());

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(tournament.name),
          actions: [
            if (isCreator && phase != TournamentPhase.closed)
              IconButton(
                tooltip: 'End tournament',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => _confirmEnd(context, ref, tournament.id),
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Leaderboard'),
              Tab(text: 'Members'),
              Tab(text: 'Entries'),
              Tab(text: 'Chat'),
            ],
          ),
        ),
        floatingActionButton: phase == TournamentPhase.live
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.white,
                icon: const Icon(Icons.add),
                label: const Text('Submit catch'),
                onPressed: () {
                  // M3/U8 mounts the submit sheet here.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Submit flow lands in M3/U8 — check the catch detail screen for now.',
                      ),
                    ),
                  );
                },
              )
            : null,
        body: TabBarView(
          children: [
            _LeaderboardTab(
              tournament: tournament,
              entries: entries,
            ),
            MembersTab(tournament: tournament, isCreator: isCreator),
            EntriesTab(
              entries: entries,
              tournamentId: tournament.id,
              isCreator: isCreator,
            ),
            ChatTab(tournamentId: tournament.id),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEnd(
    BuildContext context,
    WidgetRef ref,
    String tournamentId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End tournament?'),
        content: const Text(
          'No new entries can be submitted after this. The leaderboard '
          'freezes at its current state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref
          .read(tournamentsRepositoryProvider)
          .endTournament(tournamentId);
      ref.invalidate(tournamentByIdProvider(tournamentId));
    }
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({
    required this.tournament,
    required this.entries,
  });

  final Tournament tournament;
  final List<TournamentEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        TournamentPhaseBanner(tournament: tournament),
        const SizedBox(height: AppSpacing.lg),
        LeaderboardView(
          entries: entries,
          metric: tournament.metric,
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Side pots',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Configured under the Side Pots tab.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 320,
          child: SidePotsTab(
            tournamentId: tournament.id,
            entries: entries,
          ),
        ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                "This tournament isn't available.",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
