import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TournamentPhaseBanner extends StatelessWidget {
  const TournamentPhaseBanner({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final phase = tournament.phaseAt(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final (label, copy, bg, fg, icon) = switch (phase) {
      TournamentPhase.live => (
          'LIVE',
          'Submit catches and watch the leaderboard.',
          AppColors.orange.withValues(alpha: 0.12),
          AppColors.orangeDeep,
          Icons.bolt,
        ),
      TournamentPhase.registration => (
          'OPEN FOR REGISTRATION',
          'Starts ${DateFormat.yMd().add_jm().format(tournament.startsAt.toLocal())}',
          scheme.primary.withValues(alpha: 0.08),
          scheme.primary,
          Icons.event_outlined,
        ),
      TournamentPhase.closed => (
          'CLOSED',
          tournament.endsAt.isBefore(DateTime.now())
              ? 'Ended ${DateFormat.yMd().format(tournament.endsAt.toLocal())}'
              : 'Closed by creator',
          AppColors.mist.withValues(alpha: 0.5),
          AppColors.slate,
          Icons.flag_outlined,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  copy,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
