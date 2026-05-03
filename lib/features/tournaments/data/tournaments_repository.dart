import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_dto.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_member_dto.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_data_source.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_input.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_member.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentsRepository {
  TournamentsRepository({required this.dataSource});

  final TournamentsDataSource dataSource;

  Future<Tournament> create(
    TournamentInput input, {
    required String creatorId,
  }) async {
    if (creatorId.isEmpty) {
      throw const AuthFailure('Sign in to create a tournament.');
    }
    if (input.name.trim().isEmpty) {
      throw const ValidationFailure('Tournament needs a name.');
    }
    if (!input.endsAt.isAfter(input.startsAt)) {
      throw const ValidationFailure('End must be after start.');
    }
    try {
      final row = TournamentDto.toInsertRow(input, creatorId: creatorId);
      final inserted = await dataSource.insertTournament(row);
      final tournament = TournamentDto.fromRow(inserted);

      // Bulk-invite friends if any. Creator-picked friends are trusted —
      // they land directly as 'accepted' so they can fish without a
      // pending/approval round-trip. Migration 0028 widens the
      // notify_tournament_invite trigger so 'accepted' inserts still
      // surface a "you've been invited" notification.
      if (input.invitedAnglerIds.isNotEmpty) {
        final memberRows = input.invitedAnglerIds
            .map((id) => {
                  'tournament_id': tournament.id,
                  'angler_id': id,
                  'status': 'accepted',
                })
            .toList();
        await dataSource.insertMembers(memberRows);
      }
      return tournament;
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to create tournament: ${e.message}',
          cause: e);
    }
  }

  Future<Tournament?> getById(String id) async {
    try {
      final row = await dataSource.selectById(id);
      return row == null ? null : TournamentDto.fromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load tournament: ${e.message}',
          cause: e);
    }
  }

  Future<List<Tournament>> getMine(String anglerId) async {
    if (anglerId.isEmpty) return const [];
    try {
      final rows = await dataSource.selectMine(anglerId);
      return rows.map(TournamentDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load tournaments: ${e.message}',
          cause: e);
    }
  }

  Future<Tournament> endTournament(String tournamentId) async {
    try {
      final updated = await dataSource.updateClose(tournamentId);
      return TournamentDto.fromRow(updated);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to end tournament: ${e.message}',
          cause: e);
    }
  }

  /// Hard-delete the tournament. RLS restricts this to the creator.
  /// Members + entries cascade-delete via the FK constraints in 0001.
  Future<void> deleteTournament(String tournamentId) async {
    try {
      await dataSource.deleteTournament(tournamentId);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to delete tournament: ${e.message}',
          cause: e);
    }
  }

  /// Creator-side invite: drop accepted member rows for [anglerIds] under
  /// [tournamentId]. RLS (migration 0022) restricts this to the creator.
  /// Pre-existing rows surface as a friendly unique-violation message.
  ///
  /// Status is `accepted` because the creator picked these friends
  /// explicitly — there's nothing for the invitee to approve. The 0028
  /// trigger relaxation still fires `tournament_invite` notifications
  /// so they see "you've been invited to the tournament" in their feed.
  /// Cold-invite (requestJoinByCode) keeps `pending` so creators can
  /// gate strangers.
  Future<int> inviteMembers({
    required String tournamentId,
    required List<String> anglerIds,
  }) async {
    if (anglerIds.isEmpty) return 0;
    try {
      final rows = anglerIds
          .map(
            (id) => {
              'tournament_id': tournamentId,
              'angler_id': id,
              'status': 'accepted',
            },
          )
          .toList();
      final inserted = await dataSource.insertMembers(rows);
      return inserted.length;
    } on PostgrestException catch (e) {
      // Unique-violation on (tournament_id, angler_id) means the angler
      // is already a member — partial-batch inserts split by the caller
      // make this rare; surface as a friendly message.
      if (e.code == '23505') {
        throw const ValidationFailure(
          'One or more anglers are already in this tournament.',
        );
      }
      throw NetworkFailure('Failed to invite anglers: ${e.message}',
          cause: e);
    }
  }

  /// Look up a tournament by code and request membership. Returns the
  /// tournament on success. Validation surface intentionally identical
  /// for "no tournament with that code" and "RLS denied" so attackers
  /// can't enumerate codes.
  Future<Tournament> requestJoinByCode({
    required String code,
    required String anglerId,
  }) async {
    if (anglerId.isEmpty) {
      throw const AuthFailure('Sign in to join a tournament.');
    }
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Enter a tournament code.');
    }
    try {
      final row = await dataSource.selectByIdOrJoinCode(joinCode: trimmed);
      if (row == null) {
        throw const ValidationFailure('No tournament found for that code.');
      }
      final tournament = TournamentDto.fromRow(row);
      try {
        await dataSource.upsertMemberJoin(
          tournamentId: tournament.id,
          anglerId: anglerId,
        );
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          throw const ValidationFailure(
            "You've already joined this tournament.",
          );
        }
        rethrow;
      }
      return tournament;
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not join tournament: ${e.message}',
          cause: e);
    }
  }

  Future<TournamentMember> approveMember({
    required String tournamentId,
    required String anglerId,
    required String creatorId,
  }) async {
    return _setMemberStatus(
      tournamentId: tournamentId,
      anglerId: anglerId,
      creatorId: creatorId,
      status: 'accepted',
    );
  }

  Future<TournamentMember> rejectMember({
    required String tournamentId,
    required String anglerId,
    required String creatorId,
  }) async {
    return _setMemberStatus(
      tournamentId: tournamentId,
      anglerId: anglerId,
      creatorId: creatorId,
      status: 'rejected',
    );
  }

  Future<List<TournamentMember>> getMembers(String tournamentId) async {
    try {
      final rows = await dataSource.selectMembers(tournamentId);
      return rows.map(TournamentMemberDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load members: ${e.message}', cause: e);
    }
  }

  Future<TournamentMember> _setMemberStatus({
    required String tournamentId,
    required String anglerId,
    required String creatorId,
    required String status,
  }) async {
    try {
      final updated = await dataSource.updateMemberStatus(
        tournamentId: tournamentId,
        anglerId: anglerId,
        status: status,
        approvedBy: creatorId,
      );
      return TournamentMemberDto.fromRow(updated);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not update member: ${e.message}', cause: e);
    }
  }
}
