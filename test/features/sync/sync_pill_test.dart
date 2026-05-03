import 'package:fishing_with_friends/features/sync/data/outbox_repository_provider.dart';
import 'package:fishing_with_friends/features/sync/presentation/widgets/sync_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(int count) {
  return ProviderScope(
    overrides: [
      pendingOutboxCountProvider.overrideWith(
        (ref) => Stream.value(count),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: SyncPill())),
  );
}

void main() {
  testWidgets('hidden when count is 0', (tester) async {
    await tester.pumpWidget(_harness(0));
    // CircularProgressIndicator never settles; pump a single frame.
    await tester.pump();
    expect(find.textContaining('Syncing'), findsNothing);
  });

  testWidgets('renders "Syncing N" when count > 0', (tester) async {
    await tester.pumpWidget(_harness(3));
    await tester.pump();
    expect(find.text('Syncing 3'), findsOneWidget);
  });
}
