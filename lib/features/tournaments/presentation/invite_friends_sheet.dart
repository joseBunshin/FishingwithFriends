import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet that lets a tournament creator pick from their accepted
/// friends and invite them to the tournament. Invitees already in the
/// tournament are filtered out so the list only shows valid targets.
///
/// On submit, calls TournamentsRepository.inviteMembers — pending member
/// rows land in the DB, the 0006 invite-notification trigger fires, and
/// each invitee gets a `tournament_invite` push.
class InviteFriendsSheet extends ConsumerStatefulWidget {
  const InviteFriendsSheet({
    required this.tournamentId,
    required this.alreadyInvitedIds,
    super.key,
  });

  final String tournamentId;

  /// User ids that are already members (or pending). Hidden from the
  /// pick list to prevent dupe invites.
  final Set<String> alreadyInvitedIds;

  static Future<int?> show(
    BuildContext context, {
    required String tournamentId,
    required Set<String> alreadyInvitedIds,
  }) {
    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InviteFriendsSheet(
        tournamentId: tournamentId,
        alreadyInvitedIds: alreadyInvitedIds,
      ),
    );
  }

  @override
  ConsumerState<InviteFriendsSheet> createState() =>
      _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<InviteFriendsSheet> {
  final Set<String> _selected = {};
  bool _busy = false;

  Future<void> _submit() async {
    if (_selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final invited = await ref.read(tournamentsRepositoryProvider).inviteMembers(
            tournamentId: widget.tournamentId,
            anglerIds: _selected.toList(growable: false),
          );
      if (!mounted) return;
      Navigator.of(context).pop(invited);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final bundle = ref.watch(friendsBundleProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    final candidates = bundle == null
        ? const <Profile>[]
        : bundle
            .acceptedFriendIds(user?.id ?? '')
            .where((id) => !widget.alreadyInvitedIds.contains(id))
            .map((id) => bundle.profilesById[id])
            .whereType<Profile>()
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Invite friends',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Pick friends to invite. They will see this tournament '
                'under their notifications and join with one tap.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (candidates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Center(
                    child: Text(
                      bundle == null
                          ? 'Loading friends…'
                          : "No friends left to invite — they're all in already.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (_, i) {
                      final p = candidates[i];
                      final selected = _selected.contains(p.id);
                      final hasName =
                          p.displayName != null && p.displayName!.isNotEmpty;
                      return Material(
                        color: selected
                            ? AppColors.navy.withValues(alpha: 0.06)
                            : scheme.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setState(() {
                            if (selected) {
                              _selected.remove(p.id);
                            } else {
                              _selected.add(p.id);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected
                                    ? AppColors.navy
                                    : scheme.outlineVariant,
                                width: selected ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                            child: Row(
                              children: [
                                AvatarView(
                                  avatarPath: p.avatarPath,
                                  radius: 18,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasName
                                            ? p.displayName!
                                            : p.handle,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      if (hasName)
                                        Text(
                                          p.handle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.navy
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.navy
                                          : scheme.outlineVariant,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: selected
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: AppColors.white,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _selected.isEmpty || _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _selected.isEmpty
                      ? 'Pick at least one friend'
                      : _busy
                          ? 'Inviting…'
                          : 'Invite ${_selected.length} '
                              "${_selected.length == 1 ? 'angler' : 'anglers'}",
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
