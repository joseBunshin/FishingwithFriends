import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/catches_filter.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/catch_card.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/delete_catch_sheet.dart';
import 'package:fishing_with_friends/features/sync/presentation/widgets/sync_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CatchesScreen extends ConsumerWidget {
  const CatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCatches = ref.watch(myCatchesProvider);
    final asyncFiltered = ref.watch(filteredMyCatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Catches'),
        actions: [
          const SyncPill(),
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
              : _CatchesGrid(
                  total: catches.length,
                  filtered: asyncFiltered.valueOrNull ?? catches,
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _CatchesError(
            onRetry: () => ref.invalidate(myCatchesProvider),
          ),
        ),
      ),
    );
  }
}

class _CatchesGrid extends ConsumerWidget {
  const _CatchesGrid({required this.total, required this.filtered});

  final int total;
  final List<Catch> filtered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(catchesFilterProvider);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(child: _SearchAndFilters()),
        ),
        if (filter.isActive)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: _ResultsSummary(
                count: filtered.length,
                total: total,
                onClear: () => ref.read(catchesFilterProvider.notifier).state =
                    const CatchesFilter(),
              ),
            ),
          ),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _NoMatches(),
          )
        else
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
                  final c = filtered[i];
                  return CatchCard(
                    catch_: c,
                    onTap: () => context.push('/catches/${c.id}'),
                    onLongPress: () =>
                        DeleteCatchSheet.show(context, catch_: c),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchAndFilters extends ConsumerStatefulWidget {
  const _SearchAndFilters();

  @override
  ConsumerState<_SearchAndFilters> createState() => _SearchAndFiltersState();
}

class _SearchAndFiltersState extends ConsumerState<_SearchAndFilters> {
  late final TextEditingController _searchCtl;

  @override
  void initState() {
    super.initState();
    _searchCtl = TextEditingController(
      text: ref.read(catchesFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(catchesFilterProvider);
    final species = ref.watch(myCatchesSpeciesProvider);
    final filterCtl = ref.read(catchesFilterProvider.notifier);

    return Column(
      children: [
        TextField(
          controller: _searchCtl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search species or notes...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: filter.query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtl.clear();
                      filterCtl.state = filter.copyWith(query: '');
                    },
                  ),
          ),
          onChanged: (v) => filterCtl.state = filter.copyWith(query: v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _SpeciesFilterButton(
                selected: filter.speciesLabel,
                options: species,
                onSelected: (label) => filterCtl.state =
                    filter.copyWith(speciesLabel: label),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DateFilterButton(
                selected: filter.dateRange,
                onSelected: (r) =>
                    filterCtl.state = filter.copyWith(dateRange: r),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpeciesFilterButton extends StatelessWidget {
  const _SpeciesFilterButton({
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = selected ?? 'All species';
    return PopupMenuButton<String?>(
      tooltip: 'Filter by species',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Text('All species'),
        ),
        if (options.isNotEmpty) const PopupMenuDivider(),
        for (final s in options)
          PopupMenuItem<String?>(value: s, child: Text(s)),
      ],
      child: _FilterChipShape(
        icon: Icons.tune,
        label: label,
        active: selected != null,
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({required this.selected, required this.onSelected});

  final CatchDateRange selected;
  final ValueChanged<CatchDateRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CatchDateRange>(
      tooltip: 'Filter by date',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final r in CatchDateRange.values)
          PopupMenuItem<CatchDateRange>(value: r, child: Text(r.label)),
      ],
      child: _FilterChipShape(
        icon: Icons.calendar_today_outlined,
        label: selected.label,
        active: selected != CatchDateRange.all,
      ),
    );
  }
}

class _FilterChipShape extends StatelessWidget {
  const _FilterChipShape({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = active ? AppColors.orange : scheme.outline;
    final fg = active ? AppColors.orange : scheme.onSurface;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: active ? 1.5 : 1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        color: active
            ? AppColors.orange.withValues(alpha: 0.06)
            : Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: fg),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.expand_more, size: 18, color: fg),
        ],
      ),
    );
  }
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({
    required this.count,
    required this.total,
    required this.onClear,
  });

  final int count;
  final int total;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count of $total catches',
            style: txt?.copyWith(color: AppColors.slate),
          ),
        ),
        TextButton(onPressed: onClear, child: const Text('Clear filters')),
      ],
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 40,
            color: AppColors.slate.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No catches match those filters',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try clearing one to see more.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
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
