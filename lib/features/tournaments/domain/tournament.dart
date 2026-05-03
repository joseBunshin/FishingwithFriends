import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:meta/meta.dart';

/// Scoring metric. Mirrors the `tournament_metric` enum in the DB.
/// New `biggestSingle` value is reserved for side-pot use.
enum TournamentMetric {
  weight('weight', 'Total Weight'),
  length('length', 'Total Length'),
  biggestFish('biggest_fish', 'Biggest Fish'),
  mostCatches('most_catches', 'Most Catches'),
  longestCatch('longest_catch', 'Longest Catch'),
  biggestSingle('biggest_single', 'Biggest Single Catch');

  const TournamentMetric(this.id, this.label);

  final String id;
  final String label;

  static TournamentMetric fromId(String id) {
    return TournamentMetric.values.firstWhere(
      (m) => m.id == id,
      orElse: () => throw ArgumentError.value(id, 'id', 'Unknown metric'),
    );
  }

  static TournamentMetric? tryFromId(String id) {
    for (final m in TournamentMetric.values) {
      if (m.id == id) return m;
    }
    return null;
  }
}

@immutable
class Tournament {
  const Tournament({
    required this.id,
    required this.creatorId,
    required this.name,
    required this.metric,
    required this.startsAt,
    required this.endsAt,
    required this.joinCode,
    required this.isClosed,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  final String id;
  final String creatorId;
  final String name;
  final String? description;
  final TournamentMetric metric;
  final DateTime startsAt;
  final DateTime endsAt;
  final String joinCode;
  final bool isClosed;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  TournamentPhase phaseAt(DateTime now) => phaseFor(
        startsAt: startsAt,
        endsAt: endsAt,
        isClosed: isClosed,
        now: now,
      );

  Tournament copyWith({
    String? id,
    String? creatorId,
    String? name,
    String? description,
    TournamentMetric? metric,
    DateTime? startsAt,
    DateTime? endsAt,
    String? joinCode,
    bool? isClosed,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tournament(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      description: description ?? this.description,
      metric: metric ?? this.metric,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      joinCode: joinCode ?? this.joinCode,
      isClosed: isClosed ?? this.isClosed,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tournament &&
          other.id == id &&
          other.creatorId == creatorId &&
          other.name == name &&
          other.description == description &&
          other.metric == metric &&
          other.startsAt == startsAt &&
          other.endsAt == endsAt &&
          other.joinCode == joinCode &&
          other.isClosed == isClosed &&
          other.isPublic == isPublic &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll([
        id,
        creatorId,
        name,
        description,
        metric,
        startsAt,
        endsAt,
        joinCode,
        isClosed,
        isPublic,
        createdAt,
        updatedAt,
      ]);
}
