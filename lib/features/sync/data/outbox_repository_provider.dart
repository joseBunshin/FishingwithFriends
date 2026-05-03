import 'package:fishing_with_friends/core/local_db/local_database_provider.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  return OutboxRepository(ref.watch(localDatabaseProvider));
});

/// Stream of pending+uploading+failed outbox counts. Drives the SyncPill
/// in the app bar. On web, the offline stack is disabled (drift requires
/// a WASM bundle we don't ship); always emits 0 there.
final pendingOutboxCountProvider = StreamProvider<int>((ref) {
  if (kIsWeb) return Stream.value(0);
  return ref.watch(outboxRepositoryProvider).pendingCountStream();
});
