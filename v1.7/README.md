



# 2D Digital World Twin Creator v1.7

For **Animated NPCs**, the illustrated cutout library, red-jacket player and no-LLM **Test walking** window, see [NPC body-parts animation](docs/npc_body_parts.md). The main character and generic, storyline and trader humans all animate when walking; older static settings migrate automatically.

**v1.7 complete — 8 October 2026.** This release fixes importing new OSM maps containing trees, protects existing projects and simplifies town setup into separate tool buttons. **Play test project** has its own named page and can create/launch a ready new town in one action. The exact `gold_coast.osm` import and rendered game startup were verified; the user confirmed the fix. Separate v1.1–v1.6 releases remain preserved; next development is v1.8. See [release changes](CHANGELOG.md) and [import/play instructions](docs/editor_usability.md).

Local **Ollama** integration remains included for natural NPC/NPR persona conversations, optional town information, venue notes and game lore. Model-proposed trades require game validation and player confirmation. This is a Godot source release; Gold Coast's missing usable aerial routes, standalone export and extended performance testing remain recorded limitations.

The first v1.6 stage adds **building heights and raised-roof perspective**. Valid OSM `building:levels` values load automatically; missing/unusable counts use one floor. In **Advanced map editor → Set building heights**, enter a total-floor count, click buildings, then save. **Building Creator** offers individual floor counts, generic roof/wall styles and custom roof/wall uploads. These are visual overrides: original ground footprints, collisions, doors and furnished interiors stay unchanged. See [building heights](docs/building_heights.md) for instructions and current limits.

Project Website: https://www.shanescomputing.com.au/2D_Digital_World_Twin_Creator.html

**Playable upper floors:** Interior Designer → **Stairs** lets creators connect existing floors or choose **New upper floor** to create one automatically with its stairs and raise the exterior count if needed. Save, then press **E** at the stairs in Play test. Existing ground-floor entrances, furniture and outside return positions remain intact. See [stairs instructions](docs/interior_stairs.md).

**Bathroom assets:** three paintable tile designs, two walk-in cubicle variants, a wall urinal and a trough urinal are available in the Interior Designer. See [bathroom asset instructions](docs/bathroom_assets.md).

**Connected buildings:** Interior Designer → **Connecting doors** places and drags a paired door between buildings whose OSM footprints share an actual wall, with no gap. Save, then press **E** for direct indoor travel. Buildings keep their own floors, furniture and outside exits. See [connecting-door instructions](docs/connected_buildings.md).

(disclaimer, GPT5.5 Sol was used to create this program & the README.md document) 


Creator Studio is a no-code Godot application for turning OpenStreetMap data into editable 2D town projects. It is being developed for creative users who should not need to write Godot code.

Playable controls use **WASD** while walking. Press **T** near an NPC or NPR to talk, type a message, then press **Enter** or **Send**; press **T**, **Escape** or **End** to finish. In the wagon, **Up/Down Arrow** adjust the cruise target by 1 km/h, **Left/Right Arrow** steer, **Shift** toggles Drive/Reverse near a stop, and **Space** brakes. The numbered speedometer shows actual speed and the selected target; a car-only odometer shows lifetime and resettable trip distance. Click the backpack at the lower right to inspect or consume items. A new player starts with **100 Keks**, **3 bananas** and **3 water bottles**. The top-right Player Stats menu reveals nutrient and hydration bars, both starting at 50/100. Creators manage built-in and custom items through **Inventory items** in Creator Studio. New towns default to a creator-editable maximum of **200 km/h** and a **7.2-second 0–100 km/h** acceleration time. See [player controls](docs/player_controls.md), [player inventory](docs/player_inventory.md) and [basic conversations](docs/basic_conversations.md).

## Quick overview

