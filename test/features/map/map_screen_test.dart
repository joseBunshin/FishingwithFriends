import 'package:fishing_with_friends/features/map/data/map_points_provider.dart';
import 'package:fishing_with_friends/features/map/domain/map_point.dart';
import 'package:fishing_with_friends/features/map/presentation/map_screen.dart';
import 'package:fishing_with_friends/features/map/presentation/widgets/heatmap_layer.dart';
import 'package:fishing_with_friends/features/map/presentation/widgets/map_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

MapPoint _own(String id, {double lat = 41, double lng = -75}) {
  return MapPoint(
    catchId: id,
    displayLatLng: LatLng(lat, lng),
    source: MapPointSource.own,
    isInMpa: false,
    isMpaShifted: false,
  );
}

MapPoint _friend(String id, {double lat = 42, double lng = -76}) {
  return MapPoint(
    catchId: id,
    displayLatLng: LatLng(lat, lng),
    source: MapPointSource.friend,
    isInMpa: false,
    isMpaShifted: false,
  );
}

Widget _harness({
  required AsyncValue<List<MapPoint>> initial,
}) {
  return ProviderScope(
    overrides: [
      mapPointsProvider.overrideWith((_) async {
        return initial.when(
          data: (v) => v,
          loading: () => throw UnimplementedError(),
          error: (e, _) => throw Exception(e.toString()),
        );
      }),
    ],
    child: const MaterialApp(home: MapScreen()),
  );
}

void main() {
  testWidgets('renders map controls + legend', (tester) async {
    await tester.pumpWidget(_harness(initial: const AsyncData([])));
    await tester.pumpAndSettle();

    expect(find.byType(MapControls), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Yours'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
  });

  testWidgets('renders own + friend pins by default (heatmap OFF)',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        initial: AsyncData([_own('a'), _friend('b')]),
      ),
    );
    await tester.pumpAndSettle();

    // Default heatmap is OFF — friend points render as pins, no heatmap.
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(find.byType(HeatmapLayer), findsNothing);
  });

  testWidgets(
      'turning Density ON makes friend points become a heatmap layer',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        initial: AsyncData([_own('a'), _friend('b')]),
      ),
    );
    await tester.pumpAndSettle();

    // Default density is OFF; tap to turn ON.
    final densityToggle = find.descendant(
      of: find.byType(MapControls),
      matching: find.text('Density'),
    );
    await tester.tap(densityToggle);
    await tester.pumpAndSettle();

    expect(find.byType(HeatmapLayer), findsOneWidget);
  });

  testWidgets('Show Friends OFF hides the heatmap layer in density mode',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        initial: AsyncData([_own('a'), _friend('b')]),
      ),
    );
    await tester.pumpAndSettle();

    // Turn on density first so a heatmap could exist.
    final densityToggle = find.descendant(
      of: find.byType(MapControls),
      matching: find.text('Density'),
    );
    await tester.tap(densityToggle);
    await tester.pumpAndSettle();
    expect(find.byType(HeatmapLayer), findsOneWidget);

    // Then toggle Show Friends OFF.
    final friendsToggle = find.descendant(
      of: find.byType(MapControls),
      matching: find.text('Show friends'),
    );
    await tester.tap(friendsToggle);
    await tester.pumpAndSettle();

    expect(find.byType(HeatmapLayer), findsNothing);
  });

  testWidgets('shows empty state pill when no points exist', (tester) async {
    await tester.pumpWidget(_harness(initial: const AsyncData([])));
    await tester.pumpAndSettle();

    expect(
      find.text('Log a catch with location to see your pins.'),
      findsOneWidget,
    );
  });
}
