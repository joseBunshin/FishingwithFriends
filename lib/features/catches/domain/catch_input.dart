import 'package:image_picker/image_picker.dart';
import 'package:meta/meta.dart';

/// Pre-persistence write-side payload assembled by `CatchLogScreen`.
/// Different from `Catch` because it carries `XFile` photos (not paths) and
/// has no id / createdAt / updatedAt.
@immutable
class CatchInput {
  const CatchInput({
    required this.photos,
    required this.caughtAt,
    required this.secretSpot,
    required this.catchAndRelease,
    this.speciesId,
    this.speciesLabel,
    this.weightKg,
    this.lengthCm,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.notes,
    this.rig,
    this.tripId,
  });

  final List<XFile> photos;
  final String? speciesId;
  final String? speciesLabel;
  final double? weightKg;
  final double? lengthCm;
  final DateTime caughtAt;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final bool secretSpot;
  final bool catchAndRelease;
  final String? notes;
  final String? rig;

  /// Optional active-trip id. The catch-log form is stateless about trips —
  /// the SaveCatchController reads `activeTripProvider` and stamps this
  /// before handing the input to the repository.
  final String? tripId;

  bool get hasLocation => latitude != null && longitude != null;
}
