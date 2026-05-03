import 'dart:async';

import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/data/signed_url_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/catches/presentation/catches_screen.dart';
import 'package:fishing_with_friends/features/catches/presentation/widgets/catch_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Catch _c({String id = '1', String? species = 'Largemouth Bass'}) {
  final now = DateTime.utc(2026, 4, 12);
  return Catch(
    id: id,
    anglerId: 'angler-1',
    speciesLabel: species,
    weightKg: 2.04,
    lengthCm: 45,
    caughtAt: now,
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: const ['ang/catch/0.jpg'],
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(AsyncValue<List<Catch>> catches) {
  final router = GoRouter(
    initialLocation: '/catches',
    routes: [
      GoRoute(path: '/catches', builder: (_, __) => const CatchesScreen()),
      GoRoute(
        path: '/log',
        builder: (_, __) => const Scaffold(body: Text('log screen')),
      ),
      GoRoute(
        path: '/catches/:id',
        builder: (ctx, state) =>
            Scaffold(body: Text('detail ${state.pathParameters['id']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      myCatchesProvider.overrideWith((ref) {
        return catches.when(
          data: Future<List<Catch>>.value,
          loading: () => Completer<List<Catch>>().future, // never completes
          error: Future<List<Catch>>.error,
        );
      }),
      // Skip real signed-URL fetching — tests assert structure, not images.
      signedUrlProvider.overrideWith((ref, path) async => 'https://test/$path'),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

Future<void> _tall(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(412, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('CatchesScreen', () {
    testWidgets('empty state shows CTA to /log', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(_wrap(const AsyncData<List<Catch>>([])));
      await tester.pumpAndSettle();

      expect(find.text('No catches yet'), findsOneWidget);
      expect(find.text('Log your first catch'), findsOneWidget);
    });

    testWidgets('renders one CatchCard per catch in the grid', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(_wrap(AsyncData<List<Catch>>([
        _c(id: '1'),
        _c(id: '2'),
        _c(id: '3'),
      ])));
      await tester.pumpAndSettle();

      expect(find.byType(CatchCard), findsNWidgets(3));
      // Species pill renders inside each card.
      expect(find.text('Largemouth Bass'), findsNWidgets(3));
    });

    testWidgets('tapping a card navigates to /catches/<id>', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(
        _wrap(AsyncData<List<Catch>>([_c(id: '42')])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CatchCard).first);
      await tester.pumpAndSettle();

      expect(find.text('detail 42'), findsOneWidget);
    });

    testWidgets('error state shows Retry', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(
        _wrap(AsyncError<List<Catch>>(Exception('boom'), StackTrace.current)),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your catches."), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });
  });
}
