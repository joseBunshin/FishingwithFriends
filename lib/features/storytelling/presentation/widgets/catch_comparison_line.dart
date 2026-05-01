import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/storytelling/application/catch_comparison_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatchComparisonLine extends ConsumerWidget {
  const CatchComparisonLine({required this.catchId, super.key});

  final String catchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCmp = ref.watch(catchComparisonProvider(catchId));
    return asyncCmp.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (cmp) {
        if (cmp == null || !cmp.isInteresting) return const SizedBox.shrink();
        return _Pill(text: _format(cmp));
      },
    );
  }

  static String _format(CatchComparison cmp) {
    final species = cmp.speciesLabel ?? 'this species';
    if (cmp.isAllTimeBest) {
      return 'Biggest $species ever';
    }
    final ord = _ordinal(cmp.rank!);
    return '$ord biggest $species this year';
  }

  static String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium,
            size: 14,
            color: AppColors.orange,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.orangeDeep,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
