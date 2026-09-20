



# 2D Digital World Twin Creator v1.3

**v1.3 completed — 21 September 2026.** This version builds on the completed v1.2 release. The separate v1.1 and v1.2 releases remain preserved; subsequent development belongs in v1.4.

Project Website: https://www.shanescomputing.com.au/2D_Digital_World_Twin_Creator.html

(disclaimer, GPT5.5 Sol was used to create this program & the README.md document) 


Creator Studio is a no-code Godot application for turning OpenStreetMap data into editable 2D town projects. It is being developed for creative users who should not need to write Godot code.

Playable controls use **WASD** while walking. In the wagon, **Up/Down Arrow** adjust the cruise target by 1 km/h, **Left/Right Arrow** steer, **Shift** toggles Drive/Reverse near a stop, and **Space** brakes. The numbered speedometer shows actual speed and the selected target; a car-only odometer shows lifetime and resettable trip distance. New towns default to a creator-editable maximum of **200 km/h** and a **7.2-second 0–100 km/h** acceleration time. See [player controls](docs/player_controls.md).

## Quick overview

Choose an OpenStreetMap `.osm` file, mark the CBD and a safe starting location on the preview, choose the local driving side and game settings, then select where the new town will be saved. **Create town project** generates the map, building/water collisions and navigation; **Play test project** launches the result. Existing projects can be reopened from Home. Start this source version by double-clicking `Start Creator Studio.cmd`; it will find Godot or explain how to select/install it.


## Starting Creator Studio

For this source version, double-click `Start Creator Studio.cmd`. The launcher searches for Godot, allows the user to locate a portable executable, checks its version and explains how to install Godot if necessary. It remembers a valid selected executable, displays startup progress, opens Creator Studio maximized and reports a plain-language failure with a startup-log location instead of silently closing.

The final public build will be exported as `2D Digital World Twin Creator.exe`, with the Godot runtime included so ordinary creators will not need the Godot editor.

Developers can also import `project.godot` in Godot 4.7 or newer and press F6/F5.

## Creating a town

1. Open **Import a town**.
2. Enter the town's display name.
3. Choose one or more `.osm` files and select **Read files and show preview**.
4. In Step 3, select **Draw CBD on map** and drag a rectangle around the CBD.
5. In the separate Step 4, select **Choose start on map**, then click an open player position. Creator Studio finds a separate safe road position for the player's vehicle.
6. Use `−`, **Reset**, `+` or the mouse wheel to zoom the preview; hold the middle mouse button and drag to pan.
7. In Step 5, choose whether traffic drives on the left or right.
8. In Step 6, select **Choose save directory** and choose where game projects belong.
9. Select **Create town project**.

Creator Studio creates `<chosen directory>/<town_id>/`. The original source files are copied and never moved.

Every create/save operation generates `data/building_collisions.json` directly from the imported OSM footprint coordinates. This deterministic process does not contact or use an LLM. Simple, concave and relation-based buildings retain their shapes; inner OSM rings remain open courtyards. Invalid geometry is listed in the validation report instead of being invented.

Creator Studio also checks roads against ground-solid building footprints before generating pathfinding. A ground route whose centre line passes through a solid building is excluded from vehicle and pedestrian graphs; a close but centre-line-clear route stays usable and is reported for review. Explicit bridges, tunnels, overhead roofs and underground structures keep their separate vertical meaning. Ambiguous non-zero-layer roads without a real bridge/tunnel tag are excluded instead of creating flying traffic. Results are saved in `data/navigation_graphs.json` and `validation.json`; the full rules and limitations are documented in [docs/map_geometry_validation.md](docs/map_geometry_validation.md).

## Reopening and play testing

From **Home**, select **Open previous project** and choose the town folder containing `town.json`—for example `test/wodonga_test`. The project reopens in the import/editor page and **Save project changes** updates its CBD, start and town metadata without copying the source files again.

Select **Play test project** to open the loaded town in a separate game window. If all six setup steps are complete but the town has not been generated yet, this button creates it automatically and asks the creator to select Play once more. Use **WASD** to walk, move beside the wagon and press **E** to enter it, use the arrow keys to drive, press **E** to exit, press **M** for the full-town map and press **Escape** to close the game window. On the map, use the mouse wheel or −/+ buttons to zoom, drag with the left mouse button to move around, select **Fit** to show the whole town, or **You** to return to the player's location. The Creator Studio stays open so work is not lost.

