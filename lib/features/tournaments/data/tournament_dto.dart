import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_input.dart';

class TournamentDto {
  const TournamentDto._();

  static Tournament fromRow(Map<String, dynamic> row) {
    return Tournament(
      id: row['id'] as String,
      creatorId: row['creator_id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      metric: TournamentMetric.fromId(row['metric'] as String),
      startsAt: DateTime.parse(row['starts_at'] as String).toUtc(),
      endsAt: DateTime.parse(row['ends_at'] as String).toUtc(),
      joinCode: (row['join_code'] as String?) ?? '',
      isClosed: (row['is_closed'] as bool?) ?? false,
      isPublic: (row['is_public'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  }

  static Map<String, dynamic> toInsertRow(
    TournamentInput input, {
    required String creatorId,
  }) {
    return {
      'creator_id': creatorId,
      'name': input.name,
      if (input.description != null) 'description': input.description,
      'metric': input.metric.id,
      'starts_at': input.startsAt.toUtc().toIso8601String(),
      'ends_at': input.endsAt.toUtc().toIso8601String(),
      'is_public': false,
    };
  }
}
