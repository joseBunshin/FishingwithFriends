import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/notifications/data/notification_preferences_provider.dart';
import 'package:fishing_with_friends/features/notifications/data/notification_preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrefs = ref.watch(notificationPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: asyncPrefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text("Couldn't load preferences: $e"),
          ),
        ),
        data: (prefs) => _Body(prefs: prefs),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.prefs});
  final NotificationPreferences prefs;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late NotificationPreferences _local = widget.prefs;
  bool _saving = false;

  Future<void> _save(NotificationPreferences next) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final prev = _local;
    setState(() {
      _local = next;
      _saving = true;
    });
    try {
      await ref.read(notificationPreferencesRepositoryProvider).upsert(
            userId: user.id,
            prefs: next,
          );
      ref.invalidate(notificationPreferencesProvider);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _local = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            'Choose which pushes you receive on your phone. The in-app '
            'feed always shows everything regardless of these settings.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        SwitchListTile.adaptive(
          title: const Text('Friend requests'),
          subtitle: const Text(
            'New friend requests and acceptance confirmations',
          ),
          value: _local.friendRequests,
          onChanged: _saving
              ? null
              : (v) => _save(_local.copyWith(friendRequests: v)),
        ),
        SwitchListTile.adaptive(
          title: const Text('Tournaments'),
          subtitle: const Text(
            'Invites, member approvals, entry verifications',
          ),
          value: _local.tournaments,
          onChanged: _saving
              ? null
              : (v) => _save(_local.copyWith(tournaments: v)),
        ),
        SwitchListTile.adaptive(
          title: const Text('Feed highlights'),
          subtitle: const Text(
            'When friends crush it — reactions and comments on your catches',
          ),
          value: _local.feed,
          onChanged: _saving
              ? null
              : (v) => _save(_local.copyWith(feed: v)),
        ),
      ],
    );
  }
}
