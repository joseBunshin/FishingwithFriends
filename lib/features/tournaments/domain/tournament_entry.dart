import 'package:meta/meta.dart';

enum TournamentEntryStatus { pending, approved, rejected }

TournamentEntryStatus parseTournamentEntryStatus(String raw) {
  switch (raw) {
    case 'pending':
      return TournamentEntryStatus.pending;
    case 'approved':
      return TournamentEntryStatus.approved;
    case 'rejected':
      return TournamentEntryStatus.rejected;
    default:
      throw ArgumentError.value(
        raw,
        'status',
        'Unknown tournament_entry status',
      );
  }
}

/// A submitted catch within a tournament. Snapshot fields
/// (`speciesLabel`, `weightKg`, `lengthCm`, `photoPath`, `caughtAt`) are
/// copied from the source catch at submission time so non-friend tournament
/// fellows can read the leaderboard without seeing the raw `catches` row.
@immutable
class TournamentEntry {
  const TournamentEntry({
    required this.id,
    required this.tournamentId,
    required this.catchId,
    required this.anglerId,
    required this.status,
    required this.submittedAt,
    this.speciesLabel,
    this.weightKg,
    this.lengthCm,
    this.photoPath,
    this.caughtAt,
    this.approvedAt,
    this.approvedBy,
  });

  final String id;
  final String tournamentId;
  final String catchId;
  final String anglerId;
  final TournamentEntryStatus status;
  final String? speciesLabel;
  final double? weightKg;
  final double? lengthCm;
  final String? photoPath;
  final DateTime? caughtAt;
  final DateTime submittedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  TournamentEntry copyWith({
    String? id,
    String? tournamentId,
    String? catchId,
    String? anglerId,
    TournamentEntryStatus? status,
    String? speciesLabel,
    double? weightKg,
    double? lengthCm,
    String? photoPath,
    DateTime? caughtAt,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? approvedBy,
  }) {
    return TournamentEntry(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      catchId: catchId ?? this.catchId,
      anglerId: anglerId ?? this.anglerId,
      status: status ?? this.status,
      speciesLabel: speciesLabel ?? this.speciesLabel,
      weightKg: weightKg ?? this.weightKg,
      lengthCm: lengthCm ?? this.lengthCm,
      photoPath: photoPath ?? this.photoPath,
      caughtAt: caughtAt ?? this.caughtAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TournamentEntry &&
          other.id == id &&
          other.tournamentId == tournamentId &&
          other.catchId == catchId &&
          other.anglerId == anglerId &&
          other.status == status &&
          other.speciesLabel == speciesLabel &&
          other.weightKg == weightKg &&
          other.lengthCm == lengthCm &&
          other.photoPath == photoPath &&
          other.caughtAt == caughtAt &&
          other.submittedAt == submittedAt &&
          other.approvedAt == approvedAt &&
          other.approvedBy == approvedBy;

  @override
  int get hashCode => Object.hashAll([
        id,
        tournamentId,
        catchId,
        anglerId,
        status,
        speciesLabel,
        weightKg,
        lengthCm,
        photoPath,
        caughtAt,
        submittedAt,
        approvedAt,
        approvedBy,
      ]);
}
