import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class Streak {
  const Streak({required this.current, required this.longest});
  final int current;
  final int longest;

  static const empty = Streak(current: 0, longest: 0);
}

/// Streak math is local-day distinct fishing dates derived from
/// `caughtAt.toLocal()`. `current` counts consecutive days ending today
/// or yesterday (soft reset — a one-day gap from "today" is still
/// considered ongoing if the previous fishing day was yesterday).
final streakProvider = FutureProvider<Streak>((ref) async {
  final mine = await ref.watch(myCatchesProvider.future);
  if (mine.isEmpty) return Streak.empty;

  final fishingDays = <DateTime>{};
  for (final c in mine) {
    final local = c.caughtAt.toLocal();
    fishingDays.add(DateTime(local.year, local.month, local.day));
  }
  return _computeStreak(fishingDays, _todayLocal());
});

/// Visible for testing.
@visibleForTesting
Streak computeStreakFromDays(Set<DateTime> days, DateTime referenceDay) =>
    _computeStreak(days, referenceDay);

DateTime _todayLocal() {
  final now = DateTime.now().toLocal();
  return DateTime(now.year, now.month, now.day);
}

Streak _computeStreak(Set<DateTime> days, DateTime today) {
  if (days.isEmpty) return Streak.empty;
  final sorted = days.toList()..sort();

  // Longest run: count consecutive day groups in the sorted list.
  var longest = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final prev = sorted[i - 1];
    final cur = sorted[i];
    if (cur.difference(prev).inDays == 1) {
      run += 1;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }

  // Current run: walk back from today; allow yesterday-only as the most
  // recent fishing day before resetting (soft).
  var current = 0;
  var cursor = today;
  if (!days.contains(cursor)) {
    final yesterday = cursor.subtract(const Duration(days: 1));
    if (days.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return Streak(current: 0, longest: longest);
    }
  }
  while (days.contains(cursor)) {
    current += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return Streak(current: current, longest: longest);
}
