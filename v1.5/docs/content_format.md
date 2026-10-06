# Creator content format v1

Creator Studio saves each town in a directory chosen by the creator. The GUI and `tools/creator-cli.js` read the same files. Nothing important is stored only in the GUI.

## Town directory

```text
<chosen workspace>/<town_id>/
├── town.json
├── game_settings.json
├── runtime_profile.json
├── validation.json
├── source_osm/
│   └── 01_original-name.osm
├── assets/
│   └── buildings/<stable_building_id>/
│       └── exterior_<content_hash>.<png|jpg|webp>
└── data/
    ├── building_exteriors.json
    ├── building_interiors.json
    ├── interior_furniture_catalog.json
    ├── interior_floor_materials.json
    ├── map_features.json
    ├── map_overrides.json
    ├── place_information.json
    ├── population_destinations.json
    ├── personas.json
    ├── storyline_npcs.json
    ├── trader_npcs.json
    ├── location_notes.json
    ├── location_notes/
    │   └── <building_id>.txt
    ├── town_knowledge.json
    ├── town_knowledge/
    │   └── custom_town_information.txt
    ├── building_collisions.json
    └── navigation_graphs.json
```

`town.json` identifies the content schema, display name, source files, imported geographic bounds, CBD rectangle, starting position and import counts. `data/map_features.json` keeps building, road, footpath, surface-parking, water, waterway, coastline and overhead-structure geometry used by the GUI preview and runtime. Source files are copied rather than moved.

`data/map_overrides.json` stores reversible creator corrections separately from OSM: hidden building feature IDs, blocked-water zones and passable-ground holes. Create/Save/Rebuild and the runtime apply these corrections before generating or consuming collisions, navigation, place information and population destinations. The saved source fingerprint flags changed OSM feature sets for review. Its contract is `schemas/map_overrides.schema.json`; see [advanced_map_editor.md](advanced_map_editor.md).

`data/building_exteriors.json` stores Building Creator choices by the stable OSM footprint ID. Exterior images are copied into `assets/buildings/<stable_building_id>/`, validated, and drawn clipped to the footprint in both Creator Studio and Play test. Scale, rotation and two-axis offset use identical UV mapping in both views. Up to eight stable-ID door records snap to footprint edges and retain verified clear outside arrow points plus nearby pedestrian-node links when available; older single-door data migrates automatically. Neither artwork nor a door changes the generated building collision. Its contract is `schemas/building_exteriors.schema.json`; see [building_creator.md](building_creator.md).

`data/building_interiors.json` stores Creator-authored floors by the same stable OSM footprint ID. A new ground floor begins as the footprint's metre-projected outline, including concave edges and courtyard holes. Upper floors copy that shape; a creator may enlarge an individual floor from 100% to 300% while preserving its proportions. Enlarged geometry is explicitly marked creator-adjusted rather than mapped or surveyed. Ground-floor entry links refer to stable exterior entrance IDs and must remain inside the usable floor. Each floor may store internal `walls` as snapped metre start/end segments with collision thickness and E-operated door locations, optional door `locked` states, and `rooms` as creator-provided names with map-label positions. Its optional `flooring` record maps deterministic 0.5-metre cell keys to built-in or creator-imported material IDs; paint is visual and does not create collision. Its `furniture` array stores validated v1.5 catalogue items with stable IDs, object type, centre position, real-metre dimensions, rotation, colours, optional copied artwork and collision. The playable runtime joins matching IDs: **E** at the exterior arrow enters the ground floor, **E** at an unlocked green internal door crosses that wall, a locked red door refuses entry, and **E** at the interior exit returns outside. Wall/door sections and furniture block ordinary walking. Runtime visibility derives separate enclosed regions from the saved walls, greys undiscovered regions and reveals them when the player uses a door to enter. The current room name is shown in the top heading instead of on the playable floor. Clicking furniture displays its saved object type above the player. Its contract is `schemas/building_interiors.schema.json`; see [interior_designer.md](interior_designer.md).

