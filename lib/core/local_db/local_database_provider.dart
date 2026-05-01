import 'package:fishing_with_friends/core/local_db/local_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Singleton local DB instance — opened lazily on first access, closed
/// when the provider is disposed (app shutdown).
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase();
  ref.onDispose(db.close);
  return db;
});
