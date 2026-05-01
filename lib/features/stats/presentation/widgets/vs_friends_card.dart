import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/stats/application/stats_vs_friends_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VsFriendsCard extends ConsumerWidget {
  const VsFriendsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(statsVsFriendsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    color: AppColors.navy),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Vs friends',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'How your last 30 days stack up',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            asyncSnap.when(
              loading: () => const _Loading(),
              error: (_, __) => const _Error(),
              data: _VsBody.new,
            ),
          ],
        ),
      ),
    );
  }
}

class _VsBody extends StatelessWidget {
  const _VsBody(this.snap);

  final VsFriendsSnapshot snap;

  @override
  Widget build(BuildContext context) {
    if (!snap.hasFriends) {
      return _ActionEmpty(
        copy: 'Add friends to compare your month.',
        actionLabel: 'Find friends',
        onTap: () => GoRouter.of(context).push('/friends'),
      );
    }
    if (snap.myCount == 0) {
      return _ActionEmpty(
        copy: 'Log a catch this month to compare against friends.',
        actionLabel: 'Log a catch',
        onTap: () => GoRouter.of(context).push('/log'),
      );
    }

    final pct = snap.percentile!.round();
    final friendTotal = snap.friendCounts.length;
    final maxCount = [
      snap.myCount,
      ...snap.friendCounts.map((f) => f.count),
    ].fold<int>(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'You out-fished $pct% of friends this month.',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${snap.myCount} catches in the last 30 days · '
          '$friendTotal ${friendTotal == 1 ? 'friend' : 'friends'} compared.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _Bar(label: 'You', count: snap.myCount, max: maxCount, isMe: true),
        for (final f in snap.friendCounts)
          _Bar(
            label: '@${_short(f.friendId)}',
            count: f.count,
            max: maxCount,
            isMe: false,
          ),
      ],
    );
  }

  static String _short(String id) => id.length <= 6 ? id : id.substring(0, 6);
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.count,
    required this.max,
    required this.isMe,
  });

  final String label;
  final int count;
  final int max;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : count / max;
    final fill = isMe ? AppColors.navy : AppColors.slate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => Stack(
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.mist,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  Container(
                    height: 14,
                    width: c.maxWidth * ratio,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionEmpty extends StatelessWidget {
  const _ActionEmpty({
    required this.copy,
    required this.actionLabel,
    required this.onTap,
  });

  final String copy;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(copy, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        ActionChip(
          avatar: const Icon(Icons.arrow_forward, size: 16),
          label: Text(actionLabel),
          onPressed: onTap,
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: Text(
          "Couldn't load comparison",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
