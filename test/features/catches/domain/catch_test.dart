import 'package:fishing_with_friends/features/catches/data/catch_dto.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/domain/catch_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

Map<String, dynamic> _row({
  String id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  String anglerId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  String speciesLabel = 'Largemouth Bass',
  double? weightKg = 2.04,
  double? lengthCm = 45.7,
  bool secretSpot = false,
  bool catchAndRelease = true,
  Object? location =
      const {'type': 'Point', 'coordinates': [-75.123, 40.456]},
  List<String> photos = const ['anglerId/catch/0.jpg'],
}) {
  return {
    'id': id,
    'angler_id': anglerId,
    'species_id': null,
    'species_label': speciesLabel,
    'weight_kg': weightKg,
    'length_cm': lengthCm,
    'caught_at': '2026-04-12T10:30:00.000Z',
    'location': location,
    'secret_spot': secretSpot,
    'catch_and_release': catchAndRelease,
    'notes': 'felt good on the line',
    'rig': 'spinnerbait',
    'photo_paths': photos,
    'conditions': const <String, dynamic>{},
    'created_at': '2026-04-12T10:31:00.000Z',
    'updated_at': '2026-04-12T10:31:00.000Z',
  };
}

void main() {
  group('CatchDto.fromRow', () {
    test('happy path: round-trips a catch row', () {
      final c = CatchDto.fromRow(_row());

      expect(c.id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(c.speciesLabel, 'Largemouth Bass');
      expect(c.weightKg, 2.04);
      expect(c.lengthCm, 45.7);
      expect(c.secretSpot, isFalse);
      expect(c.catchAndRelease, isTrue);
      expect(c.notes, 'felt good on the line');
      expect(c.rig, 'spinnerbait');
      expect(c.photoPaths, ['anglerId/catch/0.jpg']);
      expect(c.latitude, 40.456);
      expect(c.longitude, -75.123);
    });

    test('caughtAt is parsed as UTC', () {
      final c = CatchDto.fromRow(_row());
      expect(c.caughtAt.isUtc, isTrue);
      expect(c.caughtAt, DateTime.utc(2026, 4, 12, 10, 30));
    });

    test('null weight + null length + null location are accepted', () {
      final c = CatchDto.fromRow(_row(
        weightKg: null,
        lengthCm: null,
        location: null,
      ));
      expect(c.weightKg, isNull);
      expect(c.lengthCm, isNull);
      expect(c.hasLocation, isFalse);
    });

    test('empty photo list deserializes to empty list', () {
      final c = CatchDto.fromRow(_row(photos: const []));
      expect(c.photoPaths, isEmpty);
    });

    test('decodes WKT-formatted location strings', () {
      final c = CatchDto.fromRow(_row(
        location: 'SRID=4326;POINT(-122.4194 37.7749)',
      ));
      expect(c.longitude, closeTo(-122.4194, 0.0001));
      expect(c.latitude, closeTo(37.7749, 0.0001));
    });
  });

  group('CatchDto.toInsertRow', () {
    final input = CatchInput(
      photos: const <XFile>[],
      caughtAt: DateTime.utc(2026, 4, 12, 14),
      secretSpot: false,
      catchAndRelease: true,
      speciesLabel: 'Snook',
      weightKg: 4.5,
      lengthCm: 80,
      latitude: 25.7617,
      longitude: -80.1918,
      notes: 'mangrove edge',
      rig: 'live shrimp',
    );

    test('happy path: builds the expected insert map', () {
      final row = CatchDto.toInsertRow(
        input,
        catchId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        anglerId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
        photoPaths: const ['ang/catch/0.jpg', 'ang/catch/1.jpg'],
      );

      expect(row['id'], 'cccccccc-cccc-cccc-cccc-cccccccccccc');
      expect(row['angler_id'], 'dddddddd-dddd-dddd-dddd-dddddddddddd');
      expect(row['species_label'], 'Snook');
      expect(row['weight_kg'], 4.5);
      expect(row['length_cm'], 80);
      expect(row['caught_at'], '2026-04-12T14:00:00.000Z');
      expect(row['location'], 'SRID=4326;POINT(-80.1918 25.7617)');
      expect(row['secret_spot'], isFalse);
      expect(row['catch_and_release'], isTrue);
      expect(row['notes'], 'mangrove edge');
      expect(row['rig'], 'live shrimp');
      expect(row['photo_paths'], ['ang/catch/0.jpg', 'ang/catch/1.jpg']);
    });

    test('secret_spot=true still serializes location into the row', () {
      final secretInput = CatchInput(
        photos: const <XFile>[],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: true,
        catchAndRelease: false,
        latitude: 25.7617,
        longitude: -80.1918,
      );
      final row = CatchDto.toInsertRow(
        secretInput,
        catchId: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        anglerId: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
        photoPaths: const [],
      );
      expect(row['secret_spot'], isTrue);
      expect(row['location'], 'SRID=4326;POINT(-80.1918 25.7617)');
    });

    test('null lat/lng → null location literal', () {
      final noGps = CatchInput(
        photos: const <XFile>[],
        caughtAt: DateTime.utc(2026, 4, 12, 14),
        secretSpot: false,
        catchAndRelease: false,
      );
      final row = CatchDto.toInsertRow(
        noGps,
        catchId: 'gggggggg-gggg-gggg-gggg-gggggggggggg',
        anglerId: 'hhhhhhhh-hhhh-hhhh-hhhh-hhhhhhhhhhhh',
        photoPaths: const [],
      );
      expect(row['location'], isNull);
    });
  });

  group('Catch equality + copyWith', () {
    final base = Catch(
      id: '1',
      anglerId: 'a',
      caughtAt: DateTime.utc(2026, 4, 12),
      secretSpot: false,
      catchAndRelease: false,
      photoPaths: const ['p'],
      createdAt: DateTime.utc(2026, 4, 12),
      updatedAt: DateTime.utc(2026, 4, 12),
    );

    test('two catches with the same data are equal', () {
      final twin = Catch(
        id: '1',
        anglerId: 'a',
        caughtAt: DateTime.utc(2026, 4, 12),
        secretSpot: false,
        catchAndRelease: false,
        photoPaths: const ['p'],
        createdAt: DateTime.utc(2026, 4, 12),
        updatedAt: DateTime.utc(2026, 4, 12),
      );
      expect(base, equals(twin));
      expect(base.hashCode, twin.hashCode);
    });

    test('copyWith only changes named fields', () {
      final updated = base.copyWith(secretSpot: true);
      expect(updated.secretSpot, isTrue);
      expect(updated.id, base.id);
      expect(updated.photoPaths, base.photoPaths);
    });
  });
}
