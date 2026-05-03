import 'dart:async';

import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Phase-aware tournament card. LIVE tournaments get a navy-fill hero
/// treatment with a pulsing LIVE badge + countdown to end, OPEN gets a
/// surface-tinted "Starts in" card, CLOSED is a compact muted summary.
class TournamentCard extends StatelessWidget {
  const TournamentCard({required this.tournament, super.key});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final phase = tournament.phaseAt(DateTime.now());
    return switch (phase) {
      TournamentPhase.live => _LiveHeroCard(tournament: tournament),
      TournamentPhase.registration => _OpenCard(tournament: tournament),
      TournamentPhase.closed => _ClosedCard(tournament: tournament),
    };
  }
}

// ---------------------------------------------------------------------------
// LIVE — navy hero with countdown + pulsing badge
// ---------------------------------------------------------------------------
class _LiveHeroCard extends StatelessWidget {
  const _LiveHeroCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: AppColors.navy.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => context.push('/tournaments/${tournament.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _LiveBadge(),
                  const Spacer(),
                  _CountdownText(target: tournament.endsAt, prefix: 'Ends in'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                tournament.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                  letterSpacing: -0.8,
                  height: 1.05,
                ),
              ),
              if (tournament.description != null &&
                  tournament.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tournament.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mist.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _MetaChip(
                    icon: Icons.emoji_events_outlined,
                    label: tournament.metric.label,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    label:
                        '${DateFormat.MMMd().format(tournament.startsAt.toLocal())}'
                        ' → '
                        '${DateFormat.MMMd().format(tournament.endsAt.toLocal())}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View leaderboard',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: AppColors.white,
                          ),
                        ],
                      ),
                    ),
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

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctl,
            builder: (_, __) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.6 + 0.4 * _ctl.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.5 * _ctl.value),
                      blurRadius: 6 + 4 * _ctl.value,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.error,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.orange),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Self-updating "Ends in 4d 12h" / "Starts in 36m" text. Ticks every
/// 30 seconds — fast enough to look alive, cheap enough to leave running.
class _CountdownText extends StatefulWidget {
  const _CountdownText({
    required this.target,
    required this.prefix,
    this.color,
  });

  final DateTime target;
  final String prefix;
  final Color? color;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration d) {
    if (d.isNegative) return 'now';
    if (d.inDays >= 1) {
      final hrs = d.inHours - d.inDays * 24;
      return '${d.inDays}d ${hrs}h';
    }
    if (d.inHours >= 1) {
      final mins = d.inMinutes - d.inHours * 60;
      return '${d.inHours}h ${mins}m';
    }
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '<1m';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.target.difference(DateTime.now());
    return Text(
      '${widget.prefix} ${_formatRemaining(remaining)}',
      style: TextStyle(
        color: widget.color ?? AppColors.white.withValues(alpha: 0.85),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OPEN — surface-tinted "Starts in" card
// ---------------------------------------------------------------------------
class _OpenCard extends StatelessWidget {
  const _OpenCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/tournaments/${tournament.id}'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Text(
                      'OPEN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _CountdownText(
                    target: tournament.startsAt,
                    prefix: 'Starts in',
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                tournament.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
              ),
              if (tournament.description != null &&
                  tournament.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  tournament.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    tournament.metric.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${DateFormat.MMMd().format(tournament.startsAt.toLocal())}'
                    ' → '
                    '${DateFormat.MMMd().format(tournament.endsAt.toLocal())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
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

// ---------------------------------------------------------------------------
// CLOSED — compact muted summary
// ---------------------------------------------------------------------------
class _ClosedCard extends StatelessWidget {
  const _ClosedCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/tournaments/${tournament.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ended ${DateFormat.MMMd().format(tournament.endsAt.toLocal())} · '
                      '${tournament.metric.label}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