`data/interior_furniture_catalog.json` stores reusable creator-imported furniture definitions. Pictures are copied beneath `assets/interiors/furniture/`; catalogue paths must remain relative and inside that folder. Every custom entry is collision-enabled and has a creator-entered display name, plain object type, 0.1–20 metre width/depth and optional `usage_categories`. Creators may reuse the built-in Residential/Business/Office/Shop/Restaurant/Pub categories or add their own; every upload also appears under My creations. Older entries without `usage_categories` remain valid and are treated as My creations. Its contract is `schemas/interior_furniture_catalog.schema.json`.

`data/interior_floor_materials.json` stores reusable creator-imported floor textures. Pictures are copied beneath `assets/interiors/floors/`; paths must remain relative and inside that folder. Valid uploads are PNG, JPEG or WebP no larger than 20 MB or 4096 pixels per edge. The image is treated as untrusted visual data and is never executed. Built-in light oak, dark walnut and weathered grey floorboards remain project assets rather than being duplicated into every town. Its contract is `schemas/interior_floor_materials.schema.json`.

`game_settings.json` contains creator-editable NPC, traffic, NPR and NPD populations and CBD targets, left/right road rules, visual-only skin-pigmentation percentages, camera views, player-driving and traffic-recovery values. The three pigmentation controls are **Light**, **Medium** and **Dark**. They select complete static NPC sprites only, must total 100%, and do not affect age, gender, clothing, navigation, intelligence or persona. Equal weights are generated by the default-selected Equalize control. Older seven-range v1.2 settings are combined into the three new ranges when loaded. Player driving includes a creator-facing `max_speed_kmh` value (default 200); the runtime converts it with the town's saved pixels-per-metre scale and uses the same conversion for the HUD. The Creator Studio Game Settings page is the ordinary user interface; `schemas/game_settings.schema.json` defines the safe ranges.

Camera zoom is saved per town as `camera.character_zoom` for walking and `driving.camera_zoom_multiplier` for the in-car view. Despite its older key name, the in-car value is an independent absolute zoom: changing walking zoom does not change the driving view. New towns default to **2.7× on foot** and **1.5× in a car**. Both accept `0.2`–`3.0` through the GUI or CLI (`set-settings --character-zoom N --in-car-zoom N`). Explicit choices already saved in a town are preserved; a missing walking value receives 2.7×.

NPC appearances come from 18 complete transparent sprites: three skin-pigmentation groups × man/woman × young adult/adult/older adult. Outfit, face, hair and body shape are baked into each asset; the runtime does not redraw or recolour them. Traffic likewise selects from 12 complete sprites covering sedan, wagon and ute bodies in four fixed colours each. Movement transforms and tyre highlights provide motion without procedurally changing the artwork.

`data/navigation_graphs.json` is regenerated from OSM whenever the GUI creates or saves a project. It retains directed vehicle/pedestrian edges, source way IDs, distances, disconnected components, CBD reachability, the chosen road side and explicit inference warnings. OSM node IDs determine intersections, preventing roads that merely cross at different levels from being falsely joined. Its contract is `schemas/navigation_graphs.schema.json`. The shared playable preview consumes these graphs for cars, NPCs, NPRs and NPDs; the JSON remains data, not executable code.

OSM-tagged footway/path crossing edges also carry `crossing: true`; the pedestrian graph reports `mapped_crossing_edge_count`. During Play test, NPCs and NPRs wait for a vehicle gap before committing, and NPC ground traffic yields until they finish. Untagged streets are not silently labelled as crossings. See [pedestrian_crossing_parity.md](pedestrian_crossing_parity.md).

`data/building_collisions.json` is regenerated from the same imported OSM geometry. It converts longitude/latitude rings to local metres, retains concave outlines and multipolygon inner courtyards, records an 8-pixel-per-metre runtime scale, and assigns buildings to 256-metre streaming chunks. It also contains `water_areas` and tagged `water_crossings` with bridge/tunnel kind, width and OSM layer. The runtime uses these areas as the shared ground-traversal rule and the reusable Godot loader creates static building pieces only for nearby chunks. Its contract is `schemas/building_collisions.schema.json`. Textures never define physical collision.

`data/place_information.json` contains readable records derived only from tags attached to each building footprint. Records retain stable feature IDs, selected mapped fields, source-tag provenance, the OSM way/relation reference and **© OpenStreetMap contributors** attribution. The runtime joins these records to `map_features.json` geometry for hover/click selection. Its contract is `schemas/place_information.schema.json`. Nearby points of interest are not silently promoted to whole-building facts.

