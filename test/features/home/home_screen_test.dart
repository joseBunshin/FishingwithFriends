import 'dart:async';

import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/feed/data/feed_repository_provider.dart';
import 'package:fishing_with_friends/features/feed/domain/feed_item.dart';
import 'package:fishing_with_friends/features/home/data/home_metrics_provider.dart';
import 'package:fishing_with_friends/features/home/domain/home_metrics.dart';
import 'package:fishing_with_friends/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _wrap({
  required AsyncValue<HomeMetrics> metrics,
  AsyncValue<List<FeedItem>> feed = const AsyncData<List<FeedItem>>([]),
}) {
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
      GoRoute(
        path: '/friends',
        builder: (_, __) => const Scaffold(body: Text('friends screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(null),
      homeMetricsProvider.overrideWithValue(metrics),
      activityFeedProvider.overrideWith((ref) {
        return feed.when(
          data: Future<List<FeedItem>>.value,
          loading: () => Completer<List<FeedItem>>().future,
          error: Future<List<FeedItem>>.error,
        );
      }),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('empty state shows stat tiles + Find Anglers + Log CTA',
        (tester) async {
      await tester.pumpWidget(_wrap(metrics: const AsyncData(HomeMetrics.empty())));
      await tester.pumpAndSettle();

      expect(find.text('Total Catches'), findsOneWidget);
      expect(find.text('Total Weight'), findsOneWidget);
      expect(find.text('Species'), findsOneWidget);
      expect(find.text('Biggest'), findsOneWidget);
      expect(find.text('No catches in your feed yet'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Log a catch'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Find anglers'),
          findsOneWidget);
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
      await tester.pumpWidget(_wrap(metrics: const AsyncData(metrics)));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsAtLeastNWidgets(2));
      expect(find.text('500.0 lbs'), findsOneWidget);
      expect(find.text('500 lbs'), findsOneWidget);
      expect(find.text('Rainbow Trout'), findsOneWidget);
    });

    testWidgets('Find Anglers CTA navigates to /friends', (tester) async {
      await tester.pumpWidget(_wrap(metrics: const AsyncData(HomeMetrics.empty())));
      await tester.pumpAndSettle();

      final cta = find.widgetWithText(OutlinedButton, 'Find anglers');
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('friends screen'), findsOneWidget);
    });

    testWidgets('feed-error state shows Retry', (tester) async {
      await tester.pumpWidget(_wrap(
        metrics: const AsyncData(HomeMetrics.empty()),
        feed: AsyncError<List<FeedItem>>(
          Exception('boom'),
          StackTrace.current,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your activity feed."), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    });
  });
}
