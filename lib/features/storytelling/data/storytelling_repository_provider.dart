import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_data_source.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_repository.dart';
import 'package:fishing_with_friends/features/storytelling/domain/badge.dart';
import 'package:fishing_with_friends/features/storytelling/domain/personal_record.dart';
import 'package:fishing_with_friends/features/storytelling/domain/save_outcome.dart';
import 'package:fishing_with_friends/features/storytelling/domain/user_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storytellingDataSourceProvider = Provider<StorytellingDataSource>((ref) {
  return SupabaseStorytellingDataSource(ref.watch(supabaseClientProvider));
});

final storytellingRepositoryProvider = Provider<StorytellingRepository>((ref) {
  return StorytellingRepository(
    dataSource: ref.watch(storytellingDataSourceProvider),
  );
});

final myPersonalRecordsProvider =
    FutureProvider<List<PersonalRecord>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(storytellingRepositoryProvider).myPersonalRecords(user.id);
});

final allBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  return ref.watch(storytellingRepositoryProvider).allBadges();
});

final myUserBadgesProvider = FutureProvider<List<UserBadge>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(storytellingRepositoryProvider).myUserBadges(user.id);
});

/// One-shot lookup of what the trigger produced for the given catch id.
final saveOutcomeProvider =
    FutureProvider.family<SaveOutcome, String>((ref, catchId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const SaveOutcome.empty();
  return ref.watch(storytellingRepositoryProvider).saveOutcomeFor(
        anglerId: user.id,
        catchId: catchId,
      );
});
