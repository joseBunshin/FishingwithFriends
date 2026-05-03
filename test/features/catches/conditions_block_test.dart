import 'package:fishing_with_friends/features/catches/presentation/widgets/conditions_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Map<String, dynamic> conditions) {
  return MaterialApp(
    home: Scaffold(body: ConditionsBlock(conditions: conditions)),
  );
}

void main() {
  testWidgets('returns SizedBox.shrink when conditions are empty',
      (tester) async {
    await tester.pumpWidget(_wrap(const {}));
    await tester.pump();
    expect(find.text('Conditions'), findsNothing);
  });

  testWidgets('renders temp + wind pills', (tester) async {
    await tester.pumpWidget(_wrap(const {
      'temp_c': 18,
      'wind_kph': 12,
    }));
    await tester.pump();
    expect(find.text('Conditions'), findsOneWidget);
    expect(find.text('18°C'), findsOneWidget);
    expect(find.text('12 kph'), findsOneWidget);
  });

  testWidgets('renders tide + moon when present', (tester) async {
    await tester.pumpWidget(_wrap(const {
      'tide_state': 'falling',
      'moon_phase': 0.5,
    }));
    await tester.pump();
    expect(find.text('falling tide'), findsOneWidget);
    expect(find.text('Full moon'), findsOneWidget);
  });

  testWidgets('unknown fields are ignored', (tester) async {
    await tester.pumpWidget(_wrap(const {
      'unknown_key': 'whatever',
    }));
    await tester.pump();
    expect(find.text('Conditions'), findsNothing);
  });
}
