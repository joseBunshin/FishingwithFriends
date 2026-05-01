---
title: MPA display suppression — bundled GeoJSON + nearest-non-MPA shift
date: 2026-05-01
type: architecture
milestone: M4
component: lib/features/map/data/mpa_service.dart
---

# MPA display suppression

The origin requirements doc requires that Marine Protected Area pins never reveal exact GPS:

> *"if a catch's GPS falls inside a marine protected area, the location resolves to the nearest non-MPA water feature for display; raw coordinates are still stored privately."*

M4 ships this as `MpaService` (`lib/features/map/data/mpa_service.dart`), used by `mapPointsProvider` to project every catch through `shift(LatLng)` before rendering. The raw GPS in `catches.location` is never mutated.

## Decisions

### Bundled GeoJSON, not a runtime API

The full NOAA Marine Protected Areas Inventory is ~200MB unprocessed. A runtime fetch would also break the offline-first ethos in M6. We ship a curated subset of US National Marine Sanctuaries and Marine National Monuments as `assets/geo/mpa_simplified.geojson` (<2MB) and load it lazily on first map open.

### Hand-rolled point-in-polygon, not `turf_dart`

The dataset is small (~13 polygons in v1) and the algorithm is ~30 lines of pure Dart (ray-casting). A turf dependency would add 100KB+ of JS-port code for one geometric query. If the heatmap clustering grows more spatial primitives in M4.5+, we'll reassess.

### 8-direction step search, not Voronoi

When a point is inside an MPA, we walk N/NE/E/SE/S/SW/W/NW in 0.005° increments (~500m) for up to 8 iterations (max ~4km offset). Returns the first compass step that escapes every polygon. A proper "nearest point on polygon boundary" approach would need a Voronoi diagram or a per-polygon edge-distance query — overkill for a privacy-shift that's allowed to over-approximate.

If the search exhausts without finding an escape (point is deep inside a large sanctuary or surrounded by adjacent MPAs), the service returns `wasShifted: false` and the caller (`mapPointsProvider`) marks the point heatmap-only — the exact pin is suppressed entirely.

### Bundled polygons are bounding rectangles, not detailed boundaries

The asset stores rectangular envelopes around each sanctuary, not the precise multi-polygon boundaries. This is a deliberate over-approximation: a catch outside the real sanctuary but inside the rectangle gets its display offset, which is harmless. A catch inside the real sanctuary that escapes detection would *leak* a protected location — the failure mode we will not allow.

## Licensing

NOAA MPA Inventory data is public domain (17 USC 105 — works of the US Government). The bundled file's metadata block records the source URL and the curation procedure for reproducibility. See `assets/geo/README.md`.

## When to revisit

Move to a runtime-fetched MPA dataset (Supabase edge function with cached response) when **any** of:

- Total simplified GeoJSON exceeds 5MB.
- We need international MPAs (UK, EU, AU regulations differ; sourcing changes).
- Per-state or county protected-water datasets are required (the sourcing surface explodes).

Until then, bundling is simpler, offline-correct, and avoids a Supabase egress cost.

## Test surface

`test/features/map/mpa_service_test.dart` covers:

- inside / outside / edge-adjacent point classification
- shift on a clearly-in-MPA point with verification that the shifted point is outside
- escape budget exhaustion (constructed adjacent-polygon fixture) — `wasShifted` returns false
- malformed GeoJSON throws `FormatException`
- mixed-geometry features (Point + Polygon) parse without error
- concurrent first-load calls share the cached parse

`test/features/map/map_points_provider_test.dart` covers the integration: defensive secret-spot drop, no-GPS drop, MPA shift propagating to `MapPoint.isMpaShifted=true`.
