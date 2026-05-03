import 'package:drift/drift.dart';

/// Single durable queue of outbound operations. Insertion order = drain
/// order. Photo uploads typically precede their parent catch_create in
/// the queue so they land in storage before the row references the path.
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// One of: 'catch_create', 'entry_create', 'photo_upload'.
  TextColumn get opType => text().named('op_type')();

  /// JSON payload — shape varies by opType. Decoded by typed sealed
  /// classes in OutboxOp.
  TextColumn get payload => text()();

  /// One of: 'pending', 'uploading', 'failed', 'permanently_failed', 'synced'.
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();

  IntColumn get retryCount =>
      integer().named('retry_count').withDefault(const Constant(0))();

  /// Epoch ms of last attempt; null when never attempted.
  IntColumn get lastAttemptAt =>
      integer().named('last_attempt_at').nullable()();

  /// Last error message, useful when status='failed' or 'permanently_failed'.
  TextColumn get lastError =>
      text().named('last_error').nullable()();

  /// Epoch ms of insertion. Used for FIFO ordering.
  IntColumn get createdAt => integer().named('created_at')();
}
