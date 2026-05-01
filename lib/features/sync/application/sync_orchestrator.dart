import 'dart:async';
import 'dart:io';

import 'package:fishing_with_friends/features/catches/data/catches_data_source.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/data/photo_storage.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/sync/application/connectivity_service.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository_provider.dart';
import 'package:fishing_with_friends/features/sync/domain/outbox_op.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Drives the outbox queue. Listens to connectivity transitions; on
/// `false → true` triggers a `drain()`. Reentrant-safe — concurrent
/// drain calls await the in-flight one.
class SyncOrchestrator {
  SyncOrchestrator({
    required this.outbox,
    required this.connectivity,
    required this.photoStorage,
    required this.catchesDataSource,
    required this.entrySubmit,
  });

  final OutboxRepository outbox;
  final ConnectivityService connectivity;
  final PhotoStorage photoStorage;
  final CatchesDataSource catchesDataSource;

  /// Submit-entry callback indirected so the orchestrator doesn't pull
  /// the whole TournamentsRepository surface. Receives `(tournamentId,
  /// sourceCatch, anglerId)`.
  final Future<void> Function(
    String tournamentId,
    Catch sourceCatch,
    String anglerId,
  ) entrySubmit;

  Future<void>? _running;
  StreamSubscription<bool>? _sub;

  /// Begin listening for connectivity changes. Idempotent.
  Future<void> start() async {
    _sub ??= connectivity.onlineStream().listen((online) {
      if (online) unawaited(drain());
    });
    if (await connectivity.isOnline()) {
      // Don't await — let it run in the background.
      unawaited(drain());
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Drain the outbox FIFO. Reentrant — concurrent calls await the
  /// first run rather than starting a parallel drain.
  Future<void> drain() {
    return _running ??= _doDrain().whenComplete(() => _running = null);
  }

  Future<void> _doDrain() async {
    while (true) {
      final ops = await outbox.nextPending(limit: 5);
      if (ops.isEmpty) return;
      for (final op in ops) {
        if (!await connectivity.isOnline()) return;
        await _processOne(op);
      }
    }
  }

  Future<void> _processOne(OutboxOp op) async {
    await outbox.markUploading(op.id);
    try {
      switch (op.kind) {
        case final CatchCreateOp k:
          await _runCatchCreate(k);
        case final EntryCreateOp k:
          await _runEntryCreate(k);
        case PhotoUploadOp _:
          // Photo uploads happen inline within catch_create today.
          // Standalone photo_upload ops are reserved for future
          // re-attach scenarios; treat as no-op.
          break;
      }
      await outbox.markSynced(op.id);
    } on Object catch (e) {
      await outbox.markFailed(op.id, error: e.toString());
    }
  }

  Future<void> _runCatchCreate(CatchCreateOp op) async {
    final uploadedPaths = <String>[];
    for (var i = 0; i < op.localPhotoPaths.length; i++) {
      final localPath = op.localPhotoPaths[i];
      final remotePath = await photoStorage.upload(
        file: XFile(localPath),
        anglerId: op.anglerId,
        catchId: op.catchId,
        index: i,
      );
      uploadedPaths.add(remotePath);
    }

    final row = Map<String, dynamic>.from(op.row)
      ..['photo_paths'] = uploadedPaths;
    await catchesDataSource.insertCatch(row);

    // Best-effort cleanup of local photo files.
    for (final p in op.localPhotoPaths) {
      try {
        await File(p).delete();
      } on Object {
        // ignore — disk cleanup is best-effort.
      }
    }
  }

  Future<void> _runEntryCreate(EntryCreateOp op) async {
    // Look up the catch by id from the server. By this point the parent
    // catch_create op has already drained, so the row exists.
    final row = await catchesDataSource.selectById(op.sourceCatchId);
    if (row == null) {
      throw StateError(
        'Source catch ${op.sourceCatchId} not visible — entry submit aborted',
      );
    }
    // Build a Catch from the row to satisfy entrySubmit's signature.
    final source = _catchFromRow(row);
    await entrySubmit(op.tournamentId, source, op.anglerId);
  }

  static Catch _catchFromRow(Map<String, dynamic> row) {
    DateTime parse(String v) => DateTime.parse(v).toUtc();
    return Catch(
      id: row['id'] as String,
      anglerId: row['angler_id'] as String,
      speciesId: row['species_id'] as String?,
      speciesLabel: row['species_label'] as String?,
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      lengthCm: (row['length_cm'] as num?)?.toDouble(),
      caughtAt: parse(row['caught_at'] as String),
      secretSpot: row['secret_spot'] as bool? ?? false,
      catchAndRelease: row['catch_and_release'] as bool? ?? false,
      photoPaths:
          List<String>.from((row['photo_paths'] as List?) ?? const []),
      createdAt: parse(row['created_at'] as String),
      updatedAt: parse(row['updated_at'] as String),
    );
  }
}

final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) {
  final orch = SyncOrchestrator(
    outbox: ref.watch(outboxRepositoryProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    photoStorage: ref.watch(photoStorageProvider),
    catchesDataSource: ref.watch(catchesDataSourceProvider),
    entrySubmit: (tournamentId, source, anglerId) async {
      await ref
          .read(tournamentEntriesRepositoryProvider)
          .submitEntry(
            tournamentId: tournamentId,
            source: source,
            anglerId: anglerId,
          );
    },
  );
  ref.onDispose(orch.stop);
  return orch;
});