Hover over a building to see its mapped name/use and source, or click it to pin fuller details such as its available address, operator, levels, opening hours and accessibility. Click empty ground to close it; in map mode, dragging still begins from empty ground. Every popup identifies **© OpenStreetMap contributors** and its source way/relation ID. Missing information is shown as not mapped instead of being invented. Rebuild older projects to save their `data/place_information.json`; details and limitations are in [docs/building_information.md](docs/building_information.md).

The play window automatically uses the same 384×240 logical scale and compact HUD as v1.3 while Creator Studio itself keeps its larger editing layout. Buildings are styled from each map's own OSM tags and exact footprint; unlabelled buildings receive a stable generic house variant. The same town always rebuilds with the same visual choices, and no Wodonga- or Albury-specific graphics rule is required.

Roads, kerbs, car parks and footpaths now share that v1.3-style presentation and a common real-world scale. OSM width and lane tags take priority, with documented road-class defaults when detail is absent. Surface `amenity=parking` polygons retain their mapped boundary and may receive conservative scale-correct bay guides; those inferred guides are not claimed as surveyed spaces. Separately mapped footways are preserved, while explicit sidewalk tags or documented urban defaults add roadside footpaths. Solid building footprints mask all ground transport artwork and keep their collision. See [docs/scaled_transport_surfaces.md](docs/scaled_transport_surfaces.md).

Street labels also come from the current town's own OSM data. Major roads are prioritised at broad zoom levels; secondary and local street names appear progressively while zooming in. Roads that have no OSM `name` cannot be labelled reliably and remain unnamed rather than receiving an invented name.

Water placement also comes from the current map. Creator Studio recognises standard OSM water areas, waterways and multipolygon relations. A coastal export often cuts a much larger sea or harbour relation at its rectangular boundary; in that case the importer joins the supplied shoreline fragments to the declared export edge and selects the side containing the least mapped land development. The result is marked as reconstructed OSM-boundary geometry and shown in the preview. This uses no LLM and contains no town-specific coordinates.

Ground players, the owned vehicle, traffic, NPCs and NPRs cannot cross mapped open water. An OSM road tagged as a bridge remains traversable over it. A tagged tunnel remains connected below the surface and its travellers are hidden while underground. NPDs are aerial and may continue to fly over water and buildings.

Bridge and tunnel entry/exit markers are generated from their OSM corridor endpoints. A land bridge deck appears when the player approaches through a bridge endpoint in the bridge direction; the HUD confirms **ON BRIDGE** until the exit is crossed. A lower road passing beneath does not activate or connect to the bridge. Bridges over mapped water remain visible normally. Tunnel travel retains the visible tunnel road and controlled character/vehicle against black surroundings.

If the file omits necessary water members and the local water side cannot be resolved safely, project creation stops with a plain-language message instead of silently treating the sea as land. Obtain a more complete OSM export; the planned Advanced Map Editor will later provide a no-code manual correction path. No importer can reconstruct water that is absent and untagged in its source file.

OSM multipolygons distinguish the required `outer` water edge from optional `inner` island or dry-land holes. A complete outer edge remains usable even when a bounded export omits some inner members: Creator Studio conservatively keeps those uncertain patches as water and saves a warning, but it does not block project creation. Only missing or ambiguous outer water geometry is a safety blocker.

During ordinary walking or driving, the top bar follows v1.3's location-heading behaviour and displays `<TOWN> / <STREET>`. If the player is on an unnamed driveway or service road, it displays `NEAR <STREET>` when a named OSM road is within 160 metres. This distinguishes the nearest known location from the unnamed road actually under the player.

Projects created or saved through the GUI receive all deterministic map, collision and navigation data needed by this preview. A project created only through the Node CLI remains marked `pending_runtime_build`; run the documented Godot build command in `docs/content_format.md`, or open and save it in Creator Studio, before using Play test.

The active Belconnen test now includes the University of Canberra campus. Its player starts on open exterior ground beside Cooper Lodge's Telita Street frontage and the wagon is placed separately on nearby clear road space. OSM identifies the named Cooper Lodge footprint but does not currently tag a doorway on it, so the project records `entrance_verified: false` and does not claim an invented exact entrance. An interior spawn remains part of the future interior system.

