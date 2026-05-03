import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';

/// Source of a [MapPoint] — drives pin color (own = navy, friend = green).
enum MapPointSource { own, friend }

/// A single catch projected for the map. Immutable value; produced by
/// `mapPointsProvider` after secret-spot filtering and MPA shift.
@immutable
class MapPoint {
  const MapPoint({
    required this.catchId,
    required this.displayLatLng,
    required this.source,
    required this.isInMpa,
    required this.isMpaShifted,
    this.speciesLabel,
  });

  final String catchId;
  final LatLng displayLatLng;
  final MapPointSource source;

  /// True when the underlying raw GPS fell inside an MPA polygon.
  /// Display logic may want to surface a small lock badge.
  final bool isInMpa;

  /// True when [displayLatLng] differs from the raw GPS because of MPA
  /// shift. Always false when [isInMpa] is false.
  final bool isMpaShifted;

  final String? speciesLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPoint &&
          other.catchId == catchId &&
          other.displayLatLng == displayLatLng &&
          other.source == source &&
          other.isInMpa == isInMpa &&
          other.isMpaShifted == isMpaShifted &&
          other.speciesLabel == speciesLabel;

  @override
  int get hashCode => Object.hash(
        catchId,
        displayLatLng,
        source,
        isInMpa,
        isMpaShifted,
        speciesLabel,
      );
}