**Interior Designer** now starts with a building selector and app-style buttons for floors, entrances, walls/rooms, floor textures, furniture, uploads and NPC placement. **NPCs and personas** uses buttons for Generic NPCs, NPR, Storyline NPCs, Trader NPCs, Local LLM and Town information. Back preserves edits within each section; the top floppy disk stays visible. Storyline/trader placement lists are separate, with the same human personas and an added trading inventory for traders. Save before leaving a main section.

Trader NPCs can sell catalogue items for Keks. Configure **Trader NPCs** inside **NPCs and personas**, then save with the top floppy disk. In play, press **T** and ask to buy, or use **Shop**; **Accept purchase** updates both inventories together. The Albury pub example has Moe selling beer for 5 Keks. Local Ollama proposes purchases only—the game checks stock/payment and the player confirms. See [trader setup and purchases](docs/trader_npcs.md).

Clear purchase requests now open confirmation without waiting for Ollama, using current remaining stock. Startup loads venue references and stock context before warming the model. Interior Designer also supports placed **Generic NPCs/NPRs** and optional **Location notes** text uploads, available to indoor and street conversations. The Albury pub test reference includes “A pub to enjoy a beer without judgement”. See [placement and venue references](docs/location_notes.md). Open-ended dialogue speed and factual accuracy still depend on the selected local model.

Choose an OpenStreetMap `.osm` file, mark the CBD and safe player/car starting locations on the preview, choose the local driving side and game settings, then select where the new town will be saved. Import a town uses separate, self-explanatory buttons with Back navigation; the map and top floppy-disk Save remain visible. **Play test project → Play current project** launches the result and creates a fully configured unsaved town automatically. Green ticks and red crosses beside required menu items show whether they are ready. Existing projects can be reopened from Home or selected on the Play test project page. Start this source version by double-clicking `Start Creator Studio.cmd`; it will find Godot or explain how to select/install it.

v1.5 carries forward v1.4's directional actor presentation, map-derived population destinations, Advanced Map Editor, Building Creator and playable footprint-shaped interiors, then expands the no-code Interior Designer. Its illustrated furniture list contains metre-scaled built-ins and accepts creator-uploaded PNG/JPEG/WebP objects with automatic collision. The floor preview has Advanced Map Editor-style zoom/pan controls, and clicking furniture during play identifies its object type above the player. See [directional actor animation](docs/directional_actor_animation.md), [population destinations](docs/population_destinations.md), [Advanced Map Editor](docs/advanced_map_editor.md), [Building Creator](docs/building_creator.md) and [Interior Designer](docs/interior_designer.md).


## Starting Creator Studio

For this source version, double-click `Start Creator Studio.cmd`. The launcher searches for Godot, allows the user to locate a portable executable, checks its version and explains how to install Godot if necessary. It remembers a valid selected executable, displays startup progress, opens Creator Studio maximized and reports a plain-language failure with a startup-log location instead of silently closing.

The final public build will be exported as `2D Digital World Twin Creator.exe`, with the Godot runtime included so ordinary creators will not need the Godot editor.

Developers can also import `project.godot` in Godot 4.7 or newer and press F6/F5.

## Creating a town

1. Open **Import a town**.
2. Enter the town's display name.
3. Choose one or more `.osm` files and select **Read files and show preview**.
4. Open **CBD area** and drag a rectangle around the CBD.
5. Open **Player start**, then click an open player position. Creator Studio finds a separate safe road position for the player's vehicle; **Car start** lets you place and rotate it.
6. Use `−`, **Reset**, `+` or the mouse wheel to zoom the preview; hold the middle mouse button and drag to pan.
7. Open **Driving side** and choose whether traffic drives on the left or right.
8. Open **Save folder**, select **Choose save directory** and choose where game projects belong.
9. Save, then open **Play test project → Play current project**. A ready unsaved town is created automatically when played.

Creator Studio creates `<chosen directory>/<town_id>/`. The original source files are copied and never moved.

