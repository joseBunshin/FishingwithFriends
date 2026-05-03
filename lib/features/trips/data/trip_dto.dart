import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:fishing_with_friends/features/trips/domain/trip_input.dart';

class TripDto {
  const TripDto._();

  static Trip fromRow(Map<String, dynamic> row) {
    return Trip(
      id: row['id'] as String,
      anglerId: row['angler_id'] as String,
      title: row['title'] as String,
      bodyOfWater: row['body_of_water'] as String?,
      coverPhotoPath: row['cover_photo_path'] as String?,
      startedAt: DateTime.parse(row['started_at'] as String).toUtc(),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.parse(row['ended_at'] as String).toUtc(),
      isActive: (row['is_active'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  }

  static Map<String, dynamic> toInsertRow(
    TripInput input, {
    required String anglerId,
  }) {
    return {
      'angler_id': anglerId,
      'title': input.title,
      if (input.bodyOfWater != null && input.bodyOfWater!.isNotEmpty)
        'body_of_water': input.bodyOfWater,
      'is_active': true,
    };
  }
}
