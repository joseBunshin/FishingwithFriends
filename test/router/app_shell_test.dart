import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/router/app_shell.dart';
import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _expectedLabels = [
  'Home',
  'Catches',
  'Log',
  'Stats',
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
            AppRoutes.stats,
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
    testWidgets('renders 8 NavigationDestinations in expected order',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final destinations = find.byType(NavigationDestination);
      expect(destinations, findsNWidgets(8));

      for (final label in _expectedLabels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('tapping the Log destination pushes /log', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();

      expect(find.text('catch log screen'), findsOneWidget);
    });

    testWidgets('does not overflow at 320pt width', (tester) async {
      await tester.pumpWidget(_wrap(size: const Size(320, 568)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
