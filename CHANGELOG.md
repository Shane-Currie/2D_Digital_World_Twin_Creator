# Changelog

## v1.1 complete — 2026-09-13

The v1.1 milestone is complete. This release includes the Creator Studio town import/reopen workflow, configurable populations and driving settings, playable town previews, real-world map-centre coordinates, mapped water/land cover, and the final bridge/tunnel corrections below.

- Prevent player cars and walking characters from leaving bridge/tunnel sides; retain safe endpoint entry and exit.
- Show the controlled actor and road against black in tunnels and grey beneath bridges.
- Remove underground road stripes from the surface and restore every bridge span in map overview.
- Focused crossing, rendering and runtime checks passed; the reported map gap was visually checked at its geographic location. Detailed dated results follow.

This closes the v1.1 scope, not the full product roadmap. Advanced editors, the remaining simulation migration, Windows executable export and documented complex crossing/collision limitations remain future work. Extended gameplay/performance testing remains user-led.

## 2026-09-10 — v1.1 Creator Studio foundation

- Created the first **2D Digital World Twin Creator** Godot project at the user-specified v1.1 location 
- Added a beginner-oriented GUI shell and guided OSM town importer. Creators can choose multiple `.osm` files, preview roads/building footprints, draw a rectangular CBD, click the starting location and choose the directory where their game files are saved.
- Added content-pack writing with copied source files, `town.json`, `data/map_features.json` and a validation report. Added documented v1 schemas for towns, future personas and future placed NPCs.
- Added clickable building inspection as groundwork for exterior, entrance and interior tools; those editing features remain pending.
- Added a local-service preflight for Ollama, LM Studio and llama.cpp. This is detection only and is explicitly isolated from creation workflows; local LLMs remain reserved solely for future NPC dialogue.
- Added a friendly Windows development launcher that locates Godot, reports missing/incompatible versions and offers installation help. The exported `.exe` remains pending because no Godot executable is currently available on this host.
- Added a Codex-friendly Node CLI using the same content format for import, list, inspect and validation operations.
- Added a no-code Game Settings page. It loads and saves town-specific traffic count, pedestrian count, CBD traffic/pedestrian targets, player-vehicle handling and traffic-jam recovery values, with recommended v1.3 defaults and safe input ranges.
- Added `game_settings.json`, its documented schema, CLI `get-settings`/`set-settings` commands and performance warnings for unusually large populations.
- Added an explicit runtime feature profile requiring the player, wagon, NPC traffic and pedestrians, signals, map/collisions, venues/interiors, property boundaries, breakable fences, camera/minimap and jam recovery. This records the full v1.3 compatibility target; the reusable playable runtime remains pending.
- Added hard starting-position safety for custom OSM maps. A click inside or too close to a fixed building is rejected; the vehicle receives a separate nearby road position with a larger clearance envelope. Content validation repeats the player, vehicle, separation and map-boundary checks.

### Verification

