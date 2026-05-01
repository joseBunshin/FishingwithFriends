import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/friends/application/friend_search_controller.dart';
import 'package:fishing_with_friends/features/friends/application/friends_controller.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/friends/domain/friendship.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final username = user?.email?.split('@').first ?? 'angler';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _UsernameCard(username: '@$username'),
        const SizedBox(height: AppSpacing.lg),
        Text('Find Anglers',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const _SearchInput(),
        const SizedBox(height: AppSpacing.sm),
        _SearchResults(bundle: bundle),
        if (bundle.pendingIncoming.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Friend Requests (${bundle.pendingIncoming.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final f in bundle.pendingIncoming)
            _PendingRow(
              friendship: f,
              profile: bundle.profilesById[f.requesterId],
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'My Friends (${bundle.accepted.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (bundle.accepted.isEmpty)
          const _EmptyFriendsCard()
        else
          for (final f in bundle.accepted)
            _FriendRow(
              friendship: f,
              currentUserId: user?.id ?? '',
              profile: bundle.profilesById[f.otherSide(user?.id ?? '')],
            ),
      ],
    );
  }
}

class _UsernameCard extends StatelessWidget {
  const _UsernameCard({required this.username});

  final String username;

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
                  Text('Your Username',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(username,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.outlined(
              tooltip: 'Copy username',
              icon: const Icon(Icons.content_copy, size: 16),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: username));
              },
            ),
          ],
        ),
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
        return Column(
          children: [
            for (final p in results)
              _SearchResultRow(profile: p, bundle: bundle),
          ],
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
        child: const Text('Send'),
      );
    }

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.handle,
                      style: Theme.of(context).textTheme.titleSmall),
                  if (profile.displayName != null)
                    Text(
                      profile.displayName!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            action,
          ],
        ),
      ),
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
                profile?.handle ?? '@unknown',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => controller.reject(friendship),
              child: const Text('Reject'),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton(
              onPressed: busy ? null : () => controller.accept(friendship),
              child: const Text('Accept'),
            ),
          ],
        ),
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
                profile?.handle ?? '@unknown',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              onPressed: busy
                  ? null
                  : () => _confirmRemove(context, ref,
                      friendship.otherSide(currentUserId)),
              icon: const Icon(Icons.close),
              tooltip: 'Remove friend',
            ),
          ],
        ),
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
        title: const Text('Remove friend?'),
        content: const Text(
          "You'll stop seeing each other's catches.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(friendsControllerProvider.notifier)
          .removeFriend(otherUserId);
    }
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 18,
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
      child: Icon(Icons.person, size: 20, color: scheme.primary),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color:
            muted ? scheme.onSurface.withValues(alpha: 0.06) : scheme.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
              muted ? scheme.onSurface.withValues(alpha: 0.7) : scheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyFriendsCard extends StatelessWidget {
  const _EmptyFriendsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'No friends yet — search by username above.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
