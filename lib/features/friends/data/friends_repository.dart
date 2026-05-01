import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/friends/data/friends_data_source.dart';
import 'package:fishing_with_friends/features/friends/domain/friendship.dart';
import 'package:fishing_with_friends/features/friends/domain/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Friend-graph operations layered on top of `friendships` + `profiles`.
class FriendsRepository {
  FriendsRepository({required this.dataSource});

  final FriendsDataSource dataSource;

  Future<List<Profile>> search({
    required String query,
    required String currentUserId,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      throw const ValidationFailure(
        'Enter at least 2 characters to search.',
      );
    }
    if (currentUserId.isEmpty) {
      throw const AuthFailure('Sign in to search anglers.');
    }
    try {
      final rows = await dataSource.searchProfiles(
        query: trimmed,
        currentUserId: currentUserId,
      );
      return rows.map(_profileFromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Search failed: ${e.message}', cause: e);
    }
  }

  Future<Friendship> sendRequest({
    required String currentUserId,
    required String addresseeId,
  }) async {
    if (currentUserId.isEmpty) {
      throw const AuthFailure('Sign in to send a friend request.');
    }
    if (currentUserId == addresseeId) {
      throw const ValidationFailure("You can't friend yourself.");
    }
    try {
      final row = await dataSource.insertFriendship(
        requesterId: currentUserId,
        addresseeId: addresseeId,
      );
      return _friendshipFromRow(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ValidationFailure(
          "You've already sent a request or you're already friends.",
        );
      }
      throw NetworkFailure('Could not send request: ${e.message}', cause: e);
    }
  }

  Future<Friendship> accept(Friendship friendship) async {
    return _setStatus(friendship, 'accepted');
  }

  Future<void> reject(Friendship friendship) async {
    try {
      await dataSource.deleteFriendship(
        userA: friendship.requesterId,
        userB: friendship.addresseeId,
      );
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not reject request: ${e.message}', cause: e);
    }
  }

  Future<void> removeFriend({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      await dataSource.deleteFriendship(
        userA: currentUserId,
        userB: otherUserId,
      );
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not remove friend: ${e.message}', cause: e);
    }
  }

  Future<FriendsBundle> loadFor(String currentUserId) async {
    if (currentUserId.isEmpty) {
      return const FriendsBundle(
        accepted: [],
        pendingIncoming: [],
        pendingOutgoing: [],
        profilesById: {},
      );
    }
    try {
      final rows = await dataSource.selectFriendshipsForUser(currentUserId);
      final friendships = rows.map(_friendshipFromRow).toList();

      final accepted = <Friendship>[];
      final incoming = <Friendship>[];
      final outgoing = <Friendship>[];
      final otherIds = <String>{};

      for (final f in friendships) {
        final other = f.otherSide(currentUserId);
        otherIds.add(other);
        switch (f.status) {
          case FriendshipStatus.accepted:
            accepted.add(f);
          case FriendshipStatus.pending:
            if (f.addresseeId == currentUserId) {
              incoming.add(f);
            } else {
              outgoing.add(f);
            }
          case FriendshipStatus.blocked:
            // Surfaced separately later; not part of M2 scope.
            break;
        }
      }

      final profileRows = await dataSource.selectProfilesByIds(otherIds.toList());
      final profilesById = <String, Profile>{
        for (final row in profileRows) (row['id'] as String): _profileFromRow(row),
      };

      return FriendsBundle(
        accepted: accepted,
        pendingIncoming: incoming,
        pendingOutgoing: outgoing,
        profilesById: profilesById,
      );
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not load friends: ${e.message}', cause: e);
    }
  }

  Future<Friendship> _setStatus(Friendship f, String status) async {
    try {
      final row = await dataSource.updateStatus(
        requesterId: f.requesterId,
        addresseeId: f.addresseeId,
        status: status,
      );
      return _friendshipFromRow(row);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not update friendship: ${e.message}',
          cause: e);
    }
  }

  static Profile _profileFromRow(Map<String, dynamic> row) {
    return Profile(
      id: row['id'] as String,
      username: row['username'] as String,
      displayName: row['display_name'] as String?,
      avatarPath: row['avatar_path'] as String?,
    );
  }

  static Friendship _friendshipFromRow(Map<String, dynamic> row) {
    return Friendship(
      requesterId: row['requester_id'] as String,
      addresseeId: row['addressee_id'] as String,
      status: Friendship.parseStatus(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  }
}

/// Composite read result returned by `loadFor` so the Friends screen can
/// render its three sections from a single round trip.
class FriendsBundle {
  const FriendsBundle({
    required this.accepted,
    required this.pendingIncoming,
    required this.pendingOutgoing,
    required this.profilesById,
  });

  final List<Friendship> accepted;
  final List<Friendship> pendingIncoming;
  final List<Friendship> pendingOutgoing;
  final Map<String, Profile> profilesById;

  bool get isEmpty =>
      accepted.isEmpty && pendingIncoming.isEmpty && pendingOutgoing.isEmpty;

  /// Returns the *other* angler's id for each accepted friendship,
  /// relative to the bundle owner ([currentUserId]).
  List<String> acceptedFriendIds(String currentUserId) {
    return accepted.map((f) => f.otherSide(currentUserId)).toList();
  }
}