## Pathfinding status

Creating or saving a town now generates `data/navigation_graphs.json` from that town's own OSM data. It creates directed vehicle and pedestrian route graphs, respects one-way and access tags, uses shared OSM node IDs for real intersections, avoids falsely joining grade-separated crossings, checks whether both starts can reach the CBD, and reports disconnected sections. Where dedicated footpaths are absent, pedestrian routes beside ordinary non-motorway roads are explicitly marked as inferred.

Mapped pedestrian crossings now make NPCs and NPR robots wait for an approaching car or occupied player wagon before walking across. Once they commit, NPC traffic yields until they are clear; upper bridge and tunnel traffic remains on its separate level. This uses standard OSM tags from each imported town and no LLM. Existing projects need **Rebuild project** to save the newly marked crossing routes. See [docs/pedestrian_crossing_parity.md](docs/pedestrian_crossing_parity.md) for the current limitations.

Before those graphs are saved, a spatial geometry audit removes ground segments that cross solid building footprints and rejects unclassified vertical roads. This uses the uploaded map itself, so the same process applies to dense cities, inland towns and coastal maps without an LLM. Rebuild older projects to add the audit data and corrected routes.

The shared preview consumes these graphs for moving traffic and walking NPCs/NPRs; NPDs consume the aerial graph and may fly over footprints. Traffic is visually offset to the selected left or right side, population/CBD counts and wagon handling use the saved settings, and NPC skin colours use only the saved pigmentation-tone percentages.

This remains a functional preview rather than a complete simulation. Imported signal/stop locations, simple signal phases, movement-aware junction reservations, compatible queue movements, NPC/NPR roadside routes and committed-crossing vehicle yield are connected. Detailed surveyed lane turns, exact real-world controller timing and universal coverage of incomplete OSM data remain unavailable. Graph and visual generation work without an LLM; planet-scale/PBF streaming is not supported.

## First working milestone

The inherited completed v1.2 foundation available in v1.3 provides:

- A guided Godot GUI with Home, Town Import and System Setup pages.
- Selection of one or more raw `.osm` XML files.
- A visual preview of imported roads and building footprints.
- Map-preview zoom buttons, mouse-wheel zoom and middle-button panning for detailed placement work.
- Click-and-drag CBD selection and click-to-place starting location.
- Hard spawn-safety checks: the player cannot start in a fixed building footprint, and the player's vehicle is automatically given a separate clear position on a nearby road.
- An explicit folder picker controlling where the creator's game files are saved.
- A portable, human-readable town content pack with copied OSM sources.
- Clickable building-footprint inspection as the foundation for the exterior/interior editor.
- Optional detection of Ollama, LM Studio and llama.cpp local services, clearly restricted to future NPC dialogue.
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
- A zoomable in-game town map with visible −, +, Fit and You controls, mouse-wheel zoom, drag panning and street names taken automatically from each imported map's OSM `name` tags.
- A runtime feature profile carrying forward the complete v1.3 gameplay target, including the player, wagon, traffic, pedestrians, signals, venues, fences, collisions and camera.
- An **Open previous project** workflow that restores the saved map, copied OSM sources, CBD, player/vehicle starts and project identity for continued editing.
- A visible **Play test** readiness check. Current GUI-created or upgraded towns launch the shared preview; incomplete CLI-created packs receive a plain-language build message.
- OSM-attributed building information in both Creator **Inspect** and the playable game: hover for a quick summary, click to pin details, and click empty ground to close it. Direct footprint tags are used without an LLM or invented missing facts.

Building texture upload, door placement, interior creation, custom NPC placement, persona conversations, full venue/boundary/fence parity and self-contained Windows export are later milestones. The per-town wagon odometer saves mileage, but a general save-game system remains to be built.

## Codex-compatible CLI

Node.js is needed only for the development CLI, not for the finished Creator Studio application.

```text
node tools/creator-cli.js help
node tools/creator-cli.js list-towns --workspace <directory> --json
node tools/creator-cli.js inspect-town --town <town-directory> --json
node tools/creator-cli.js inspect-building --town <town-directory> --feature-id <OSM_ID> --json
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

Run from this v1.3 directory:

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
