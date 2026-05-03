import 'package:fishing_with_friends/core/units/measurement_format.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/settings/data/app_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class ConditionsCorrelation {
  const ConditionsCorrelation({
    required this.species,
    required this.tideState,
    required this.tempBucket,
    required this.sampleSize,
  });

  final String species;
  final String? tideState;
  final String? tempBucket;
  final int sampleSize;

  String get headline {
    final parts = <String>[];
    if (tideState != null) parts.add('$tideState tide');
    if (tempBucket != null) parts.add(tempBucket!);
    if (parts.isEmpty) return 'Mixed conditions';
    return parts.join(' · ');
  }
}

/// Returns null until at least 10 same-species catches with non-empty
/// conditions exist. Otherwise computes the dominant tide_state +
/// temperature bucket of the user's top-quartile catches by weight,
/// per top species.
final conditionsCorrelationProvider =
    FutureProvider<List<ConditionsCorrelation>>((ref) async {
  final units = ref.watch(displayUnitsProvider);
  final mine = await ref.watch(myCatchesProvider.future);
  final withConditions = mine
      .where((c) =>
          c.conditions.isNotEmpty && (c.speciesLabel?.isNotEmpty ?? false))
      .toList();
  if (withConditions.length < 10) return const [];

  // Group by species; require at least 4 per species.
  final bySpecies = <String, List<Catch>>{};
  for (final c in withConditions) {
    final s = c.speciesLabel!;
    bySpecies.putIfAbsent(s, () => []).add(c);
  }

  final result = <ConditionsCorrelation>[];
  for (final entry in bySpecies.entries) {
    final list = entry.value;
    if (list.length < 4) continue;
    list.sort((a, b) {
      final aw = a.weightKg ?? 0;
      final bw = b.weightKg ?? 0;
      return bw.compareTo(aw);
    });
    final topQuartile = list.take((list.length / 4).ceil().clamp(2, 5));

    final tideCounts = <String, int>{};
    final temps = <double>[];
    for (final c in topQuartile) {
      final tide = c.conditions['tide_state'];
      if (tide is String) {
        tideCounts[tide] = (tideCounts[tide] ?? 0) + 1;
      }
      final t = c.conditions['temp_c'];
      if (t is num) temps.add(t.toDouble());
    }
    String? dominantTide;
    if (tideCounts.isNotEmpty) {
      dominantTide = tideCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }
    String? tempBucket;
    if (temps.isNotEmpty) {
      final avg = temps.reduce((a, b) => a + b) / temps.length;
      final loC = avg - 3;
      final hiC = avg + 3;
      final loStr = formatTemperature(loC, units);
      final hiStr = formatTemperature(hiC, units);
      tempBucket = '${_stripUnit(loStr)}–$hiStr water';
    }
    result.add(ConditionsCorrelation(
      species: entry.key,
      tideState: dominantTide,
      tempBucket: tempBucket,
      sampleSize: list.length,
    ));
  }
  return result;
});

/// Drops the trailing °C / °F so we can build "12–18°C water"-style
/// ranges without repeating the unit on the low end.
String _stripUnit(String formatted) {
  return formatted
      .replaceAll('°C', '')
      .replaceAll('°F', '');
}