- Focused CLI test passed 38 checks: OSM import, selected output directory, source copy, town data, player/vehicle clearance, rejection of the fixture's deliberately inside-building start, default settings, valid settings updates, rejection of an out-of-range CBD target, listing, inspection and validation.
- Godot parser/startup and Windows `.exe` export remain unverified because no Godot executable is installed or discoverable on this host. The launcher reports that limitation rather than presenting a successful build.
- Follow-up correction: Godot 4.7.2 was located on the user's OneDrive Desktop. Repaired the development launcher so it remembers that executable, safely quotes the project path containing spaces, opens the app maximized, waits up to 20 seconds for a visible window, writes `creator-studio-startup.log`, and keeps an error message visible if startup fails.
- Verified the repaired launcher against `Godot_v4.7.2-stable_win64.exe`: it detected the version, launched the project and reported `Creator Studio is ready`. This supersedes the earlier statement that Godot was not discoverable; Windows release `.exe` export remains pending.
- Moved starting-location selection into its own Step 4. The button remains unavailable until an OSM preview is loaded and the CBD is drawn, then changes to `Start tool active — click map`; acceptance and safety rejection both provide visible next-action text.
- Added map-preview `−`, `Reset` and `+` controls, 100%–1,200% mouse-wheel zoom, zoom-around-cursor behaviour and middle-button drag panning.
- Removed duplicate closing OSM nodes before filling preview polygons and stopped querying XML element names on whitespace nodes. This eliminated the observed polygon-triangulation and XML-parser error spam.
- Godot GUI regression check passed: dedicated start step, tool activation, safe map click, automatic vehicle placement, zoom/reset and closed-polygon cleanup. The existing 38 content/CLI checks also passed.
- Fixed the reported large-map starting-location hang/crash. The vehicle search no longer performs a road-candidate × every-building calculation; it scans the imported features once, filters to the 250-metre search area, sorts nearby road candidates and performs at most 64 detailed clearance checks.
- Fixed zoomed map artwork covering the wizard/sidebar by clipping both the entire preview panel and a dedicated canvas container. Map drawing can no longer escape into the menu area.
- Scalability verification passed without town-specific production logic: Godot found a safe start among 4,385 buildings and 3,307 roads in 46 ms; the matching Node implementation handled a synthetic 150,001-feature city at New York-like coordinates in 121 ms. The 38 foundation checks and the GUI workflow check also pass.
- Limitation: these checks establish start-selection responsiveness, not that an arbitrarily large or malformed planet-scale OSM XML file can be imported or rendered. City-scale import/render streaming and explicit resource-limit feedback remain separate hardening work; do not represent the synthetic test as a full New York end-to-end import.
- Added **Open previous project** on the Home page. It reads an existing content folder, reconstructs its map geometry, restores copied OSM sources, CBD and player/vehicle starts, remembers the recent project and changes the create action to **Save project changes** without recopying source data.
- Added visible **Play test** controls on Home and the town editor. Current content-only projects now receive a plain-language `Playable game not generated yet` explanation instead of appearing launchable or doing nothing. The secure generated-runtime launcher remains pending with the runtime migration.
- Verified the loader against the user's `test/wodonga_test` project: 762 buildings, 569 roads, 1,331 total features, CBD, both starts, source files and pending-runtime status restored.
- Clarified generic pathfinding status: arbitrary imported OSM geometry does not yet have generated vehicle/pedestrian navigation graphs. Successful import or preview must not be presented as working NPC pathfinding.
- Replaced that pending pathfinding status with a first map-independent route-data implementation. Creating or saving any valid imported project now writes `data/navigation_graphs.json` for vehicles and pedestrians, respects one-way/access tags, preserves OSM node identity so bridges and tunnels are not falsely joined, checks CBD reachability and reports disconnected networks. The playable traffic/NPC runtime still needs to consume these graphs.
- Added a left/right driving-side choice to import Step 5 and Game Settings. It is saved in `game_settings.json` and navigation metadata; physical lane offsets and turn behaviour remain part of the pending playable runtime.
- Added a visual-only **Skin tone distribution** section with very light through very deep ranges plus unspecified/automatic. Percentages must total exactly 100%. No identity categories are stored and skin tone does not affect any other NPC setting. The values are persisted for the future NPC artwork generator, which is not playable yet.
- Wrapped and size-bounded explanatory dialogs so the complete Play test readiness message remains readable instead of extending beyond the window.
- Updated the user's `test/wodonga_test` project with generated navigation: 2,210 vehicle nodes / 3,147 directed edges and 3,052 pedestrian nodes / 7,144 directed edges. Both saved starts can reach the selected CBD; validation reports four vehicle and six pedestrian network sections for later review.
- Focused checks pass: 46 CLI/content checks; UI start/zoom/clipping, road-side, skin-tone total and message wrapping; topology checks for one-way roads, true intersections and grade separation; project reopen; and the 4,385-building/3,307-road fixture generated navigation in 815 ms. These are focused data-generation checks, not full gameplay or New York end-to-end testing.
- Superseded the pre-release unspecified skin-tone default with the requested **Equalize percentages** control at the top of **Skin pigmentation tones**. It is selected by default; manual edits release it. Renamed the darker ranges to medium-dark, dark and very dark.
- Added editable NPR count/CBD target defaults of 20/100% and NPD defaults of 10/90%. Added a 25-node map-bounded aerial graph whose 80 directed links deliberately permit building overflight; NPRs reuse pedestrian route data.
- Added the NPR walking sheet, NPD flight sheet, grass/track reference sheet and the requested future-quality gameplay reference under `assets/` and `docs/previews/`. This reference establishes direction only; functionality and mechanics remain the current priority.
- The user's Wodonga test project was upgraded to the new settings and aerial navigation format. Updated focused verification passes 53 CLI/content checks plus the Creator UI and navigation topology checks.

## 2026-09-11 — Map-independent active building collisions

- Creating or saving a town now generates `data/building_collisions.json` directly from the imported OSM coordinates. A local metre projection preserves real footprint dimensions and an 8-pixel-per-metre runtime scale. Textures do not control collision.
- Added a reusable Godot loader that creates `StaticBody2D` convex collision pieces in nearby 256-metre chunks. Player, vehicle, NPC and NPR collision masks can share the layer; airborne NPDs remain outside it.
- Extended both GUI and CLI importers to join OSM building multipolygon relations, retain concave outlines and preserve inner rings as open courtyards. Preview selection and safe-start checks also respect courtyard holes.
- Collision generation is deterministic and contains no LLM calls or town-specific coordinates. Older v1.1 projects remain reopenable and gain collision data when saved.
- Added a bounded Belconnen Town Centre OSM test source and a loadable test project at `../test/belconnen_collision_test`. The source bbox is `149.055,-35.245,149.080,-35.225`; it is not the whole ACT district. Data © OpenStreetMap contributors, ODbL 1.0.

### Focused verification

