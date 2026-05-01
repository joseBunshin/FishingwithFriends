import 'package:fishing_with_friends/core/local_db/local_database_provider.dart';
import 'package:fishing_with_friends/features/sync/data/outbox_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  return OutboxRepository(ref.watch(localDatabaseProvider));
});

final pendingOutboxCountProvider = StreamProvider<int>((ref) {
  return ref.watch(outboxRepositoryProvider).pendingCountStream();
});
