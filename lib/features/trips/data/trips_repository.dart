import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/trips/data/trip_dto.dart';
import 'package:fishing_with_friends/features/trips/data/trips_data_source.dart';
import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:fishing_with_friends/features/trips/domain/trip_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripsRepository {
  TripsRepository({required this.dataSource});

  final TripsDataSource dataSource;

  Future<Trip> startTrip(
    TripInput input, {
    required String anglerId,
  }) async {
    if (anglerId.isEmpty) {
      throw const AuthFailure('Sign in to start a trip.');
    }
    if (input.title.trim().isEmpty) {
      throw const ValidationFailure('Trip needs a title.');
    }
    try {
      final row = TripDto.toInsertRow(input, anglerId: anglerId);
      final inserted = await dataSource.insertTrip(row);
      return TripDto.fromRow(inserted);
    } on PostgrestException catch (e) {
      // Partial unique index violation: angler already has an active trip.
      if (e.code == '23505' || e.message.contains('trips_one_active_per_angler')) {
        throw const ValidationFailure(
          'You already have an active trip — end it before starting a new one.',
        );
      }
      throw NetworkFailure('Failed to start trip: ${e.message}', cause: e);
    }
  }

  Future<Trip> endTrip(String tripId) async {
    try {
      final updated = await dataSource.endActiveTrip(tripId);
      return TripDto.fromRow(updated);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to end trip: ${e.message}', cause: e);
    }
  }

  Future<Trip?> getActiveTrip(String anglerId) async {
    if (anglerId.isEmpty) return null;
    try {
      final row = await dataSource.selectActiveTrip(anglerId);
      return row == null ? null : TripDto.fromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load active trip: ${e.message}',
          cause: e);
    }
  }

  Future<Trip?> getById(String id) async {
    try {
      final row = await dataSource.selectById(id);
      return row == null ? null : TripDto.fromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load trip: ${e.message}', cause: e);
    }
  }

  Future<List<Trip>> getMine(String anglerId) async {
    if (anglerId.isEmpty) return const [];
    try {
      final rows = await dataSource.selectMine(anglerId);
      return rows.map(TripDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load trips: ${e.message}', cause: e);
    }
  }
}
