import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/create_tournament_sheet.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/join_by_code_sheet.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/tournament_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTournaments = ref.watch(myTournamentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.password),
            tooltip: 'Enter join code',
            onPressed: () => JoinByCodeSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New tournament',
            onPressed: () => CreateTournamentSheet.show(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTournamentsProvider),
        child: asyncTournaments.when(
          data: (tournaments) => tournaments.isEmpty
              ? const _EmptyState()
              : _PartitionedList(tournaments: tournaments),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ErrorState(),
        ),
      ),
    );
  }
}

class _PartitionedList extends StatelessWidget {
  const _PartitionedList({required this.tournaments});

  final List<Tournament> tournaments;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final live = <Tournament>[];
    final registration = <Tournament>[];
    final closed = <Tournament>[];
    for (final t in tournaments) {
      switch (t.phaseAt(now)) {
        case TournamentPhase.live:
          live.add(t);
        case TournamentPhase.registration:
          registration.add(t);
        case TournamentPhase.closed:
          closed.add(t);
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _JoinByCodeCard(),
        const SizedBox(height: AppSpacing.lg),
        if (live.isNotEmpty) ...[
          SectionLabel('Live now', trailing: '${live.length}'),
          const SizedBox(height: AppSpacing.md),
          for (final t in live) ...[
            TournamentCard(tournament: t),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
        if (registration.isNotEmpty) ...[
          if (live.isNotEmpty) const SizedBox(height: AppSpacing.md),
          SectionLabel('Open for entry', trailing: '${registration.length}'),
          const SizedBox(height: AppSpacing.md),
          for (final t in registration) ...[
            TournamentCard(tournament: t),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
        if (closed.isNotEmpty) ...[
          if (live.isNotEmpty || registration.isNotEmpty)
            const SizedBox(height: AppSpacing.md),
          SectionLabel('Past', trailing: '${closed.length}'),
          const SizedBox(height: AppSpacing.md),
          for (final t in closed) ...[
            TournamentCard(tournament: t),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No tournaments yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Start one — invite friends or share a join code.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => CreateTournamentSheet.show(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create a tournament'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => JoinByCodeSheet.show(context),
                  icon: const Icon(Icons.password),
                  label: const Text('Have a join code?'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JoinByCodeCard extends StatelessWidget {
  const _JoinByCodeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => JoinByCodeSheet.show(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.password,
                  color: AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have a join code?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter the 8-character code to request a spot.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: const [
        SizedBox(height: AppSpacing.xxxl),
        Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text("Couldn't load your tournaments. Pull to retry."),
            ),
          ),
        ),
      ],
    );
  }
}
