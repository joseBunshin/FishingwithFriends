import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Per-angler view of one tournament's entries. Reachable from leaderboard
/// rows + member rows — cheaper than a full profile detour when all you
/// want is "what did this angler submit to *this* tournament?"
class AnglerEntriesScreen extends ConsumerWidget {
  const AnglerEntriesScreen({
    required this.tournamentId,
    required this.anglerId,
    super.key,
  });

  final String tournamentId;
  final String anglerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTournament = ref.watch(tournamentByIdProvider(tournamentId));
    final asyncProfile = ref.watch(profileByIdProvider(anglerId));
    final asyncEntries = ref.watch(tournamentEntriesProvider(tournamentId));

    final tournament = asyncTournament.valueOrNull;
    final profile = asyncProfile.valueOrNull;
    final allEntries = asyncEntries.valueOrNull ?? const <TournamentEntry>[];
    final entries = allEntries
        .where((e) => e.anglerId == anglerId)
        .toList(growable: false);

    final scheme = Theme.of(context).colorScheme;
    final displayName = (profile?.displayName?.isNotEmpty ?? false)
        ? profile!.displayName!
        : (profile?.handle ?? 'Angler');
    final handle = profile?.handle ?? '@angler';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Navy hero — same pattern as ProfileScreen but scoped to this
          // tournament context. Surfaces the angler identity + a count of
          // their entries up top.
          Container(
            decoration: const BoxDecoration(color: AppColors.navy),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              MediaQuery.of(context).padding.top + AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AvatarView(avatarPath: profile?.avatarPath, radius: 36),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            handle,
                            style: const TextStyle(
                              color: AppColors.mist,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${entries.length}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entries.length == 1 ? 'ENTRY' : 'ENTRIES',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (tournament != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        size: 14,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          tournament.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Entries list
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'No entries from this angler yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  for (final e in entries) ...[
                    _AnglerEntryCard(entry: e),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AnglerEntryCard extends ConsumerWidget {
  const _AnglerEntryCard({required this.entry});

  final TournamentEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final units = ref.watch(displayUnitsProvider);
    final weight = formatWeight(entry.weightKg, units);
    final length = formatLength(entry.lengthCm, units);

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/catches/${entry.catchId}'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.speciesLabel ?? 'Unknown species',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                  _StatusPill(status: entry.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (weight != null)
                    _MetricChip(label: weight, emphasized: true),
                  if (length != null) _MetricChip(label: length),
                ],
              ),
              if (entry.caughtAt != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Caught ${DateFormat.MMMd().add_jm().format(entry.caughtAt!.toLocal())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = emphasized ? AppColors.navy : scheme.surfaceContainerHighest;
    final fg = emphasized ? AppColors.white : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: emphasized
            ? null
            : Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TournamentEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TournamentEntryStatus.pending => (
          'PENDING',
          AppColors.warning,
        ),
      TournamentEntryStatus.approved => (
          'APPROVED',
          AppColors.success,
        ),
      TournamentEntryStatus.rejected => (
          'REJECTED',
          AppColors.error,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
