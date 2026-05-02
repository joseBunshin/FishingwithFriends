import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fishing_with_friends/core/local_db/local_database.dart';
import 'package:fishing_with_friends/core/local_db/local_database_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pending (queued, not-yet-synced) catches read straight from the
/// `catches_cache` drift table. Lives here, not in the catches feature,
/// so the catches_repository_provider can consume it without importing
/// the offline orchestrator (which would form a cycle).
///
/// On web the offline stack is disabled (drift requires a WASM bundle
/// we don't ship); always emits an empty list there.
final pendingCatchesProvider = StreamProvider<List<Catch>>((ref) {
  if (kIsWeb) return Stream.value(const <Catch>[]);
  final db = ref.watch(localDatabaseProvider);
  final query = db.select(db.catchesCache)
    ..where((t) => t.isPending.equals(true))
    ..orderBy([(t) => OrderingTerm.desc(t.caughtAt)]);
  return query.watch().map(
        (rows) =>
            rows.map(_cacheRowToDomain).toList(growable: false),
      );
});

/// Efficient `contains` lookup for tiles deciding whether to render an
/// upload-pending badge.
final pendingCatchIdsProvider = Provider<Set<String>>((ref) {
  final pending =
      ref.watch(pendingCatchesProvider).valueOrNull ?? const <Catch>[];
  return {for (final c in pending) c.id};
});

Catch _cacheRowToDomain(CatchesCacheData row) {
  return Catch(
    id: row.id,
    anglerId: row.anglerId,
    speciesId: row.speciesId,
    speciesLabel: row.speciesLabel,
    weightKg: row.weightKg,
    lengthCm: row.lengthCm,
    caughtAt: DateTime.fromMillisecondsSinceEpoch(row.caughtAt, isUtc: true),
    latitude: row.latitude,
    longitude: row.longitude,
    secretSpot: row.secretSpot,
    catchAndRelease: row.catchAndRelease,
    notes: row.notes,
    rig: row.rig,
    tripId: row.tripId,
    photoPaths: List<String>.from(
      (jsonDecode(row.photoPaths) as List?) ?? const <String>[],
    ),
    conditions: Map<String, dynamic>.from(
      (jsonDecode(row.conditions) as Map?) ?? const <String, dynamic>{},
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
  );
}
