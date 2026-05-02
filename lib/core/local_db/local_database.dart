import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fishing_with_friends/core/local_db/tables/catches_cache.dart';
import 'package:fishing_with_friends/core/local_db/tables/outbox.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  // On web we provide DriftWebOptions to satisfy the constructor, but the
  // offline-first stack is gated behind kIsWeb upstream — no queries
  // actually run, so the WASM bundle is never loaded.
  return driftDatabase(
    name: 'fwf_local_db',
    web: kIsWeb
        ? DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          )
        : null,
  );
}