`data/population_destinations.json` contains the subset of directly tagged building footprints that can be linked to a pedestrian graph node within 250 metres. It groups mapped residential, education, health, retail, office, hospitality, civic, recreation, industrial and transport uses for NPC/NPR route planning while explicitly leaving exact entrances unverified. The runtime only selects places in the actor's connected walking-network section and falls back to ordinary graph wandering when a map has no usable destinations. Its contract is `schemas/population_destinations.schema.json`; see [population_destinations.md](population_destinations.md).

`data/storyline_npcs.json` stores persistent creator-placed characters separately from the editable random persona library. Its optional `npc_role` distinguishes `storyline`, `trader`, `generic` and `npr`; `actor_kind` distinguishes human `npc` from robot `npr`. New IDs use the role prefix and shared monotonic counter. Legacy placements with active/nonempty trader profiles are classified in memory, preserving IDs/stock and effective personas; explicit roles are authoritative and migration persists on Save. The shared file is retained for compatibility while creator lists/workflows are separate. Outdoor records use latitude/longitude and validate town bounds, fixed buildings, water and pedestrian-network proximity. Interior records use `building_id`, `floor_id`, `x_metres` and `y_metres`, validated against `data/building_interiors.json`. Each character retains a stable ID, name, actor-compatible persona and artwork. Explicitly placed generic NPCs/NPRs currently stand at their assigned points; this is not an interior roaming system. See `schemas/npc.schema.json`.

Water import recognises standard OSM closed ways and multipolygon tag families including `natural=water`, `water=*`, `landuse=reservoir`, `waterway=riverbank` and swimming pools, plus linear waterways and coastlines. Bounded coastal exports may omit remote members of a harbour/sea relation. The deterministic importer clips supplied outer shoreline chains to the declared OSM `<bounds>`, closes them along that export rectangle, and selects the candidate containing less mapped building/ordinary-road evidence. Such features carry `geometry_quality: clipped_osm_boundary_inference`; they are inferred only at the known export edge, not surveyed closures.

If an incomplete relation cannot be resolved unambiguously, `unresolved_water_relations` is non-zero and validation blocks a playable build. This is a safety rule: unknown water must not silently become drivable ground. A complete source export is still required for that import blocker. The Advanced Map Editor can correct known local omissions after a town is created, but its current rectangle tool does not certify an unknown incomplete coastline relation. The GUI and Node CLI apply identical rules and neither path calls an LLM.

Missing relation members are classified by OSM role. Missing `outer` members can make the water edge unknown and invoke reconstruction or the blocker above. Missing `inner` members represent omitted islands/dry-land holes; when the outer ring is complete, the importer keeps the uncertain holes conservatively blocked as water, emits a warning and permits the project to build. It must not discard a valid outer water polygon merely because an optional inner member is outside the export.

When OSM supplies `<bounds>`, that declared export rectangle is the playable map boundary even if a complete road way contains end nodes slightly outside it. Player and owned-vehicle movement cannot escape around a coastal water polygon by leaving the authoritative exported area.

`town.json` records both portable copied OSM files and, for new imports, their original local paths. The GUI exposes one **Rebuild project** action: it automatically prefers all available originals and otherwise uses the copies. A rebuild regenerates map features, collisions, navigation, traffic controls, validation and the shared playable profile without requiring code or an LLM.

`data/map_features.json` preserves tags attached to OSM road nodes. Navigation generation classifies traffic signals, stop signs, give-way signs and crossings from those tags. When no explicit controls are present, the runtime uses basic safe junction reservations and reports the assumption instead of inventing surveyed controls.

`runtime_profile.json` records the complete gameplay feature family the generated game must provide. GUI-created or upgraded projects use `preview_ready` and `creator_studio_shared_runtime`, allowing **Play test project** to open the town with the current generic mechanics. Node-only imports use `pending_runtime_build` until the Godot build command below creates navigation data and upgrades the profile. `preview_ready` does not mean full v1.3 parity; read `preview_limitations` before making compatibility claims.

`starting_location` contains separate geographic positions for the player and the player's vehicle. Creator Studio rejects a player position inside or within 1 metre of a fixed building footprint, finds a road position for the vehicle with 4 metres of footprint clearance, and keeps at least 8 metres between them. These checks run again during validation so an unsafe manual file edit cannot silently pass. As new non-movable footprint types are added, they must use `fixed_footprint` and participate in the same validation.

