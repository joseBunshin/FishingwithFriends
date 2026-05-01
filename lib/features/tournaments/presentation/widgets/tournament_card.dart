import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TournamentCard extends StatelessWidget {
  const TournamentCard({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final phase = tournament.phaseAt(DateTime.now());
    return Card(
      child: InkWell(
        onTap: () => context.push('/tournaments/${tournament.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tournament.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  _PhasePill(phase: phase),
                ],
              ),
              if (tournament.description != null &&
                  tournament.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tournament.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${DateFormat.MMMd().format(tournament.startsAt.toLocal())}'
                    ' → '
                    '${DateFormat.MMMd().format(tournament.endsAt.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(Icons.emoji_events_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    tournament.metric.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.phase});

  final TournamentPhase phase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (phase) {
      TournamentPhase.live => (
          'LIVE',
          AppColors.orange.withValues(alpha: 0.15),
          AppColors.orangeDeep,
        ),
      TournamentPhase.registration => (
          'OPEN',
          scheme.primary.withValues(alpha: 0.10),
          scheme.primary,
        ),
      TournamentPhase.closed => (
          'CLOSED',
          AppColors.mist.withValues(alpha: 0.6),
          AppColors.slate,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
