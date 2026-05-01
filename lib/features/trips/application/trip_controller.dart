import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository_provider.dart';
import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:fishing_with_friends/features/trips/domain/trip_input.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TripController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<Trip?> start(TripInput input) async {
    if (state.isLoading) return null;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const AuthFailure('Sign in to start a trip.'),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    try {
      final trip = await ref
          .read(tripsRepositoryProvider)
          .startTrip(input, anglerId: user.id);
      ref
        ..invalidate(activeTripProvider)
        ..invalidate(myTripsProvider);
      state = const AsyncData(null);
      return trip;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<bool> end(String tripId) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await ref.read(tripsRepositoryProvider).endTrip(tripId);
      ref
        ..invalidate(activeTripProvider)
        ..invalidate(myTripsProvider);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final tripControllerProvider =
    AsyncNotifierProvider<TripController, void>(TripController.new);
