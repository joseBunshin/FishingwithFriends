import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';

/// Maps between `Catch` domain objects and Supabase row maps.
/// Isolated from the rest of the app so PostGIS encoding stays in one place.
class CatchDto {
  const CatchDto._();

  /// Build a `Catch` from a Supabase row (either `catches` or
  /// `catches_friend_view`).
  static Catch fromRow(Map<String, dynamic> row) {
    return Catch(
      id: row['id'] as String,
      anglerId: row['angler_id'] as String,
      speciesId: row['species_id'] as String?,
      speciesLabel: row['species_label'] as String?,
      weightKg: _asDouble(row['weight_kg']),
      lengthCm: _asDouble(row['length_cm']),
      caughtAt: DateTime.parse(row['caught_at'] as String).toUtc(),
      latitude: _latitudeFromLocation(row['location']),
      longitude: _longitudeFromLocation(row['location']),
      secretSpot: (row['secret_spot'] as bool?) ?? false,
      catchAndRelease: (row['catch_and_release'] as bool?) ?? false,
      notes: row['notes'] as String?,
      rig: row['rig'] as String?,
      tripId: row['trip_id'] as String?,
      photoPaths: List<String>.from(
        (row['photo_paths'] as List<dynamic>? ?? const []).cast<String>(),
      ),
      conditions: Map<String, dynamic>.from(
        row['conditions'] as Map<String, dynamic>? ?? const {},
      ),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  }

  /// Build the row map sent to `catches.insert(...)`.
  /// Caller supplies the `catchId` so photos can be uploaded under
  /// `<angler_id>/<catchId>/...` *before* the row is inserted.
  static Map<String, dynamic> toInsertRow(
    CatchInput input, {
    required String catchId,
    required String anglerId,
    required List<String> photoPaths,
  }) {
    return {
      'id': catchId,
      'angler_id': anglerId,
      if (input.speciesId != null) 'species_id': input.speciesId,
      if (input.speciesLabel != null) 'species_label': input.speciesLabel,
      'weight_kg': input.weightKg,
      'length_cm': input.lengthCm,
      'caught_at': input.caughtAt.toUtc().toIso8601String(),
      'location': _locationLiteral(input.latitude, input.longitude),
      'secret_spot': input.secretSpot,
      'catch_and_release': input.catchAndRelease,
      'notes': input.notes,
      'rig': input.rig,
      if (input.tripId != null) 'trip_id': input.tripId,
      'photo_paths': photoPaths,
    };
  }

  /// PostGIS WKT literal `SRID=4326;POINT(<lng> <lat>)` or `null`.
  static String? _locationLiteral(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return 'SRID=4326;POINT($lng $lat)';
  }

  /// Supabase returns geography columns as GeoJSON when selected as JSON.
  /// Most queries return text (the WKT literal); be defensive about both.
  static double? _latitudeFromLocation(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      final coords = raw['coordinates'];
      if (coords is List && coords.length == 2) return _asDouble(coords[1]);
    }
    if (raw is String) return _wktLatitude(raw);
    return null;
  }

  static double? _longitudeFromLocation(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      final coords = raw['coordinates'];
      if (coords is List && coords.length == 2) return _asDouble(coords[0]);
    }
    if (raw is String) return _wktLongitude(raw);
    return null;
  }

  static final RegExp _wkt = RegExp(
    r'POINT\s*\(\s*([-\d.eE]+)\s+([-\d.eE]+)\s*\)',
  );

  static double? _wktLongitude(String wkt) {
    final m = _wkt.firstMatch(wkt);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  static double? _wktLatitude(String wkt) {
    final m = _wkt.firstMatch(wkt);
    return m == null ? null : double.tryParse(m.group(2)!);
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
