# Map-limit road markers

Red Xs identify roads reaching the current town's playable boundary, in outdoor gameplay and the M map. They are drawn automatically when a town loads, so existing projects do not require a rebuild.

`scripts/runtime/map_limits/road_exit_markers.gd` intersects imported road polylines with the same projected `town.json` bounds used for movement protection. Complete OSM ways can continue outside an export; neither their source endpoints nor the furthest feature coordinates define the playable boundary. Interior dead ends, outside-only roads, tangential corner contacts, edge-following roads and pedestrian paths do not produce road-exit markers. A 0.25-metre edge tolerance handles projected endpoint rounding. Duplicate coincident ways are combined at the same crossing layer.

Xs retain readable screen dimensions across walking, driving and overview zoom. Visually coincident Xs combine at broad overview scale but retain all underlying road-exit records. Tunnel markers show in the tunnel view and the map, not as surface exits during ordinary outdoor gameplay.

This is a visual-only layer: it creates no bodies, traffic signals, reservations or navigation edges, and does not change the existing map-boundary movement protection. Original OSM files and saved town data are untouched. Green arrows and linked-map travel are not yet implemented; no red exit is advertised as an available transition.

Focused verification: `tools/tests/verify_road_exit_markers.gd` checks all four sides, through-going clipped ways, actual boundary endpoints, duplicated ways, corner contacts, edge-following roads, internal dead ends, tunnel layers, coordinate offsets, three world scales, zoom and collision separation. With `--town <project directory>` it also inspects a real saved project read-only; `--render` saves actual renderer previews with a player wagon and a fitted map.
