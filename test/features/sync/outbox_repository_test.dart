import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:fishing_with_friends/core/local_db/local_database.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository.dart';
import 'package:fishing_with_friends/features/sync/domain/outbox_op.dart';
import 'package:flutter_test/flutter_test.dart';

LocalDatabase _db() => LocalDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );

CatchCreateOp _catchOp({String catchId = 'c-1'}) {
  return CatchCreateOp(
    catchId: catchId,
    anglerId: 'u1',
    row: const {'species_label': 'Largemouth'},
    localPhotoPaths: const ['/tmp/0.jpg'],
  );
}

PhotoUploadOp _photoOp({String catchId = 'c-1', int index = 0}) {
  return PhotoUploadOp(
    localPath: '/tmp/$index.jpg',
    anglerId: 'u1',
    catchId: catchId,
    index: index,
  );
}

void main() {
  late LocalDatabase db;
  late OutboxRepository repo;

  setUp(() {
    db = _db();
    repo = OutboxRepository(db);
  });

  tearDown(() async => db.close());

  test('enqueue + nextPending returns FIFO order', () async {
    await repo.enqueue(_photoOp(index: 0));
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.enqueue(_catchOp());
    final ops = await repo.nextPending();
    expect(ops, hasLength(2));
    expect(ops.first.kind, isA<PhotoUploadOp>());
    expect(ops[1].kind, isA<CatchCreateOp>());
  });

  test('markSynced removes the op from pending count', () async {
    final id = await repo.enqueue(_catchOp());
    expect(await repo.pendingCount(), 1);
    await repo.markSynced(id);
    expect(await repo.pendingCount(), 0);
  });

  test('markFailed increments retry_count + sets status=failed', () async {
    final id = await repo.enqueue(_catchOp());
    await repo.markFailed(id, error: 'boom');
    final ops = await db.select(db.outbox).get();
    expect(ops.first.retryCount, 1);
    expect(ops.first.status, 'failed');
    expect(ops.first.lastError, 'boom');
  });

  test('markFailed transitions to permanently_failed after retry budget',
      () async {
    final id = await repo.enqueue(_catchOp());
    for (var i = 0; i < 10; i++) {
      await repo.markFailed(id, error: 'boom');
    }
    final ops = await db.select(db.outbox).get();
    expect(ops.first.retryCount, 10);
    expect(ops.first.status, 'permanently_failed');
  });

  test('retry re-pends a failed op', () async {
    final id = await repo.enqueue(_catchOp());
    await repo.markFailed(id, error: 'boom');
    await repo.retry(id);
    final ops = await db.select(db.outbox).get();
    expect(ops.first.status, 'pending');
    expect(ops.first.lastError, isNull);
  });

  test('pendingCountStream emits on insert + status change', () async {
    final stream = repo.pendingCountStream();
    final emissions = <int>[];
    final sub = stream.listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final id = await repo.enqueue(_catchOp());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await repo.markSynced(id);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(emissions, contains(0));
    expect(emissions, contains(1));
    expect(emissions.last, 0);
  });

  test('OutboxOpKind decode round-trips a CatchCreateOp', () {
    final op = _catchOp();
    final decoded = OutboxOpKind.decode('catch_create', op.encode());
    expect(decoded, isA<CatchCreateOp>());
    expect((decoded as CatchCreateOp).catchId, 'c-1');
  });
}
