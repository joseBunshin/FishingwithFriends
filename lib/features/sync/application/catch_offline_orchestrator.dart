import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/local_db/local_database.dart';
import 'package:fishing_with_friends/core/local_db/local_database_provider.dart';
import 'package:fishing_with_friends/features/catches/data/catch_dto.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';
import 'package:fishing_with_friends/features/sync/application/connectivity_service.dart';
import 'package:fishing_with_friends/features/sync/application/sync_orchestrator.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository_provider.dart';
import 'package:fishing_with_friends/features/sync/domain/outbox_op.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Wraps the existing [CatchesRepository.create] with an offline-aware path:
///
///   * Online → call the repo direct, then mirror the result into
///     `catches_cache` so subsequent offline starts have read-side parity.
///   * Offline → copy photos to a stable app-docs dir, write a row into
///     `catches_cache` flagged `isPending=true`, enqueue a CatchCreateOp,
///     return an optimistic [Catch] pointing at the local files.
///
/// The catch's id is generated client-side either way so the optimistic
/// row keeps the same id once the queue drains and the server-side insert
/// runs (preserves PR + badge attribution).
class CatchOfflineOrchestrator {
  CatchOfflineOrchestrator({
    required this.repo,
    required this.outbox,
    required this.connectivity,
    required this.localDb,
    required this.syncOrchestrator,
    Uuid? uuid,
    Future<Directory> Function()? appDocsDirOverride,
  })  : _uuid = uuid ?? const Uuid(),
        _appDocsDirOverride = appDocsDirOverride;

  final CatchesRepository repo;
  final OutboxRepository outbox;
  final ConnectivityService connectivity;
  final LocalDatabase localDb;
  final SyncOrchestrator syncOrchestrator;
  final Uuid _uuid;
  final Future<Directory> Function()? _appDocsDirOverride;

  Future<Catch> create(
    CatchInput input, {
    required String anglerId,
  }) async {
    if (anglerId.isEmpty) {
      throw const AuthFailure('You must be signed in to log a catch.');
    }
    if (input.photos.isEmpty) {
      throw const ValidationFailure(
        'At least one photo is required to log a catch.',
      );
    }

    // Web bypass: drift requires a WASM bundle we don't ship and
    // path_provider can't write to local disk. Skip the offline stack
    // entirely and call the repo direct — web is a dev convenience,
    // not an offline-supported surface.
    if (kIsWeb) {
      return repo.create(input, anglerId: anglerId);
    }

    final online = await connectivity.isOnline();
    if (online) {
      try {
        final saved = await repo.create(input, anglerId: anglerId);
        await _upsertCacheRow(saved, isPending: false);
        return saved;
      } on NetworkFailure {
        // Network said online but the request failed mid-flight —
        // degrade to the offline queue so the user doesn't lose work.
        return _enqueueOffline(input, anglerId: anglerId);
      }
    }
    return _enqueueOffline(input, anglerId: anglerId);
  }

  Future<Catch> _enqueueOffline(
    CatchInput input, {
    required String anglerId,
  }) async {
    final catchId = _uuid.v4();
    final localPaths = await _copyPhotosToAppDocs(catchId, input);

    final row = CatchDto.toInsertRow(
      input,
      catchId: catchId,
      anglerId: anglerId,
      photoPaths: const [],
    );

    final optimistic = Catch(
      id: catchId,
      anglerId: anglerId,
      speciesId: input.speciesId,
      speciesLabel: input.speciesLabel,
      weightKg: input.weightKg,
      lengthCm: input.lengthCm,
      caughtAt: input.caughtAt.toUtc(),
      latitude: input.latitude,
      longitude: input.longitude,
      secretSpot: input.secretSpot,
      catchAndRelease: input.catchAndRelease,
      notes: input.notes,
      rig: input.rig,
      tripId: input.tripId,
      photoPaths: localPaths, // local file:// paths until sync
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await _upsertCacheRow(optimistic, isPending: true);

    await outbox.enqueue(
      CatchCreateOp(
        catchId: catchId,
        anglerId: anglerId,
        row: row,
        localPhotoPaths: localPaths,
      ),
    );

    // Kick the orchestrator. If we're online (mid-flight degradation
    // path), this drains immediately; offline, it's a no-op until
    // connectivity returns.
    unawaited(syncOrchestrator.drain());

    return optimistic;
  }

  Future<List<String>> _copyPhotosToAppDocs(
    String catchId,
    CatchInput input,
  ) async {
    final dir = await _resolveAppDocsDir();
    final queuedDir = Directory('${dir.path}/queued_photos/$catchId');
    await queuedDir.create(recursive: true);
    final paths = <String>[];
    for (var i = 0; i < input.photos.length; i++) {
      final src = input.photos[i];
      final ext = _ext(src.name);
      final dest = '${queuedDir.path}/$i$ext';
      final bytes = await src.readAsBytes();
      await File(dest).writeAsBytes(bytes, flush: true);
      paths.add(dest);
    }
    return paths;
  }

  Future<Directory> _resolveAppDocsDir() async {
    final override = _appDocsDirOverride;
    if (override != null) return override();
    return getApplicationDocumentsDirectory();
  }

  static String _ext(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return '.jpg';
    return filename.substring(dot).toLowerCase();
  }

  Future<void> _upsertCacheRow(Catch c, {required bool isPending}) async {
    await localDb.into(localDb.catchesCache).insertOnConflictUpdate(
          CatchesCacheCompanion.insert(
            id: c.id,
            anglerId: c.anglerId,
            speciesId: Value(c.speciesId),
            speciesLabel: Value(c.speciesLabel),
            weightKg: Value(c.weightKg),
            lengthCm: Value(c.lengthCm),
            caughtAt: c.caughtAt.millisecondsSinceEpoch,
            latitude: Value(c.latitude),
            longitude: Value(c.longitude),
            secretSpot: Value(c.secretSpot),
            catchAndRelease: Value(c.catchAndRelease),
            notes: Value(c.notes),
            rig: Value(c.rig),
            tripId: Value(c.tripId),
            photoPaths: Value(jsonEncode(c.photoPaths)),
            conditions: Value(jsonEncode(c.conditions)),
            createdAt: c.createdAt.millisecondsSinceEpoch,
            updatedAt: c.updatedAt.millisecondsSinceEpoch,
            isPending: Value(isPending),
          ),
        );
  }
}

final catchOfflineOrchestratorProvider =
    Provider<CatchOfflineOrchestrator>((ref) {
  return CatchOfflineOrchestrator(
    repo: ref.watch(catchesRepositoryProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    localDb: ref.watch(localDatabaseProvider),
    syncOrchestrator: ref.watch(syncOrchestratorProvider),
  );
});
