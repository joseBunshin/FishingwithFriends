import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/storytelling/application/streak_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStreak = ref.watch(streakProvider);
    return asyncStreak.when(
      loading: () => const _Pill(label: '— day fishing streak', longest: null),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s.current == 0 && s.longest == 0) return const SizedBox.shrink();
        // "fishing" qualifier disambiguates from logins / trips / app-opens.
        return _Pill(
          label: '${s.current}-day fishing streak',
          longest: s.longest,
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.longest});
  final String label;
  final int? longest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 16,
                color: AppColors.orange,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        if (longest != null && longest! > 0) ...[
          const SizedBox(height: AppSpacing.xxs),
          // Mist-on-navy uppercase kicker matches the rest of the
          // navy hero strip's muted-text language. The original
          // bodySmall + onSurface (near-black) read as muted dirt
          // against the navy background — the bug-batch-4 U1 fix.
          Text(
            'LONGEST · $longest ${longest == 1 ? 'DAY' : 'DAYS'}',
            style: const TextStyle(
              color: AppColors.mist,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
