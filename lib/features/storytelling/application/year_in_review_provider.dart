import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/trips/data/trips_repository_provider.dart';
import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class YearInReviewSummary {
  const YearInReviewSummary({
    required this.windowStart,
    required this.windowEnd,
    required this.topCatches,
    required this.biggest,
    required this.distinctSpecies,
    required this.mostCaughtSpeciesLabel,
    required this.daysFished,
    required this.biggestTrip,
    required this.biggestTripWeightKg,
    required this.friendLeaderboard,
  });

  final DateTime windowStart;
  final DateTime windowEnd;

  final List<Catch> topCatches;
  final Catch? biggest;
  final int distinctSpecies;
  final String? mostCaughtSpeciesLabel;
  final int daysFished;
  final Trip? biggestTrip;
  final double biggestTripWeightKg;
  final List<FriendStanding> friendLeaderboard;

  bool get isEmpty =>
      topCatches.isEmpty &&
      biggest == null &&
      daysFished == 0 &&
      friendLeaderboard.isEmpty;
}

@immutable
class FriendStanding {
  const FriendStanding({required this.friendId, required this.count});
  final String friendId;
  final int count;
}

final yearInReviewProvider = FutureProvider<YearInReviewSummary>((ref) async {
  final now = DateTime.now();
  final windowStart = now.subtract(const Duration(days: 365));

  final mine = await ref.watch(myCatchesProvider.future);
  final myInWindow = mine
      .where((c) =>
          c.caughtAt.isAfter(windowStart) && !c.caughtAt.isAfter(now))
      .toList();

  // Top by weight desc (null weights last).
  final topCatches = [...myInWindow]..sort((a, b) {
      if (a.weightKg == null && b.weightKg == null) return 0;
      if (a.weightKg == null) return 1;
      if (b.weightKg == null) return -1;
      return b.weightKg!.compareTo(a.weightKg!);
    });
  final top = topCatches.take(5).toList();

  final biggest = top.isEmpty ? null : top.first;

  // Species
  final speciesCounts = <String, int>{};
  for (final c in myInWindow) {
    final label = c.speciesLabel;
    if (label == null || label.isEmpty) continue;
    speciesCounts[label] = (speciesCounts[label] ?? 0) + 1;
  }
  final mostCaughtSpecies = speciesCounts.entries.isEmpty
      ? null
      : (speciesCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

  // Days fished
  final fishingDays = <DateTime>{};
  for (final c in myInWindow) {
    final local = c.caughtAt.toLocal();
    fishingDays.add(DateTime(local.year, local.month, local.day));
  }

  // Biggest trip
  Trip? biggestTrip;
  var biggestTripWeight = 0.0;
  try {
    final trips = await ref.watch(myTripsProvider.future);
    final tripWeights = <String, double>{};
    for (final c in myInWindow) {
      final tid = c.tripId;
      final w = c.weightKg;
      if (tid == null || w == null) continue;
      tripWeights[tid] = (tripWeights[tid] ?? 0) + w;
    }
    if (tripWeights.isNotEmpty) {
      final entry = tripWeights.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      biggestTripWeight = entry.value;
      biggestTrip = trips.firstWhere(
        (t) => t.id == entry.key,
        orElse: () => trips.first,
      );
    }
  } on Object {
    // Trip enrichment is best-effort.
  }

  // Friend leaderboard
  final leaderboard = <FriendStanding>[];
  try {
    final friendIds = ref.read(friendIdsProvider).valueOrNull ?? const [];
    if (friendIds.isNotEmpty) {
      final friends = await ref.watch(friendsCatchesProvider.future);
      final perFriend = <String, int>{
        for (final f in friendIds) f: 0,
      };
      for (final c in friends) {
        if (!perFriend.containsKey(c.anglerId)) continue;
        if (c.caughtAt.isAfter(windowStart) &&
            !c.caughtAt.isAfter(now)) {
          perFriend[c.anglerId] = perFriend[c.anglerId]! + 1;
        }
      }
      leaderboard
        ..addAll(
          perFriend.entries.map(
            (e) => FriendStanding(friendId: e.key, count: e.value),
          ),
        )
        ..sort((a, b) => b.count.compareTo(a.count));
    }
  } on Object {
    // Friend leaderboard is best-effort.
  }

  return YearInReviewSummary(
    windowStart: windowStart,
    windowEnd: now,
    topCatches: top,
    biggest: biggest,
    distinctSpecies: speciesCounts.length,
    mostCaughtSpeciesLabel: mostCaughtSpecies,
    daysFished: fishingDays.length,
    biggestTrip: biggestTrip,
    biggestTripWeightKg: biggestTripWeight,
    friendLeaderboard: leaderboard.take(5).toList(),
  );
});