Every create/save operation generates `data/building_collisions.json` directly from the imported OSM footprint coordinates. This deterministic process does not contact or use an LLM. Simple, concave and relation-based buildings retain their shapes; inner OSM rings remain open courtyards. Invalid geometry is listed in the validation report instead of being invented.

Creator Studio also checks roads against ground-solid building footprints before generating pathfinding. A ground route whose centre line passes through a solid building is excluded from vehicle and pedestrian graphs; a close but centre-line-clear route stays usable and is reported for review. Explicit bridges, tunnels, overhead roofs and underground structures keep their separate vertical meaning. Ambiguous non-zero-layer roads without a real bridge/tunnel tag are excluded instead of creating flying traffic. Results are saved in `data/navigation_graphs.json` and `validation.json`; the full rules and limitations are documented in [docs/map_geometry_validation.md](docs/map_geometry_validation.md).

## Reopening and play testing

From **Home**, select **Open previous project** and choose the town folder containing `town.json`—for example `test/wodonga_test`. The project reopens in the import/editor page and **Save project changes** updates its CBD, start and town metadata without copying the source files again.

Choose **Advanced map editor** for map corrections. Select an imported building to hide/restore it, or drag a rectangle for missing blocked water or an incorrectly mapped passable area. The same page can copy an exact clicked latitude/longitude for a storyline NPC. Undo/Redo works during the editing session. **Save corrections and rebuild** updates generated collision and pathfinding files while leaving both the original and copied OSM files unchanged.

Choose **Building Creator** to select an active OSM building footprint. **Export footprint for Paint** saves a north-up, real-proportion PNG with a grey editable footprint and transparent exterior/courtyard space; keep its canvas size unchanged in Microsoft Paint, then import the painted PNG with **Choose exterior image**. Existing PNG/JPG/WebP artwork can also be imported directly. The image is copied into the town and clipped to the mapped footprint; no-code controls adjust its scale, rotation and horizontal/vertical position. Add, move or remove up to eight entrances. Every door snaps to its chosen wall and each green arrow is accepted only where Creator Studio finds a clear outside approach. Save the design to make the same alignment and entrances appear in Play test. Building collision remains the original effective footprint, so artwork cannot make a wall passable. Link an entrance in **Interior Designer**, then stand at its exterior arrow and press **E** in Play test to enter. Interior Designer can also select/copy stable building, floor and X/Y metre locations for storyline NPC placement.

Select **Play test project** in the main left menu to open the loaded town in a separate game window. If all six setup steps are complete but the town has not been generated yet, this button creates it automatically and asks the creator to select Play once more. Use **WASD** to walk, move beside the wagon and press **E** to enter it, use the arrow keys to drive, press **E** to exit, press **M** for the current map and press **Escape** to close the game window. Outdoors, M opens the full-town map; indoors, it opens a fitted map of the current building floor. Move the mouse over either map to update the turquoise crosshair and its latitude/longitude or building/floor/X/Y details. **Copy location** puts plain text on the clipboard for the Storyline NPC creator or another app. Use the mouse wheel or −/+ buttons to zoom, drag with the left mouse button to move around, select **Fit** to show the complete town/floor, or **You** to return to the player's location. Location details are deliberately hidden during normal play. The Creator Studio stays open so work is not lost.

Hover over a building to see its mapped name/use and source, or click it to pin fuller details such as its available address, operator, levels, opening hours and accessibility. Click empty ground to close it; in map mode, dragging still begins from empty ground. Every popup identifies **© OpenStreetMap contributors** and its source way/relation ID. Missing information is shown as not mapped instead of being invented. Rebuild older projects to save their `data/place_information.json`; details and limitations are in [docs/building_information.md](docs/building_information.md).

The play window automatically uses the same 384×240 logical scale and compact HUD as v1.3 while Creator Studio itself keeps its larger editing layout. Buildings are styled from each map's own OSM tags and exact footprint; unlabelled buildings receive a stable generic house variant. The same town always rebuilds with the same visual choices, and no Wodonga- or Albury-specific graphics rule is required.

