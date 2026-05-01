import 'package:meta/meta.dart';

@immutable
class Comment {
  const Comment({
    required this.id,
    required this.catchId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String catchId;
  final String authorId;
  final String body;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDeleted => deletedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment &&
          other.id == id &&
          other.catchId == catchId &&
          other.authorId == authorId &&
          other.body == body &&
          other.deletedAt == deletedAt &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        catchId,
        authorId,
        body,
        deletedAt,
        createdAt,
        updatedAt,
      );
}
