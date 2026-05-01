import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/trips/application/trip_controller.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository_provider.dart';
import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Banner shown above the Catch-Log photo target + at the top of Catches
/// when an active trip exists. Hidden otherwise.
class ActiveTripBanner extends ConsumerWidget {
  const ActiveTripBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrip = ref.watch(activeTripProvider);
    return asyncTrip.maybeWhen(
      data: (trip) => trip == null ? const SizedBox.shrink() : _Banner(trip: trip),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({required this.trip});

  final Trip trip;

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End trip?'),
        content: const Text(
          "New catches won't join this trip after it ends.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End trip'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(tripControllerProvider.notifier).end(trip.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.orange.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => context.push('/trips/${trip.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_boat_outlined,
                  size: 18,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Active trip',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.orangeDeep,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      trip.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _confirmEnd(context, ref),
                child: const Text('End'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