Roads, kerbs, car parks and footpaths now share that v1.3-style presentation and a common real-world scale. OSM width and lane tags take priority, with documented road-class defaults when detail is absent. Surface `amenity=parking` polygons retain their mapped boundary and may receive conservative scale-correct bay guides; those inferred guides are not claimed as surveyed spaces. Separately mapped footways are preserved, while explicit sidewalk tags or documented urban defaults add roadside footpaths. Solid building footprints mask all ground transport artwork and keep their collision. See [docs/scaled_transport_surfaces.md](docs/scaled_transport_surfaces.md).

Street labels also come from the current town's own OSM data. Major roads are prioritised at broad zoom levels; secondary and local street names appear progressively while zooming in. Roads that have no OSM `name` cannot be labelled reliably and remain unnamed rather than receiving an invented name.

Water placement also comes from the current map. Creator Studio recognises standard OSM water areas, waterways and multipolygon relations. A coastal export often cuts a much larger sea or harbour relation at its rectangular boundary; in that case the importer joins the supplied shoreline fragments to the declared export edge and selects the side containing the least mapped land development. The result is marked as reconstructed OSM-boundary geometry and shown in the preview. This uses no LLM and contains no town-specific coordinates.

Ground players, the owned vehicle, traffic, NPCs and NPRs cannot cross mapped open water. An OSM road tagged as a bridge remains traversable over it. A tagged tunnel remains connected below the surface and its travellers are hidden while underground. NPDs are aerial and may continue to fly over water and buildings.

Bridge and tunnel entry/exit markers are generated from their OSM corridor endpoints. A land bridge deck appears when the player approaches through a bridge endpoint in the bridge direction; the HUD confirms **ON BRIDGE** until the exit is crossed. A lower road passing beneath does not activate or connect to the bridge. Bridges over mapped water remain visible normally. Tunnel travel retains the visible tunnel road and controlled character/vehicle against black surroundings.

If the file omits necessary water members and the local water side cannot be resolved safely, project creation stops with a plain-language message instead of silently treating the sea as land. Obtain a more complete OSM export for this incomplete-relation safety blocker. The Advanced Map Editor can correct known local missing-water areas in an otherwise valid town, but it does not claim that a creator-drawn rectangle reconstructs an unknown coastline. No importer can reconstruct water that is absent and untagged in its source file.

OSM multipolygons distinguish the required `outer` water edge from optional `inner` island or dry-land holes. A complete outer edge remains usable even when a bounded export omits some inner members: Creator Studio conservatively keeps those uncertain patches as water and saves a warning, but it does not block project creation. Only missing or ambiguous outer water geometry is a safety blocker.

During ordinary walking or driving, the top bar follows v1.3's location-heading behaviour and displays `<TOWN> / <STREET>`. If the player is on an unnamed driveway or service road, it displays `NEAR <STREET>` when a named OSM road is within 160 metres. This distinguishes the nearest known location from the unnamed road actually under the player.

Projects created or saved through the GUI receive all deterministic map, collision and navigation data needed by this preview. A project created only through the Node CLI remains marked `pending_runtime_build`; run the documented Godot build command in `docs/content_format.md`, or open and save it in Creator Studio, before using Play test.

The active Belconnen test now includes the University of Canberra campus. Its player starts on open exterior ground beside Cooper Lodge's Telita Street frontage and the wagon is placed separately on nearby clear road space. OSM identifies the named Cooper Lodge footprint but does not currently tag a doorway on it, so the project records `entrance_verified: false` and does not claim an invented exact entrance. An interior spawn remains part of the future interior system.

## Pathfinding status

