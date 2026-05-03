import 'package:fishing_with_friends/core/theme/app_theme.dart';
import 'package:fishing_with_friends/features/catches/presentation/catch_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap() {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const CatchLogScreen(),
    ),
  );
}

Future<void> _useTallViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(412, 2800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('CatchLogScreen', () {
    testWidgets('renders all required regions', (tester) async {
      await _useTallViewport(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Log a Catch'), findsOneWidget);
      expect(find.text('Add Photos'), findsOneWidget);
      expect(find.text('Species *'), findsOneWidget);
      expect(find.text('Weight *'), findsOneWidget);
      expect(find.text('Length *'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Additional Details'), findsOneWidget);
      expect(find.text('Catch & Release'), findsOneWidget);
      expect(find.text('Secret Spot'), findsOneWidget);
      expect(find.text('Save Catch'), findsOneWidget);
    });

    testWidgets('Save without species shows validation error', (tester) async {
      await _useTallViewport(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, 'Save Catch');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('Secret Spot and Catch & Release toggle independently',
        (tester) async {
      await _useTallViewport(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final secretSpot = find.widgetWithText(SwitchListTile, 'Secret Spot');
      final catchRelease =
          find.widgetWithText(SwitchListTile, 'Catch & Release');

      await tester.ensureVisible(secretSpot);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(secretSpot).value, isFalse);
      expect(tester.widget<SwitchListTile>(catchRelease).value, isFalse);

      await tester.tap(secretSpot);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(secretSpot).value, isTrue);
      expect(
        tester.widget<SwitchListTile>(catchRelease).value,
        isFalse,
        reason: 'C&R should not toggle when Secret Spot is tapped',
      );
    });

    testWidgets('weight + length unit toggles render labels', (tester) async {
      await _useTallViewport(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('lbs'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(find.text('in'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);
    });
  });
}
