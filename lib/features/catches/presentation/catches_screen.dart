import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatchesScreen extends ConsumerWidget {
  const CatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Catches')),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl * 2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
        ),
        itemCount: 8,
        itemBuilder: (_, i) {
          final scheme = Theme.of(context).colorScheme;
          return Card(
            child: Center(
              child: Icon(Icons.set_meal,
                  size: 40, color: scheme.primary.withValues(alpha: 0.4)),
            ),
          );
        },
      ),
    );
  }
}
