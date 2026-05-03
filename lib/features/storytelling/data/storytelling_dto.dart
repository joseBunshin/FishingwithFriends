import 'package:fishing_with_friends/features/storytelling/domain/badge.dart';
import 'package:fishing_with_friends/features/storytelling/domain/personal_record.dart';
import 'package:fishing_with_friends/features/storytelling/domain/user_badge.dart';

/// Maps Postgrest rows to storytelling domain values.
class PersonalRecordDto {
  const PersonalRecordDto._();

  /// Expects a row that may join `species(common_name)` for the label.
  static PersonalRecord fromRow(Map<String, dynamic> row) {
    final species = row['species'];
    final speciesLabel = species is Map<String, dynamic>
        ? species['common_name'] as String?
        : null;
    return PersonalRecord(
      id: row['id'] as String,
      anglerId: row['angler_id'] as String,
      speciesId: row['species_id'] as String?,
      speciesLabel: speciesLabel,
      metric: PrMetricX.parse(row['metric'] as String),
      value: (row['value'] as num).toDouble(),
      catchId: row['catch_id'] as String,
      achievedAt: DateTime.parse(row['achieved_at'] as String).toUtc(),
    );
  }
}

class BadgeDto {
  const BadgeDto._();

  static Badge fromRow(Map<String, dynamic> row) {
    final params = row['params'];
    return Badge(
      code: row['code'] as String,
      title: row['title'] as String,
      description: row['description'] as String,
      iconName: row['icon_name'] as String,
      predicate: row['predicate'] as String,
      params: params is Map<String, dynamic>
          ? Map<String, dynamic>.from(params)
          : const {},
    );
  }
}

class UserBadgeDto {
  const UserBadgeDto._();

  /// Expects a row joined with `badges(*)` so the definition is inline.
  static UserBadge fromRow(Map<String, dynamic> row) {
    final def = row['badges'];
    if (def is! Map<String, dynamic>) {
      throw const FormatException(
        'user_badges row missing joined badges definition',
      );
    }
    return UserBadge(
      id: row['id'] as String,
      anglerId: row['angler_id'] as String,
      badgeCode: row['badge_code'] as String,
      earnedAt: DateTime.parse(row['earned_at'] as String).toUtc(),
      sourceCatchId: row['source_catch_id'] as String?,
      definition: BadgeDto.fromRow(def),
    );
  }
}
