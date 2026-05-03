import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';

class TournamentEntryDto {
  const TournamentEntryDto._();

  static TournamentEntry fromRow(Map<String, dynamic> row) {
    return TournamentEntry(
      id: row['id'] as String,
      tournamentId: row['tournament_id'] as String,
      catchId: row['catch_id'] as String,
      anglerId: row['angler_id'] as String,
      status: parseTournamentEntryStatus(row['status'] as String),
      speciesLabel: row['species_label'] as String?,
      weightKg: _asDouble(row['weight_kg']),
      lengthCm: _asDouble(row['length_cm']),
      photoPath: row['photo_path'] as String?,
      caughtAt: row['caught_at'] == null
          ? null
          : DateTime.parse(row['caught_at'] as String).toUtc(),
      submittedAt: DateTime.parse(row['submitted_at'] as String).toUtc(),
      approvedAt: row['approved_at'] == null
          ? null
          : DateTime.parse(row['approved_at'] as String).toUtc(),
      approvedBy: row['approved_by'] as String?,
    );
  }

  /// Build the row the submit-entry call inserts. The angler-side caller
  /// constructs a snapshot of the source catch and hands it in here.
  static Map<String, dynamic> toInsertRow({
    required String tournamentId,
    required String catchId,
    required String anglerId,
    String? speciesLabel,
    double? weightKg,
    double? lengthCm,
    String? photoPath,
    DateTime? caughtAt,
  }) {
    return {
      'tournament_id': tournamentId,
      'catch_id': catchId,
      'angler_id': anglerId,
      'status': 'pending',
      if (speciesLabel != null) 'species_label': speciesLabel,
      if (weightKg != null) 'weight_kg': weightKg,
      if (lengthCm != null) 'length_cm': lengthCm,
      if (photoPath != null) 'photo_path': photoPath,
      if (caughtAt != null) 'caught_at': caughtAt.toUtc().toIso8601String(),
    };
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