- The real Belconnen sample imported 40,992 nodes, 5,769 ways and 301 relations, identifying 1,277 building footprints and 2,758 roads. All 1,277 footprints produced collision data in 1.744 seconds on this focused run.
- Godot physics found collision inside OSM building relation `5333681` (22 outer vertices, approximately 2,260 m²), zero collision in the inner courtyard of relation `5329382`, and zero collision at the automatically validated open start. The probe loaded nine nearby chunks.
- A separate controlled physics check confirmed that player- and car-sized bodies stop at the generated footprint while open ground remains clear. The Creator UI check and 57 CLI/content checks pass.
- Scope: this supports valid `.osm` XML building ways and multipolygon relations of ordinary town/city size. Malformed geometry is reported instead of guessed. Planet-scale/PBF streaming and the remainder of the town-independent playable runtime remain separate work.

## 2026-09-11 — First playable imported-town preview

- Replaced the content-only Play test result with a shared Creator Studio runtime. A `preview_ready` town now opens in a separate safe process, leaving Creator Studio and unsaved workflow context open.
- Added a walking player, enterable/drivable wagon, camera and full-town overview, green grass ground with bounded decorative stalk density, walking/tire marks, OSM road/building rendering and nearby streamed footprint collisions.
- Connected saved per-town data to the preview: car/NPC/NPR/NPD counts and CBD targets populate their generated vehicle, pedestrian and aerial graphs; traffic is visually positioned on the selected left/right side; the wagon uses saved driving/camera values; NPC appearance samples only the saved skin-pigmentation-tone percentages.
- Complex but valid OSM outlines are triangulated once and rendered as primitives. Geometry that cannot be filled remains outlined rather than emitting repeated draw failures or preventing the rest of the map from playing.
- Saving an older project now upgrades `runtime_profile.json` after regenerating collisions/navigation. Node-only imports remain `pending_runtime_build` until the deterministic Godot build command is run, preventing an incomplete pack from being falsely advertised as playable.

### Focused verification

- The bounded Belconnen project started with 330 requested moving road users and nine nearby collision chunks. The same runtime check passed on the existing Wodonga project with the same requested total and nine nearby chunks, without town-specific runtime coordinates or an LLM.
- Project reopening, Creator UI, navigation topology, building physics and the 57-check Node foundation suite pass. The runtime check also confirms the saved road side and wagon forward speed reach the game objects.
- A real graphical render was inspected at `data/towns/belconnen/reports/playable_preview.png`; it shows the player and wagon at the safe starts, imported roads/buildings, varied moving population, green ground/grass stalks and a contained HUD. This is an actual runtime capture, not concept artwork.
- Scope: route followers currently lack detailed turning arcs, traffic signals, intersection reservations, pedestrian/vehicle avoidance and jam recovery. Venues/interiors, property boundaries/breakable fences, custom NPC/persona dialogue and save-game progress are also not yet migrated. This is not a full gameplay/performance result or planet-scale/PBF support.

## 2026-09-11 — Cooper Lodge start and first direct gameplay migration

- Expanded the bounded real Belconnen OSM source east to API bbox `149.055,-35.245,149.090,-35.225`, covering both Belconnen Town Centre and the University of Canberra campus. The earlier smaller extract remains preserved. Data © OpenStreetMap contributors, ODbL 1.0.
- Made Cooper Lodge (OSM way `297173255`) the named Belconnen player start. The player position at approximately `149.08255,-35.23931` is on safety-checked exterior ground beside the Telita Street frontage; ordinary spawn logic puts the wagon roughly nine metres away on clear road space. The current OSM footprint does not tag an entrance, so `entrance_verified` is deliberately false and no doorway/interior spawn is claimed.
- Migrated the original Generational Australian Survival four-direction pixel player and white Holden VZ wagon conventions into the shared runtime. The wagon uses the town's saved speed, acceleration, braking, steering and camera zoom values.
- Replaced the permissive preview enter/exit toggle with the original-style rules: the player must be beside the wagon with no building between them, the wagon must stop before exit, and the player is placed only in a physics-checked clear exit position.
- Replaced dot/box population placeholders with the existing-style pixel pedestrian, NPR, NPD and top-down car drawing conventions. Skin-pigmentation settings remain visual only. Road ways now render as continuous styled paths instead of disconnected segment strips.

### Focused verification

- The expanded map imported 50,795 nodes, 7,613 ways and 355 relations, identifying 1,525 buildings and 3,743 roads. All 1,525 footprints generated collision data.
- Godot physics confirmed collision inside Cooper Lodge's 20-vertex, approximately 2,577 m² OSM footprint, zero collision at the named player start, and a clear automatically placed wagon start. Eight nearby collision chunks loaded.
- Runtime startup and inherited enter/exit checks passed on both expanded Belconnen and the existing Wodonga project, each with the configured 330 moving population agents. This confirms cross-town startup, not full traffic/performance behaviour.
- The actual running result was inspected at `data/towns/belconnen/reports/cooper_lodge_gameplay_stage.png`. It shows the named lodge start, migrated player and white wagon, continuous roads and pixel population; it is not concept artwork.
- Remaining gap: the imported-town traffic population still follows the first simple graph consumer. The mature v1.3 signal, junction reservation, obstacle avoidance, queue flow and jam recovery managers have not yet been adapted to arbitrary OSM graphs.

