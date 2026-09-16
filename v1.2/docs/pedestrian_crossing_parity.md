# Mapped pedestrian crossing safety

This is a focused, map-independent transfer of Generational Australian Survival v1.3's pedestrian-crossing rule into the Creator Studio preview. NPC pedestrians and NPR robots use the same saved OSM walking graph. NPD drones remain aerial and are never treated as walkers.

Godot marks a pedestrian graph edge as `crossing: true` only when its `footway`, `pedestrian` or `crossing` tag identifies a crossing on a walkable footway/path/pedestrian way. No crossing is invented from an untagged ordinary street or a point-only crossing tag. The graph records `mapped_crossing_edge_count`; each edge keeps its OSM source way ID. **Rebuild project** refreshes older towns from their saved OSM without asking the creator to edit code.

Before entering a marked crossing, a walker forecasts nearby NPC traffic and the occupied player wagon for enough time to cross with a buffer. If the approach is unsafe, the walker waits and retries. After eight seconds, it tries a non-crossing outgoing route if the OSM graph supplies one. If a route is still unavailable, it remains waiting instead of walking into traffic. When a walker commits, it reserves the crossing until it reaches the other side; ground-level NPC cars yield with clearance for their full artwork. A car legally waiting for the walker is not relocated by the traffic-jam fallback. Bridge and tunnel cars remain on separate layers and are not stopped by a surface crossing.

This does **not** yet add a physical collision body to the preview's procedurally drawn NPCs, force the player to brake after a walker commits, infer unmarked crossings, or replace the traffic-light fallback with surveyed signal timing. Future traffic and Advanced Map Editor stages can strengthen these areas without altering the original OSM.

Focused checks:

- `tools/tests/verify_runtime_crossings.gd`: approaching/stationary vehicles, occupied wagon forecast, NPC yield and release, NPR route inheritance, eight-second alternative and bridge separation.
- `tools/tests/verify_runtime_crossing_maps.gd`: real Howlong, Kingston ACT and Gold Coast exports; no map-specific production rules or LLM calls.
- Isolated Kingston and Gold Coast test projects regenerated navigation and passed shared 330-agent runtime startup. Source files and user projects were preserved. Extended gameplay and performance testing remain with the user.
