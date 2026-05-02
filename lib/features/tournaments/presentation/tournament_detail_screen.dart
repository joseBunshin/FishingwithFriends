import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_member.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/submit_entry_sheet.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/chat_tab.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/entries_tab.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/leaderboard_view.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/widgets/members_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    final asyncMembers =
        ref.watch(tournamentMembersProvider(tournament.id));
    final entries = asyncEntries.valueOrNull ?? const <TournamentEntry>[];
    final members = asyncMembers.valueOrNull ?? const <TournamentMember>[];
    final acceptedCount = members
        .where((m) => m.status == TournamentMemberStatus.accepted)
        .length;
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
            if (isCreator)
              PopupMenuButton<_CreatorAction>(
                tooltip: 'Tournament options',
                icon: const Icon(Icons.more_vert),
                onSelected: (a) => _handleCreatorAction(context, ref, a),
                itemBuilder: (_) => [
                  if (phase != TournamentPhase.closed)
                    const PopupMenuItem(
                      value: _CreatorAction.end,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.flag_outlined),
                        title: Text('End tournament'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: _CreatorAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Delete tournament',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
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
                icon: const Icon(Icons.add),
                label: const Text('Submit catch'),
                onPressed: () => SubmitEntrySheet.pickCatch(
                  context,
                  tournament: tournament,
                ),
              )
            : null,
        body: TabBarView(
          children: [
            _LeaderboardTab(
              tournament: tournament,
              entries: entries,
              memberCount: acceptedCount,
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

  Future<void> _handleCreatorAction(
    BuildContext context,
    WidgetRef ref,
    _CreatorAction action,
  ) async {
    switch (action) {
      case _CreatorAction.end:
        await _confirmEnd(context, ref, tournament.id);
      case _CreatorAction.delete:
        await _confirmDelete(context, ref, tournament.id);
    }
  }

  Future<void> _confirmEnd(
    BuildContext context,
    WidgetRef ref,
    String tournamentId,
  ) async {
    final ok = await _confirmActionSheet(
      context: context,
      title: 'End tournament?',
      message: 'No new entries can be submitted after this. The leaderboard '
          'freezes at its current state.',
      confirmLabel: 'End tournament',
      destructive: false,
    );
    if (ok ?? false) {
      try {
        await ref
            .read(tournamentsRepositoryProvider)
            .endTournament(tournamentId);
        ref.invalidate(tournamentByIdProvider(tournamentId));
      } on AppException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String tournamentId,
  ) async {
    final ok = await _confirmActionSheet(
      context: context,
      title: 'Delete tournament?',
      message: 'This removes the tournament for everyone. All entries, '
          "members, and chat history will be deleted. This can't be undone.",
      confirmLabel: 'Delete tournament',
      destructive: true,
    );
    if (ok ?? false) {
      try {
        await ref
            .read(tournamentsRepositoryProvider)
            .deleteTournament(tournamentId);
        // Drop both the list AND the by-id cache for this tournament so
        // navigating back to /tourneys re-fetches without showing the
        // ghost row.
        ref
          ..invalidate(myTournamentsProvider)
          ..invalidate(tournamentByIdProvider(tournamentId));
        if (!context.mounted) return;
        context.pop();
      } on AppException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

enum _CreatorAction { end, delete }

/// Reusable confirmation dialog matching the Friends-tab "Remove friend"
/// style: title row with X-icon close (= cancel), message, single
/// full-width confirm CTA.
Future<bool?> _confirmActionSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required bool destructive,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Cancel',
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(ctx, false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(48),
                    )
                  : FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
              child: Text(confirmLabel),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({
    required this.tournament,
    required this.entries,
    required this.memberCount,
  });

  final Tournament tournament;
  final List<TournamentEntry> entries;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _TournamentInfoStrip(
          tournament: tournament,
          memberCount: memberCount,
          entryCount: entries.length,
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('Leaderboard'),
        const SizedBox(height: AppSpacing.md),
        LeaderboardView(
          entries: entries,
          metric: tournament.metric,
          tournamentId: tournament.id,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Compact tournament parameters strip used at the top of the
/// leaderboard tab. Replaces the bare phase banner + the side-pots
/// bubble with one bordered tile containing: phase pill + countdown,
/// metric, date range, member + entry counts.
class _TournamentInfoStrip extends StatelessWidget {
  const _TournamentInfoStrip({
    required this.tournament,
    required this.memberCount,
    required this.entryCount,
  });

  final Tournament tournament;
  final int memberCount;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phase = tournament.phaseAt(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PhasePill(phase: phase),
              const Spacer(),
              if (phase == TournamentPhase.live)
                _Countdown(
                  prefix: 'Ends in',
                  target: tournament.endsAt,
                )
              else if (phase == TournamentPhase.registration)
                _Countdown(
                  prefix: 'Starts in',
                  target: tournament.startsAt,
                )
              else
                Text(
                  'Ended ${DateFormat.MMMd().format(tournament.endsAt.toLocal())}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
          if (tournament.description != null &&
              tournament.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              tournament.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _InfoChip(
                icon: Icons.emoji_events_outlined,
                label: tournament.metric.label,
              ),
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                label:
                    '${DateFormat.MMMd().format(tournament.startsAt.toLocal())}'
                    ' → '
                    '${DateFormat.MMMd().format(tournament.endsAt.toLocal())}',
              ),
              _InfoChip(
                icon: Icons.people_outline,
                label: '$memberCount '
                    '${memberCount == 1 ? 'angler' : 'anglers'}',
              ),
              _InfoChip(
                icon: Icons.set_meal_outlined,
                label: '$entryCount '
                    '${entryCount == 1 ? 'entry' : 'entries'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.phase});

  final TournamentPhase phase;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (phase) {
      TournamentPhase.live => (
          'LIVE',
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
        ),
      TournamentPhase.registration => (
          'OPEN',
          AppColors.navy.withValues(alpha: 0.10),
          AppColors.navy,
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
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.navy),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

/// Self-updating "Ends in 4d 12h" / "Starts in 36m" copy. Ticks every
/// 30s — same pattern used by TournamentCard's countdown.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.target, required this.prefix});

  final DateTime target;
  final String prefix;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
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
    final scheme = Theme.of(context).colorScheme;
    final remaining = widget.target.difference(DateTime.now());
    return Text(
      '${widget.prefix} ${_formatRemaining(remaining)}',
      style: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
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