## 2026-09-11 — Play-test readiness guidance and generic traffic safeguards

- Replaced unexplained disabled Create/Play controls with clickable actions and plain-language prerequisite reporting. The import form now lists every missing setup item beside Create. Play test reports those same missing items or, when setup is complete, tells the creator to generate the project once before playing.
- Corrected the import heading from five to six guided steps. Existing map/CBD/start selections remain in the current window when a readiness message is shown.
- Added the first generated-map traffic safeguards derived from the v1.3 traffic approach: cars retain a following gap on the same directed road segment, conflicting cars cannot own the same intersection node simultaneously, moving traffic avoids the visible player and owned wagon, and timed-out jams use saved recovery settings to relocate to a clear distant graph node.
- Recorded these traffic capabilities in newly generated runtime profiles. Signals, detailed turning corridors/conflict scheduling, physical traffic bodies and full v1.3 traffic parity remain pending.
- Located and regenerated the user's complete Albury project at `../test/albury test/albury_test`; the outer `albury test` directory is the chosen workspace, not the playable project itself.
- Open previous project and Choose project to play now accept either the exact generated project folder or its immediate parent when that parent contains exactly one town. Parents containing multiple towns produce a clear instruction to choose the specific child.

### Focused verification

- Creator UI check passed for save-folder-last readiness, named missing conditions from both Create and Play test, and the separate generate-before-play notice.
- Project reopening passed for a direct Wodonga project and the single-town Albury parent workspace.
- Controlled traffic check passed for queue spacing, exclusive four-arm junction use/release and settings-driven relocation of a jammed car to a clear node 900 pixels away.
- Albury regenerated successfully with 2,240 vehicle nodes / 3,675 directed edges and 3,988 pedestrian nodes / 9,394 directed edges; both starts can reach its CBD. Its runtime started with all 330 configured agents and six nearby building-collision chunks.
- The 57-check CLI/content foundation suite passed. Godot emitted host log/certificate warnings in headless mode, but the project checks exited successfully.

## 2026-09-11 — One-button rebuild and imported traffic controls

- Added a single **Rebuild project** action for loaded towns. It rereads OSM and regenerates map features, collisions, all three navigation graphs, traffic-control data, validation and the playable profile while keeping the creator's CBD, starts and game settings.
- New projects remember the original OSM paths and still keep their portable source copies. Rebuild automatically prefers all available originals and falls back to the project copies without presenting technical source choices. Older projects remain compatible and use their copies.
- Added tagged OSM-node preservation to both Godot and Node importers and to `map_features.json`. Vehicle graphs classify traffic signals, stop signs, give-way signs and crossings; projects created before this metadata refresh it from their copied sources when reopened.
- Cars now obey generated signal phases, wait on amber/red, proceed on green, and stop for one second at imported stop signs. Legal traffic-light waits are excluded from jam timing. Added small top-down signal/stop/give-way markers and smoothed traffic-car heading changes.
- Runtime profiles and validation reports now state traffic-control capabilities and counts. Maps with no explicit controls receive a warning and continue with basic safe intersection reservations.

### Focused verification

- Creator Studio itself rebuilt the user's Albury project from its copied `01_albury.osm`, finding 171 vehicle-network traffic-signal nodes, 12 give-way nodes and 111 crossing nodes. No OSM stop node in that extract belonged to a generated drivable segment.
- The rebuilt Albury profile is `preview_ready`; startup passed with 330 configured agents and six nearby collision chunks. Vehicle and pedestrian starts remain CBD-reachable.
- Focused navigation and traffic tests passed for tagged-control preservation, signal phases, a one-second stop, queue spacing, exclusive junction release and distant jam recovery. GUI readiness/rebuild checks and 61 CLI/content checks passed.
- Limitation: current signal timing is a deterministic fallback because OSM generally describes signal locations, not the local controller schedule. Detailed turn corridors, compatible simultaneous movements and full v1.3 traffic conflict scheduling remain pending.

## 2026-09-11 — Map-independent v1.3 graphical-parity stage

- Switched play tests—not the Creator Studio editor—to the v1.3 384×240 logical pixel canvas with viewport scaling, compact top/bottom HUD bars, small readable status text and a restrained starting-location marker.
- Replaced flat orange footprints with a deterministic generic building-art layer. OSM building/amenity/shop tags select residential, commercial, civic, health, industrial or tall-building palettes; missing tags receive a stable brick/weatherboard/rendered variant. Alternating triangulated roof faces, seams, shadows, facade edges, windows and small roof details stay tied to each imported footprint. Footprint coordinates and collision polygons are unchanged.
- Adapted the v1.3 ground and road treatment to arbitrary imported geometry: greener grass, bounded stalk detail, pale road/footpath borders and dashed markings on major imported roads. The previously migrated v1.3-scale player and white wagon remain unchanged.
- Did not copy Central Wodonga's footprint-specific SVGs into other towns. Those files fit particular Wodonga polygons; the shared renderer applies the same visual language to the actual geometry and tags in each new map without town coordinates or an LLM.

