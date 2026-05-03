import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/storytelling/application/year_in_review_provider.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

Catch _catch({
  required String id,
  String anglerId = 'me',
  String? speciesLabel,
  double? weightKg,
  String? tripId,
  DateTime? at,
}) {
  final ts = at ?? _daysAgo(10);
  return Catch(
    id: id,
    anglerId: anglerId,
    speciesId: speciesLabel != null ? 's-$speciesLabel' : null,
    speciesLabel: speciesLabel,
    weightKg: weightKg,
    caughtAt: ts,
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: const [],
    createdAt: ts,
    updatedAt: ts,
    tripId: tripId,
  );
}

ProviderContainer _container({
  List<Catch> mine = const [],
  List<Catch> friends = const [],
  List<String> friendIds = const [],
}) {
  return ProviderContainer(
    overrides: [
      myCatchesProvider.overrideWith((_) async => mine),
      friendsCatchesProvider.overrideWith((_) async => friends),
      friendIdsProvider.overrideWith(
        (_) => AsyncValue.data(friendIds),
      ),
      myTripsProvider.overrideWith((_) async => const []),
    ],
  );
}

void main() {
  test('empty catches returns empty summary', () async {
    final container = _container();
    addTearDown(container.dispose);
    final s = await container.read(yearInReviewProvider.future);
    expect(s.isEmpty, isTrue);
    expect(s.daysFished, 0);
  });

  test('top catches sorted by weight desc, biggest = top 1', () async {
    final container = _container(mine: [
      _catch(id: 'c1', speciesLabel: 'Bass', weightKg: 1),
      _catch(id: 'c2', speciesLabel: 'Bass', weightKg: 5),
      _catch(id: 'c3', speciesLabel: 'Bass', weightKg: 3),
    ]);
    addTearDown(container.dispose);
    final s = await container.read(yearInReviewProvider.future);
    expect(s.topCatches.first.id, 'c2');
    expect(s.biggest!.weightKg, 5);
  });

  test('species count is distinct, mostCaught = highest count', () async {
    final container = _container(mine: [
      _catch(id: 'c1', speciesLabel: 'Bass'),
      _catch(id: 'c2', speciesLabel: 'Bass'),
      _catch(id: 'c3', speciesLabel: 'Trout'),
    ]);
    addTearDown(container.dispose);
    final s = await container.read(yearInReviewProvider.future);
    expect(s.distinctSpecies, 2);
    expect(s.mostCaughtSpeciesLabel, 'Bass');
  });

  test('daysFished counts distinct local days', () async {
    final container = _container(mine: [
      _catch(id: 'c1', at: _daysAgo(1)),
      _catch(id: 'c2', at: _daysAgo(1)),
      _catch(id: 'c3', at: _daysAgo(2)),
    ]);
    addTearDown(container.dispose);
    final s = await container.read(yearInReviewProvider.future);
    expect(s.daysFished, 2);
  });

  test('excludes catches older than 365 days', () async {
    final container = _container(mine: [
      _catch(id: 'old', at: _daysAgo(400), weightKg: 100),
      _catch(id: 'new', at: _daysAgo(10), weightKg: 5),
    ]);
    addTearDown(container.dispose);
    final s = await container.read(yearInReviewProvider.future);
    expect(s.biggest!.id, 'new');
  });

  test('friend leaderboard returns sorted standings', () async {
    final container = _container(
      mine: [_catch(id: 'me1', at: _daysAgo(1))],
      friends: [
        _catch(id: 'fA1', anglerId: 'A', at: _daysAgo(1)),
        _catch(id: 'fA2', anglerId: 'A', at: _daysAgo(2)),
        _catch(id: 'fB1', anglerId: 'B', at: _daysAgo(1)),
      ],
      friendIds: ['A', 'B'],
    );
    addTearDown(container.dispose);
    final s = await container.read(yearInReviewProvider.future);
    expect(s.friendLeaderboard, hasLength(2));
    expect(s.friendLeaderboard.first.friendId, 'A');
    expect(s.friendLeaderboard.first.count, 2);
  });
}
