import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/catches/data/catches_data_source.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository.dart';
import 'package:fishing_with_friends/features/catches/data/photo_storage.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final photoStorageProvider = Provider<PhotoStorage>((ref) {
  return SupabasePhotoStorage(ref.watch(supabaseClientProvider));
});

final catchesDataSourceProvider = Provider<CatchesDataSource>((ref) {
  return SupabaseCatchesDataSource(ref.watch(supabaseClientProvider));
});

final catchesRepositoryProvider = Provider<CatchesRepository>((ref) {
  return CatchesRepository(
    dataSource: ref.watch(catchesDataSourceProvider),
    storage: ref.watch(photoStorageProvider),
  );
});

/// Logged-in user's own catches, ordered newest first.
final myCatchesProvider = FutureProvider<List<Catch>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(catchesRepositoryProvider).getMine(user.id);
});

/// Single catch by id. Owner sees their own row including raw GPS;
/// friend sees the friend-view row with location nulled when secret_spot=true.
final catchByIdProvider = FutureProvider.family<Catch?, String>((ref, id) {
  return ref.watch(catchesRepositoryProvider).getById(id);
});
