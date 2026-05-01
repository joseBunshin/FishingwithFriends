import 'package:fishing_with_friends/features/feed/data/feed_data_source.dart';
import 'package:fishing_with_friends/features/feed/data/feed_repository.dart';
import 'package:fishing_with_friends/features/feed/domain/reaction.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFeedDataSource implements FeedDataSource {
  List<Map<String, dynamic>> catches = const [];
  List<Map<String, dynamic>> reactions = const [];
  List<Map<String, dynamic>> comments = const [];
  List<Map<String, dynamic>> myReactions = const [];

  @override
  Future<List<Map<String, dynamic>>> selectFeedCatches({
    required String currentUserId,
    required List<String> friendIds,
    int limit = 50,
  }) async => catches;

  @override
  Future<List<Map<String, dynamic>>> selectReactionAggregates(
    List<String> catchIds,
  ) async => reactions;

  @override
  Future<List<Map<String, dynamic>>> selectCommentCounts(
    List<String> catchIds,
  ) async => comments;

  @override
  Future<List<Map<String, dynamic>>> selectMyReactions({
    required String userId,
    required List<String> catchIds,
  }) async => myReactions;
}

Map<String, dynamic> _catchRow(String id, {bool secret = false}) {
  return {
    'id': id,
    'angler_id': 'angler-1',
    'species_id': null,
    'species_label': 'Bass',
    'weight_kg': 2.0,
    'length_cm': 45.0,
    'caught_at': '2026-04-12T14:00:00.000Z',
    'location': secret
        ? null
        : const {'type': 'Point', 'coordinates': [-75.0, 40.0]},
    'secret_spot': secret,
    'catch_and_release': false,
    'rig': null,
    'trip_id': null,
    'notes': null,
    'photo_paths': const <String>[],
    'conditions': const <String, dynamic>{},
    'created_at': '2026-04-12T14:01:00.000Z',
    'updated_at': '2026-04-12T14:01:00.000Z',
  };
}

void main() {
  group('FeedRepository.getFeed', () {
    test('empty currentUserId short-circuits to empty list', () async {
      final repo = FeedRepository(dataSource: _FakeFeedDataSource());
      final feed = await repo.getFeed(currentUserId: '', friendIds: const []);
      expect(feed, isEmpty);
    });

    test('aggregates reaction counts by kind per catch', () async {
      final ds = _FakeFeedDataSource()
        ..catches = [_catchRow('c1'), _catchRow('c2')]
        ..reactions = [
          {'catch_id': 'c1', 'kind': 'rod'},
          {'catch_id': 'c1', 'kind': 'rod'},
          {'catch_id': 'c1', 'kind': 'fire'},
          {'catch_id': 'c2', 'kind': 'handshake'},
        ];
      final repo = FeedRepository(dataSource: ds);
      final feed = await repo.getFeed(
        currentUserId: 'me',
        friendIds: const ['angler-1'],
      );
      expect(feed[0].reactionCounts[ReactionKind.rod], 2);
      expect(feed[0].reactionCounts[ReactionKind.fire], 1);
      expect(feed[0].totalReactions, 3);
      expect(feed[1].reactionCounts[ReactionKind.handshake], 1);
    });

    test('myReaction populated only when current user reacted', () async {
      final ds = _FakeFeedDataSource()
        ..catches = [_catchRow('c1'), _catchRow('c2')]
        ..myReactions = [
          {'catch_id': 'c1', 'kind': 'fire'},
        ];
      final repo = FeedRepository(dataSource: ds);
      final feed = await repo.getFeed(
        currentUserId: 'me',
        friendIds: const ['angler-1'],
      );
      expect(feed[0].myReaction, ReactionKind.fire);
      expect(feed[1].myReaction, isNull);
    });

    test('commentCount aggregates non-deleted rows', () async {
      final ds = _FakeFeedDataSource()
        ..catches = [_catchRow('c1')]
        ..comments = [
          {'catch_id': 'c1', 'deleted_at': null},
          {'catch_id': 'c1', 'deleted_at': null},
        ];
      final repo = FeedRepository(dataSource: ds);
      final feed = await repo.getFeed(
        currentUserId: 'me',
        friendIds: const ['angler-1'],
      );
      expect(feed.first.commentCount, 2);
    });

    test('secret-spot row in feed has null location', () async {
      final ds = _FakeFeedDataSource()
        ..catches = [_catchRow('c1', secret: true)];
      final repo = FeedRepository(dataSource: ds);
      final feed = await repo.getFeed(
        currentUserId: 'me',
        friendIds: const ['angler-1'],
      );
      expect(feed.first.catch_.secretSpot, isTrue);
      expect(feed.first.catch_.hasLocation, isFalse);
    });

    test('unknown reaction kind from future schema is silently dropped',
        () async {
      final ds = _FakeFeedDataSource()
        ..catches = [_catchRow('c1')]
        ..reactions = [
          {'catch_id': 'c1', 'kind': 'thumbs_up'},
          {'catch_id': 'c1', 'kind': 'rod'},
        ];
      final repo = FeedRepository(dataSource: ds);
      final feed = await repo.getFeed(
        currentUserId: 'me',
        friendIds: const ['angler-1'],
      );
      expect(feed.first.reactionCounts[ReactionKind.rod], 1);
      expect(feed.first.totalReactions, 1);
    });
  });
}