### Focused verification

- Albury runtime passed with all 330 configured road users and six nearby collision chunks. Its actual capture at `artwork/previews/albury_v13_style_vehicle.png` confirms the wagon and imported road scale; its selected player start is open grass and the separate wagon is approximately 73 metres away, so that view does not contain a nearby building.
- The same unchanged renderer passed on Belconnen around the Cooper Lodge setup with 330 road users and eight collision chunks. `artwork/previews/belconnen_v13_style_stage.png` is an actual 384×240 Godot capture showing the imported building treatment, player, wagon, roads and HUD together.
- The runtime check asserts OSM style classification for retail, health, industrial and tall buildings. The Creator UI regression passed, confirming the editor remains usable at its larger layout. The 61-check CLI/content suite also passed.
- Remaining graphical gaps include generic trees and street furniture, detailed doors/custom textures, building interiors, property boundaries/fences and venue-specific artwork. OSM tags can guide a visual category but cannot reconstruct a surveyed facade or missing architecture.

## 2026-09-11 — Demo-ready map zoom and OSM street names

- Added visible −, +, Fit and You controls to the in-game map opened with **M**. Mouse-wheel and keyboard −/+ zoom are also supported; left-mouse dragging pans, **Home** fits the town and **F** returns to the player/vehicle.
- Removed a fixed relative zoom ceiling. Maximum zoom is calculated from the final camera scale, allowing geographically large imported cities to reach street level as well as small towns.
- Generated street labels from each road feature's OSM `name` tag. Split OSM ways may repeat a name in spatially separated neighbourhoods, while a placement grid removes local overlaps. Major names are prioritised at town scale, with secondary and local names revealed as screen scale becomes readable.
- Unnamed roads stay unnamed. The application does not infer or invent street names, and all label/zoom rules are shared across imported maps without an LLM or town-specific coordinates.

### Focused verification

- Belconnen and Albury runtime checks passed with their 330 configured agents and eight/six active collision chunks. The check confirms each map produced street labels and exercises map opening, zooming, fitting and closing.
- The actual Godot capture `artwork/previews/belconnen_zoomable_street_map.png` visibly shows the map controls and the imported **Telita Street** label near Cooper Lodge.
- The Creator GUI regression and 61-check CLI/content suite passed. Headless Godot emitted only the existing host log/certificate warnings.

## 2026-09-11 — v1.3-style current-street heading correction

- User's Howlong screenshot showed that painted map labels did not reproduce v1.3's ordinary driving display. Ported the relevant v1.3 behaviour: the gameplay top bar now updates every 0.15 seconds from the player/wagon position and displays the town plus the nearest current OSM street.
- Added a 256-pixel spatial index of every named imported road segment, avoiding a whole-town scan while the player moves. The same query works for all generated maps and uses only saved OSM `name` tags.
- If the focus is on the named road, the heading uses its name directly. If it is on an unnamed service road but a named street is within 160 metres, the heading says **NEAR** that street. More distant or wholly unnamed areas show only the town name; no street is invented.
- World-space street labels are now reserved for map mode, matching v1.3 instead of relying on an occasional road-midpoint label during normal gameplay.

### Focused verification

- The exact Howlong project from the user screenshot passed with 330 agents and six collision chunks. Its selected wagon road is unnamed; the nearest named road is Larmer Street at approximately 81 metres, and the actual runtime capture `artwork/previews/howlong_v13_street_heading.png` visibly shows **HOWLONG / NEAR LARMER STREET**.
- Albury and Belconnen runtime checks passed with the same location code and six/eight collision chunks. The Creator GUI and 61-check content suite also passed.

## 2026-09-11 — Universal OSM water, bridge and tunnel stage

- Extended both the Creator Studio and Codex/Node importers with matching, deterministic classification for OSM closed water, water multipolygons, waterways, coastlines, `building=roof`, bridge roads, tunnel roads and layer metadata. No town coordinates or LLM calls participate.
- Added bounded-coast reconstruction for normal rectangular OSM exports that contain only local fragments of a larger harbour/sea relation. The importer clips supplied shoreline chains to the declared `<bounds>`, closes only along that known boundary and selects the side with less mapped building/ordinary-road evidence. Reconstructed shapes retain `geometry_quality: clipped_osm_boundary_inference` and a visible warning.
- Unresolved or untagged missing water is not guessed. Ambiguous incomplete water relations now fail the safe-build validation with a plain-language re-export instruction so a project cannot silently make unknown sea drivable.
- The declared OSM export rectangle is now the playable boundary when present. Complete ways may contain end nodes outside a bounded download, but the player, owned vehicle and generated ground/aerial populations cannot use graph nodes outside that authoritative area or escape around a coastline through unclassified space.
- Generated collision/environment data now includes water polygons and bridge/tunnel crossing corridors. Player and wagon movement is sampled against the shared surface rule to prevent high-speed crossing of open water. Vehicle/pedestrian/NPR graphs remove unprotected edges through water while retaining tagged bridge/tunnel routes; aerial NPDs remain unrestricted. Tunnel population and player/vehicle presentation is hidden while below the surface.
- Reclassified `building=roof` as an overhead structure so canopies do not become ground-solid building walls. Surface roads render above water on bridges; tunnel roads render below land/water.
- Created a clean playable regression project at `../test/the_rocks_water_demo` from the user's actual `OSM/Sydney/The Rocks.osm`; this does not modify or rebuild the previously diagnosed mixed-source project.

