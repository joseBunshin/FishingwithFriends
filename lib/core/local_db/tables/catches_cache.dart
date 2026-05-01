import 'package:drift/drift.dart';

/// Local mirror of `public.catches` for offline reads + optimistic UI.
/// Rows with [isPending] = true are queued-but-not-yet-synced; the sync
/// orchestrator clears the flag after a successful upload.
class CatchesCache extends Table {
  /// Catch UUID — same id used in the server-side row when synced.
  TextColumn get id => text()();

  TextColumn get anglerId => text().named('angler_id')();

  TextColumn get speciesId => text().named('species_id').nullable()();
  TextColumn get speciesLabel => text().named('species_label').nullable()();

  RealColumn get weightKg => real().named('weight_kg').nullable()();
  RealColumn get lengthCm => real().named('length_cm').nullable()();

  /// Epoch ms.
  IntColumn get caughtAt => integer().named('caught_at')();

  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  BoolColumn get secretSpot =>
      boolean().named('secret_spot').withDefault(const Constant(false))();
  BoolColumn get catchAndRelease =>
      boolean().named('catch_and_release').withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();
  TextColumn get rig => text().nullable()();
  TextColumn get tripId => text().named('trip_id').nullable()();

  /// JSON-encoded `List<String>`.
  TextColumn get photoPaths =>
      text().named('photo_paths').withDefault(const Constant('[]'))();

  /// JSON-encoded map.
  TextColumn get conditions =>
      text().withDefault(const Constant('{}'))();

  /// Epoch ms.
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  /// True when this row reflects a queued (not-yet-synced) catch.
  BoolColumn get isPending =>
      boolean().named('is_pending').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
