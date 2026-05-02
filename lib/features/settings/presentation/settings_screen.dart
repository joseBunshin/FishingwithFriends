import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeModeProvider);
    final units = ref.watch(displayUnitsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          const _Section(title: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {theme},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const _Section(title: 'Units'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedButton<DisplayUnits>(
              segments: const [
                ButtonSegment(
                  value: DisplayUnits.imperial,
                  label: Text('lbs · in · °F'),
                ),
                ButtonSegment(
                  value: DisplayUnits.metric,
                  label: Text('kg · cm · °C'),
                ),
              ],
              selected: {units},
              onSelectionChanged: (s) =>
                  ref.read(displayUnitsProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const _Section(title: 'About'),
          const ListTile(
            title: Text('Fishing with Friends'),
            subtitle: Text('v1.0.0 · Bunshin Studios'),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Privacy'),
            subtitle: Text(
              'Friends-only by default. No public feed, no public profiles.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Support'),
            subtitle: Text('jose.diaz@bunshin.io'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const _Section(title: 'Danger zone'),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text(
              'Delete account',
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Permanently erase your profile, catches, photos, friends, and tournament history. This cannot be undone.',
            ),
            onTap: () => _confirmAndDelete(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final client = ref.read(supabaseClientProvider);

    try {
      // Edge function (not RPC) — Supabase blocks direct delete from
      // auth.users, so the auth admin API has to run server-side with
      // the service-role key. See supabase/functions/delete-account.
      final res = await client.functions.invoke('delete-account');
      if (res.status >= 400) {
        throw Exception('status ${res.status}: ${res.data}');
      }
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
      return;
    }

    // The auth user is gone; signing out clears the local session and the
    // router redirects back to /sign-in via authStateChangesProvider.
    await client.auth.signOut();
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const _phrase = 'DELETE';
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canConfirm = _controller.text.trim().toUpperCase() == _phrase;

    return AlertDialog(
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently removes your profile, catches, photos, '
            'friend connections, tournament history, and notifications. '
            'It cannot be undone.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Type $_phrase to confirm.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: _phrase,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          onPressed: !canConfirm || _busy
              ? null
              : () {
                  setState(() => _busy = true);
                  Navigator.of(context).pop(true);
                },
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
