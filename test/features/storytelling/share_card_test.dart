import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Catch _catch({
  String id = 'c-1',
  String? speciesLabel = 'Largemouth',
  double? weightKg = 4,
  double? lengthCm = 50,
  bool secretSpot = false,
  bool catchAndRelease = false,
  double? lat = 41,
  double? lng = -75,
}) {
  return Catch(
    id: id,
    anglerId: 'u1',
    speciesId: 's-1',
    speciesLabel: speciesLabel,
    weightKg: weightKg,
    lengthCm: lengthCm,
    caughtAt: DateTime.utc(2026, 4, 1),
    latitude: lat,
    longitude: lng,
    secretSpot: secretSpot,
    catchAndRelease: catchAndRelease,
    photoPaths: const ['u1/c1/0.jpg'],
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

Widget _harness(Catch c, {String? photoUrl}) {
  return MaterialApp(
    home: Center(
      child: FittedBox(
        // Squish the 1080x1920 card into the test viewport.
        child: ShareCard(catch_: c, photoUrl: photoUrl),
      ),
    ),
  );
}

void main() {
  testWidgets('renders species + weight + length pills', (tester) async {
    await tester.pumpWidget(_harness(_catch()));
    await tester.pumpAndSettle();

    expect(find.text('Largemouth'), findsOneWidget);
    expect(find.text('8.8 lbs'), findsOneWidget);
    expect(find.text('19.7 in'), findsOneWidget);
    expect(find.text('Fishing with Friends'), findsOneWidget);
  });

  testWidgets('secret-spot catch shows "Secret spot", not coordinates',
      (tester) async {
    await tester.pumpWidget(_harness(_catch(secretSpot: true)));
    await tester.pumpAndSettle();

    expect(find.text('Secret spot'), findsOneWidget);
    expect(find.textContaining('41.00'), findsNothing);
  });

  testWidgets('no-GPS catch shows "Location not set"', (tester) async {
    await tester.pumpWidget(_harness(_catch(lat: null, lng: null)));
    await tester.pumpAndSettle();

    expect(find.text('Location not set'), findsOneWidget);
  });

  testWidgets('catch missing weight + length renders without error',
      (tester) async {
    await tester.pumpWidget(_harness(_catch(weightKg: null, lengthCm: null)));
    await tester.pumpAndSettle();

    expect(find.text('Largemouth'), findsOneWidget);
    expect(find.textContaining('lbs'), findsNothing);
    // 19.7 in pill is gone with no length set.
    expect(find.textContaining('19.7'), findsNothing);
  });

  testWidgets('catch & release adds an extra chip', (tester) async {
    await tester.pumpWidget(_harness(_catch(catchAndRelease: true)));
    await tester.pumpAndSettle();

    expect(find.text('Catch & release'), findsOneWidget);
  });
}
