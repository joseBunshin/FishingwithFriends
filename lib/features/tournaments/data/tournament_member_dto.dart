import 'package:fishing_with_friends/features/tournaments/domain/tournament_member.dart';

class TournamentMemberDto {
  const TournamentMemberDto._();

  static TournamentMember fromRow(Map<String, dynamic> row) {
    return TournamentMember(
      tournamentId: row['tournament_id'] as String,
      anglerId: row['angler_id'] as String,
      status: parseTournamentMemberStatus(row['status'] as String),
      approvedBy: row['approved_by'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  }
}
