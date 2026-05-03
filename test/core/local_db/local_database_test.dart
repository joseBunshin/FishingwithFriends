import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:fishing_with_friends/core/local_db/local_database.dart';
import 'package:flutter_test/flutter_test.dart';

LocalDatabase _inMemoryDb() => LocalDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );

void main() {
  group('LocalDatabase schema', () {
    late LocalDatabase db;

    setUp(() {
      db = _inMemoryDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('opens at schema version 1', () {
      expect(db.schemaVersion, 1);
    });

    test('outbox insert returns autoincrement id', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.into(db.outbox).insert(
            OutboxCompanion.insert(
              opType: 'catch_create',
              payload: '{"foo":"bar"}',
              createdAt: now,
            ),
          );
      expect(id, isPositive);
    });

    test('outbox select returns the inserted row with defaults', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.outbox).insert(
            OutboxCompanion.insert(
              opType: 'photo_upload',
              payload: '{"path":"/tmp/x.jpg"}',
              createdAt: now,
            ),
          );
      final rows = await db.select(db.outbox).get();
      expect(rows, hasLength(1));
      expect(rows.first.status, 'pending');
      expect(rows.first.retryCount, 0);
      expect(rows.first.lastAttemptAt, isNull);
      expect(rows.first.opType, 'photo_upload');
    });

    test('catches_cache round-trips JSON columns', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.catchesCache).insert(
            CatchesCacheCompanion.insert(
              id: 'c-1',
              anglerId: 'u1',
              caughtAt: now,
              createdAt: now,
              updatedAt: now,
              speciesLabel: const Value('Largemouth'),
              weightKg: const Value(4.2),
              photoPaths: const Value('["a.jpg","b.jpg"]'),
              conditions: const Value('{"temp_c":18}'),
              isPending: const Value(true),
            ),
          );
      final rows = await db.select(db.catchesCache).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, 'c-1');
      expect(rows.first.speciesLabel, 'Largemouth');
      expect(rows.first.weightKg, 4.2);
      expect(rows.first.photoPaths, '["a.jpg","b.jpg"]');
      expect(rows.first.conditions, '{"temp_c":18}');
      expect(rows.first.isPending, isTrue);
    });
  });
}