Creating or saving a town now generates `data/navigation_graphs.json` from that town's own OSM data. It creates directed vehicle and pedestrian route graphs, respects one-way and access tags, uses shared OSM node IDs for real intersections, avoids falsely joining grade-separated crossings, checks whether both starts can reach the CBD, and reports disconnected sections. Where dedicated footpaths are absent, pedestrian routes beside ordinary non-motorway roads are explicitly marked as inferred.

Mapped pedestrian crossings now make NPCs and NPR robots wait for an approaching car or occupied player wagon before walking across. Once they commit, NPC traffic yields until they are clear; upper bridge and tunnel traffic remains on its separate level. This uses standard OSM tags from each imported town and no LLM. Existing projects need **Rebuild project** to save the newly marked crossing routes. See [docs/pedestrian_crossing_parity.md](docs/pedestrian_crossing_parity.md) for the current limitations.

Before those graphs are saved, a spatial geometry audit removes ground segments that cross solid building footprints and rejects unclassified vertical roads. This uses the uploaded map itself, so the same process applies to dense cities, inland towns and coastal maps without an LLM. Rebuild older projects to add the audit data and corrected routes.

The shared preview consumes these graphs for moving traffic and walking NPCs/NPRs; NPDs consume the aerial graph and may fly over footprints. Traffic is visually offset to the selected left or right side, population/CBD counts and wagon handling use the saved settings, and NPC skin colours use only the saved pigmentation-tone percentages.

Creating or rebuilding a town also generates `data/population_destinations.json`. Direct OSM tags on building footprints identify homes and education, health, retail, office, hospitality, civic, recreation, industrial or transport activities. NPCs alternate between a reachable mapped activity and home when a residential footprint is available; NPRs visit reachable activity places. Trips stay inside the actor's connected pedestrian-network section and retain the existing footpath/crossing safety. Untagged buildings, exact doors and tenant uses are not invented. Maps without usable destination tags keep the safe graph-wandering fallback.

This remains a functional preview rather than a complete simulation. Imported signal/stop locations, simple signal phases, movement-aware junction reservations, compatible queue movements, NPC/NPR roadside routes and committed-crossing vehicle yield are connected. Detailed surveyed lane turns, exact real-world controller timing and universal coverage of incomplete OSM data remain unavailable. Graph and visual generation work without an LLM; planet-scale/PBF streaming is not supported.

## First working milestone

The completed v1.4 foundation carried into v1.5 provides:

