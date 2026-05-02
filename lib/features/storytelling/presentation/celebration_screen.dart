import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_repository_provider.dart';
import 'package:fishing_with_friends/features/storytelling/domain/personal_record.dart';
import 'package:fishing_with_friends/features/storytelling/domain/save_outcome.dart';
import 'package:fishing_with_friends/features/storytelling/domain/user_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full-screen celebration shown after a catch save that produced a new
/// PR or earned a badge. Multiple outcomes paginate as a PageView.
class CelebrationScreen extends ConsumerStatefulWidget {
  const CelebrationScreen({required this.catchId, super.key});

  final String catchId;

  @override
  ConsumerState<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends ConsumerState<CelebrationScreen> {
  final PageController _pageCtl = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncOutcome = ref.watch(saveOutcomeProvider(widget.catchId));
    final asyncCatch = ref.watch(catchByIdProvider(widget.catchId));

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: SafeArea(
        child: asyncOutcome.when(
          loading: () => const _Loading(),
          error: (_, __) => _Fallback(catchId: widget.catchId),
          data: (outcome) {
            if (!outcome.isCelebratory) {
              return _Fallback(catchId: widget.catchId);
            }
            final pages = _pagesFor(outcome);
            return Stack(
              children: [
                PageView.builder(
                  controller: _pageCtl,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => pages[i],
                ),
                Positioned(
                  top: AppSpacing.lg,
                  left: 0,
                  right: 0,
                  child: _PageDots(count: pages.length, index: _index),
                ),
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => context.go('/home'),
                  ),
                ),
                Positioned(
                  bottom: AppSpacing.xl,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: _CtaRow(
                    catchId: widget.catchId,
                    photoPath: asyncCatch.valueOrNull?.photoPaths.firstOrNull,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _pagesFor(SaveOutcome outcome) {
    return [
      ...outcome.newPRs.map((pr) => _PRPage(record: pr)),
      ...outcome.newBadges.map((ub) => _BadgePage(userBadge: ub)),
    ];
  }
}

class _PRPage extends ConsumerWidget {
  const _PRPage({required this.record});

  final PersonalRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(displayUnitsProvider);
    final value = record.metric == PrMetric.weightKg
        ? formatWeight(record.value, units) ?? '—'
        : formatLength(record.value, units) ?? '—';
    final species = record.speciesLabel ?? 'this species';
    return _PageScaffold(
      headlineKicker: 'NEW PR!',
      headline: 'Biggest $species ${record.metric.label}',
      value: value,
      icon: record.metric == PrMetric.weightKg
          ? Icons.scale_outlined
          : Icons.straighten,
    );
  }
}

class _BadgePage extends StatelessWidget {
  const _BadgePage({required this.userBadge});

  final UserBadge userBadge;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      headlineKicker: 'BADGE UNLOCKED',
      headline: userBadge.definition.title,
      value: userBadge.definition.description,
      icon: _iconFor(userBadge.definition.iconName),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    required this.headlineKicker,
    required this.headline,
    required this.value,
    required this.icon,
  });

  final String headlineKicker;
  final String headline;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxxl,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 72, color: AppColors.orange),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            headlineKicker,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.orange,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            headline,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.mist,
                ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _CtaRow extends ConsumerWidget {
  const _CtaRow({required this.catchId, this.photoPath});
  final String catchId;
  final String? photoPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () async {
              await HapticFeedback.mediumImpact();
              if (!context.mounted) return;
              context.go('/catches/$catchId');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: const Text('See catch'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: () => context.go('/home'),
          style: TextButton.styleFrom(foregroundColor: AppColors.mist),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.orange),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.catchId});
  final String catchId;

  @override
  Widget build(BuildContext context) {
    // Couldn't load outcome (or empty) — degrade to the catch detail.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.go('/catches/$catchId');
    });
    return const _Loading();
  }
}

IconData _iconFor(String name) => switch (name) {
      'set_meal' => Icons.set_meal,
      'inventory_2' => Icons.inventory_2,
      'workspace_premium' => Icons.workspace_premium,
      'menu_book' => Icons.menu_book,
      'auto_awesome' => Icons.auto_awesome,
      _ => Icons.emoji_events_outlined,
    };
