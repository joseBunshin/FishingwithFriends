import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New tournament',
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl * 2),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            leading: const Icon(Icons.emoji_events, size: 36),
            title: Text('Spring Bass Cup ${i + 1}'),
            subtitle: const Text('12 anglers • 3 days remaining'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
  }
}
