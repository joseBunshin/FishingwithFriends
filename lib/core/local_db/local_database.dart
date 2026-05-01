import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fishing_with_friends/core/local_db/tables/catches_cache.dart';
import 'package:fishing_with_friends/core/local_db/tables/outbox.dart';

part 'local_database.g.dart';

/// Singleton drift database for offline-first persistence.
///
/// Holds the durable outbox queue and the catches read-cache. Opened
/// once at app boot (see `local_database_provider.dart`) and closed on
/// dispose.
@DriftDatabase(tables: [Outbox, CatchesCache])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  /// Test-only constructor — pass an in-memory or otherwise-pre-built
  /// executor. The default factory uses `drift_flutter`'s native bridge.
  LocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'fwf_local_db');
}
