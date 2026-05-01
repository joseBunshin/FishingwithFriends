import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/friends/data/friends_data_source.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository.dart';
import 'package:fishing_with_friends/features/friends/domain/friendship.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeFriendsDataSource implements FriendsDataSource {
  List<Map<String, dynamic>> searchResults = const [];
  List<Map<String, dynamic>> friendships = const [];
  Map<String, Map<String, dynamic>> profilesById = const {};
  bool throwUniqueOnInsert = false;

  @override
  Future<List<Map<String, dynamic>>> searchProfiles({
    required String query,
    required String currentUserId,
    int limit = 25,
  }) async {
    return searchResults;
  }

  @override
  Future<List<Map<String, dynamic>>> selectProfilesByIds(
    List<String> ids,
  ) async {
    return ids.map((id) => profilesById[id]).whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<Map<String, dynamic>> insertFriendship({
    required String requesterId,
    required String addresseeId,
  }) async {
    if (throwUniqueOnInsert) {
      throw const PostgrestException(message: 'duplicate', code: '23505');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
    };
  }

  @override
  Future<Map<String, dynamic>> updateStatus({
    required String requesterId,
    required String addresseeId,
    required String status,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': status,
      'created_at': '2026-04-12T00:00:00.000Z',
      'updated_at': now,
    };
  }

  @override
  Future<void> deleteFriendship({
    required String userA,
    required String userB,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> selectFriendshipsForUser(
    String userId,
  ) async => friendships;
}

Map<String, dynamic> _profileRow(String id, String username) => {
      'id': id,
      'username': username,
      'display_name': null,
      'avatar_path': null,
    };

void main() {
  group('FriendsRepository.search', () {
    test('returns profiles for a 2+ char query', () async {
      final ds = _FakeFriendsDataSource()
        ..searchResults = [
          _profileRow('u1', 'silentfisher100'),
          _profileRow('u2', 'silentfisher200'),
        ];
      final repo = FriendsRepository(dataSource: ds);
      final results = await repo.search(query: 'silent', currentUserId: 'me');
      expect(results, hasLength(2));
      expect(results.first.username, 'silentfisher100');
      expect(results.first.handle, '@silentfisher100');
    });

    test('rejects 1-char query with ValidationFailure', () async {
      final repo = FriendsRepository(dataSource: _FakeFriendsDataSource());
      await expectLater(
        () => repo.search(query: 'a', currentUserId: 'me'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects empty currentUserId with AuthFailure', () async {
      final repo = FriendsRepository(dataSource: _FakeFriendsDataSource());
      await expectLater(
        () => repo.search(query: 'silent', currentUserId: ''),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('FriendsRepository.sendRequest', () {
    test('happy path: returns Friendship with status=pending', () async {
      final repo = FriendsRepository(dataSource: _FakeFriendsDataSource());
      final f = await repo.sendRequest(
        currentUserId: 'me',
        addresseeId: 'u1',
      );
      expect(f.requesterId, 'me');
      expect(f.addresseeId, 'u1');
      expect(f.status, FriendshipStatus.pending);
    });

    test('refuses self-friendship', () async {
      final repo = FriendsRepository(dataSource: _FakeFriendsDataSource());
      await expectLater(
        () =>
            repo.sendRequest(currentUserId: 'me', addresseeId: 'me'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('unique-violation maps to friendly ValidationFailure', () async {
      final ds = _FakeFriendsDataSource()..throwUniqueOnInsert = true;
      final repo = FriendsRepository(dataSource: ds);
      await expectLater(
        () => repo.sendRequest(currentUserId: 'me', addresseeId: 'u1'),
        throwsA(isA<ValidationFailure>().having(
          (e) => e.message,
          'message',
          contains('already sent'),
        )),
      );
    });
  });

  group('FriendsRepository.loadFor', () {
    test('partitions friendships into accepted / incoming / outgoing',
        () async {
      const now = '2026-04-12T00:00:00.000Z';
      final ds = _FakeFriendsDataSource()
        ..friendships = [
          {
            'requester_id': 'me',
            'addressee_id': 'friend',
            'status': 'accepted',
            'created_at': now,
            'updated_at': now,
          },
          {
            'requester_id': 'sender',
            'addressee_id': 'me',
            'status': 'pending',
            'created_at': now,
            'updated_at': now,
          },
          {
            'requester_id': 'me',
            'addressee_id': 'pending',
            'status': 'pending',
            'created_at': now,
            'updated_at': now,
          },
        ]
        ..profilesById = {
          'friend': _profileRow('friend', 'cool_friend'),
          'sender': _profileRow('sender', 'inbound_user'),
          'pending': _profileRow('pending', 'outbound_user'),
        };
      final repo = FriendsRepository(dataSource: ds);
      final bundle = await repo.loadFor('me');

      expect(bundle.accepted, hasLength(1));
      expect(bundle.pendingIncoming, hasLength(1));
      expect(bundle.pendingOutgoing, hasLength(1));
      expect(bundle.profilesById['friend']?.username, 'cool_friend');
    });

    test('acceptedFriendIds returns the *other* angler ids', () {
      final now = DateTime.utc(2026, 4, 12);
      final bundle = FriendsBundle(
        accepted: [
          Friendship(
            requesterId: 'me',
            addresseeId: 'a',
            status: FriendshipStatus.accepted,
            createdAt: now,
            updatedAt: now,
          ),
          Friendship(
            requesterId: 'b',
            addresseeId: 'me',
            status: FriendshipStatus.accepted,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        pendingIncoming: const [],
        pendingOutgoing: const [],
        profilesById: const {},
      );
      expect(bundle.acceptedFriendIds('me'), ['a', 'b']);
    });

    test('empty currentUserId returns an empty bundle (no DS calls)',
        () async {
      final repo = FriendsRepository(dataSource: _FakeFriendsDataSource());
      final bundle = await repo.loadFor('');
      expect(bundle.isEmpty, isTrue);
    });
  });
}
