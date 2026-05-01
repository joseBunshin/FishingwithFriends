import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/trips/data/trips_data_source.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository.dart';
import 'package:fishing_with_friends/features/trips/domain/trip_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeTripsDataSource implements TripsDataSource {
  bool throwUniqueOnInsert = false;
  bool throwGenericOnInsert = false;
  Map<String, dynamic>? activeTrip;
  Map<String, dynamic>? byId;
  List<Map<String, dynamic>> mine = const [];

  @override
  Future<Map<String, dynamic>> insertTrip(Map<String, dynamic> row) async {
    if (throwUniqueOnInsert) {
      throw const PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"trips_one_active_per_angler"',
        code: '23505',
      );
    }
    if (throwGenericOnInsert) {
      throw const PostgrestException(message: 'connection refused');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      ...row,
      'id': 'trip-1',
      'started_at': now,
      'ended_at': null,
      'is_active': true,
      'created_at': now,
      'updated_at': now,
      'cover_photo_path': null,
    };
  }

  @override
  Future<Map<String, dynamic>> endActiveTrip(String tripId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': tripId,
      'angler_id': 'angler-1',
      'title': 'Saturday',
      'body_of_water': null,
      'cover_photo_path': null,
      'started_at': '2026-04-12T08:00:00.000Z',
      'ended_at': now,
      'is_active': false,
      'created_at': '2026-04-12T08:00:00.000Z',
      'updated_at': now,
    };
  }

  @override
  Future<Map<String, dynamic>?> selectActiveTrip(String anglerId) async =>
      activeTrip;

  @override
  Future<Map<String, dynamic>?> selectById(String id) async => byId;

  @override
  Future<List<Map<String, dynamic>>> selectMine(String anglerId) async => mine;
}

void main() {
  group('TripsRepository.startTrip', () {
    late _FakeTripsDataSource ds;
    late TripsRepository repo;

    setUp(() {
      ds = _FakeTripsDataSource();
      repo = TripsRepository(dataSource: ds);
    });

    test('happy path: returns Trip with isActive=true', () async {
      final trip = await repo.startTrip(
        const TripInput(title: 'Saturday at Lake Erie', bodyOfWater: 'Erie'),
        anglerId: 'angler-1',
      );
      expect(trip.isActive, isTrue);
      expect(trip.title, 'Saturday at Lake Erie');
      expect(trip.bodyOfWater, 'Erie');
    });

    test('partial-unique violation maps to ValidationFailure', () async {
      ds.throwUniqueOnInsert = true;
      await expectLater(
        () => repo.startTrip(
          const TripInput(title: 'Another'),
          anglerId: 'angler-1',
        ),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('already have an active trip'),
        )),
      );
    });

    test('generic Postgrest error maps to NetworkFailure', () async {
      ds.throwGenericOnInsert = true;
      await expectLater(
        () => repo.startTrip(
          const TripInput(title: 'X'),
          anglerId: 'angler-1',
        ),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('empty title is rejected with ValidationFailure', () async {
      await expectLater(
        () => repo.startTrip(
          const TripInput(title: '   '),
          anglerId: 'angler-1',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('empty anglerId is rejected with AuthFailure', () async {
      await expectLater(
        () => repo.startTrip(
          const TripInput(title: 'Saturday'),
          anglerId: '',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('TripsRepository.endTrip', () {
    test('flips isActive=false and stamps endedAt', () async {
      final repo = TripsRepository(dataSource: _FakeTripsDataSource());
      final ended = await repo.endTrip('trip-1');
      expect(ended.isActive, isFalse);
      expect(ended.endedAt, isNotNull);
    });
  });

  group('TripsRepository.getActiveTrip', () {
    test('returns the active trip when present', () async {
      final ds = _FakeTripsDataSource()
        ..activeTrip = {
          'id': 'trip-1',
          'angler_id': 'angler-1',
          'title': 'Saturday',
          'body_of_water': null,
          'cover_photo_path': null,
          'started_at': '2026-04-12T08:00:00.000Z',
          'ended_at': null,
          'is_active': true,
          'created_at': '2026-04-12T08:00:00.000Z',
          'updated_at': '2026-04-12T08:00:00.000Z',
        };
      final repo = TripsRepository(dataSource: ds);
      final trip = await repo.getActiveTrip('angler-1');
      expect(trip, isNotNull);
      expect(trip!.id, 'trip-1');
    });

    test('returns null when no active trip', () async {
      final repo = TripsRepository(dataSource: _FakeTripsDataSource());
      final trip = await repo.getActiveTrip('angler-1');
      expect(trip, isNull);
    });

    test('returns null on empty anglerId without hitting data source',
        () async {
      final repo = TripsRepository(dataSource: _FakeTripsDataSource());
      final trip = await repo.getActiveTrip('');
      expect(trip, isNull);
    });
  });
}
