import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/map/data/mpa_service.dart';
import 'package:fishing_with_friends/features/map/data/mpa_service_provider.dart';
import 'package:fishing_with_friends/features/map/domain/map_point.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Combined own + friend catches projected for the map. Applies, in order:
///   1. Drop catches without GPS.
///   2. Drop friend catches flagged secret_spot defensively (RLS already
///      nulls their location at the DB layer; this is belt-and-suspenders).
///   3. Apply MPA shift symmetrically — owner sees own catches shifted too
///      so screenshots that leak the screen don't reveal sanctuary catches.
///   4. Tag each point with source (own / friend), isInMpa, isMpaShifted.
final mapPointsProvider = FutureProvider<List<MapPoint>>((ref) async {
  final mine = await ref.watch(myCatchesProvider.future);
  final friends = await ref.watch(friendsCatchesProvider.future);
  final mpa = ref.watch(mpaServiceProvider);

  final out = <MapPoint>[];
  for (final c in mine) {
    final point = await _project(c, MapPointSource.own, mpa);
    if (point != null) out.add(point);
  }
  for (final c in friends) {
    if (c.secretSpot) continue;
    final point = await _project(c, MapPointSource.friend, mpa);
    if (point != null) out.add(point);
  }
  return out;
});

Future<MapPoint?> _project(
  Catch c,
  MapPointSource source,
  MpaService mpa,
) async {
  if (!c.hasLocation) return null;
  final raw = LatLng(c.latitude!, c.longitude!);
  final shift = await mpa.shift(raw);
  return MapPoint(
    catchId: c.id,
    displayLatLng: shift.displayLatLng,
    source: source,
    isInMpa: shift.wasInMpa,
    isMpaShifted: shift.wasShifted,
    speciesLabel: c.speciesLabel,
  );
}
