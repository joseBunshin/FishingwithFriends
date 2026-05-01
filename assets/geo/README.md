# Geographic assets

Bundled geographic data used by Fishing with Friends at runtime. All files in this directory are loaded via `rootBundle` from Dart code; nothing here is fetched at runtime.

## `mpa_simplified.geojson`

Simplified bounding polygons for major US National Marine Sanctuaries and Marine National Monuments. Used by `MpaService` (`lib/features/map/data/mpa_service.dart`) to suppress the display of catch pins that fall inside a protected area, per the requirements doc privacy rule:

> *"if a catch's GPS falls inside a marine protected area, the location resolves to the nearest non-MPA water feature for display; raw coordinates are still stored privately."*

### Source

NOAA Office of National Marine Sanctuaries — public domain (17 USC 105 — works of the US Government). https://sanctuaries.noaa.gov/

The full NOAA Marine Protected Areas Inventory shapefile is ~200MB unprocessed and is impractical to ship in a mobile app bundle. This file is a hand-curated subset covering the largest and most-fished US sanctuaries plus the Pacific monuments.

### What's included (v1 starter)

| Code | Name | Region |
|------|------|--------|
| FKNMS | Florida Keys National Marine Sanctuary | South Florida |
| CINMS | Channel Islands National Marine Sanctuary | Southern California |
| MBNMS | Monterey Bay National Marine Sanctuary | Central California |
| GFNMS | Greater Farallones National Marine Sanctuary | Northern California |
| CBNMS | Cordell Bank National Marine Sanctuary | Northern California |
| OCNMS | Olympic Coast National Marine Sanctuary | Washington |
| SBNMS | Stellwagen Bank National Marine Sanctuary | Massachusetts |
| GRNMS | Gray's Reef National Marine Sanctuary | Georgia |
| FGBNMS | Flower Garden Banks National Marine Sanctuary | Gulf of Mexico |
| HIHWNMS | Hawaiian Islands Humpback Whale National Marine Sanctuary | Hawaii |
| PMNM | Papahānaumokuākea Marine National Monument | NW Hawaiian Islands |
| TBNMS | Thunder Bay National Marine Sanctuary | Lake Huron, Michigan |
| MBPNMS | Mallows Bay-Potomac National Marine Sanctuary | Maryland (Potomac River) |

### Simplification rules

- **Bounding rectangles, not detailed polygons.** Each sanctuary is represented as a rectangular envelope that contains its actual boundary. This is a deliberate over-approximation: a catch outside the real sanctuary but inside the bounding rectangle gets its display offset, which is harmless. A catch inside the real sanctuary that escapes detection because of under-approximation would *leak* a protected location, which we will not allow.
- **Coordinates in `[longitude, latitude]` order.** Standard GeoJSON convention.
- **Holes / inner rings dropped.** A few sanctuaries have unprotected enclaves; we treat the whole envelope as MPA for display purposes. False positives are privacy-correct.

### How to refresh

The Dart code only requires:
1. Top-level `type: "FeatureCollection"`.
2. Each feature has a `properties.name` (string) and a `geometry` of type `Polygon` with a single outer ring. Multi-polygon features are not currently supported — split them into multiple `Feature`s with the same `name`.
3. Polygon rings closed (first coordinate equals last).

To regenerate from the full NOAA dataset:
1. Download the MPA Inventory shapefile from https://marineprotectedareas.noaa.gov/dataanalysis/mpainventory/.
2. Filter to features matching the `Marine Protected Area Type` values you want (we use `National Marine Sanctuary` + `Marine National Monument`).
3. Reproject to EPSG:4326 (WGS-84 lat/lng) if not already.
4. Simplify each polygon to a bounding rectangle (or use `mapshaper -simplify dp 0.001` for slightly more detail; keep total file <2MB).
5. Export as GeoJSON; replace this file.
6. Run `flutter test test/features/map/mpa_service_test.dart` to confirm the loader still parses cleanly.

### When to revisit

Move to a runtime-fetched MPA dataset (Supabase edge function with cached response) when **any** of these is true:
- Total simplified GeoJSON exceeds 5MB.
- We need international MPAs (UK, EU, AU regulations differ; sourcing changes).
- Per-state or county protected-water datasets are required (the sourcing surface explodes).

Until then, bundling is simpler, offline-correct, and avoids a Supabase egress cost.
