import 'package:fishing_with_friends/features/storytelling/data/storytelling_repository_provider.dart';
import 'package:fishing_with_friends/features/storytelling/domain/badge.dart' as fwf;
import 'package:fishing_with_friends/features/storytelling/domain/user_badge.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/badge_wall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

fwf.Badge _badge(String code, String title) {
  return fwf.Badge(
    code: code,
    title: title,
    description: '$code description',
    iconName: 'set_meal',
    predicate: code,
    params: const {},
  );
}

UserBadge _earned(fwf.Badge def) {
  return UserBadge(
    id: 'ub-${def.code}',
    anglerId: 'u1',
    badgeCode: def.code,
    earnedAt: DateTime.utc(2026, 4, 1),
    sourceCatchId: 'c-1',
    definition: def,
  );
}

const _anglerId = 'u1';

Widget _harness({
  required List<fwf.Badge> all,
  required List<UserBadge> earned,
}) {
  return ProviderScope(
    overrides: [
      allBadgesProvider.overrideWith((_) async => all),
      userBadgesForAnglerProvider(_anglerId).overrideWith((_) async => earned),
    ],
    child: const MaterialApp(
      home: Scaffold(body: BadgeWall(anglerId: _anglerId)),
    ),
  );
}

void main() {
  testWidgets('renders all seeded badges with earned ones colored',
      (tester) async {
    final defs = [
      _badge('first_catch', 'First Catch'),
      _badge('ten_catches', 'Tackle Box'),
      _badge('hundred_catches', 'Centurion'),
    ];
    await tester.pumpWidget(_harness(
      all: defs,
      earned: [_earned(defs[0])],
    ));
    await tester.pumpAndSettle();

    expect(find.text('First Catch'), findsOneWidget);
    expect(find.text('Tackle Box'), findsOneWidget);
    expect(find.text('Centurion'), findsOneWidget);
  });

  testWidgets('shows empty state when no badge definitions exist',
      (tester) async {
    await tester.pumpWidget(_harness(all: const [], earned: const []));
    await tester.pumpAndSettle();

    expect(find.text('No badges defined yet.'), findsOneWidget);
  });

  testWidgets('tapping a tile opens description sheet', (tester) async {
    final def = _badge('first_catch', 'First Catch');
    await tester.pumpWidget(_harness(all: [def], earned: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('First Catch'));
    await tester.pumpAndSettle();

    // Sheet shows the description text + a Locked indicator.
    expect(find.text('first_catch description'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
  });

  testWidgets('earned tile sheet shows the earned-on date', (tester) async {
    final def = _badge('first_catch', 'First Catch');
    await tester.pumpWidget(_harness(all: [def], earned: [_earned(def)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('First Catch'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Earned'), findsOneWidget);
  });
}
