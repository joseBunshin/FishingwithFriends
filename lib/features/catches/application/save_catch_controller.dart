import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';
import 'package:fishing_with_friends/features/notifications/application/push_registration_service.dart';
import 'package:fishing_with_friends/features/sync/application/catch_offline_orchestrator.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the upload + insert flow from the catch-log form.
///
/// State semantics:
/// - `AsyncData(null)` — idle (post-init or post-success-reset)
/// - `AsyncLoading()` — submission in flight; UI shows progress + disables Save
/// - `AsyncError` — submission failed; UI shows the error.message
class SaveCatchController extends AsyncNotifier<void> {
  bool _disposed = false;

  @override
  FutureOr<void> build() {
    ref.onDispose(() => _disposed = true);
  }

  /// Returns the persisted catch on success, `null` on failure (state already
  /// holds the AsyncError for the UI to read).
  Future<Catch?> submit(CatchInput input) async {
    if (state.isLoading) return null;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const AuthFailure('Sign in to log a catch.'),
        StackTrace.current,
      );
      return null;
    }

    state = const AsyncLoading();
    try {
      // Stamp the active trip id (if any) before handing off to the
      // repository so the inserted row joins the trip atomically.
      final activeTrip = ref.read(activeTripProvider).valueOrNull;
      final stamped = activeTrip == null
          ? input
          : CatchInput(
              photos: input.photos,
              caughtAt: input.caughtAt,
              secretSpot: input.secretSpot,
              catchAndRelease: input.catchAndRelease,
              speciesId: input.speciesId,
              speciesLabel: input.speciesLabel,
              weightKg: input.weightKg,
              lengthCm: input.lengthCm,
              latitude: input.latitude,
              longitude: input.longitude,
              locationLabel: input.locationLabel,
              notes: input.notes,
              rig: input.rig,
              tripId: activeTrip.id,
            );

      final saved = await ref
          .read(catchOfflineOrchestratorProvider)
          .create(stamped, anglerId: user.id);
      ref.invalidate(syncedMyCatchesProvider);
      state = const AsyncData(null);

      // Lazy push registration — first successful save is the right
      // moment to ask for notification permission. Idempotent service;
      // safe to call every time. kIsWeb bypass is inside the service.
      unawaited(
        ref.read(pushRegistrationServiceProvider).requestAndRegister(),
      );

      // Conditions auto-fill is async server-side (pg_net trigger →
      // edge function → service-role UPDATE on the catch row). The row
      // we just inserted has conditions={} until the function writes
      // back ~3-5s later. Schedule two re-fetches so the catch detail
      // and grid pick up the populated conditions without the user
      // having to pull-to-refresh.
      _scheduleConditionsRefetch(saved.id);

      return saved;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Re-fetch the catch + the grid at +5s and +12s so the conditions
  /// block populates on the detail screen as soon as the edge function
  /// writes back. No-op when the catch's providers are no longer
  /// observed.
  void _scheduleConditionsRefetch(String catchId) {
    for (final delay in const [
      Duration(seconds: 5),
      Duration(seconds: 12),
    ]) {
      Future<void>.delayed(delay).then((_) {
        if (_disposed) return;
        ref
          ..invalidate(catchByIdProvider(catchId))
          ..invalidate(syncedMyCatchesProvider);
      });
    }
  }
}

final saveCatchControllerProvider =
    AsyncNotifierProvider<SaveCatchController, void>(SaveCatchController.new);