### Focused verification

- Generic fixture check passed for open-water blocking, bridge and tunnel traversal, untagged-road rejection, underground metadata, roof classification, water-safe spawning and blocking validation for an unresolved relation.
- The Rocks import processed 27,540 nodes and 4,437 ways in approximately 1.3 seconds. It produced 23 water areas, including four unique clipped-boundary harbour sections; neither of its two incomplete large harbour relations remained unresolved. It preserved 148 bridge-tagged and 142 tunnel-tagged road ways and excluded 63 overhead roofs from solid-building collision.
- The Rocks navigation retained 130 directed bridge edges and 117 tunnel edges. Its playable runtime started with 330 configured road users and nine nearby collision chunks. The map-independent navigation, Creator UI and expanded 72-check Node/content regressions passed.
- Actual rendered inspection is saved at `tools/tests/output/the_rocks_environment.png`; it shows the harbour on the correct side of the supplied shoreline and the Sydney Harbour Bridge crossing the water. This is an automated-map overview, not polished final artwork or extended gameplay/performance proof.

## 2026-09-11 — Create/Play workflow loop corrected

- User screenshot showed the **Create the project before Play test** dialog after attempting to create a fully configured town. Code tracing confirmed that exact dialog was emitted only by the Play-test handler; Create and Play remain distinct correctly wired buttons.
- Made the workflow tolerant of an accidental Play click or a click landing after the scrolled form shifts. When all six setup steps are complete and no generated project exists, Play now runs the same safe project-generation path automatically and confirms creation; selecting Play again launches it.
- Create failures now open a readable dialog containing the actual save/validation error instead of placing the reason only in the narrow bottom status bar. Imported OSM data and selections remain in the window.
- Preserved inferred-water provenance (`geometry_quality` and source relation ID) when Godot writes `map_features.json`.

### Focused verification

- GUI regression reproduced a complete ungenerated town, selected Play, generated its collision/navigation/runtime files and confirmed the button changed to **Save project changes**. Incomplete Create and Play actions still list their exact missing setup conditions. The check passed without launching an external game process.

## 2026-09-11 — Gold Coast incomplete-inner-water correction

- User's `OSM/gold.osm` was incorrectly blocked as unsafe despite visibly importing water. Diagnosis of relation `6168517` found all three `outer` river-boundary ways present and joinable; the nine absent members were exclusively `inner` island/dry-land holes.
- Both Godot and Node importers now count missing outer and inner relation members separately. A missing outer water edge still invokes bounded reconstruction or blocks an unsafe build. A complete outer edge with missing inner holes remains valid and blocking; uncertain omitted holes conservatively stay water and produce a readable warning rather than preventing creation.
- The classification uses only standard OSM member roles and geometry. It contains no Gold Coast coordinates, LLM call or per-town choice and therefore applies to every imported multipolygon.

### Focused verification

- The exact 13.2 MB `gold.osm` import now produces 166 blocking water areas, 62 bridge-tagged roads, 11 tunnel-tagged roads and zero unresolved water relations. The nine missing inner members are reported without blocking project creation.
- The real The Rocks clipped-outer reconstruction and deliberately unresolved-outer fixture still pass. The Creator GUI regression and 72-check Node/content suite also pass.

## 2026-09-11 — Valid CBD selections no longer fail at map edges

- Fixed the reported **The CBD area must stay inside the imported map** Create error. Geographic coordinates rounded through Vector2 could move a valid edge selection about seven centimetres beyond the imported boundary. CBD selection now stores full-precision scalar coordinates clamped to the exact imported extent; player start persistence retains that precision too.
- Kept strict validation for genuinely outside selections. Readiness now directs creators to redraw an invalid CBD in Step 3 before Create, instead of reporting Ready.
- Preview fills now skip polygons that fail triangulation, retaining their outlines without changing saved source or collision geometry.

### Focused verification

