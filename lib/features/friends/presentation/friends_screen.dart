import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/widgets/section_label.dart';
import 'package:fishing_with_friends/features/friends/application/friend_search_controller.dart';
import 'package:fishing_with_friends/features/friends/application/friends_controller.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/friends/domain/friendship.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:fishing_with_friends/features/profile/data/my_profile_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(friendsControllerProvider, (_, next) {
      final err = next.error;
      if (err is AppException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      }
    });

    final bundleAsync = ref.watch(friendsBundleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(friendsBundleProvider),
        child: bundleAsync.when(
          data: (bundle) => _Body(bundle: bundle),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ErrorState(),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.bundle});

  final FriendsBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Prefer the authoritative profile.handle so edits made via the
    // Edit Profile screen reflect here. Fall back to the email-local-part
    // only while the profile is still loading or absent (first-launch
    // edge cases) so the card never renders empty.
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final emailFallback = user?.email?.split('@').first ?? 'angler';
    final handle = profile?.handle ?? '@$emailFallback';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _UsernameCard(username: handle),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SectionLabel('Find anglers'),
        ),
        const SizedBox(height: AppSpacing.md),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _SearchInput(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _SearchResults(bundle: bundle),
        ),
        if (bundle.pendingIncoming.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SectionLabel(
              'Friend requests',
              trailing: '${bundle.pendingIncoming.length}',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final f in bundle.pendingIncoming)
            _PendingRow(
              friendship: f,
              profile: bundle.profilesById[f.requesterId],
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SectionLabel(
            'My friends',
            trailing:
                bundle.accepted.isEmpty ? null : '${bundle.accepted.length}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (bundle.accepted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _EmptyFriendsCard(),
          )
        else
          for (final f in bundle.accepted)
            _FriendRow(
              friendship: f,
              currentUserId: user?.id ?? '',
              profile: bundle.profilesById[f.otherSide(user?.id ?? '')],
            ),
        // Bottom-nav clearance (extendBody:true on the shell scaffold).
        SizedBox(height: 88 + MediaQuery.viewPaddingOf(context).bottom),
      ],
    );
  }
}

class _UsernameCard extends StatelessWidget {
  const _UsernameCard({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR HANDLE'.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.mist.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  username,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy handle',
            icon: const Icon(Icons.content_copy, color: AppColors.orange),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: username));
            },
          ),
        ],
      ),
    );
  }
}

class _SearchInput extends ConsumerStatefulWidget {
  const _SearchInput();

  @override
  ConsumerState<_SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends ConsumerState<_SearchInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (v) =>
          ref.read(friendSearchControllerProvider.notifier).setQuery(v),
      decoration: const InputDecoration(
        hintText: 'Search by username...',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.bundle});

  final FriendsBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncResults = ref.watch(friendSearchControllerProvider);
    return asyncResults.when(
      data: (results) {
        if (results.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            children: [
              for (final p in results)
                _SearchResultRow(profile: p, bundle: bundle),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

/// Sharper row treatment used by all three list types (search result,
/// pending invite, accepted friend). Avatar 24px, display name big +
/// bold, handle muted small, no Card wrapper — just a hairline divider
/// between adjacent rows. Trailing widget supplied by caller.
class _AnglerRow extends StatelessWidget {
  const _AnglerRow({
    required this.userId,
    required this.profile,
    required this.fallbackHandle,
    required this.trailing,
  });

  final String userId;
  final Profile? profile;
  final String fallbackHandle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDisplayName = profile?.displayName?.isNotEmpty ?? false;
    final primary = hasDisplayName
        ? profile!.displayName!
        : profile?.handle ?? fallbackHandle;
    final secondary = hasDisplayName ? profile!.handle : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/profile/$userId'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              AvatarView(avatarPath: profile?.avatarPath, radius: 24),
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
                        fontSize: 16,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultRow extends ConsumerWidget {
  const _SearchResultRow({required this.profile, required this.bundle});

  final Profile profile;
  final FriendsBundle bundle;

  bool get _alreadyFriend =>
      bundle.accepted.any((f) => f.involves(profile.id));
  bool get _alreadyPending =>
      bundle.pendingIncoming.any((f) => f.requesterId == profile.id) ||
      bundle.pendingOutgoing.any((f) => f.addresseeId == profile.id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(friendsControllerProvider.notifier);
    final busy = ref.watch(friendsControllerProvider).isLoading;

    Widget action;
    if (_alreadyFriend) {
      action = const _PillLabel(label: 'Friends', muted: true);
    } else if (_alreadyPending) {
      action = const _PillLabel(label: 'Pending', muted: true);
    } else {
      action = FilledButton(
        onPressed: busy ? null : () => controller.sendRequest(profile.id),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: const Text('Add'),
      );
    }

    return _AnglerRow(
      userId: profile.id,
      profile: profile,
      fallbackHandle: profile.handle,
      trailing: action,
    );
  }
}

class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.friendship, required this.profile});

  final Friendship friendship;
  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(friendsControllerProvider.notifier);
    final busy = ref.watch(friendsControllerProvider).isLoading;

    return _AnglerRow(
      userId: friendship.requesterId,
      profile: profile,
      fallbackHandle: '@unknown',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Reject',
            onPressed: busy ? null : () => controller.reject(friendship),
            icon: const Icon(Icons.close, size: 20),
          ),
          FilledButton(
            onPressed: busy ? null : () => controller.accept(friendship),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends ConsumerWidget {
  const _FriendRow({
    required this.friendship,
    required this.currentUserId,
    required this.profile,
  });

  final Friendship friendship;
  final String currentUserId;
  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(friendsControllerProvider).isLoading;
    final otherId = friendship.otherSide(currentUserId);

    return _AnglerRow(
      userId: otherId,
      profile: profile,
      fallbackHandle: '@unknown',
      trailing: IconButton(
        onPressed: busy ? null : () => _confirmRemove(context, ref, otherId),
        icon: const Icon(Icons.more_horiz, size: 20),
        tooltip: 'Manage',
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String otherUserId,
  ) async {
    final confirmed = await showDialog<bool>(
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
                    'Remove friend?',
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
            Text(
              "You'll stop seeing each other's catches.",
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Remove friend'),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(friendsControllerProvider.notifier)
          .removeFriend(otherUserId);
    }
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: muted ? AppColors.mist : AppColors.orange,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: muted ? AppColors.slate : AppColors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyFriendsCard extends StatelessWidget {
  const _EmptyFriendsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Center(
        child: Text(
          'No friends yet — search by username above.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          "Couldn't load your friends. Pull down to retry.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