- A guided Godot GUI with Home, Town Import and System Setup pages.
- Selection of one or more raw `.osm` XML files.
- A visual preview of imported roads and building footprints.
- Map-preview zoom buttons, mouse-wheel zoom and middle-button panning for detailed placement work.
- Click-and-drag CBD selection and click-to-place starting location.
- Hard spawn-safety checks: the player cannot start in a fixed building footprint, and the player's vehicle is automatically given a separate clear position on a nearby road.
- An explicit folder picker controlling where the creator's game files are saved.
- A portable, human-readable town content pack with copied OSM sources.
- Clickable building-footprint inspection as the foundation for the exterior/interior editor.
- Local Ollama persona dialogue: the playable town loads its persona library, town knowledge and shared model prompt behind an animated startup screen, then press **T** near an NPC/NPR, type a message and see the short reply stream into the character's speech bubble. Loading failures offer Retry or Continue without conversations. The no-code **NPCs and personas** page manages random persona pools, optional town knowledge, and outdoor/interior storyline-NPC placement. A placed storyline NPC can use a creator-provided name and any saved human NPC persona, or retain random defaults; its existing static appearance remains random in this version. The local LLM remains restricted to localhost dialogue text and cannot browse, change gameplay or modify town data.
- A deterministic command-line interface for Codex and automated checks.
- A friendly development launcher that explains when a suitable Godot installation cannot be found.
- A no-code Game Settings page for traffic, pedestrians, NPRs, NPDs, CBD targets, left/right road rules, visual skin-pigmentation distribution, player-vehicle handling and NPC traffic-jam recovery.
- Generated vehicle and pedestrian route graphs derived from each imported town's own OSM roads, including one-way and access rules, OSM-node intersections and disconnected-area reporting.
- Automatic metre-accurate building collision polygons derived from ordinary OSM building ways and multipolygon relations, including open inner courtyards and streamed map chunks.
- Automatic OSM water, bridge and tunnel handling: closed water and reconstructable clipped coastlines block ground movement, tagged bridge decks remain legal surface routes, and tagged tunnel traffic travels below the surface.
- Layer-aware bridge and tunnel portals: connected OSM pieces become one corridor with visible entry/exit markers. Water bridges stay visible; land overpasses reveal their upper deck after the player enters an endpoint zone, while the lower town and road remain visible and lower traffic stays on its independent layer.
- A shared playable imported-town preview: **Play test project** opens the selected town in a separate game window with the walking player, drivable wagon, OSM roads/buildings, active footprint collision, moving traffic/NPCs/NPRs/NPDs, grass marks and an overview map.
- The first direct gameplay migration from Generational Australian Survival: its four-direction pixel player, white Holden VZ wagon, scale/handling, safe enter/exit behaviour and pixel-style road populations now run against imported-town data.
- A shared v1.3-style graphical renderer for every built town: play tests use the original 384×240 pixel-art presentation, compact HUD, green ground, bordered roads/footpaths and deterministic footprint-clipped roof, facade and window treatments selected from OSM tags.
- Zoomable in-game outdoor and current-floor interior maps with visible −, +, Fit and You controls, mouse-wheel zoom, drag panning, a mouse-following location crosshair and plain-text **Copy location** for Storyline NPC placement or another app. Outdoor street names come automatically from each imported map's OSM `name` tags.
- A runtime feature profile carrying forward the complete v1.3 gameplay target, including the player, wagon, traffic, pedestrians, signals, venues, fences, collisions and camera.
- An **Open previous project** workflow that restores the saved map, copied OSM sources, CBD, player/vehicle starts and project identity for continued editing.
- A visible **Play test** readiness check. Current GUI-created or upgraded towns launch the shared preview; incomplete CLI-created packs receive a plain-language build message.
- OSM-attributed building information in both Creator **Inspect** and the playable game: hover for a quick summary, click to pin details, and click empty ground to close it. Direct footprint tags are used without an LLM or invented missing facts.
- Deterministic NPC/NPR population destinations built from directly tagged OSM building uses and the current town's reachable pedestrian graph, with residential home/activity trips and a safe random-wandering fallback for sparse maps.
- A no-code **Building Creator** for Paint-ready footprint-template export, stable-ID exterior image import, exact-footprint clipping, clear door/green-arrow placement and matching playable rendering.
- A no-code **Interior Designer** that converts the exact selected footprint into a blank ground floor, preserves courtyard holes, adds footprint-shaped upper floors, permits clearly labelled proportional floor enlargement, saves ground-floor entry links, snaps internal wall endpoints to the footprint/other walls, adds a doorway by clicking any visible wall, and lets the creator lock a door. Unlocked doors show green; locked doors show red and produce a player speech bubble instead of opening. Named rooms are greyed until entered and their names appear in the top gameplay heading rather than on the floor. The designer also shows pictures in its furniture list, supports 100%–1,200% zoom and middle-drag panning, places/removes 16 built-ins, and imports creator artwork with automatic real-metre collision.
- An NPC/NPR conversation layer: T selects a nearby character, pauses both participants, frames them with a closer camera, accepts typed dialogue and streams the local-model reply into the NPC/NPR's floating speech bubble.

Stairs, upper-floor travel, advanced object actions, per-pixel custom-object collision, selectable storyline templates/artwork, full venue/boundary/fence parity and self-contained Windows export are later milestones. Random-pool persona conversations, outdoor/interior storyline NPC placement, linked ground-floor entrances and creator-drawn internal wall/door layouts are now playable. Upper-floor NPC locations may be saved but are not reachable until floor travel exists. The per-town wagon odometer saves mileage, but a general save-game system remains to be built.