- Reproduced the edge error before the correction. The new `tools/tests/verify_cbd_selection.gd` passes 18 coordinate cases covering exact edges, zoom, pan, reversed drags, different coordinate signs and JSON round trips. Deliberately outside selections still fail validation and readiness.
- Ran the actual Creator Create handler on the user's `gold.osm` and `sun.osm`, generated isolated regression projects with collision/navigation data, and successfully reopened and validated both. Rendered screenshots were inspected; the Sun preview matches the reported map. Tests do not change workspace/recent-project preferences or existing user projects.
- Sun's generated runtime passed its brief startup/control check with 330 configured road users and three loaded collision chunks. Godot emitted the known sandbox log-file/certificate-store warnings; no script or polygon-triangulation errors occurred. This is focused verification, not extended traffic or performance testing.
- Reports and screenshots: `tools/tests/output/gold_cbd_selection_validation.json`, `sun_cbd_selection_validation.json`, `gold_cbd_create_verified.png` and `sun_cbd_create_verified.png`. Restart Creator Studio to load the corrected scripts.

## 2026-09-11 — Map-centre latitude and longitude

- Added a bottom-right latitude/longitude overlay to the Creator map preview and playable M map view. Displays the visible map centre, independent of the mouse pointer, in real-world decimal degrees to six places using the imported OSM bounds and saved geographic projection.
- Readout follows pan, zoom, fit/reset and viewport changes. Runtime uses the rendered camera transform so coordinates follow the visible centre during camera smoothing. Preview shows dashes before import; runtime hides the overlay outside map view. Background contrast and non-interactive labels preserve readability and map controls.
- Verification: existing Gold/Sun GUI Create/reopen and 18 coordinate-case checks passed with the overlay present. Creator preview and Sun runtime fitted-map captures were inspected; the fitted runtime readout agrees with the source map centre to within projection rounding (a few millionths of a degree). Native startup produced no script errors; known sandbox log/certificate warnings remain. Screenshots: `tools/tests/output/map_centre_coordinates.png`, `map_centre_coordinates_zoomed.png` and `sun_cbd_create_verified.png`.

## 2026-09-12 — Universal mapped land cover

- Create/Rebuild now imports and renders mapped grass, parks, woods, scrub, wetlands, sand, rock, paved areas and farmland in the Creator preview and playable runtime. GUI/Node use the same documented tag table; import summaries include area counts. Existing projects gain this data through **Rebuild project** after restarting Creator Studio.
- Preserve complete multipolygon holes, separately tagged buildings and smaller surfaces. Missing boundaries are omitted with warnings, not guessed. Exclude non-ground cover tags. Grass effects respect mapped surfaces and buildings; wetlands do not become invented deep water. Water holes retain underlying land-cover artwork.
- Added shared cached land-cover geometry and a spatial lookup. The first hole-baking approach failed on two real park shapes; strip decomposition replaced it and the final The Rocks capture rendered without geometry/script errors.
- Focused checks passed for holes, malformed data, tag aliases, vertical exclusions, roads/buildings and unchanged building/water collision data. Godot/Node results agree for The Rocks (284 areas) and Howlong (69); three incomplete The Rocks land relations are warned and omitted. Creator UI and 72 foundation checks passed. Isolated rebuilt runtimes passed startup/control checks with 330 agents and nine/six collision chunks. Known sandbox log/certificate warnings persist; extended gameplay/performance was not performed.
- Actual inspected captures: `tools/tests/output/land_cover_overview.png`, `land_cover_the_rocks.png`, `land_cover_howlong.png` and `land_cover_howlong_vehicle.png`. Original source files and user projects were preserved. Remaining scope and tag references: `docs/land_cover.md`.

## 2026-09-12 — Tunnel blackout with visible player vehicle

- When the controlled car/character is in a mapped tunnel, keep it visible against black and hide the surface map, population, tracks and starting markers. The HUD and controls remain available. Restore the map on leaving; M overview temporarily shows the surface map normally.
- Implemented in the shared runtime, so existing generated projects use it after restarting Play test; no rebuild is needed for this visual change if tunnel data already exists.
- Verified the actual rendered wagon on a Sydney Harbour Tunnel segment, switching M overview and restoring the surface view. Final capture: `tools/tests/output/tunnel_blackout.png`; focused capture hook reports `TUNNEL PRESENTATION PASSED`. Final run had no script errors; known sandbox log/certificate warnings persist. The initial capture assertion needed a second frame because SceneTree.process_frame fires before node updates.
- Presentation change only: proper entrance detection, underground/surface collision separation and tunnel interiors remain pending. Extended driving through an entire tunnel was not tested.

## 2026-09-12 — Visible roads inside the tunnel blackout

- Retain mapped tunnel road surfaces, edges and applicable existing road markings beneath the visible car/character. Surrounding surface geography stays black. Reuses imported road geometry and widths in a tunnel-only renderer mode, with normal rendering restored by M overview or leaving the tunnel.
- Focused rendered check passed for visible wagon/road, overview switching and surface restoration. Visually inspected `tools/tests/output/tunnel_visible_road.png`; final run had no script errors (known sandbox log/certificate warnings remain).
- Restart Play test to load this presentation change; no rebuild needed for projects already containing tunnel data. Entrance detection and layer/collision behaviour are unchanged.

