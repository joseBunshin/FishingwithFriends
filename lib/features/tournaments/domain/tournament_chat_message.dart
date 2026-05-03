import 'package:meta/meta.dart';

@immutable
class TournamentChatMessage {
  const TournamentChatMessage({
    required this.id,
    required this.tournamentId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String tournamentId;
  final String authorId;
  final String body;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDeleted => deletedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TournamentChatMessage &&
          other.id == id &&
          other.tournamentId == tournamentId &&
          other.authorId == authorId &&
          other.body == body &&
          other.deletedAt == deletedAt &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        tournamentId,
        authorId,
        body,
        deletedAt,
        createdAt,
        updatedAt,
      );
}
