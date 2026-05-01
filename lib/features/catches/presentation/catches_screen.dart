import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/catch_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CatchesScreen extends ConsumerWidget {
  const CatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCatches = ref.watch(myCatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Catches'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.logCatch),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Log a catch',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myCatchesProvider),
        child: asyncCatches.when(
          data: (catches) => catches.isEmpty
              ? const _EmptyCatches()
              : _CatchesGrid(catches: catches),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _CatchesError(
            onRetry: () => ref.invalidate(myCatchesProvider),
          ),
        ),
      ),
    );
  }
}

class _CatchesGrid extends StatelessWidget {
  const _CatchesGrid({required this.catches});

  final List<Catch> catches;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(child: _SearchAndFilters()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final c = catches[i];
                return CatchCard(
                  catch_: c,
                  onTap: () => context.push('/catches/${c.id}'),
                );
              },
              childCount: catches.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters();

  @override
  Widget build(BuildContext context) {
    // Visible-but-inert in M1 — filtering wires up alongside Stats / Map (M4).
    return Column(
      children: [
        const TextField(
          decoration: InputDecoration(
            hintText: 'Search by species or location...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('All Species'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: const Text('Any date'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyCatches extends StatelessWidget {
  const _EmptyCatches();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.set_meal_outlined,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No catches yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your logged catches will live here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: () => context.push(AppRoutes.logCatch),
                  icon: const Icon(Icons.add),
                  label: const Text('Log your first catch'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CatchesError extends StatelessWidget {
  const _CatchesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 36,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text("Couldn't load your catches."),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
