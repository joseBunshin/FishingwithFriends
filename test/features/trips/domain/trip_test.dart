import 'package:fishing_with_friends/features/trips/data/trip_dto.dart';
import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:fishing_with_friends/features/trips/domain/trip_input.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  bool isActive = true,
  String? endedAt,
}) {
  return {
    'id': 'tttttttt-tttt-tttt-tttt-tttttttttttt',
    'angler_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'title': 'Saturday at Lake Erie',
    'body_of_water': 'Lake Erie',
    'cover_photo_path': 'a/t/0.jpg',
    'started_at': '2026-04-12T08:00:00.000Z',
    'ended_at': endedAt,
    'is_active': isActive,
    'created_at': '2026-04-12T08:00:00.000Z',
    'updated_at': '2026-04-12T08:00:00.000Z',
  };
}

void main() {
  group('TripDto.fromRow', () {
    test('round-trips an active trip', () {
      final t = TripDto.fromRow(_row());
      expect(t.id, 'tttttttt-tttt-tttt-tttt-tttttttttttt');
      expect(t.title, 'Saturday at Lake Erie');
      expect(t.bodyOfWater, 'Lake Erie');
      expect(t.coverPhotoPath, 'a/t/0.jpg');
      expect(t.isActive, isTrue);
      expect(t.endedAt, isNull);
      expect(t.startedAt.isUtc, isTrue);
    });

    test('round-trips an ended trip', () {
      final t = TripDto.fromRow(_row(
        isActive: false,
        endedAt: '2026-04-12T18:00:00.000Z',
      ));
      expect(t.isActive, isFalse);
      expect(t.endedAt, DateTime.utc(2026, 4, 12, 18));
    });
  });

  group('TripDto.toInsertRow', () {
    test('builds insert with title only when no body of water', () {
      final row = TripDto.toInsertRow(
        const TripInput(title: 'Quick stop'),
        anglerId: 'a',
      );
      expect(row['title'], 'Quick stop');
      expect(row.containsKey('body_of_water'), isFalse);
      expect(row['is_active'], isTrue);
    });

    test('builds insert with body of water when provided', () {
      final row = TripDto.toInsertRow(
        const TripInput(title: 'Saturday', bodyOfWater: 'Lake Erie'),
        anglerId: 'a',
      );
      expect(row['body_of_water'], 'Lake Erie');
    });
  });

  group('Trip equality + copyWith', () {
    final base = Trip(
      id: '1',
      anglerId: 'a',
      title: 't',
      startedAt: DateTime.utc(2026, 4, 12),
      isActive: true,
      createdAt: DateTime.utc(2026, 4, 12),
      updatedAt: DateTime.utc(2026, 4, 12),
    );

    test('two trips with same data are equal', () {
      final twin = Trip(
        id: '1',
        anglerId: 'a',
        title: 't',
        startedAt: DateTime.utc(2026, 4, 12),
        isActive: true,
        createdAt: DateTime.utc(2026, 4, 12),
        updatedAt: DateTime.utc(2026, 4, 12),
      );
      expect(base, equals(twin));
      expect(base.hashCode, twin.hashCode);
    });

    test('copyWith only changes named fields', () {
      final ended = base.copyWith(
        isActive: false,
        endedAt: DateTime.utc(2026, 4, 12, 18),
      );
      expect(ended.isActive, isFalse);
      expect(ended.endedAt, DateTime.utc(2026, 4, 12, 18));
      expect(ended.title, 't');
    });
  });
}