## 2026-09-12 — Layer-aware bridge/tunnel portals and traffic-route correction

- Confirmed traffic cars and NPD drones use separate agent kinds, artwork routines and navigation graphs. The reported flying cars were not drone-marked car assets.
- General NPC traffic no longer spawns or routes on OSM `service=driveway`, `service=parking_aisle`, or non-zero-layer roads that lack an explicit bridge/tunnel classification. Runtime loading also filters unsafe edges from older generated graphs; rebuilding writes the corrected graph permanently.
- Connected bridge/tunnel OSM ways are merged into complete visual corridors with generated entry and exit markers. This prevents a marker at every harmless OSM way split.
- Water bridge decks remain visible over mapped blue water. Land bridge decks remain hidden until the controlled player/vehicle enters an endpoint zone while moving along the bridge approach; the HUD then displays **ON BRIDGE** through the corridor. Crossing the lower road does not activate the bridge.
- At road-over-road crossings, lower traffic is drawn below the bridge deck and bridge traffic above it. Geometric overlap does not create a navigation junction; OSM must supply a real shared node on the same layer.
- Rebuilt the user's Gold project from its original OSM. Its vehicle graph changed from 10,856 to 7,308 directed edges and now contains zero ambiguous driveway/unclassified vertical edges; the runtime passed with 330 agents and nine collision chunks.

### Focused verification

- The actual The Rocks OSM contains road-over-road bridges and water bridges. Its import/renderer check passed with 130 directed bridge edges and 117 tunnel edges, including independent lower-road geometry, permanent water-bridge display and automatic land-bridge portals.
- Navigation, environmental-water, Creator UI, traffic-flow and 72-check CLI/content regressions passed. Gold and The Rocks runtime checks passed. Known host log/certificate warnings remain; extended user driving remains the user's test.
- Actual runtime captures: `tools/tests/output/bridge_entry.png`, `bridge_exit.png`, `tunnel_entry.png` and `tunnel_exit.png`. These generated test outputs are excluded from the public repository but can be reviewed locally.

## 2026-09-13 — Bridge/tunnel side boundaries and grey underpasses

- Walking and player driving now retain an active bridge/tunnel corridor after entering through an endpoint. Reject movement or turning that puts the actor footprint beyond a side; allow forward or reverse departure through either end after the actor fully clears it. Vehicle entry/exit retains the correct crossing state and checks safe placement.
- Tunnel roads no longer draw across the surface map or cut through bridge artwork. Underground gameplay still shows tunnel roads and the controlled actor against black.
- Driving or walking on a lower road beneath a bridge shows that road and the controlled actor against grey (`#4a4a4a`). Driving selects vehicle roads rather than pedestrian paths. Upper-bridge travel stays distinct; M overview and leaving the covered area restore the appropriate map presentation.
- Corrected underpass road lookup after road-width sorting by remapping segments using stable path IDs. The rendered regression asserts the selected lower road identity as well as visibility and restoration.
- Focused checks passed: `verify_crossing_boundaries.gd` (both corridor types, fast side movement, turning overhang, forward/reverse exits, curved geometry, actual car/walker motion), `verify_crossing_render.gd` (continuous bridge, no surface tunnel stripe, visible underground road with black surroundings), and environmental-water regression. Gold and The Rocks startup/control checks passed with 330 agents and nine collision chunks each. Known sandbox log/certificate-store warnings remain; no script errors occurred in final checks.
- Visually inspected actual runtime captures: `tools/tests/output/bridge_boundaries_gold.png`, `tunnel_boundaries_rocks.png` and `under_bridge_grey.png`. Grey underpass capture also verifies M overview and surface restoration. Local test outputs are excluded from Git.
- Restart **Play test** to load these changes; projects already containing crossing data do not need rebuilding. Extended driving/performance, underground building-collision separation, ambiguous starts inside crossings and complex transitions between different corridors remain outside these focused checks. Existing user maps and starts were preserved.

## 2026-09-13 — Restore missing bridge spans in map view

- Fixed a separate cause of missing spans: M overview inherited the gameplay rule that hides inactive land bridges. The overview now draws every mapped bridge corridor, independently of player position or crossing state. Closing M restores gameplay visibility, including the separate grey underpass and black tunnel views.
- Extended the rendered crossing regression to check multiple inactive land bridges at several points, unchanged player crossing state and restoration after closing the overview. All assertions passed, alongside its existing surface/tunnel overlap checks.
- Reproduced the reported area in the user's Rocks project near latitude -33.860570, longitude 151.205987 at 15x map zoom. Visually inspected `tools/tests/output/bridge_map_complete_user.png`: the highway lanes continue across the previously missing sections. Added optional geographic capture arguments for repeatable map-view checks; they do not modify saved starts or map data.
- No script errors in final checks; known host log/certificate-store warnings remain. This was a focused rendering correction, not extended driving/performance testing. Restart **Play test**; no project rebuild is required.