A curated start may also include `label`, `osm_building_id`, `placement` and `entrance_verified`. These are descriptive provenance, not permission to bypass geometry checks. Use `entrance_verified: false` when a start is associated with a named building but the source does not establish an exact doorway; never convert a place name into an invented entrance.

The schema is `schemas/town.schema.json`. Future migrations must increase `schema_version` and provide an explicit upgrade command; never silently reinterpret an older content pack.

## Coordinate convention

- Geographic points are `[longitude, latitude]` decimal degrees.
- Bounds use `west`, `south`, `east`, `north`.
- Godot/game coordinates are generated later and must not replace the geographic source.

## Codex contract

Use the CLI for predictable reads and writes. Pass `--json` for one machine-readable JSON object. A non-zero exit code means validation or the requested operation failed.

```text
node tools/creator-cli.js list-towns --workspace <directory> --json
node tools/creator-cli.js inspect-town --town <town-directory> --json
node tools/creator-cli.js inspect-building --town <town-directory> --feature-id <OSM_ID> --json
node tools/creator-cli.js list-personas --town <town-directory> --json
node tools/creator-cli.js show-town-knowledge --town <town-directory> --json
node tools/creator-cli.js validate-town --town <town-directory> --json
node tools/creator-cli.js get-settings --town <town-directory> --json
node tools/creator-cli.js set-settings --town <town-directory> --traffic-car-count 200 --cbd-car-percent 70 --json
node tools/creator-cli.js set-settings --town <town-directory> --driving-side left --robot-count 20 --cbd-robot-percent 100 --drone-count 10 --cbd-drone-percent 90 --equalize-skin-tones --json
```

`inspect-building` returns one generated, OSM-attributed record without operating the GUI. Use the stable feature ID displayed by Creator Studio or the playable popup.

Codex can regenerate a saved town's navigation without operating the GUI:

```text
Godot_v4.7.2-stable_win64.exe --headless --path <creator-v1.2> --script res://tools/build_town_navigation.gd -- --town <town-directory>
```

Do not edit copied OSM source files. Building, interior and persona editors store user choices in explicit town data files with stable IDs.

## Local LLM boundary

`data/personas.json` stores the shared persona library and selected installed Ollama model. Placed human categories share human choices, including editable Barkeep/Shopkeeper defaults; NPRs use robot personas. The legacy `trader_only` flag excludes specialist presets from random roaming assignments, not explicit human selections. The runtime contacts only `http://127.0.0.1:11434` for dialogue. A trader reply may propose an item/quantity, but only validated purchase confirmation changes inventory; the model cannot call gameplay functions or modify project content. Files remain documented JSON for creators/Codex without GUI automation.

`data/location_notes.json` maps stable building IDs to copied UTF-8 files at `data/location_notes/<building_id>.txt`. References are optional, capped at 64 KB each and 128 buildings, validated and loaded once per runtime startup. All floors share their building reference. Conversations receive bounded relevant excerpts, current indoor building/floor context or explicit outdoor context; street characters can discuss named venues without pretending to be inside them. Reference text is untrusted background, never commands or authoritative trader stock. See `schemas/location_notes.schema.json` and [location notes](location_notes.md).

`data/town_knowledge.json` stores optional town-reference metadata and a cached Wikipedia lead summary. A creator-imported UTF-8 text file is copied to `data/town_knowledge/custom_town_information.txt`; its original filename, import time, size and SHA-256 fingerprint are recorded. Either source, both sources or neither source is valid. At startup the runtime refreshes an exact creator-supplied HTTPS Wikipedia article URL once, falls back to the last cache when offline, and passes only bounded separately labelled excerpts to conversations. The local LLM receives no web or file tool, and reference text cannot issue gameplay commands. Its contract is `schemas/town_knowledge.schema.json`; use `show-town-knowledge` for a deterministic read without fetching Wikipedia or invoking Ollama.

Town import, coordinate projection, collision generation, validation, chunking and route generation are deterministic operations. They never call a local LLM, Codex or an online model and contain no town-specific coordinates. Unsupported or malformed OSM geometry is reported; model output is never used to guess a replacement footprint.
