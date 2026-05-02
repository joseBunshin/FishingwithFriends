import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/local_db/local_database.dart';
import 'package:fishing_with_friends/features/catches/data/catches_data_source.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository.dart';
import 'package:fishing_with_friends/features/catches/data/photo_storage.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';
import 'package:fishing_with_friends/features/sync/application/catch_offline_orchestrator.dart';
import 'package:fishing_with_friends/features/sync/application/connectivity_service.dart';
import 'package:fishing_with_friends/features/sync/application/sync_orchestrator.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakeConnectivity implements ConnectivityService {
  bool online = true;
  @override
  Future<bool> isOnline() async => online;
  @override
  Stream<bool> onlineStream() => const Stream<bool>.empty();
}

class _FakePhotoStorage implements PhotoStorage {
  @override
  Future<String> upload({
    required XFile file,
    required String anglerId,
    required String catchId,
    required int index,
  }) async => '$anglerId/$catchId/$index.jpg';

  @override
  Future<String> signedUrl(String path,
          {Duration ttl = const Duration(hours: 1)}) async =>
      'https://signed/$path';
}

class _FakeCatchesDataSource implements CatchesDataSource {
  Map<String, dynamic>? lastInserted;
  @override
  Future<Map<String, dynamic>> insertCatch(Map<String, dynamic> row) async {
    lastInserted = row;
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      ...row,
      'created_at': now,
      'updated_at': now,
      'photo_paths': <String>[],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> selectMine(String anglerId) async => [];
  @override
  Future<List<Map<String, dynamic>>> selectFriendsView(
          {required List<String> friendIds}) async =>
      [];
  @override
  Future<Map<String, dynamic>?> selectById(String id) async => null;
}

class _FailingDataSource extends _FakeCatchesDataSource {
  @override
  Future<Map<String, dynamic>> insertCatch(Map<String, dynamic> row) async {
    throw const NetworkFailure('boom');
  }
}

CatchInput _input({int photoCount = 1}) {
  return CatchInput(
    photos: [
      for (var i = 0; i < photoCount; i++)
        XFile.fromData(Uint8List.fromList([1, 2, 3, i]), name: 'p$i.jpg'),
    ],
    caughtAt: DateTime.utc(2026, 4, 1, 12),
    secretSpot: false,
    catchAndRelease: false,
    speciesLabel: 'Largemouth',
    weightKg: 4,
  );
}

void main() {
  late LocalDatabase db;
  late OutboxRepository outbox;
  late _FakeConnectivity conn;
  late _FakePhotoStorage storage;
  late _FakeCatchesDataSource ds;
  late CatchesRepository repo;
  late SyncOrchestrator syncOrch;
  late CatchOfflineOrchestrator orch;
  late Directory tempDir;

  setUp(() async {
    db = LocalDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    outbox = OutboxRepository(db);
    conn = _FakeConnectivity();
    storage = _FakePhotoStorage();
    ds = _FakeCatchesDataSource();
    repo = CatchesRepository(dataSource: ds, storage: storage);
    syncOrch = SyncOrchestrator(
      outbox: outbox,
      connectivity: conn,
      photoStorage: storage,
      catchesDataSource: ds,
      entrySubmit: (_, __, ___) async {},
    );
    tempDir = Directory.systemTemp.createTempSync('fwf_offline_test_');
    orch = CatchOfflineOrchestrator(
      repo: repo,
      outbox: outbox,
      connectivity: conn,
      localDb: db,
      syncOrchestrator: syncOrch,
      appDocsDirOverride: () async => tempDir,
    );
  });

  tearDown(() async {
    // Wait for any background drain triggered by an offline enqueue to
    // settle before closing the DB. The orchestrator's drain() is
    // single-flight, so this resolves to whatever is already in flight.
    await syncOrch.drain();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('online path: writes to repo + caches with isPending=false', () async {
    conn.online = true;
    final saved = await orch.create(_input(), anglerId: 'u1');
    expect(saved.anglerId, 'u1');
    expect(ds.lastInserted, isNotNull);

    final cached =
        await db.select(db.catchesCache).get();
    expect(cached, hasLength(1));
    expect(cached.first.isPending, isFalse);
    expect(await outbox.pendingCount(), 0);
  });

  test('offline path: enqueues + caches with isPending=true', () async {
    conn.online = false;
    final optimistic = await orch.create(_input(), anglerId: 'u1');
    expect(optimistic.anglerId, 'u1');
    // Repo wasn't called.
    expect(ds.lastInserted, isNull);

    final cached =
        await db.select(db.catchesCache).get();
    expect(cached, hasLength(1));
    expect(cached.first.isPending, isTrue);

    expect(await outbox.pendingCount(), 1);
  });

  test('mid-flight network failure degrades to the queue', () async {
    conn.online = true;
    final failingDs = _FailingDataSource();
    final failingRepo =
        CatchesRepository(dataSource: failingDs, storage: storage);
    final orchFail = CatchOfflineOrchestrator(
      repo: failingRepo,
      outbox: outbox,
      connectivity: conn,
      localDb: db,
      syncOrchestrator: syncOrch,
      appDocsDirOverride: () async => tempDir,
    );

    final optimistic = await orchFail.create(_input(), anglerId: 'u1');
    expect(optimistic.id, isNotEmpty);
    expect(await outbox.pendingCount(), 1);
  });

  test('rejects empty anglerId', () async {
    expect(
      () => orch.create(_input(), anglerId: ''),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('rejects no photos', () async {
    expect(
      () => orch.create(_input(photoCount: 0), anglerId: 'u1'),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('queued photos copied to app docs override dir', () async {
    conn.online = false;
    await orch.create(_input(), anglerId: 'u1');
    final queued = Directory('${tempDir.path}/queued_photos');
    expect(queued.existsSync(), isTrue);
    final files = queued
        .listSync(recursive: true)
        .whereType<File>()
        .toList();
    expect(files, isNotEmpty);
  });
}

// Smoke: import Catch so it isn't tree-shaken.
// ignore: unused_element
typedef _C = Catch;
