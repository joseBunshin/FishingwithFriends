import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_data_source.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_input.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_member.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeDataSource implements TournamentsDataSource {
  Map<String, dynamic>? lookupByCode;
  bool throwUniqueOnUpsert = false;

  @override
  Future<Map<String, dynamic>> insertTournament(
    Map<String, dynamic> row,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      ...row,
      'id': 'tttttttt-tttt-tttt-tttt-tttttttttttt',
      'join_code': 'abcd1234',
      'is_closed': false,
      'created_at': now,
      'updated_at': now,
    };
  }

  @override
  Future<Map<String, dynamic>?> selectByIdOrJoinCode({
    String? id,
    String? joinCode,
  }) async => lookupByCode;

  @override
  Future<Map<String, dynamic>?> selectById(String id) async => null;

  @override
  Future<List<Map<String, dynamic>>> selectMine(String anglerId) async => const [];

  bool deletedCalled = false;

  @override
  Future<void> deleteTournament(String tournamentId) async {
    deletedCalled = true;
  }

  @override
  Future<Map<String, dynamic>> updateClose(String tournamentId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': tournamentId,
      'creator_id': 'c',
      'name': 'X',
      'description': null,
      'metric': 'weight',
      'starts_at': '2026-04-12T10:00:00.000Z',
      'ends_at': '2026-04-12T18:00:00.000Z',
      'join_code': 'abcd1234',
      'is_closed': true,
      'is_public': false,
      'created_at': '2026-04-12T08:00:00.000Z',
      'updated_at': now,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> insertMembers(
    List<Map<String, dynamic>> rows,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return rows
        .map((r) => {...r, 'created_at': now, 'updated_at': now})
        .toList();
  }

  @override
  Future<Map<String, dynamic>> upsertMemberJoin({
    required String tournamentId,
    required String anglerId,
  }) async {
    if (throwUniqueOnUpsert) {
      throw const PostgrestException(message: 'duplicate', code: '23505');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'tournament_id': tournamentId,
      'angler_id': anglerId,
      'status': 'pending',
      'approved_by': null,
      'created_at': now,
      'updated_at': now,
    };
  }

  @override
  Future<Map<String, dynamic>> updateMemberStatus({
    required String tournamentId,
    required String anglerId,
    required String status,
    required String approvedBy,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'tournament_id': tournamentId,
      'angler_id': anglerId,
      'status': status,
      'approved_by': approvedBy,
      'created_at': '2026-04-12T08:00:00.000Z',
      'updated_at': now,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> selectMembers(
    String tournamentId,
  ) async => const [];
}

TournamentInput _validInput() => TournamentInput(
      name: 'Spring Cup',
      metric: TournamentMetric.weight,
      startsAt: DateTime.utc(2026, 4, 12, 10),
      endsAt: DateTime.utc(2026, 4, 12, 18),
    );

Map<String, dynamic> _tournamentRow({String code = 'abcd1234'}) {
  return {
    'id': 'tttttttt-tttt-tttt-tttt-tttttttttttt',
    'creator_id': 'c',
    'name': 'Spring Cup',
    'description': null,
    'metric': 'weight',
    'starts_at': '2026-04-12T10:00:00.000Z',
    'ends_at': '2026-04-12T18:00:00.000Z',
    'join_code': code,
    'is_closed': false,
    'is_public': false,
    'created_at': '2026-04-12T08:00:00.000Z',
    'updated_at': '2026-04-12T08:00:00.000Z',
  };
}

void main() {
  group('TournamentsRepository.create', () {
    test('happy path: returns Tournament with join_code populated', () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      final t = await repo.create(_validInput(), creatorId: 'c1');
      expect(t.joinCode, 'abcd1234');
      expect(t.isClosed, isFalse);
    });

    test('rejects empty creatorId with AuthFailure', () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      await expectLater(
        () => repo.create(_validInput(), creatorId: ''),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('rejects ends ≤ starts with ValidationFailure', () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      final input = TournamentInput(
        name: 'Bad',
        metric: TournamentMetric.weight,
        startsAt: DateTime.utc(2026, 4, 12, 18),
        endsAt: DateTime.utc(2026, 4, 12, 10),
      );
      await expectLater(
        () => repo.create(input, creatorId: 'c1'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('TournamentsRepository.requestJoinByCode (privacy load-bearing)', () {
    test('valid code → success returns Tournament', () async {
      final ds = _FakeDataSource()..lookupByCode = _tournamentRow();
      final repo = TournamentsRepository(dataSource: ds);
      final t = await repo.requestJoinByCode(
        code: 'abcd1234',
        anglerId: 'angler-1',
      );
      expect(t.joinCode, 'abcd1234');
    });

    test('unknown code → ValidationFailure (does NOT leak existence)',
        () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      await expectLater(
        () => repo.requestJoinByCode(
          code: 'deadbeef',
          anglerId: 'angler-1',
        ),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('No tournament found'),
        )),
      );
    });

    test('empty code → ValidationFailure', () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      await expectLater(
        () =>
            repo.requestJoinByCode(code: '   ', anglerId: 'angler-1'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('empty anglerId → AuthFailure', () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      await expectLater(
        () => repo.requestJoinByCode(code: 'abcd1234', anglerId: ''),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('duplicate join (already a member) → friendly ValidationFailure',
        () async {
      final ds = _FakeDataSource()
        ..lookupByCode = _tournamentRow()
        ..throwUniqueOnUpsert = true;
      final repo = TournamentsRepository(dataSource: ds);
      await expectLater(
        () => repo.requestJoinByCode(
          code: 'abcd1234',
          anglerId: 'angler-1',
        ),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('already joined'),
        )),
      );
    });
  });

  group('TournamentsRepository.approve/reject/end', () {
    test('approveMember flips status to accepted', () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      final m = await repo.approveMember(
        tournamentId: 't1',
        anglerId: 'a1',
        creatorId: 'c1',
      );
      expect(m.status, TournamentMemberStatus.accepted);
      expect(m.approvedBy, 'c1');
    });

    test('rejectMember flips status to rejected', () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      final m = await repo.rejectMember(
        tournamentId: 't1',
        anglerId: 'a1',
        creatorId: 'c1',
      );
      expect(m.status, TournamentMemberStatus.rejected);
    });

    test('endTournament flips is_closed=true', () async {
      final repo = TournamentsRepository(dataSource: _FakeDataSource());
      final t = await repo.endTournament('t1');
      expect(t.isClosed, isTrue);
    });
  });
}
