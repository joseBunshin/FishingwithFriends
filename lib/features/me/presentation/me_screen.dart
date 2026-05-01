import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: scheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.person, size: 48, color: scheme.primary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  user?.email ?? 'Signed out',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '@silentfisher409',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.workspace_premium_outlined),
                  title: Text('Personal Records'),
                  subtitle: Text('Arrives in M5'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.military_tech_outlined),
                  title: Text('Badges'),
                  subtitle: Text('Arrives in M5'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('Notifications'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: scheme.error),
                  title: Text(
                    'Sign out',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () =>
                      ref.read(supabaseClientProvider).auth.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
