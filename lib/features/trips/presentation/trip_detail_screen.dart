import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/catch_card.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository_provider.dart';
import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrip = ref.watch(tripByIdProvider(tripId));
    return asyncTrip.when(
      data: (trip) => trip == null
          ? const _NotFound()
          : _Body(trip: trip),
      loading: () => const _Loading(),
      error: (_, __) => const _NotFound(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // M2: trip's catches come from myCatchesProvider (owner view) filtered
    // by trip_id. Friend view of a trip is a follow-up plan.
    final myCatchesAsync = ref.watch(myCatchesProvider);
    final tripCatches = myCatchesAsync.valueOrNull
            ?.where((c) => c.tripId == trip.id)
            .toList(growable: false) ??
        const <Catch>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(trip.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Headline(trip: trip),
          const SizedBox(height: AppSpacing.lg),
          _Summary(trip: trip, catches: tripCatches),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Catches (${tripCatches.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (tripCatches.isEmpty)
            const _EmptyTripCatches()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.82,
              ),
              itemCount: tripCatches.length,
              itemBuilder: (_, i) => CatchCard(
                catch_: tripCatches[i],
                onTap: () =>
                    context.push('/catches/${tripCatches[i].id}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trip.bodyOfWater != null && trip.bodyOfWater!.isNotEmpty)
          Text(trip.bodyOfWater!,
              style: Theme.of(context).textTheme.bodyMedium),
        Text(trip.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: trip.isActive
                    ? AppColors.orange.withValues(alpha: 0.15)
                    : AppColors.mist.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                trip.isActive ? 'Active' : 'Closed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: trip.isActive ? AppColors.orangeDeep : AppColors.slate,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              DateFormat.yMMMd().format(trip.startedAt.toLocal()) +
                  (trip.endedAt != null
                      ? ' → ${DateFormat.yMMMd().format(trip.endedAt!.toLocal())}'
                      : ''),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.trip, required this.catches});

  final Trip trip;
  final List<Catch> catches;

  @override
  Widget build(BuildContext context) {
    final total = catches.length;
    final totalKg = catches
        .map((c) => c.weightKg ?? 0)
        .fold<double>(0, (sum, w) => sum + w);
    final totalLbs = (totalKg * 2.20462).toStringAsFixed(1);

    final speciesCount = <String, int>{};
    for (final c in catches) {
      final s = c.speciesLabel ?? c.speciesId;
      if (s == null || s.isEmpty) continue;
      speciesCount[s] = (speciesCount[s] ?? 0) + 1;
    }
    String? topSpecies;
    var topCount = 0;
    speciesCount.forEach((s, n) {
      if (n > topCount) {
        topCount = n;
        topSpecies = s;
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            _SummaryStat(label: 'Catches', value: '$total'),
            const _SummaryDivider(),
            _SummaryStat(label: 'Total', value: '$totalLbs lbs'),
            const _SummaryDivider(),
            _SummaryStat(
              label: 'Top species',
              value: topSpecies ?? '—',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.mist,
    );
  }
}

class _EmptyTripCatches extends StatelessWidget {
  const _EmptyTripCatches();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            'Catches will appear as you log them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_boat_outlined, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                "This trip isn't available.",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
