import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:meta/meta.dart';

@immutable
class TournamentSidePot {
  const TournamentSidePot({
    required this.id,
    required this.tournamentId,
    required this.name,
    required this.metric,
    required this.createdAt,
    this.speciesFilter,
  });

  final String id;
  final String tournamentId;
  final String name;
  final TournamentMetric metric;
  final String? speciesFilter;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TournamentSidePot &&
          other.id == id &&
          other.tournamentId == tournamentId &&
          other.name == name &&
          other.metric == metric &&
          other.speciesFilter == speciesFilter &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        tournamentId,
        name,
        metric,
        speciesFilter,
        createdAt,
      );
}
