import 'package:drift/drift.dart';
import 'package:fishing_with_friends/core/local_db/local_database.dart';
import 'package:fishing_with_friends/features/sync/domain/outbox_op.dart';

/// Typed API over the `outbox` table. Reads + writes are async; one
/// stream surface (`pendingCountStream`) drives the sync-pill UI.
class OutboxRepository {
  OutboxRepository(this._db);

  final LocalDatabase _db;

  /// Persist a new op as `pending`. Returns the assigned auto-increment id.
  Future<int> enqueue(OutboxOpKind kind) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            opType: kind.opType,
            payload: kind.encode(),
            createdAt: now,
          ),
        );
  }

  /// FIFO claim of the next [limit] pending rows for processing.
  Future<List<OutboxOp>> nextPending({int limit = 10}) async {
    final rows = await (_db.select(_db.outbox)
          ..where((t) => t.status.equals(OutboxStatus.pending.dbValue))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<void> markUploading(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        status: Value(OutboxStatus.uploading.dbValue),
        lastAttemptAt: Value(now),
      ),
    );
  }

  Future<void> markSynced(int id) async {
    await (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        status: Value(OutboxStatus.synced.dbValue),
      ),
    );
  }

  /// Increment retry, set status. After [maxRetries], transitions to
  /// `permanently_failed` so the orchestrator stops re-attempting.
  Future<void> markFailed(
    int id, {
    required String error,
    int maxRetries = 10,
  }) async {
    final row = await (_db.select(_db.outbox)..where((t) => t.id.equals(id)))
        .getSingle();
    final nextRetry = row.retryCount + 1;
    final terminal = nextRetry >= maxRetries;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        status: Value(
          terminal
              ? OutboxStatus.permanentlyFailed.dbValue
              : OutboxStatus.failed.dbValue,
        ),
        retryCount: Value(nextRetry),
        lastAttemptAt: Value(now),
        lastError: Value(error),
      ),
    );
  }

  /// Re-pend a failed op (manual retry from UI).
  Future<void> retry(int id) async {
    await (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      const OutboxCompanion(
        status: Value('pending'),
        lastError: Value(null),
      ),
    );
  }

  /// Delete synced rows older than [retention]. Run periodically to keep
  /// the table from growing unbounded.
  Future<int> cleanupSynced({Duration retention = const Duration(days: 7)}) {
    final cutoff = DateTime.now()
        .subtract(retention)
        .millisecondsSinceEpoch;
    return (_db.delete(_db.outbox)
          ..where((t) =>
              t.status.equals(OutboxStatus.synced.dbValue) &
              t.lastAttemptAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Reactive count of pending + uploading + failed ops — drives the
  /// sync-pill UI.
  Stream<int> pendingCountStream() {
    final query = _db.selectOnly(_db.outbox)
      ..addColumns([_db.outbox.id.count()])
      ..where(
        _db.outbox.status.isIn(const [
          'pending',
          'uploading',
          'failed',
        ]),
      );
    return query.watchSingle().map(
          (row) => row.read(_db.outbox.id.count()) ?? 0,
        );
  }

  /// One-shot read used by tests + drain orchestrator.
  Future<int> pendingCount() async {
    final query = _db.selectOnly(_db.outbox)
      ..addColumns([_db.outbox.id.count()])
      ..where(
        _db.outbox.status.isIn(const [
          'pending',
          'uploading',
          'failed',
        ]),
      );
    final row = await query.getSingle();
    return row.read(_db.outbox.id.count()) ?? 0;
  }

  static OutboxOp _toDomain(OutboxData row) {
    return OutboxOp(
      id: row.id,
      kind: OutboxOpKind.decode(row.opType, row.payload),
      status: OutboxStatusX.parse(row.status),
      retryCount: row.retryCount,
      lastAttemptAt: row.lastAttemptAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastAttemptAt!),
      lastError: row.lastError,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }
}
