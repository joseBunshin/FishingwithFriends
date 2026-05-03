import 'package:meta/meta.dart';

enum TournamentMemberStatus { pending, accepted, rejected }

TournamentMemberStatus parseTournamentMemberStatus(String raw) {
  switch (raw) {
    case 'pending':
      return TournamentMemberStatus.pending;
    case 'accepted':
      return TournamentMemberStatus.accepted;
    case 'rejected':
      return TournamentMemberStatus.rejected;
    default:
      throw ArgumentError.value(
        raw,
        'status',
        'Unknown tournament_member status',
      );
  }
}

@immutable
class TournamentMember {
  const TournamentMember({
    required this.tournamentId,
    required this.anglerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedBy,
  });

  final String tournamentId;
  final String anglerId;
  final TournamentMemberStatus status;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TournamentMember &&
          other.tournamentId == tournamentId &&
          other.anglerId == anglerId &&
          other.status == status &&
          other.approvedBy == approvedBy &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        tournamentId,
        anglerId,
        status,
        approvedBy,
        createdAt,
        updatedAt,
      );
}
