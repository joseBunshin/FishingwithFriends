import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:fishing_with_friends/features/tournaments/application/tournament_member_controller.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_member.dart';
import 'package:fishing_with_friends/features/tournaments/presentation/invite_friends_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        final allMemberIds = {for (final m in members) m.anglerId};
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (isCreator) ...[
              _InviteHeader(
                tournament: tournament,
                alreadyInvitedIds: allMemberIds,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (pending.isNotEmpty) ...[
              SectionLabel('Pending', trailing: '${pending.length}'),
              const SizedBox(height: AppSpacing.md),
              for (final m in pending) ...[
                _MemberRow(
                  member: m,
                  isCreator: isCreator,
                  tournamentId: tournament.id,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
            SectionLabel(
              'Accepted',
              trailing: accepted.isEmpty ? null : '${accepted.length}',
            ),
            const SizedBox(height: AppSpacing.md),
            if (accepted.isEmpty)
              const _Empty('No accepted members yet.')
            else
              for (final m in accepted) ...[
                _MemberRow(
                  member: m,
                  isCreator: isCreator,
                  tournamentId: tournament.id,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Empty("Couldn't load members."),
    );
  }
}

/// Two ways to add anglers to a tournament — direct friend invite + the
/// shareable join code. Stacked under the "Members" tab for the creator
/// so the path from "tournament exists" to "people are in it" is one tap.
class _InviteHeader extends ConsumerWidget {
  const _InviteHeader({
    required this.tournament,
    required this.alreadyInvitedIds,
  });

  final Tournament tournament;
  final Set<String> alreadyInvitedIds;

  Future<void> _openInvite(BuildContext context, WidgetRef ref) async {
    final invitedCount = await InviteFriendsSheet.show(
      context,
      tournamentId: tournament.id,
      alreadyInvitedIds: alreadyInvitedIds,
    );
    if (invitedCount != null && invitedCount > 0) {
      ref.invalidate(tournamentMembersProvider(tournament.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            invitedCount == 1
                ? 'Invited 1 angler.'
                : 'Invited $invitedCount anglers.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => _openInvite(context, ref),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Invite friends'),
        ),
        const SizedBox(height: AppSpacing.md),
        _JoinCodeCard(joinCode: tournament.joinCode),
      ],
    );
  }
}

/// Navy hero with the 8-char join code in tracked white type. Tap a
/// dedicated copy button on the right to put it on the clipboard.
class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.joinCode});

  final String joinCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OR SHARE THIS CODE',
                  style: TextStyle(
                    color: AppColors.mist.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  joinCode.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'For non-friends — they enter it from the Tournaments tab.',
                  style: TextStyle(
                    color: AppColors.mist.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy join code',
            icon: const Icon(Icons.content_copy, color: AppColors.orange),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: joinCode));
            },
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final bundle = ref.watch(friendsBundleProvider).valueOrNull;
    final profile = bundle?.profilesById[member.anglerId];
    final hasDisplayName = profile?.displayName?.isNotEmpty ?? false;
    final primary = hasDisplayName
        ? profile!.displayName!
        : profile?.handle ?? '@angler';
    final secondary = hasDisplayName ? profile!.handle : null;
    final controller = ref.read(tournamentMemberControllerProvider.notifier);
    final busy =
        ref.watch(tournamentMemberControllerProvider).isLoading;
    final canApprove =
        isCreator && member.status == TournamentMemberStatus.pending;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tap a member → their tournament-scoped entries view, not their
        // full profile. The user wants a quick "what'd they submit?" peek.
        onTap: () => context.push(
          '/tournaments/$tournamentId/anglers/${member.anglerId}',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              AvatarView(avatarPath: profile?.avatarPath, radius: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondary,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canApprove) ...[
                IconButton(
                  tooltip: 'Reject',
                  visualDensity: VisualDensity.compact,
                  onPressed: busy
                      ? null
                      : () => controller.reject(
                            tournamentId: tournamentId,
                            anglerId: member.anglerId,
                          ),
                  icon: const Icon(Icons.close, size: 20),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => controller.approve(
                            tournamentId: tournamentId,
                            anglerId: member.anglerId,
                          ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ],
          ),
        ),
      ),
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
