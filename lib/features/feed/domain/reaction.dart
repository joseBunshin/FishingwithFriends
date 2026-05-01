import 'package:meta/meta.dart';

/// The five reaction kinds in v1. Stable string keys must match the CHECK
/// constraint in `0005_trips_and_social.sql` (`feed_reactions.kind`).
enum ReactionKind {
  rod('rod', '🎣', 'Catch'),
  fire('fire', '🔥', 'Fire'),
  fist('fist', '👊', 'Strong'),
  mind('mind', '🤯', 'Mind blown'),
  handshake('handshake', '🤝', 'Respect');

  const ReactionKind(this.id, this.emoji, this.label);

  final String id;
  final String emoji;
  final String label;

  static ReactionKind fromId(String id) {
    return ReactionKind.values.firstWhere(
      (k) => k.id == id,
      orElse: () =>
          throw ArgumentError.value(id, 'id', 'Unknown reaction kind'),
    );
  }
}

@immutable
class Reaction {
  const Reaction({
    required this.catchId,
    required this.userId,
    required this.kind,
    required this.createdAt,
  });

  final String catchId;
  final String userId;
  final ReactionKind kind;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reaction &&
          other.catchId == catchId &&
          other.userId == userId &&
          other.kind == kind &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(catchId, userId, kind, createdAt);
}
