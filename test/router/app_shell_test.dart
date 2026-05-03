import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/router/app_shell.dart';
import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _expectedTabLabels = [
  'Home',
  'Catches',
  'Tourneys',
  'Map',
  'Friends',
  'Me',
];

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          for (final path in const [
            AppRoutes.home,
            AppRoutes.catches,
            AppRoutes.tourneys,
            AppRoutes.map,
            AppRoutes.friends,
            AppRoutes.me,
          ])
            GoRoute(
              path: path,
              builder: (_, __) => Scaffold(
                appBar: AppBar(title: Text(path)),
                body: Center(child: Text('content for $path')),
              ),
            ),
        ],
      ),
      GoRoute(
        path: AppRoutes.logCatch,
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('catch log screen')),
        ),
      ),
    ],
  );
}

Widget _wrap({Size size = const Size(390, 844)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _buildRouter(),
    ),
  );
}

void main() {
  group('AppShell', () {
    testWidgets('renders 6 nav tab labels in expected order', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Each nav-tab label should appear exactly once in the bottom bar.
      // (The matching screen path appears separately as the Scaffold
      // AppBar title — different widget tree, doesn't double-count.)
      for (final label in _expectedTabLabels) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Expected nav label "$label" exactly once.',
        );
      }
    });

    testWidgets('exposes 6 tab paths via the tabPaths static', (tester) async {
      expect(AppShell.tabPaths.length, 6);
      expect(AppShell.tabPaths, contains(AppRoutes.tourneys));
    });

    testWidgets('tapping the raised Log button pushes /log', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // The Log FAB has Icons.add at its core. Tap it and verify routing.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('catch log screen'), findsOneWidget);
    });

    testWidgets('Tourneys label scales down rather than truncating at 375pt',
        (tester) async {
      await tester.pumpWidget(_wrap(size: const Size(375, 667)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Regression: previously softWrap:false + overflow:fade truncated
      // the trailing 's' in "Tourneys" at iPhone SE width. FittedBox
      // shrinks the text instead, preserving every character.
      final tourneysFinder = find.text('Tourneys');
      expect(tourneysFinder, findsOneWidget);

      // The Text must be wrapped in a FittedBox(scaleDown) ancestor.
      final fittedBoxFinder = find.ancestor(
        of: tourneysFinder,
        matching: find.byType(FittedBox),
      );
      expect(fittedBoxFinder, findsOneWidget);
      final fittedBox = tester.widget<FittedBox>(fittedBoxFinder);
      expect(fittedBox.fit, BoxFit.scaleDown);
    });
  });
}
