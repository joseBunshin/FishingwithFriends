import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/stats/application/stats_vs_friends_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Catch _catch({
  required String anglerId,
  required DateTime caughtAt,
}) {
  return Catch(
    id: '$anglerId-${caughtAt.millisecondsSinceEpoch}',
    anglerId: anglerId,
    caughtAt: caughtAt,
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: const [],
    createdAt: caughtAt,
    updatedAt: caughtAt,
  );
}

ProviderContainer _container({
  required List<Catch> mine,
  required List<Catch> friends,
  required List<String> friendIds,
}) {
  return ProviderContainer(
    overrides: [
      myCatchesProvider.overrideWith((_) async => mine),
      friendsCatchesProvider.overrideWith((_) async => friends),
      friendIdsProvider.overrideWith(
        (_) => AsyncValue.data(friendIds),
      ),
    ],
  );
}

DateTime _daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

void main() {
  // Reference fixture from the plan: my=5, friend A=3, friend B=8, friend C=4.
  // I beat A and C (>=), do not beat B → percentile = 2/3 = 67%.
  test('percentile counts ties as beats and ranks correctly', () async {
    final container = _container(
      mine: [
        for (var i = 0; i < 5; i++) _catch(anglerId: 'me', caughtAt: _daysAgo(i + 1)),
      ],
      friends: [
        for (var i = 0; i < 3; i++) _catch(anglerId: 'A', caughtAt: _daysAgo(i + 1)),
        for (var i = 0; i < 8; i++) _catch(anglerId: 'B', caughtAt: _daysAgo(i + 1)),
        for (var i = 0; i < 4; i++) _catch(anglerId: 'C', caughtAt: _daysAgo(i + 1)),
      ],
      friendIds: ['A', 'B', 'C'],
    );
    addTearDown(container.dispose);

    final snap = await container.read(statsVsFriendsProvider.future);
    expect(snap.myCount, 5);
    expect(snap.friendCounts.length, 3);
    expect(snap.friendCounts[0].friendId, 'B');
    expect(snap.friendCounts[1].friendId, 'C');
    expect(snap.friendCounts[2].friendId, 'A');
    expect(snap.percentile!.round(), 67);
  });

  test('counts a tie as a beat (>=)', () async {
    final container = _container(
      mine: [
        for (var i = 0; i < 5; i++) _catch(anglerId: 'me', caughtAt: _daysAgo(i + 1)),
      ],
      friends: [
        for (var i = 0; i < 5; i++) _catch(anglerId: 'A', caughtAt: _daysAgo(i + 1)),
      ],
      friendIds: ['A'],
    );
    addTearDown(container.dispose);

    final snap = await container.read(statsVsFriendsProvider.future);
    expect(snap.percentile, 100);
  });

  test('returns null percentile when there are no friends', () async {
    final container = _container(
      mine: [_catch(anglerId: 'me', caughtAt: _daysAgo(1))],
      friends: const [],
      friendIds: const [],
    );
    addTearDown(container.dispose);

    final snap = await container.read(statsVsFriendsProvider.future);
    expect(snap.hasFriends, isFalse);
    expect(snap.percentile, isNull);
  });

  test('myCount is 0 when no own catches in the window', () async {
    final container = _container(
      mine: const [],
      friends: [_catch(anglerId: 'A', caughtAt: _daysAgo(1))],
      friendIds: ['A'],
    );
    addTearDown(container.dispose);

    final snap = await container.read(statsVsFriendsProvider.future);
    expect(snap.myCount, 0);
    // 0 vs 1: I lose. percentile = 0/1.
    expect(snap.percentile, 0);
  });

  test('excludes catches older than 30 days', () async {
    final container = _container(
      mine: [
        _catch(anglerId: 'me', caughtAt: _daysAgo(31)),
        _catch(anglerId: 'me', caughtAt: _daysAgo(1)),
      ],
      friends: [
        _catch(anglerId: 'A', caughtAt: _daysAgo(60)),
      ],
      friendIds: ['A'],
    );
    addTearDown(container.dispose);

    final snap = await container.read(statsVsFriendsProvider.future);
    expect(snap.myCount, 1);
    expect(snap.friendCounts[0].count, 0);
  });

  test('excludes future-dated catches', () async {
    final container = _container(
      mine: [
        _catch(anglerId: 'me', caughtAt: DateTime.now().add(const Duration(hours: 1))),
        _catch(anglerId: 'me', caughtAt: _daysAgo(1)),
      ],
      friends: const [],
      friendIds: const [],
    );
    addTearDown(container.dispose);

    final snap = await container.read(statsVsFriendsProvider.future);
    expect(snap.myCount, 1);
  });
}
