import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/local_db/local_database.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/catches/application/save_catch_controller.dart';
import 'package:fishing_with_friends/features/catches/data/catches_data_source.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/data/photo_storage.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';
import 'package:fishing_with_friends/features/sync/application/catch_offline_orchestrator.dart';
import 'package:fishing_with_friends/features/sync/application/connectivity_service.dart';
import 'package:fishing_with_friends/features/sync/application/sync_orchestrator.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AlwaysOnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> isOnline() async => true;
  @override
  Stream<bool> onlineStream() => const Stream<bool>.empty();
}

/// Pass-through orchestrator that defers to the repo. Lets the
/// controller tests avoid wiring drift + path_provider — those paths
/// have their own dedicated tests in
/// `test/features/sync/catch_offline_orchestrator_test.dart`.
class _FakeOrchestrator extends CatchOfflineOrchestrator {
  _FakeOrchestrator(this._repo)
      : super(
          repo: _repo,
          outbox: _NullOutbox(),
          connectivity: _AlwaysOnlineConnectivity(),
          localDb: _NullDb(),
          syncOrchestrator: _NullSync(),
        );

  final CatchesRepository _repo;

  @override
  Future<Catch> create(CatchInput input, {required String anglerId}) {
    return _repo.create(input, anglerId: anglerId);
  }
}

class _NullOutbox extends OutboxRepository {
  _NullOutbox() : super(_NullDb());
}

class _NullDb extends LocalDatabase {
  _NullDb()
      : super.forTesting(
          DatabaseConnection(NativeDatabase.memory()),
        );
}

class _NullSync extends SyncOrchestrator {
  _NullSync()
      : super(
          outbox: _NullOutbox(),
          connectivity: _AlwaysOnlineConnectivity(),
          photoStorage: _StubPhotoStorage(),
          catchesDataSource: _StubDataSource(),
          entrySubmit: _noEntrySubmit,
        );

  static Future<void> _noEntrySubmit(_, __, ___) async {}
}

class _StubPhotoStorage implements PhotoStorage {
  @override
  Future<String> upload({
    required XFile file,
    required String anglerId,
    required String catchId,
    required int index,
  }) async => '$anglerId/$catchId/$index.jpg';

  @override
  Future<String> signedUrl(String path,
      {Duration ttl = const Duration(hours: 1)}) async => 'https://x/$path';
}

class _StubDataSource implements CatchesDataSource {
  bool throwOnInsert = false;

  @override
  Future<Map<String, dynamic>> insertCatch(Map<String, dynamic> row) async {
    if (throwOnInsert) {
      throw const PostgrestException(message: 'rls denial');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      ...row,
      'created_at': now,
      'updated_at': now,
      'conditions': const <String, dynamic>{},
    };
  }

  @override
  Future<List<Map<String, dynamic>>> selectMine(String anglerId) async => const [];

  @override
  Future<List<Map<String, dynamic>>> selectFriendsView({
    required List<String> friendIds,
  }) async => const [];

  @override
  Future<Map<String, dynamic>?> selectById(String id) async => null;
}

CatchInput _validInput() => CatchInput(
      photos: [XFile('a.jpg')],
      caughtAt: DateTime.utc(2026, 4, 12, 14),
      secretSpot: false,
      catchAndRelease: false,
      speciesLabel: 'Largemouth Bass',
      weightKg: 2,
      lengthCm: 45,
    );

ProviderContainer _container({
  Object? user,
  CatchesDataSource? dataSource,
}) {
  final ds = dataSource ?? _StubDataSource();
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(user as User?),
      photoStorageProvider.overrideWithValue(_StubPhotoStorage()),
      catchesDataSourceProvider.overrideWithValue(ds),
      catchesRepositoryProvider.overrideWith(
        (ref) => CatchesRepository(
          dataSource: ref.watch(catchesDataSourceProvider),
          storage: ref.watch(photoStorageProvider),
        ),
      ),
      catchOfflineOrchestratorProvider.overrideWith(
        (ref) => _FakeOrchestrator(ref.watch(catchesRepositoryProvider)),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

User _fakeUser(String id) {
  // Build a minimal supabase User from JSON. The class is JSON-friendly.
  return User.fromJson({
    'id': id,
    'app_metadata': const <String, dynamic>{},
    'user_metadata': const <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
  })!;
}

void main() {
  group('SaveCatchController.submit', () {
    test('happy path: idle → loading → data, returns saved Catch', () async {
      final container = _container(user: _fakeUser('angler-1'));
      final controller = container.read(saveCatchControllerProvider.notifier);

      expect(container.read(saveCatchControllerProvider), isA<AsyncData<void>>());

      final saved = await controller.submit(_validInput());

      expect(saved, isNotNull);
      expect(saved!.anglerId, 'angler-1');
      expect(container.read(saveCatchControllerProvider), isA<AsyncData<void>>());
    });

    test('not signed in → AsyncError(AuthFailure), returns null', () async {
      final container = _container(user: null);
      final controller = container.read(saveCatchControllerProvider.notifier);

      final saved = await controller.submit(_validInput());

      expect(saved, isNull);
      final state = container.read(saveCatchControllerProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<AuthFailure>());
    });

    test('insert fails → AsyncError(NetworkFailure), returns null', () async {
      // Test against the pass-through orchestrator (online direct path).
      // Offline degradation is covered separately in
      // catch_offline_orchestrator_test.dart.
      final ds = _StubDataSource()..throwOnInsert = true;
      final container = _container(user: _fakeUser('angler-1'), dataSource: ds);
      final controller = container.read(saveCatchControllerProvider.notifier);

      final saved = await controller.submit(_validInput());

      expect(saved, isNull);
      final state = container.read(saveCatchControllerProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<NetworkFailure>());
    });

    test('double-tap during in-flight call returns null without re-submitting',
        () async {
      final container = _container(user: _fakeUser('angler-1'));
      final controller = container.read(saveCatchControllerProvider.notifier);

      // Fire two in parallel — first wins, second sees state.isLoading
      // and short-circuits.
      final first = controller.submit(_validInput());
      final second = controller.submit(_validInput());
      final results = await Future.wait([first, second]);

      // One of them should be the saved catch; the other should be null.
      final nonNullCount = results.where((r) => r != null).length;
      expect(nonNullCount, 1);
    });

    test('empty photos input → AsyncError(ValidationFailure), returns null',
        () async {
      final container = _container(user: _fakeUser('angler-1'));
      final controller = container.read(saveCatchControllerProvider.notifier);

      final saved = await controller.submit(
        CatchInput(
          photos: const [],
          caughtAt: DateTime.utc(2026, 4, 12, 14),
          secretSpot: false,
          catchAndRelease: false,
          speciesLabel: 'Bass',
        ),
      );

      expect(saved, isNull);
      final state = container.read(saveCatchControllerProvider);
      expect(state.error, isA<ValidationFailure>());
    });
  });
}
