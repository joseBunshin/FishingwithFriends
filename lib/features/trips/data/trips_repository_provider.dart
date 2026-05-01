import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/trips/data/trips_data_source.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository.dart';
import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tripsDataSourceProvider = Provider<TripsDataSource>((ref) {
  return SupabaseTripsDataSource(ref.watch(supabaseClientProvider));
});

final tripsRepositoryProvider = Provider<TripsRepository>((ref) {
  return TripsRepository(dataSource: ref.watch(tripsDataSourceProvider));
});

/// The user's currently active Trip, or null if none.
/// Single source of truth — Catch-Log + Catches + Home all watch this.
final activeTripProvider = FutureProvider<Trip?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(tripsRepositoryProvider).getActiveTrip(user.id);
});

/// All trips the current user owns, newest first.
final myTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(tripsRepositoryProvider).getMine(user.id);
});

final tripByIdProvider = FutureProvider.family<Trip?, String>((ref, id) {
  return ref.watch(tripsRepositoryProvider).getById(id);
});
