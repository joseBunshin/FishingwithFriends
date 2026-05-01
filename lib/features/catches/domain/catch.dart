import 'package:meta/meta.dart';

/// A persisted catch record. Immutable; freezed enters when models multiply.
@immutable
class Catch {
  const Catch({
    required this.id,
    required this.anglerId,
    required this.caughtAt,
    required this.secretSpot,
    required this.catchAndRelease,
    required this.photoPaths,
    required this.createdAt,
    required this.updatedAt,
    this.speciesId,
    this.speciesLabel,
    this.weightKg,
    this.lengthCm,
    this.latitude,
    this.longitude,
    this.notes,
    this.rig,
    this.conditions = const {},
  });

  final String id;
  final String anglerId;
  final String? speciesId;
  final String? speciesLabel;
  final double? weightKg;
  final double? lengthCm;
  final DateTime caughtAt;
  final double? latitude;
  final double? longitude;
  final bool secretSpot;
  final bool catchAndRelease;
  final String? notes;
  final String? rig;
  final List<String> photoPaths;
  final Map<String, dynamic> conditions;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasLocation => latitude != null && longitude != null;

  Catch copyWith({
    String? id,
    String? anglerId,
    String? speciesId,
    String? speciesLabel,
    double? weightKg,
    double? lengthCm,
    DateTime? caughtAt,
    double? latitude,
    double? longitude,
    bool? secretSpot,
    bool? catchAndRelease,
    String? notes,
    String? rig,
    List<String>? photoPaths,
    Map<String, dynamic>? conditions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Catch(
      id: id ?? this.id,
      anglerId: anglerId ?? this.anglerId,
      speciesId: speciesId ?? this.speciesId,
      speciesLabel: speciesLabel ?? this.speciesLabel,
      weightKg: weightKg ?? this.weightKg,
      lengthCm: lengthCm ?? this.lengthCm,
      caughtAt: caughtAt ?? this.caughtAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      secretSpot: secretSpot ?? this.secretSpot,
      catchAndRelease: catchAndRelease ?? this.catchAndRelease,
      notes: notes ?? this.notes,
      rig: rig ?? this.rig,
      photoPaths: photoPaths ?? this.photoPaths,
      conditions: conditions ?? this.conditions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Catch &&
          other.id == id &&
          other.anglerId == anglerId &&
          other.speciesId == speciesId &&
          other.speciesLabel == speciesLabel &&
          other.weightKg == weightKg &&
          other.lengthCm == lengthCm &&
          other.caughtAt == caughtAt &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.secretSpot == secretSpot &&
          other.catchAndRelease == catchAndRelease &&
          other.notes == notes &&
          other.rig == rig &&
          _listEq(other.photoPaths, photoPaths) &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll([
        id,
        anglerId,
        speciesId,
        speciesLabel,
        weightKg,
        lengthCm,
        caughtAt,
        latitude,
        longitude,
        secretSpot,
        catchAndRelease,
        notes,
        rig,
        Object.hashAll(photoPaths),
        createdAt,
        updatedAt,
      ]);

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
