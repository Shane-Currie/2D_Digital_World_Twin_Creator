# Mapped pedestrian crossing safety

This is a focused, map-independent transfer of Generational Australian Survival v1.3's pedestrian-crossing rule into the Creator Studio preview. NPC pedestrians and NPR robots use the same saved OSM walking graph. NPD drones remain aerial and are never treated as walkers.

The saved pedestrian graph records OSM-marked crossings and keeps each source way ID. At runtime, NPCs and NPRs use the same road-width rules as the renderer to walk on a mapped or inferred roadside footpath, not the vehicle centre line. A one-sided OSM sidewalk tag is respected in either walking direction. A blocked roadside route is held rather than replaced with a route through the traffic lane. Existing saved towns gain this runtime behaviour without changing their OSM files.

Creator validation now records the number of directed pedestrian links that rely on inferred roadside walking space, with a plain-language warning that these are not surveyed pavements. Saved towns need a Rebuild for that new report, though the runtime movement fix also applies before rebuilding.

Before entering an OSM-marked crossing, an untagged footway spanning a surface road, or a connector between walking corridors, a walker forecasts nearby NPC traffic and the occupied player wagon for enough time to cross with a buffer. Signal-tagged crossings additionally use the preview's walking phase. If unsafe, the walker waits and retries; after eight seconds it may choose a non-crossing outgoing edge. A committed crossing is reserved until clear, and both NPC cars and the player wagon yield. Bridge and tunnel traffic on different levels is excluded from surface-crossing conflicts.

Limitations: OSM often omits actual footpath detail, so a roadside corridor may be inferred; this is not a surveyed pavement. Local connectors are conservative and can make walkers wait at ordinary corners. The route check uses the current water/building geometry, but unsupported or incomplete OSM remains a source of uncertainty. Procedurally drawn walkers still have no physical collision body, and the preview's signal cycle is not surveyed controller timing. Reverse gear and optional player lane/path assistance are separate pending stages.

Focused checks:

- `tools/tests/verify_runtime_crossings.gd`: approaching/stationary vehicles, occupied wagon forecast and yield, NPC/NPR reservations, signal phase, untagged footway crossing detection, roadside offset, one-sided sidewalk continuity and bridge separation.
- `tools/tests/verify_runtime_footpaths.gd`: an imported playable town's NPC/NPR road-edge targets and blocked-route fallback.
- `tools/tests/verify_runtime_crossing_maps.gd`: real Howlong, Kingston ACT and Gold Coast exports; no map-specific production rules or LLM calls.
- The current Albury test project started without script errors. Its focused route check found 99 NPC/NPR road-edge routes and two safely held blocked routes. This is not an extended traffic-flow or visual gameplay test.
