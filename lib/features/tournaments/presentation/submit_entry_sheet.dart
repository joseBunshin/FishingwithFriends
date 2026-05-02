import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/tournaments/application/submit_entry_controller.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Bottom sheet that lets the angler choose a catch to submit to a
/// tournament. Two entry points (call sites pick the constructor):
///   * pickCatch  — tournament is fixed; pick from owned catches
///   * pickTournament — catch is fixed; pick from active tournaments
class SubmitEntrySheet extends ConsumerWidget {
  const SubmitEntrySheet._({this.tournament, this.lockedCatch});

  final Tournament? tournament;
  final Catch? lockedCatch;

  static Future<void> pickCatch(
    BuildContext context, {
    required Tournament tournament,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SubmitEntrySheet._(tournament: tournament),
    );
  }

  static Future<void> pickTournament(
    BuildContext context, {
    required Catch source,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SubmitEntrySheet._(lockedCatch: source),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tournament != null) {
      return _PickCatchBody(tournament: tournament!);
    }
    return _PickTournamentBody(source: lockedCatch!);
  }
}

class _PickCatchBody extends ConsumerWidget {
  const _PickCatchBody({required this.tournament});

  final Tournament tournament;

  bool _matches(Catch c) {
    return !c.caughtAt.isBefore(tournament.startsAt) &&
        !c.caughtAt.isAfter(tournament.endsAt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCatches = ref.watch(myCatchesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: asyncCatches.when(
          data: (catches) {
            final eligible = catches.where(_matches).toList();
            if (eligible.isEmpty) {
              return _Empty(
                title: 'No matching catches',
                detail:
                    'Log a catch within '
                    '${DateFormat.MMMd().format(tournament.startsAt.toLocal())} '
                    '→ '
                    '${DateFormat.MMMd().format(tournament.endsAt.toLocal())} '
                    'to submit.',
              );
            }
            return _CatchList(
              catches: eligible,
              tournament: tournament,
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const _Empty(title: "Couldn't load catches", detail: ''),
        ),
      ),
    );
  }
}

class _CatchList extends ConsumerWidget {
  const _CatchList({required this.catches, required this.tournament});

  final List<Catch> catches;
  final Tournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(submitEntryControllerProvider).isLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Submit a catch',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          tournament.name,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: catches.length,
            itemBuilder: (_, i) {
              final c = catches[i];
              return _CatchTile(
                catch_: c,
                onTap: busy
                    ? null
                    : () => _submit(context, ref, c),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    Catch source,
  ) async {
    final entry =
        await ref.read(submitEntryControllerProvider.notifier).submit(
              tournament: tournament,
              source: source,
            );
    if (!context.mounted) return;
    if (entry != null) {
      Navigator.of(context).pop();
      // Auto-approved when the submitter is the creator (server-side).
      final approved = entry.status == TournamentEntryStatus.approved;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? "It's on the leaderboard."
                : 'Submitted! The creator will approve.',
          ),
        ),
      );
      return;
    }
    final err = ref.read(submitEntryControllerProvider).error;
    if (err is AppException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    }
  }
}

class _PickTournamentBody extends ConsumerWidget {
  const _PickTournamentBody({required this.source});

  final Catch source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTournaments = ref.watch(myTournamentsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: asyncTournaments.when(
          data: (tournaments) {
            final eligible = tournaments.where((t) {
              final phase = t.phaseAt(DateTime.now());
              if (phase != TournamentPhase.live) return false;
              return !source.caughtAt.isBefore(t.startsAt) &&
                  !source.caughtAt.isAfter(t.endsAt);
            }).toList();
            if (eligible.isEmpty) {
              return const _Empty(
                title: 'No active tournaments fit this catch',
                detail: 'The catch must fall within a live tournament.',
              );
            }
            return _TournamentList(
              tournaments: eligible,
              source: source,
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const _Empty(title: "Couldn't load tournaments", detail: ''),
        ),
      ),
    );
  }
}

class _TournamentList extends ConsumerWidget {
  const _TournamentList({required this.tournaments, required this.source});

  final List<Tournament> tournaments;
  final Catch source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(submitEntryControllerProvider).isLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Submit to tournament',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tournaments.length,
            itemBuilder: (_, i) {
              final t = tournaments[i];
              return Card(
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text(t.metric.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy ? null : () => _submit(context, ref, t),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    Tournament tournament,
  ) async {
    final entry =
        await ref.read(submitEntryControllerProvider.notifier).submit(
              tournament: tournament,
              source: source,
            );
    if (!context.mounted) return;
    if (entry != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submitted to ${tournament.name}.'),
        ),
      );
      return;
    }
    final err = ref.read(submitEntryControllerProvider).error;
    if (err is AppException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    }
  }
}

class _CatchTile extends ConsumerWidget {
  const _CatchTile({required this.catch_, required this.onTap});

  final Catch catch_;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(displayUnitsProvider);
    final weight = formatWeight(catch_.weightKg, units) ?? '—';
    return Card(
      child: ListTile(
        title: Text(catch_.speciesLabel ?? 'Catch'),
        subtitle: Text(
          '$weight · '
          '${DateFormat.MMMd().add_jm().format(catch_.caughtAt.toLocal())}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 36,
            color: AppColors.slate.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
