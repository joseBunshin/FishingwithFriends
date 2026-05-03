import 'package:meta/meta.dart';

enum FriendshipStatus { pending, accepted, blocked }

@immutable
class Friendship {
  const Friendship({
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns the *other* angler's id given the current user.
  String otherSide(String currentUserId) =>
      requesterId == currentUserId ? addresseeId : requesterId;

  bool involves(String userId) =>
      requesterId == userId || addresseeId == userId;

  static FriendshipStatus parseStatus(String raw) {
    switch (raw) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        throw ArgumentError.value(raw, 'status', 'Unknown friendship status');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friendship &&
          other.requesterId == requesterId &&
          other.addresseeId == addresseeId &&
          other.status == status &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(requesterId, addresseeId, status, createdAt, updatedAt);
}
