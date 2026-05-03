import 'package:meta/meta.dart';

enum PrMetric { weightKg, lengthCm }

extension PrMetricX on PrMetric {
  String get dbValue => switch (this) {
        PrMetric.weightKg => 'weight_kg',
        PrMetric.lengthCm => 'length_cm',
      };

  static PrMetric parse(String raw) => switch (raw) {
        'weight_kg' => PrMetric.weightKg,
        'length_cm' => PrMetric.lengthCm,
        _ => throw FormatException('Unknown pr_metric: $raw'),
      };

  String get label => switch (this) {
        PrMetric.weightKg => 'weight',
        PrMetric.lengthCm => 'length',
      };
}

@immutable
class PersonalRecord {
  const PersonalRecord({
    required this.id,
    required this.anglerId,
    required this.metric,
    required this.value,
    required this.catchId,
    required this.achievedAt,
    this.speciesId,
    this.speciesLabel,
  });

  final String id;
  final String anglerId;
  final String? speciesId;
  final String? speciesLabel;
  final PrMetric metric;
  final double value;
  final String catchId;
  final DateTime achievedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalRecord &&
          other.id == id &&
          other.anglerId == anglerId &&
          other.speciesId == speciesId &&
          other.speciesLabel == speciesLabel &&
          other.metric == metric &&
          other.value == value &&
          other.catchId == catchId &&
          other.achievedAt == achievedAt;

  @override
  int get hashCode => Object.hash(
        id, anglerId, speciesId, speciesLabel, metric, value, catchId,
        achievedAt,
      );
}
