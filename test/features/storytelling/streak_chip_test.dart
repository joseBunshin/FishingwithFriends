import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/storytelling/application/streak_provider.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/streak_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required AsyncValue<Streak> streak}) {
  return ProviderScope(
    overrides: [streakProvider.overrideWith((ref) async {
      return streak.when(
        data: (s) => s,
        loading: () => Future.delayed(
          const Duration(seconds: 30),
          () => Streak.empty,
        ),
        error: (e, st) => Future.error(e),
      );
    })],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: StreakChip()),
    ),
  );
}

void main() {
  group('StreakChip', () {
    // Bug-batch-4 U1: regression guard for the streak chip's primary
    // label clarity ("fishing streak" disambiguates from logins/trips)
    // and the subtitle visual treatment (mist uppercase kicker, not
    // bodySmall onSurface).

    testWidgets('renders 3-day fishing streak with LONGEST · 5 DAYS subtitle',
        (tester) async {
      await tester.pumpWidget(
        _wrap(streak: const AsyncData(Streak(current: 3, longest: 5))),
      );
      await tester.pumpAndSettle();

      expect(find.text('3-day fishing streak'), findsOneWidget);
      expect(find.text('LONGEST · 5 DAYS'), findsOneWidget);
    });

    testWidgets('singular grammar: 1-day fishing streak + LONGEST · 1 DAY',
        (tester) async {
      await tester.pumpWidget(
        _wrap(streak: const AsyncData(Streak(current: 1, longest: 1))),
      );
      await tester.pumpAndSettle();

      expect(find.text('1-day fishing streak'), findsOneWidget);
      expect(find.text('LONGEST · 1 DAY'), findsOneWidget);
    });

    testWidgets('empty state hides the chip entirely', (tester) async {
      await tester.pumpWidget(
        _wrap(streak: const AsyncData(Streak.empty)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.local_fire_department), findsNothing);
      expect(find.textContaining('streak'), findsNothing);
    });

    testWidgets('zero longest: primary label renders, subtitle does not',
        (tester) async {
      // current 5, longest 0 — fresh streak that's never been longer
      // than today's count. The chip's `longest > 0` guard hides the
      // subtitle. Streak.longest is non-nullable int, so longest: 0
      // (not null) is the correct way to exercise this branch.
      await tester.pumpWidget(
        _wrap(streak: const AsyncData(Streak(current: 5, longest: 0))),
      );
      await tester.pumpAndSettle();

      expect(find.text('5-day fishing streak'), findsOneWidget);
      expect(find.textContaining('LONGEST'), findsNothing);
    });
  });
}
