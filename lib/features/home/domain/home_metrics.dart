/// Snapshot of an angler's logbook stats shown on the Home tab.
/// Wired to a real Riverpod provider in M1; M0 supplies `HomeMetrics.empty()`.
class HomeMetrics {
  const HomeMetrics({
    required this.totalCatches,
    required this.totalWeightKg,
    required this.uniqueSpecies,
    this.biggestWeightKg,
    this.biggestSpecies,
  });

  const HomeMetrics.empty()
      : totalCatches = 0,
        totalWeightKg = 0,
        uniqueSpecies = 0,
        biggestWeightKg = null,
        biggestSpecies = null;

  final int totalCatches;
  final double totalWeightKg;
  final int uniqueSpecies;
  final double? biggestWeightKg;
  final String? biggestSpecies;

  bool get isEmpty => totalCatches == 0;
}
