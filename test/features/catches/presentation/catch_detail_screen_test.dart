import 'dart:async';

import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/data/signed_url_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/catch_detail_screen.dart';
import 'package:fishing_with_friends/features/feed/data/feed_writers_provider.dart';
import 'package:fishing_with_friends/features/feed/domain/comment.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Catch _c({
  String id = '42',
  bool secretSpot = false,
  double? lat = 40.456,
  double? lng = -75.123,
  List<String> photos = const ['ang/catch/0.jpg', 'ang/catch/1.jpg', 'ang/catch/2.jpg'],
}) {
  final now = DateTime.utc(2026, 4, 12, 10, 30);
  return Catch(
    id: id,
    anglerId: 'angler-1',
    speciesLabel: 'Largemouth Bass',
    weightKg: 2.04,
    lengthCm: 45.7,
    caughtAt: now,
    latitude: lat,
    longitude: lng,
    secretSpot: secretSpot,
    catchAndRelease: true,
    notes: 'felt good on the line',
    rig: 'spinnerbait',
    photoPaths: photos,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(AsyncValue<Catch?> result) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(null),
      catchByIdProvider('42').overrideWith((ref) {
        return result.when(
          data: Future<Catch?>.value,
          loading: () => Completer<Catch?>().future,
          error: Future<Catch?>.error,
        );
      }),
      signedUrlProvider.overrideWith((ref, path) async => 'https://test/$path'),
      friendsBundleProvider.overrideWith((ref) async => const FriendsBundle(
            accepted: [],
            pendingIncoming: [],
            pendingOutgoing: [],
            profilesById: {},
          )),
      catchCommentsProvider('42')
          .overrideWith((ref) async => const <Comment>[]),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const CatchDetailScreen(catchId: '42'),
    ),
  );
}

Future<void> _tall(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(412, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('CatchDetailScreen', () {
    testWidgets('renders species + measurements + carousel for owner view',
        (tester) async {
      await _tall(tester);
      await tester.pumpWidget(_wrap(AsyncData<Catch?>(_c())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Largemouth Bass'), findsAtLeastNWidgets(1));
      expect(find.text('4.5 lbs'), findsOneWidget); // 2.04 kg → 4.50 lbs
      expect(find.text('18.0 in'), findsOneWidget); // 45.7 cm → 18.0 in
      expect(find.text('Catch & release'), findsOneWidget);
      expect(find.text('felt good on the line'), findsOneWidget);
      expect(find.text('spinnerbait'), findsOneWidget);
    });

    testWidgets('hero tag matches grid: catch-photo-<id>', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(_wrap(AsyncData<Catch?>(_c(id: '42'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final hero = tester.widgetList<Hero>(find.byType(Hero)).firstWhere(
            (h) => h.tag == 'catch-photo-42',
            orElse: () => throw StateError('hero tag not found'),
          );
      expect(hero.tag, 'catch-photo-42');
    });

    testWidgets('Secret Spot row reads "Location hidden" not coordinates',
        (tester) async {
      await _tall(tester);
      await tester.pumpWidget(_wrap(AsyncData<Catch?>(_c(secretSpot: true))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Location hidden'), findsOneWidget);
      expect(
        find.textContaining('40.456'),
        findsNothing,
        reason: 'Secret Spot must not leak the latitude into the UI',
      );
    });

    testWidgets('null catch (RLS denial) shows "isn\'t available"',
        (tester) async {
      await _tall(tester);
      await tester.pumpWidget(_wrap(const AsyncData<Catch?>(null)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text("This catch isn't available."), findsOneWidget);
    });

    testWidgets('zero photos still renders (placeholder hero tile)',
        (tester) async {
      await _tall(tester);
      await tester.pumpWidget(
        _wrap(AsyncData<Catch?>(_c(photos: const []))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.set_meal_outlined), findsAtLeastNWidgets(1));
      expect(find.text('Largemouth Bass'), findsAtLeastNWidgets(1));
    });
  });
}
