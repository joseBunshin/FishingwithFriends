import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_side_pot.dart';

class TournamentSidePotDto {
  const TournamentSidePotDto._();

  static TournamentSidePot fromRow(Map<String, dynamic> row) {
    return TournamentSidePot(
      id: row['id'] as String,
      tournamentId: row['tournament_id'] as String,
      name: row['name'] as String,
      metric: TournamentMetric.fromId(row['metric'] as String),
      speciesFilter: row['species_filter'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }

  static Map<String, dynamic> toInsertRow({
    required String tournamentId,
    required String name,
    required TournamentMetric metric,
    String? speciesFilter,
  }) {
    return {
      'tournament_id': tournamentId,
      'name': name,
      'metric': metric.id,
      if (speciesFilter != null) 'species_filter': speciesFilter,
    };
  }
}
