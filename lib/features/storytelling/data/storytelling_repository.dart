import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_data_source.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_dto.dart';
import 'package:fishing_with_friends/features/storytelling/domain/badge.dart';
import 'package:fishing_with_friends/features/storytelling/domain/personal_record.dart';
import 'package:fishing_with_friends/features/storytelling/domain/save_outcome.dart';
import 'package:fishing_with_friends/features/storytelling/domain/user_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-side orchestrator for storytelling rows. Writes happen in the
/// 0009 trigger; this layer never inserts directly.
class StorytellingRepository {
  StorytellingRepository({required this.dataSource});

  final StorytellingDataSource dataSource;

  Future<List<PersonalRecord>> myPersonalRecords(String anglerId) async {
    if (anglerId.isEmpty) {
      throw const AuthFailure('You must be signed in.');
    }
    try {
      final rows = await dataSource.selectMyPersonalRecords(anglerId);
      return rows.map(PersonalRecordDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load PRs: ${e.message}', cause: e);
    }
  }

  Future<List<Badge>> allBadges() async {
    try {
      final rows = await dataSource.selectAllBadges();
      return rows.map(BadgeDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load badges: ${e.message}', cause: e);
    }
  }

  Future<List<UserBadge>> myUserBadges(String anglerId) async {
    if (anglerId.isEmpty) {
      throw const AuthFailure('You must be signed in.');
    }
    try {
      final rows = await dataSource.selectMyUserBadges(anglerId);
      return rows.map(UserBadgeDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to load earned badges: ${e.message}',
        cause: e,
      );
    }
  }

  /// What did the trigger produce for [catchId]? Returns `SaveOutcome.empty()`
  /// when neither PRs nor badges are tied to this catch.
  Future<SaveOutcome> saveOutcomeFor({
    required String anglerId,
    required String catchId,
  }) async {
    if (anglerId.isEmpty || catchId.isEmpty) {
      return const SaveOutcome.empty();
    }
    try {
      final prRows = await dataSource.selectPRsForCatch(catchId);
      final ubRows = await dataSource.selectUserBadgesForCatch(
        anglerId,
        catchId,
      );
      return SaveOutcome(
        newPRs: prRows.map(PersonalRecordDto.fromRow).toList(growable: false),
        newBadges:
            ubRows.map(UserBadgeDto.fromRow).toList(growable: false),
      );
    } on PostgrestException catch (e) {
      throw NetworkFailure(
        'Failed to load save outcome: ${e.message}',
        cause: e,
      );
    }
  }
}
