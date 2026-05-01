import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/catches/data/catches_data_source.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository.dart';
import 'package:fishing_with_friends/features/catches/data/photo_storage.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class _RecordingPhotoStorage implements PhotoStorage {
  final List<String> calls = [];
  Object? throwOnUploadAt; // index to throw at, or null

  @override
  Future<String> upload({
    required XFile file,
    required String anglerId,
    required String catchId,
    required int index,
  }) async {
    calls.add('upload($index)');
    if (throwOnUploadAt == index) {
      throw const StorageException('boom', error: 'boom');
    }
    return '$anglerId/$catchId/$index.jpg';
  }

  @override
  Future<String> signedUrl(String path,
      {Duration ttl = const Duration(hours: 1)}) async {
    calls.add('signedUrl($path)');
    return 'https://signed.example/$path';
  }
}

class _RecordingDataSource implements CatchesDataSource {
  final List<String> calls = [];
  bool throwOnInsert = false;
  Map<String, dynamic>? lastInsertedRow;
  List<Map<String, dynamic>> mine = const [];
  List<Map<String, dynamic>> friends = const [];
  Map<String, dynamic>? byId;

  @override
  Future<Map<String, dynamic>> insertCatch(Map<String, dynamic> row) async {
    calls.add('insert');
    if (throwOnInsert) {
      throw const PostgrestException(message: 'rls denial');
    }
    lastInsertedRow = row;
    return _hydrateInsertedRow(row);
  }

  @override
  Future<List<Map<String, dynamic>>> selectMine(String anglerId) async {
    calls.add('selectMine($anglerId)');
    return mine;
  }

  @override
  Future<List<Map<String, dynamic>>> selectFriendsView({
    required List<String> friendIds,
  }) async {
    calls.add('selectFriendsView(${friendIds.length})');
    return friends;
  }

  @override
  Future<Map<String, dynamic>?> selectById(String id) async {
    calls.add('selectById($id)');
    return byId;
  }

  /// The real Supabase insert returns the row with server-populated columns
  /// (created_at, updated_at, photo_paths echoed back). Mirror that shape.
  Map<String, dynamic> _hydrateInsertedRow(Map<String, dynamic> input) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      ...input,
      'created_at': now,
      'updated_at': now,
      'conditions': const <String, dynamic>{},
    };
  }
}

