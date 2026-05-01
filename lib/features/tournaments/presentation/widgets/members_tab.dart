import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/application/tournament_member_controller.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MembersTab extends ConsumerWidget {
  const MembersTab({
    required this.tournament,
    required this.isCreator,
    super.key,
  });

  final Tournament tournament;
  final bool isCreator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMembers =
        ref.watch(tournamentMembersProvider(tournament.id));
    return asyncMembers.when(
      data: (members) {
        final pending = members
            .where((m) => m.status == TournamentMemberStatus.pending)
            .toList();
        final accepted = members
            .where((m) => m.status == TournamentMemberStatus.accepted)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (isCreator) _JoinCodeCard(joinCode: tournament.joinCode),
            if (isCreator) const SizedBox(height: AppSpacing.lg),
            if (pending.isNotEmpty) ...[
              Text(
                'Pending (${pending.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final m in pending)
                _MemberRow(
                  member: m,
                  isCreator: isCreator,
                  tournamentId: tournament.id,
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              'Accepted (${accepted.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (accepted.isEmpty)
              const _Empty('No accepted members yet.')
            else
              for (final m in accepted)
                _MemberRow(
                  member: m,
                  isCreator: isCreator,
                  tournamentId: tournament.id,
                ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Empty("Couldn't load members."),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.joinCode});

  final String joinCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Code',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    joinCode.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: AppColors.orange,
                        ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: joinCode));
              },
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.member,
    required this.isCreator,
    required this.tournamentId,
  });

  final TournamentMember member;
  final bool isCreator;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(friendsBundleProvider).valueOrNull;
    final handle =
        bundle?.profilesById[member.anglerId]?.handle ?? '@angler';
    final controller = ref.read(tournamentMemberControllerProvider.notifier);
    final busy =
        ref.watch(tournamentMemberControllerProvider).isLoading;
    final canApprove =
        isCreator && member.status == TournamentMemberStatus.pending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const _AvatarPlaceholder(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                handle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (canApprove) ...[
              TextButton(
                onPressed: busy
                    ? null
                    : () => controller.reject(
                          tournamentId: tournamentId,
                          anglerId: member.anglerId,
                        ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => controller.approve(
                          tournamentId: tournamentId,
                          anglerId: member.anglerId,
                        ),
                child: const Text('Accept'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 16,
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
      child: Icon(Icons.person, size: 18, color: scheme.primary),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
