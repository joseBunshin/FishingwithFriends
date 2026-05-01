import 'package:fishing_with_friends/features/storytelling/domain/badge.dart';
import 'package:meta/meta.dart';

@immutable
class UserBadge {
  const UserBadge({
    required this.id,
    required this.anglerId,
    required this.badgeCode,
    required this.earnedAt,
    required this.definition,
    this.sourceCatchId,
  });

  final String id;
  final String anglerId;
  final String badgeCode;
  final DateTime earnedAt;
  final String? sourceCatchId;
  final Badge definition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserBadge &&
          other.id == id &&
          other.anglerId == anglerId &&
          other.badgeCode == badgeCode &&
          other.earnedAt == earnedAt &&
          other.sourceCatchId == sourceCatchId &&
          other.definition == definition;

  @override
  int get hashCode => Object.hash(
        id,
        anglerId,
        badgeCode,
        earnedAt,
        sourceCatchId,
        definition,
      );
}
