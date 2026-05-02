import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/tournaments/application/tournament_entry_controller.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EntriesTab extends ConsumerWidget {
  const EntriesTab({
    required this.entries,
    required this.tournamentId,
    required this.isCreator,
    super.key,
  });

  final List<TournamentEntry> entries;
  final String tournamentId;
  final bool isCreator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No entries yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    final pending = entries
        .where((e) => e.status == TournamentEntryStatus.pending)
        .toList();
    final resolved = entries
        .where((e) => e.status != TournamentEntryStatus.pending)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (pending.isNotEmpty) ...[
          SectionLabel('Pending', trailing: '${pending.length}'),
          const SizedBox(height: AppSpacing.md),
          for (final e in pending) ...[
            _EntryRow(
              entry: e,
              tournamentId: tournamentId,
              isCreator: isCreator,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
        SectionLabel(
          'Submitted',
          trailing: resolved.isEmpty ? null : '${resolved.length}',
        ),
        const SizedBox(height: AppSpacing.md),
        if (resolved.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'No approved or rejected entries yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final e in resolved) ...[
            _EntryRow(
              entry: e,
              tournamentId: tournamentId,
              isCreator: isCreator,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.tournamentId,
    required this.isCreator,
  });

  final TournamentEntry entry;
  final String tournamentId;
  final bool isCreator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(friendsBundleProvider).valueOrNull;
    final handle =
        bundle?.profilesById[entry.anglerId]?.handle ?? '@angler';
    final controller =
        ref.read(tournamentEntryControllerProvider.notifier);
    final busy =
        ref.watch(tournamentEntryControllerProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;

    final units = ref.watch(displayUnitsProvider);
    final weight = formatWeight(entry.weightKg, units) ?? '—';
    final length = formatLength(entry.lengthCm, units) ?? '—';

    final canApprove =
        isCreator && entry.status == TournamentEntryStatus.pending;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/tournaments/$tournamentId/anglers/${entry.anglerId}',
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
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
                      handle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  _StatusPill(status: entry.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (entry.speciesLabel != null) entry.speciesLabel!,
                  weight,
                  length,
                ].join(' · '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (entry.caughtAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    'caught ${DateFormat.MMMd().add_jm().format(entry.caughtAt!.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ),
              if (canApprove) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => controller.reject(
                                entryId: entry.id,
                                tournamentId: tournamentId,
                              ),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => controller.approve(
                                entryId: entry.id,
                                tournamentId: tournamentId,
                              ),
                      child: const Text('Approve'),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TournamentEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TournamentEntryStatus.pending => ('PENDING', AppColors.warning),
      TournamentEntryStatus.approved => ('APPROVED', AppColors.success),
      TournamentEntryStatus.rejected => ('REJECTED', AppColors.error),
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