## Codex-compatible CLI

Node.js is needed only for the development CLI, not for the finished Creator Studio application.

```text
node tools/creator-cli.js help
node tools/creator-cli.js list-towns --workspace <directory> --json
node tools/creator-cli.js inspect-town --town <town-directory> --json
node tools/creator-cli.js inspect-building --town <town-directory> --feature-id <OSM_ID> --json
node tools/creator-cli.js list-personas --town <town-directory> --json
node tools/creator-cli.js show-town-knowledge --town <town-directory> --json
node tools/creator-cli.js validate-town --town <town-directory> --json
node tools/creator-cli.js get-settings --town <town-directory> --json
node tools/creator-cli.js set-settings --town <town-directory> --traffic-car-count 200 --cbd-car-percent 70 --json
node tools/creator-cli.js set-settings --town <town-directory> --robot-count 20 --drone-count 10 --equalize-skin-tones --json
```

The CLI import form is:

```text
node tools/creator-cli.js import-town --name "Example Town" --workspace <directory> --osm <file.osm> --cbd west,south,east,north --start longitude,latitude --json
```

See `docs/content_format.md` and `schemas/` for the stable content contract.

## Focused verification

Run from this v1.6 directory:

```text
node tools/tests/verify_foundation.js
```

The test imports a tiny OSM fixture through the CLI, verifies the selected output directory, reads the resulting JSON, validates the town and confirms that it can be listed and inspected.

With Godot available, the GUI regression check is:

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_creator_ui.gd
```

It verifies the dedicated start step, start-tool activation, a safe player click, automatic vehicle placement, zoom/reset, map clipping, road-side selection, skin-tone controls and readable wrapped messages.

The navigation topology check is:

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_navigation_builder.gd
```

It verifies one-way routing, true OSM-node intersections, grade-separated crossings, walking routes and saved driving side.

The population-destination check is:

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_population_destinations.gd -- --town <built-town-directory>
```

It verifies direct OSM-use classification, truthful unknown buildings, route-link distance, pedestrian-graph trip planning, connected-section filtering and NPC/NPR destination assignment. Supplying a built town also checks that the real imported map produces usable homes and activities.

Environmental and real-coastal regression checks are:

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_environmental_water.gd
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_the_rocks_environment.gd
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_gold_coast_environment.gd
```

They verify blocking water, legal bridge/tunnel corridors, underground metadata, roof classification, safe failure for unresolved outer water, deterministic reconstruction of clipped Sydney Harbour geometry, and safe acceptance of the complete outer water boundary in the user's Gold Coast map when only inner island holes are absent.

Two larger responsiveness checks protect the map-independent start search:

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_large_map_start.gd
node tools/tests/verify_city_scale_start.js
```

The Godot check uses all 18 Central Wodonga OSM chunks. The synthetic check uses 150,001 features at New York-like coordinates. Production code contains no town-specific coordinates; these are test fixtures only.

The real-map building collision check uses a bounded OpenStreetMap extract of Belconnen Town Centre:

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_belconnen_building_collisions.gd
```

It verifies OSM way and multipolygon import, metre projection, active solid building physics, open courtyards, safe open ground and nine-chunk streaming. The stored sample is a bounded test area, not the whole ACT district. Data © OpenStreetMap contributors, ODbL 1.0: https://www.openstreetmap.org/copyright

The shared runtime can be checked directly against any built town:

```text
Godot_v4.7.2-stable_win64.exe --headless --path . -- --play-town <town-directory> --verify-runtime
```

This confirms the map bounds, requested moving population, saved road side/vehicle settings and nearby streamed collisions initialise together. It is a focused startup check, not an extended traffic/performance test.
