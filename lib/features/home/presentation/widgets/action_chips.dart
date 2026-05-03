import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Top-of-Home action chips — orange primary "Log a Catch" + outlined
/// "View Catches" — matching the Lovable Home reference.
class HomeActionChips extends StatelessWidget {
  const HomeActionChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => context.push(AppRoutes.logCatch),
            icon: const Icon(Icons.add),
            label: const Text('Log a Catch'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => context.go(AppRoutes.catches),
            child: const Text('View Catches'),
          ),
        ),
      ],
    );
  }
}
