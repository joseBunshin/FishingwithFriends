import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/home/domain/home_metrics.dart';
import 'package:fishing_with_friends/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _wrap(HomeMetrics metrics) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/log',
        builder: (_, __) => const Scaffold(body: Text('log screen')),
      ),
      GoRoute(
        path: '/catches',
        builder: (_, __) => const Scaffold(body: Text('catches screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [homeMetricsProvider.overrideWithValue(metrics)],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('empty state shows zeroed tiles + first-catch CTA',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeMetrics.empty()));
      await tester.pumpAndSettle();

      expect(find.text('Total Catches'), findsOneWidget);
      expect(find.text('Total Weight'), findsOneWidget);
      expect(find.text('Species'), findsOneWidget);
      expect(find.text('Biggest'), findsOneWidget);
      expect(find.text('No catches yet'), findsOneWidget);
      expect(find.text('Log your first catch'), findsOneWidget);
    });

    testWidgets('populated metrics render values formatted in lbs',
        (tester) async {
      const metrics = HomeMetrics(
        totalCatches: 1,
        totalWeightKg: 226.796,
        uniqueSpecies: 1,
        biggestWeightKg: 226.796,
        biggestSpecies: 'Rainbow Trout',
      );
      await tester.pumpWidget(_wrap(metrics));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsAtLeastNWidgets(2));
      expect(find.text('500.0 lbs'), findsOneWidget);
      expect(find.text('500 lbs'), findsOneWidget);
      expect(find.text('Rainbow Trout'), findsOneWidget);
    });

    testWidgets('first-catch CTA navigates to /log', (tester) async {
      await tester.pumpWidget(_wrap(const HomeMetrics.empty()));
      await tester.pumpAndSettle();

      final cta = find.text('Log your first catch');
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('log screen'), findsOneWidget);
    });
  });
}
