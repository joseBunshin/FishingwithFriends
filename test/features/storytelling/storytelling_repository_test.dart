import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_data_source.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_repository.dart';
import 'package:fishing_with_friends/features/storytelling/domain/personal_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecordingDataSource implements StorytellingDataSource {
  List<Map<String, dynamic>> myPRs = [];
  List<Map<String, dynamic>> allBadges = [];
  List<Map<String, dynamic>> myUserBadges = [];
  List<Map<String, dynamic>> prsForCatch = [];
  List<Map<String, dynamic>> userBadgesForCatch = [];
  bool throwOnPRs = false;

  @override
  Future<List<Map<String, dynamic>>> selectMyPersonalRecords(
    String anglerId,
  ) async {
    if (throwOnPRs) {
      throw const PostgrestException(message: 'boom');
    }
    return myPRs;
  }

  @override
  Future<List<Map<String, dynamic>>> selectAllBadges() async => allBadges;

  @override
  Future<List<Map<String, dynamic>>> selectMyUserBadges(
    String anglerId,
  ) async => myUserBadges;

  @override
  Future<List<Map<String, dynamic>>> selectPRsForCatch(String catchId) async =>
      prsForCatch;

  @override
  Future<List<Map<String, dynamic>>> selectUserBadgesForCatch(
    String anglerId,
    String catchId,
  ) async => userBadgesForCatch;
}

Map<String, dynamic> _badgeRow({
  String code = 'first_catch',
  String title = 'First Catch',
  String description = 'Your first catch',
  String iconName = 'set_meal',
  String predicate = 'first_catch',
  Map<String, dynamic> params = const {},
}) {
  return {
    'code': code,
    'title': title,
    'description': description,
    'icon_name': iconName,
    'predicate': predicate,
    'params': params,
  };
}

Map<String, dynamic> _prRow({
  String id = 'pr-1',
  String anglerId = 'u1',
  String? speciesId = 'sp-1',
  String speciesLabel = 'Largemouth',
  String metric = 'weight_kg',
  double value = 4.5,
  String catchId = 'c-1',
  String achievedAt = '2026-04-01T12:00:00Z',
}) {
  return {
    'id': id,
    'angler_id': anglerId,
    'species_id': speciesId,
    'metric': metric,
    'value': value,
    'catch_id': catchId,
    'achieved_at': achievedAt,
    'species': {'common_name': speciesLabel},
  };
}

Map<String, dynamic> _userBadgeRow({
  String id = 'ub-1',
  String anglerId = 'u1',
  String code = 'first_catch',
  String earnedAt = '2026-04-01T12:00:00Z',
  String? sourceCatchId = 'c-1',
}) {
  return {
    'id': id,
    'angler_id': anglerId,
    'badge_code': code,
    'earned_at': earnedAt,
    'source_catch_id': sourceCatchId,
    'badges': _badgeRow(code: code),
  };
}

void main() {
  group('StorytellingRepository.myPersonalRecords', () {
    test('maps rows to PersonalRecord with species label', () async {
      final ds = _RecordingDataSource()..myPRs = [_prRow()];
      final repo = StorytellingRepository(dataSource: ds);
      final result = await repo.myPersonalRecords('u1');
      expect(result, hasLength(1));
      expect(result.first.speciesLabel, 'Largemouth');
      expect(result.first.metric, PrMetric.weightKg);
      expect(result.first.value, 4.5);
    });

    test('throws AuthFailure on empty angler id', () async {
      final repo = StorytellingRepository(dataSource: _RecordingDataSource());
      expect(
        () => repo.myPersonalRecords(''),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('wraps PostgrestException in NetworkFailure', () async {
      final ds = _RecordingDataSource()..throwOnPRs = true;
      final repo = StorytellingRepository(dataSource: ds);
      expect(
        () => repo.myPersonalRecords('u1'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('StorytellingRepository.saveOutcomeFor', () {
    test('returns empty outcome when both reads come back empty', () async {
      final repo = StorytellingRepository(dataSource: _RecordingDataSource());
      final outcome = await repo.saveOutcomeFor(
        anglerId: 'u1',
        catchId: 'c-1',
      );
      expect(outcome.isCelebratory, isFalse);
      expect(outcome.totalCount, 0);
    });

    test('returns celebratory outcome when PR rows are present', () async {
      final ds = _RecordingDataSource()..prsForCatch = [_prRow()];
      final repo = StorytellingRepository(dataSource: ds);
      final outcome = await repo.saveOutcomeFor(
        anglerId: 'u1',
        catchId: 'c-1',
      );
      expect(outcome.isCelebratory, isTrue);
      expect(outcome.newPRs, hasLength(1));
      expect(outcome.newBadges, isEmpty);
    });

    test('returns celebratory outcome when badge rows are present', () async {
      final ds = _RecordingDataSource()..userBadgesForCatch = [_userBadgeRow()];
      final repo = StorytellingRepository(dataSource: ds);
      final outcome = await repo.saveOutcomeFor(
        anglerId: 'u1',
        catchId: 'c-1',
      );
      expect(outcome.isCelebratory, isTrue);
      expect(outcome.newBadges, hasLength(1));
      expect(outcome.newBadges.first.definition.code, 'first_catch');
    });

    test('returns empty outcome on empty ids without dispatching', () async {
      final repo = StorytellingRepository(dataSource: _RecordingDataSource());
      expect(
        (await repo.saveOutcomeFor(anglerId: '', catchId: '')).isCelebratory,
        isFalse,
      );
    });
  });

  group('StorytellingRepository.allBadges', () {
    test('returns mapped Badge values', () async {
      final ds = _RecordingDataSource()
        ..allBadges = [_badgeRow(), _badgeRow(code: 'ten_catches')];
      final repo = StorytellingRepository(dataSource: ds);
      final badges = await repo.allBadges();
      expect(badges, hasLength(2));
      expect(badges.first.code, 'first_catch');
      expect(badges[1].code, 'ten_catches');
    });
  });
}
