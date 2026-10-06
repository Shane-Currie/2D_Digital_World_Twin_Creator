# Scaled roads, parking and footpaths

Creator Studio renders transport surfaces from each imported town's own OSM geometry. The shared runtime uses 8 pixels per real-world metre. The white player wagon is 17×40 pixels, representing approximately 2.1×5 metres, and road, footpath and parking dimensions use that same scale.

## Road widths

`scripts/roads/road_dimensions.gd` is the single dimension source used by rendering, safe vehicle placement, bridge/tunnel corridors and road/building clearance checks.

1. A usable OSM `width` value is authoritative.
2. `est_width` is used when `width` is absent.
3. An OSM `lanes` count is multiplied by a road-class lane width.
4. When all three are missing, deterministic road-class defaults are used. Typical defaults are 6 metres for an ordinary two-lane residential road, 3.2 metres for a driveway, 6 metres for a parking aisle, 1.8 metres for a footway and 2.5 metres for a cycleway.

Widths are clamped to safe rendering limits. Unit-suffixed values such as `6.4 m` are accepted. The application does not claim an inferred width is surveyed OSM data.

## Footpaths and kerbs

Separately mapped `highway=footway`, `path`, `pedestrian`, `cycleway`, `steps` and `bridleway` ways are retained. Road-side footpaths follow explicit `sidewalk`, `sidewalk:left` and `sidewalk:right` tags. For ordinary urban road classes with no sidewalk information, the preview draws a conservative footpath on each side so a sparse map remains legible and playable. `sidewalk=no`, `none` or `separate` prevents that inference.

Kerbs, asphalt, footpath edges and lane markings retain the Generational Australian Survival v1.3 palette. Lane dashes, kerb thickness and footpath widths are scaled in metres rather than fixed independently of the vehicle.

OSM often divides one physical street into separate ways at intersections. The renderer therefore paints every ground-road kerb underlay first, all asphalt surfaces second, and all markings last. Connected ways blend into one road surface instead of leaving a kerb seam across the junction.

## Surface car parks

Closed OSM areas and multipolygons tagged `amenity=parking` are stored as `kind: parking`. Underground, rooftop and multi-storey parking is excluded from the ground surface. The mapped polygon is authoritative; the program does not expand it.

For a sufficiently large paved area, the runtime draws conservative 2.6-metre bay guides and 5.2-metre bay depth. These lines are inferred presentation, not a claim about the real bay layout. Grass, gravel and unpaved car parks keep an appropriate surface and do not receive painted bay lines.

Paved car parks use the same asphalt as roads and are painted below connecting access roads. This removes the mismatched rectangle and perimeter line where a mapped parking aisle meets the car park while preserving the outside kerb.

## Building protection and layers

All ground transport paint is drawn below ground-solid buildings, and `surface_kind_at` applies the same footprint-and-hole mask used for focused validation. The streamed building collision shapes remain authoritative, so the player and vehicles cannot use transport artwork to pass through a building. Parking bay guides that intersect a solid footprint are omitted.

Overhead structures and explicit bridge decks remain on their existing upper layers. Tunnels remain in the isolated tunnel view. A close or contradictory source feature can still require later Advanced Map Editor review; the application reports ambiguous route geometry instead of deciding whether the road or building is the incorrect real-world feature.

## Focused verification

- `tools/tests/verify_surface_transport.gd` checks explicit widths with units, lane-derived widths, road-class defaults, separate and inferred footpaths, parking polygons, bay dimensions and solid-building masking.
- `tools/tests/verify_surface_transport_maps.gd` processes Howlong, Gold Coast, Sydney Harbour and Kingston ACT without town-specific settings and writes `tools/tests/output/surface_transport_maps.json`.
- Isolated Wodonga, Gold Coast and Kingston projects were rebuilt and passed the shared runtime startup/control check with 330 moving road users. The original user projects and source OSM files were not changed.
- Actual Godot captures are under `tools/tests/output/stage4_transport_visuals/`.

These are focused generation, rendering and startup checks. Extended driving, pedestrian behaviour and performance remain user-tested.
