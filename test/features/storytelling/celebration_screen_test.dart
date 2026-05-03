import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/storytelling/data/storytelling_repository_provider.dart';
import 'package:fishing_with_friends/features/storytelling/domain/badge.dart' as fwf;
import 'package:fishing_with_friends/features/storytelling/domain/personal_record.dart';
import 'package:fishing_with_friends/features/storytelling/domain/save_outcome.dart';
import 'package:fishing_with_friends/features/storytelling/domain/user_badge.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/celebration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

PersonalRecord _pr({
  String catchId = 'c-1',
  String species = 'Largemouth',
  PrMetric metric = PrMetric.weightKg,
  double value = 4.2,
}) {
  return PersonalRecord(
    id: 'pr-${species}_${metric.dbValue}',
    anglerId: 'u1',
    speciesId: 's-1',
    speciesLabel: species,
    metric: metric,
    value: value,
    catchId: catchId,
    achievedAt: DateTime.utc(2026, 4, 1),
  );
}

UserBadge _userBadge({
  String code = 'first_catch',
  String title = 'First Catch',
  String description = 'You logged your very first catch.',
}) {
  return UserBadge(
    id: 'ub-1',
    anglerId: 'u1',
    badgeCode: code,
    earnedAt: DateTime.utc(2026, 4, 1),
    sourceCatchId: 'c-1',
    definition: fwf.Badge(
      code: code,
      title: title,
      description: description,
      iconName: 'set_meal',
      predicate: code,
      params: const {},
    ),
  );
}

Catch _bareCatch(String id) {
  return Catch(
    id: id,
    anglerId: 'u1',
    caughtAt: DateTime.utc(2026, 4, 1),
    secretSpot: false,
    catchAndRelease: false,
    photoPaths: ['u1/$id/0.jpg'],
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

Widget _harness({
  required SaveOutcome outcome,
  GoRouter? router,
}) {
  final r = router ??
      GoRouter(
        initialLocation: '/celebrate/c-1',
        routes: [
          GoRoute(
            path: '/celebrate/:catchId',
            builder: (_, state) => CelebrationScreen(
              catchId: state.pathParameters['catchId']!,
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/catches/:id',
            builder: (_, state) => Scaffold(
              body: Text('detail-${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

  return ProviderScope(
    overrides: [
      saveOutcomeProvider('c-1').overrideWith((_) async => outcome),
      catchByIdProvider('c-1').overrideWith((_) async => _bareCatch('c-1')),
    ],
    child: MaterialApp.router(routerConfig: r),
  );
}

void main() {
  testWidgets('renders PR headline when outcome has new PRs', (tester) async {
    await tester.pumpWidget(
      _harness(outcome: SaveOutcome(newPRs: [_pr()], newBadges: const [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEW PR!'), findsOneWidget);
    expect(find.textContaining('Largemouth'), findsOneWidget);
  });

  testWidgets('renders badge headline when outcome has earned badge',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        outcome: SaveOutcome(newPRs: const [], newBadges: [_userBadge()]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BADGE UNLOCKED'), findsOneWidget);
    expect(find.text('First Catch'), findsOneWidget);
  });

  testWidgets('paginates multiple outcomes (PR + badge)', (tester) async {
    await tester.pumpWidget(
      _harness(
        outcome: SaveOutcome(
          newPRs: [_pr(), _pr(metric: PrMetric.lengthCm, value: 50)],
          newBadges: [_userBadge()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First page: PR. Page dots count = 3.
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('NEW PR!'), findsOneWidget);
  });

  testWidgets('non-celebratory outcome redirects to catch detail',
      (tester) async {
    await tester.pumpWidget(
      _harness(outcome: const SaveOutcome.empty()),
    );
    await tester.pumpAndSettle();

    expect(find.text('detail-c-1'), findsOneWidget);
  });

  testWidgets('Done button navigates to /home', (tester) async {
    await tester.pumpWidget(
      _harness(outcome: SaveOutcome(newPRs: [_pr()], newBadges: const [])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