void main() {
  group('CatchesRepository.create', () {
    late _RecordingPhotoStorage storage;
    late _RecordingDataSource dataSource;
    late CatchesRepository repo;

    setUp(() {
      storage = _RecordingPhotoStorage();
      dataSource = _RecordingDataSource();
      repo = CatchesRepository(
        dataSource: dataSource,
        storage: storage,
        uuid: const Uuid(),
      );
    });

    test('uploads all photos before inserting the row', () async {
      final input = CatchInput(
        photos: [XFile('a.jpg'), XFile('b.jpg')],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
        speciesLabel: 'Largemouth Bass',
        weightKg: 2,
        lengthCm: 45,
      );

      await repo.create(input, anglerId: 'angler-1');

      expect(
        [...storage.calls, ...dataSource.calls],
        ['upload(0)', 'upload(1)', 'insert'],
        reason: 'photo uploads must precede the row insert',
      );

      final row = dataSource.lastInsertedRow!;
      expect(row['photo_paths'], hasLength(2));
      expect(row['angler_id'], 'angler-1');
      expect(row['secret_spot'], isFalse);
      expect(row['catch_and_release'], isFalse);
    });

    test('forwards trip_id to the insert row when input carries one',
        () async {
      final input = CatchInput(
        photos: [XFile('a.jpg')],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
        speciesLabel: 'Walleye',
        tripId: 't-id-123',
      );
      await repo.create(input, anglerId: 'angler-1');
      expect(dataSource.lastInsertedRow!['trip_id'], 't-id-123');
    });

    test('omits trip_id from the insert row when input has no trip',
        () async {
      final input = CatchInput(
        photos: [XFile('a.jpg')],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
        speciesLabel: 'Walleye',
      );
      await repo.create(input, anglerId: 'angler-1');
      expect(dataSource.lastInsertedRow!.containsKey('trip_id'), isFalse);
    });

    test('photo upload failure aborts before any insert is attempted',
        () async {
      storage.throwOnUploadAt = 1;
      final input = CatchInput(
        photos: [XFile('a.jpg'), XFile('b.jpg')],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
        speciesLabel: 'Snook',
      );

      await expectLater(
        () => repo.create(input, anglerId: 'angler-1'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(dataSource.calls, isEmpty,
          reason: 'no insert should be attempted after upload failure');
    });

    test('insert failure surfaces NetworkFailure (orphans accepted in M1)',
        () async {
      dataSource.throwOnInsert = true;
      final input = CatchInput(
        photos: [XFile('a.jpg')],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
        speciesLabel: 'Walleye',
      );

      await expectLater(
        () => repo.create(input, anglerId: 'angler-1'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(storage.calls, ['upload(0)']);
    });

    test('rejects empty photo list with ValidationFailure', () async {
      final input = CatchInput(
        photos: const [],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
      );
      await expectLater(
        () => repo.create(input, anglerId: 'angler-1'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(storage.calls, isEmpty);
    });

    test('rejects empty anglerId with AuthFailure (no upload attempted)',
        () async {
      final input = CatchInput(
        photos: [XFile('a.jpg')],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
      );
      await expectLater(
        () => repo.create(input, anglerId: ''),
        throwsA(isA<AuthFailure>()),
      );
      expect(storage.calls, isEmpty);
    });

    test('storage failure on photo 0 throws NetworkFailure cleanly', () async {
      storage.throwOnUploadAt = 0;
      final input = CatchInput(
        photos: [XFile('a.jpg')],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
      );
      await expectLater(
        () => repo.create(input, anglerId: 'angler-1'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('CatchesRepository.getMine / getFriendsCatches / getById', () {
    late _RecordingDataSource dataSource;
    late CatchesRepository repo;

    setUp(() {
      dataSource = _RecordingDataSource();
      repo = CatchesRepository(
        dataSource: dataSource,
        storage: _RecordingPhotoStorage(),
      );
    });

    Map<String, dynamic> sampleRow({
      String id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      bool secretSpot = false,
      Object? location,
    }) {
      return {
        'id': id,
        'angler_id': 'angler-1',
        'species_id': null,
        'species_label': 'Largemouth Bass',
        'weight_kg': 2.0,
        'length_cm': 45.0,
        'caught_at': '2026-04-12T14:00:00.000Z',
        'location': location,
        'secret_spot': secretSpot,
        'catch_and_release': false,
        'rig': null,
        'notes': null,
        'photo_paths': const <String>[],
        'conditions': const <String, dynamic>{},
        'created_at': '2026-04-12T14:01:00.000Z',
        'updated_at': '2026-04-12T14:01:00.000Z',
      };
    }

    test('getMine maps rows to domain catches', () async {
      dataSource.mine = [sampleRow(id: 'a'), sampleRow(id: 'b')];
      final catches = await repo.getMine('angler-1');
      expect(catches, hasLength(2));
      expect(catches.first.id, 'a');
      expect(catches.first.speciesLabel, 'Largemouth Bass');
    });

    test('getMine throws AuthFailure on empty anglerId', () async {
      await expectLater(
        () => repo.getMine(''),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('getFriendsCatches returns empty when friend list is empty',
        () async {
      final result = await repo.getFriendsCatches(friendIds: const []);
      expect(result, isEmpty);
      expect(dataSource.calls, ['selectFriendsView(0)']);
    });

    test('getFriendsCatches preserves null location for secret-spot rows',
        () async {
      dataSource.friends = [
        sampleRow(secretSpot: true, location: null),
        sampleRow(
          secretSpot: false,
          location: const {'type': 'Point', 'coordinates': [-75.0, 40.0]},
        ),
      ];
      final result = await repo.getFriendsCatches(friendIds: ['angler-2']);
      expect(result[0].secretSpot, isTrue);
      expect(result[0].latitude, isNull);
      expect(result[0].longitude, isNull);
      expect(result[1].latitude, 40.0);
      expect(result[1].longitude, -75.0);
    });

    test('getById returns null when row not visible under RLS', () async {
      dataSource.byId = null;
      final result = await repo.getById('does-not-exist');
      expect(result, isNull);
    });

    test('getById hydrates a found row', () async {
      dataSource.byId = sampleRow(id: 'found');
      final result = await repo.getById('found');
      expect(result, isNotNull);
      expect(result!.id, 'found');
    });
  });
}
