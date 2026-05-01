import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:meta/meta.dart';

@immutable
class TournamentInput {
  const TournamentInput({
    required this.name,
    required this.metric,
    required this.startsAt,
    required this.endsAt,
    this.description,
    this.bodyOfWater,
    this.speciesFilter = const [],
    this.invitedAnglerIds = const [],
  });

  final String name;
  final String? description;
  final String? bodyOfWater;
  final TournamentMetric metric;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Optional species_label filter — entries must match one of these
  /// when set. Empty list means all species allowed.
  final List<String> speciesFilter;

  final List<String> invitedAnglerIds;
}
