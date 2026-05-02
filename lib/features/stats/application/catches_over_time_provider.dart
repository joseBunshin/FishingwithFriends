import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class WeekBucket {
  const WeekBucket({required this.weekStart, required this.count});
  final DateTime weekStart;
  final int count;
}

/// Counts of own catches per ISO week (Monday-start) over the last 12 weeks.
/// Returns 12 buckets even when many are zero — keeps the chart x-axis stable.
final catchesOverTimeProvider =
    FutureProvider<List<WeekBucket>>((ref) async {
  final mine = await ref.watch(myCatchesProvider.future);
  final now = DateTime.now().toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final thisMonday = today.subtract(Duration(days: today.weekday - 1));

  final buckets = <DateTime, int>{};
  for (var i = 11; i >= 0; i--) {
    buckets[thisMonday.subtract(Duration(days: 7 * i))] = 0;
  }

  for (final c in mine) {
    final local = c.caughtAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    if (buckets.containsKey(monday)) {
      buckets[monday] = buckets[monday]! + 1;
    }
  }

  final keys = buckets.keys.toList()..sort();
  return [for (final k in keys) WeekBucket(weekStart: k, count: buckets[k]!)];
});
