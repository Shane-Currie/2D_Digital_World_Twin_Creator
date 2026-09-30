# Changelog

## 2026-09-30 — v1.4 completed release

- Version 1.4 is now the completed, preserved release. Development continues separately in `../v1.5`; do not make later feature work directly in this v1.4 checkpoint.
- The release advances v1.3 with directional animated actors and varied static vehicles, map-derived destinations, improved traffic/intersection recovery, Advanced Map Editor corrections, no-code building exteriors and footprint-shaped ground-floor interiors, outdoor/interior storyline NPC placement, local-Ollama persona dialogue and optional town knowledge, player inventory/consumables/stats, and mouse-selectable outdoor/interior map locations with Windows-clipboard copy.
- Final focused verification passed on the actual Albury project for ground-floor entry, indoor/outdoor map location copying and saved character Kekie. Godot script scanning, the relevant runtime/interior checks and all 105 foundation checks passed. Extended gameplay and performance remain user-tested as documented in the individual entries below.

## 2026-09-30 — Mouse-selectable outdoor and interior map locations

- Removed the building/floor/X/Y panel from ordinary interior gameplay so it no longer covers conversations or the playable view. Building and floor names remain in the compact heading; detailed location data now belongs exclusively to map view.
- **M** now works indoors and opens a fitted, zoomable and pannable map of the current building floor, including the ground floor. **Fit** shows the whole floor and **You** returns to the player's position. M or Escape closes the map and restores movement.
- Both outdoor and interior maps now track a turquoise crosshair under the mouse without teleporting the player. Outdoors it reports cursor latitude/longitude; indoors it reports the stable building ID, floor ID and cursor X/Y metres.
- Added **Copy location** (and the C shortcut while a map is open). It writes ordinary plain text to the Windows clipboard: `latitude, longitude` outdoors or `Interior: building=…; floor=…; x=…; y=…` indoors. The result can be pasted directly into Windows Notepad, another text file or the existing Storyline NPC creator.
- Verified on the actual Albury project that both maps produce Storyline-NPC-compatible text, normal indoor play remains free of the location overlay, the fitted ground-floor map renders without overlapping the backpack, and Kekie remains visible on `ground_floor`. The focused interior/location checks, runtime interior transfer, Godot script scan and all 105 foundation checks passed. Visual review: `tools/tests/output/albury_interior_map_locations.png`. Existing sandbox log/certificate and direct-image warnings are unchanged; extended gameplay remains user-tested.

## 2026-09-30 — Ground-floor storyline NPC visibility fix

- Fixed a runtime culling error that could hide a correctly saved ground-floor storyline NPC after the player entered a building. The population renderer retained the outdoor camera bounds while the interior used its own local coordinate space; indoor processing now refreshes those bounds from the interior camera every frame.
- The ground floor is explicitly supported and remains identified by the stable `ground_floor` floor ID. Existing placement data does not need to be recreated.
- Verified against the user's actual Albury save: **Kekie** loads and is drawable on building `484843857`, `ground_floor`, at interior X `14.55` m / Y `5.75` m. The point is approximately `49.7` metres from the saved entrance, so Kekie is intentionally not beside the doorway.
- Focused saved-project, interior-location and runtime-interior checks passed, and Godot completed script scanning. Existing direct-image import, sandbox log/certificate and test cleanup warnings are unchanged; extended gameplay remains user-tested.

## 2026-09-30 — Interior locations and storyline NPC placement

- Added a stable interior location contract using the OSM building ID, saved floor ID and local X/Y metres. This distinguishes different floors at the same latitude/longitude and survives ordinary town rebuilds as long as the building/floor IDs remain present.
- Interior Designer now provides **Select and copy interior location** on the selected floor. A blue crosshair marks the chosen point and a readable `Interior: building=…; floor=…; x=…; y=…` value is copied for **NPCs and personas → Storyline NPCs**. Placement rejects points outside the floor or inside mapped courtyard holes.
- The Storyline NPC creator now accepts either outdoor latitude/longitude or a copied interior location. Interior characters retain the existing optional custom name, saved human persona, random static appearance and local-Ollama conversation flow. They are visible/talkable only while the player occupies the same building and floor, and do not interfere with outdoor traffic or pedestrians.
- Interior saving revalidates existing storyline locations against an edited/resized floor and refuses a change that would strand a character outside the usable boundary; the creator must move that NPC first.
- While indoors, the lower-left player readout now displays the stable building ID, floor ID and live interior X/Y metres in the same compact style as the town-map latitude/longitude panel. It avoids the lower-right backpack and top-right stats controls.
- Focused checks passed for creator click-to-metre conversion, copy/paste parsing, courtyard rejection, stable data validation, runtime space isolation, same-floor conversation targeting and player readout. Existing outdoor storyline placement, runtime interior transfer, Godot script scanning, all 105 content checks and actual Albury playable startup also passed. Upper-floor locations can be saved but remain unreachable until stairs/floor travel are implemented; extended gameplay remains user-tested.

## 2026-09-30 — Creator item catalogue, consumables and player stats

- Added **Inventory items** to Creator Studio. A creator can add custom items without code, import a PNG/JPEG/WebP picture into the town, set its starting quantity, and classify it as general, currency, nutrient or hydration. Nutrient/hydration items receive an editable 1–100 restoration value. Catalogue definitions are town data in `data/item_catalog.json`; imported pictures are copied into `assets/items/`.
- Migrated the existing **Keks** and **bananas** into this same catalogue instead of retaining a separate hard-coded inventory path. Keks are currency with a starting quantity of 100. Bananas are nutrient consumables with a starting quantity of 3 and an editable default restoration of 20 points. Added water bottles as hydration consumables with a starting quantity of 3 and an editable default restoration of 25 points.
- Added a top-right **Player Stats** button. Nutrient and hydration bars remain hidden until clicked, both begin at 50/100, never exceed 100 and persist per town in `saves/player_stats.json`. Clicking a consumable in the backpack opens a confirmation prompt; confirming removes one item only when its matching stat can increase. Currency/general items cannot be consumed.
- Existing player saves merge newly catalogued items at their configured starting quantity without resetting existing Kek or banana quantities. Save failure handling prevents a stat gain from silently consuming an item.
- Added transparent water-bottle artwork and a lightweight runtime copy under `assets/inventory/`. Focused catalogue/editor and runtime checks passed for the Keks/bananas migration, custom item picture copying, types, restoration points, 50/100 defaults, 100-point caps, confirmation, persistence and safe reopening. Godot script scanning and all 105 content checks passed. Nutrient/hydration depletion over time is not part of this stage; extended gameplay remains user-tested.

## 2026-09-30 — First playable player inventory and Kek currency

- Added a small clickable backpack to the lower-right gameplay HUD. Clicking it opens or closes an itemised panel above the button; Escape closes an open backpack before exiting the game. The open panel owns its mouse area so inventory clicks cannot select an OSM building underneath it.
- New players start with **100 Keks** and **3 bananas**. Keks are stored as the game's currency item rather than hard-coded display text. Inventory quantities are held in a town-specific `saves/player_inventory.json`, reject negative values, back up an existing save before replacement and recover from a readable backup instead of overwriting damaged data.
- Added transparent pixel-art Kek coins and bananas alongside the backpack. Full-resolution originals are retained in `assets/inventory/`; lightweight 128×128 runtime copies keep texture use modest. In the open list, item icons are limited to 24×24 pixels in short rows inside a bounded scroll area so later items do not enlarge the window.
- Focused checks passed for starting quantities, open/close input, lower-right safe placement, compact/scrollable rows, click isolation, negative-quantity rejection, saving and reopening. All 105 content checks pass, the icons contain real transparent pixels, and the actual Albury project reached `PLAYABLE TOWN PREVIEW READY` with the inventory HUD constructed. Extended gameplay remains user-tested; Albury's older broad runtime verifier still stops later on its unrelated existing expected-population mismatch.

## 2026-09-30 — Backpack inventory artwork started

- Created the first inventory HUD asset at `assets/inventory/backpack_icon_v1.png`: a transparent, front-facing olive canvas backpack with warm brown leather trim, brass buckles and a readable pixel-art silhouette. The source is retained at high resolution so the HUD can scale it down cleanly.
- This entry covers artwork only. The clickable lower-right backpack, itemised inventory panel, starting 100 Keks, starting 3 bananas, Kek coin artwork, banana artwork and persistent inventory data remain pending implementation and verification.

## 2026-09-30 — Custom names and personas for outdoor storyline NPCs

- Extended **Outdoor storyline NPCs** with an optional permanent character name and a persona selector. The selector lists every saved human NPC persona, including creator-made personas, and labels built-in and custom choices separately. NPR robot personas are excluded from human storyline characters.
- Leaving the name blank or keeping **Random compatible NPC persona** preserves the fast random-placement workflow. Creator Studio rejects duplicate storyline names, multi-line names, names over 80 characters and missing/incompatible persona IDs, then saves the chosen name and stable persona ID in `data/storyline_npcs.json`.
- Placement automatically saves current persona edits before saving the character, preventing a placed character from pointing at an unsaved custom persona. A referenced custom persona remains protected from deletion. Editing that persona later keeps its link because placed characters reference its stable ID. Character artwork remains a random static NPC asset in this stage; selectable templates and imported artwork remain future work.
- Focused creator and runtime checks cover a creator-provided name, a custom saved persona, random fallbacks, persistence and playable conversation targeting. Extended gameplay testing remains with the user.

## 2026-09-30 — Grey Play test startup repaired

- Fixed the reported grey Play test window introduced with the first storyline-NPC stage. Godot could not compile the runtime because the verification population total combined typed integers with the saved storyline array size without an explicit result type; the playable scene therefore stopped before drawing the town.
- Fixed the next compatibility issue exposed by the actual saved Albury project: loaded `map_features.json` points are JSON arrays, while the new storyline placement safety pass initially expected the editor's in-memory `Vector2` values. Spawn-safety geometry now normalises vectors, `[longitude, latitude]` arrays and coordinate dictionaries through the same conversion path.
- Replayed the actual `Test Maps/albury/albury` project containing the saved Daniel Robinson storyline NPC. The runtime reached `PLAYABLE TOWN PREVIEW READY: albury` with no script/placement errors. The remaining headless image-capture warning is expected because a headless renderer cannot produce a screenshot; known certificate/image-import warnings are unrelated. Focused storyline placement and all 105 content checks still pass.

## 2026-09-30 — Outdoor storyline NPC placement

- Replaced the disabled Storyline NPC preview with the first working no-code placement stage. In **Advanced map editor**, select **Select location and copy coordinates** and click the map; a visible crosshair marks the point and its full latitude/longitude is copied in paste-ready order.
- Added **Outdoor storyline NPCs** to **NPCs and personas**. Paste the copied location and choose **Place random storyline NPC**. The creator validates map bounds, fixed building clearance, mapped water and proximity to a generated pedestrian route before saving a stable storyline ID, exact geographic position, random human name, compatible NPC persona and one existing static NPC asset in `data/storyline_npcs.json`. Saved placements can be reviewed and removed without code.
- Play test now loads these records into the shared population and conversation systems. A storyline NPC appears at the saved geographic position, remains there for reliable interaction and uses the existing typed local-Ollama dialogue. Ordinary random pedestrian counts and assignments are unchanged. Unsafe saved locations are omitted with a warning rather than moved silently.
- This stage is outdoors only. Artwork, identity and persona are random when the NPC is first created; selectable templates and imported custom artwork remain future work. The schema reserves separate stable building/floor/local-position fields for a later interior placement stage.
- Focused checks passed for the actual coordinate-picker UI and project rebuild, creator add/save/reload controls, safety validation, exact geographic-to-world placement, random static artwork loading, stationary behaviour and conversation targeting. Godot script parsing passed. These are focused checks, not extended gameplay/performance testing; known local log/certificate warnings remain unrelated.

## 2026-09-30 — NPC and NPR replies finish their sentences

- Removed the former 12-token/16-word runtime cutoff that could visibly stop a reply halfway through a thought. NPCs and NPRs are now instructed to answer with one complete natural sentence of no more than 28 words, with 40–64 generation tokens available to reach the ending.
- Increased the safe presentation envelope to 32 words / 260 characters. Completed output keeps the first full sentence; if the selected local model still returns an unterminated sentence, the display layer adds terminal punctuation instead of showing a trailing cut-off ellipsis. Streaming remains enabled, so words still appear as they are generated.
- New persona libraries use a 48-token preferred limit. Existing towns that saved the former 16-token value automatically receive the safe 40-token runtime minimum without requiring a rebuild or editing their JSON.
- Godot parsing, the 105 content checks and complete-sentence bubble wrapping passed. A real warmed Albury `llama3.2:3b` check produced first visible text in 0.53 seconds and completed in 2.95 seconds with: `I'm doing all right, just getting some last-minute shopping in before I head home for dinner, lovely day for it too.` This is a focused result; selected model and hardware still determine timing and wording.

## 2026-09-29 — Persona and town prompt work moved to map startup

- User requires all fixed dialogue preparation to happen while the map startup screen is visible. The runtime now loads the complete saved persona library, current project town name, cached Wikipedia lead and optional creator text before player control. A configured Wikipedia page refreshes once, then Ollama warms the same compact town-and-persona catalogue prompt shared by every NPC and NPR. Only the selected character name/persona ID, the player's new sentence and one prior exchange remain variable at conversation time.
- Diagnosed the reported slowdown with the installed `llama3.2:3b`: repeatedly supplying Albury's full 913-character Wikipedia summary took 34.04 seconds, including 32.41 seconds evaluating the prompt and only 1.61 seconds generating the reply. The full accepted sources remain cached, but ordinary small talk now receives only `Town: <name>` and town-related questions select one bounded relevant sentence per available source. This avoids discarding the complete cache while preventing it from bloating every request.
- Reduced current history to one prior exchange, capped generation at 12 tokens, and extended Ollama `keep_alive` to two hours. All saved persona definitions share one prewarmed system catalogue; random character names are supplied after that cacheable prefix so they do not cause a separate cold prompt for every resident.
- Verification passed for script parsing, town-knowledge/source boundaries, the scrollable persona editor, full Albury startup handoff and all 105 CLI/content checks. The real default four-persona check produced first visible text in 1.91 seconds and completed in 3.23 seconds; the actual saved Albury library (six NPC and four NPR personas) produced first text in 2.42 seconds and completed in 3.98 seconds after warm-up. Startup is intentionally longer and remains model/hardware dependent; these focused timings do not guarantee the same latency on every computer or local model.

## 2026-09-29 — Reliable town identity and visible Wikipedia save action

- Diagnosed the reported NPC location failure in the active Albury project: `data/town_knowledge.json` contained an empty Wikipedia URL, title and summary, so no optional town information could reach dialogue. Existing persona data was intact.
- Added **Save town information** directly beside the Wikipedia status, above the longer persona editor. Pressing Enter in the URL field invokes the same save action; the existing combined save button remains. Successful saving gives a plain-language footer message telling the creator to reopen Play test so the startup refresh runs.
- NPC/NPR prompts now always include the current project `display_name` as the in-game town identity. Wikipedia and custom text add factual background but are no longer required for a character to answer which town they are in. This supersedes the earlier persona-only empty-source behaviour while retaining the rule that both optional sources may remain empty.
- Focused store/prompt and Creator layout checks verify the project town name reaches the model context, pressing Enter really writes the Wikipedia URL to a temporary town configuration, and both town-information save paths exist. A real `llama3.2:3b` request using the new project-name instruction answered `We're in Albury.` User still needs to re-enter the intended Wikipedia URL because the application cannot recover text that was never saved.

## 2026-09-29 — NPC/persona configuration is fully scrollable

- Fixed the NPCs and personas page after the new optional town-information controls made the lower save row unreachable at some window sizes. The model selector, Wikipedia/text inputs, persona editor, **Save personas and town info** button and coming-soon panel now share one vertically scrolling content area beneath the fixed page heading and safety notice.
- Added a focused layout regression that confirms the page has a real vertical scroll range and can programmatically bring the save button into the visible scroll viewport. This changes layout only; saved personas, Wikipedia URLs, cached summaries and imported text remain unchanged.

## 2026-09-29 — Optional Wikipedia and creator-written town knowledge

- Added an **Optional town knowledge** panel to **NPCs and personas**. A creator may paste an exact HTTPS Wikipedia article URL, import/replace/remove a bounded UTF-8 `.txt` file, use either source alone, or leave both empty without warnings, startup delay or loss of local dialogue. Added the separate disabled **Storyline NPCs — Coming Soon** panel; selected-NPC storyline binding remains unimplemented.
- Added canonical `data/town_knowledge.json`, `schemas/town_knowledge.schema.json` and copied `data/town_knowledge/custom_town_information.txt` content. The record preserves the full accepted Wikipedia lead summary (with title, canonical URL, language, retrieval time and attribution) and full accepted creator text (with original filename, import time, byte size and SHA-256 fingerprint). New towns save an empty valid record; reopening/rebuilding older towns adds it without replacing existing data.
- At playable-map startup, the game refreshes only the exact creator-supplied Wikipedia article through Wikipedia's read-only API, then proceeds to the existing real Ollama warm-up. The optional request has a 12-second timeout; failure falls back to the prior verified cache or no town context and never blocks the map. Wikipedia is not queried per NPC message. The local model receives separately labelled bounded excerpts, has no browser/file tool and remains unable to change movement, saves or world state.
- Added Codex-facing `show-town-knowledge --town <directory> --json`; import, inspection and validation now include the same canonical town-knowledge data as the GUI. The CLI never contacts Wikipedia or Ollama.
- Focused checks passed for accepted/rejected Wikipedia URLs, redirects/API-response parsing, disambiguation rejection, empty optional configuration, full cache retention, `.txt` copy/replacement/removal, source separation, prompt injection boundary and Creator page layout. The real Wikipedia endpoint returned the Albury article and a 913-character lead summary. Albury's real `llama3.2:3b` startup warm-up still handed map control back successfully. Godot scripts parsed, the persona editor check passed and all 105 Node/content checks passed. Extended offline/slow-network gameplay remains user-tested; Wikipedia availability and local model speed are external dependencies.

## 2026-09-29 — Faster streamed dialogue and random character names

- Every NPC now receives a distinct deterministic town-seeded random first name and surname matching the existing man/woman artwork assignment; NPRs receive distinct random serial-style names. The conversation heading and local prompt use the individual character name separately from the randomly assigned speaking persona.
- This stage remains random-pool only: NPCs choose from the available NPC persona pool and NPRs from the NPR pool. Linking a storyline persona to a creator-selected NPC is explicitly deferred to the later storyline-persona stage.
- Replaced whole-response buffering with Ollama's streamed chat response. The NPC/NPR bubble updates as text arrives and remains disabled for input until the final chunk, so the player no longer waits for the complete sentence before seeing anything.
- Startup now performs a real one-token `/api/chat` warm-up with the same instruction prefix used during conversations, rather than only loading weights with an empty generation. The model remains resident for 30 minutes. Runtime limits history to the latest four messages, uses a 1,024-token context and caps generation at 16 tokens plus 16 words / 140 displayed characters.
- Focused Albury checks passed for a name on every NPC/NPR, random-pool persona assignment, streamed bubble updates, startup control handoff and the no-code persona editor. The installed `llama3.2:3b` produced first streamed text in 11.53 seconds and completed in 13.07 seconds after warm-up on this PC; model/hardware choice still determines inference time. Godot script parsing and all 101 Node/content checks passed. Known sandbox log/certificate and direct-image warnings remain unrelated; extended gameplay timing remains user-tested.

## 2026-09-28 — Compact lower-left driving instruments

- User reported that the speedometer and odometer obscured the road ahead. Reduced both instruments uniformly to 55% of their prior width and height and moved their combined block from the upper-right to the lower-left, immediately above the persistent status/help bar.
- The original logical drawing remains intact, preserving the analogue speed scale and needle, actual speed, selected cruise speed, gear, maximum speed, lifetime ODO, TRIP A and mouse-clickable trip Reset control. The odometer remains hidden on foot and stays in the same lower-left location when the map is opened from the wagon.
- The visible combined footprint changed from approximately 212×154 to 116.6×83.7 pixels in the 640×360 design viewport. This is 55% per dimension (about 30% of the former area) and ends at y=329.7, just above the lower HUD beginning at y=330.
- Focused layout and odometer persistence/reset checks passed. A graphical Albury gameplay render confirmed the panel does not cover the road ahead or overlap the lower HUD; review image: `tools/tests/output/compact_driving_instruments.png`. Existing Godot image-import and local log/certificate warnings are unchanged.

## 2026-09-28 — Approach-owned lights, matching visual phases and divided junctions

- Compared the original Generational Australian Survival v1.3 traffic manager/network builder. Its useful contract is one displayed post per incoming approach, with drawing and entry using the same phase direction. Retained the existing 48-second phase timing; the duplicate-light problem was not a timer difference.
- Removed the two horizontal/vertical lamps drawn at every raw OSM signal node. Generated entry-edge approach records now drive both displayed colours and admission decisions. Ordinary four-way junctions have four incoming posts; similar parallel entry edges share one post, and internal/outbound edges do not generate new lights. Posts sit beside the mapped road width, with approach stop lines and left/right driving-side placement.
- Replaced first-node-wins region assignment with bounded union of overlapping regions and short (up to 35 mapped metres) connections between branching cores. This handles divided-road boxes previously split between independent controls. Combined extent is capped at 80 metres to limit chaining. Internal connectors never acquire another red-light test; collision, conflict reservations, exit occupancy and later separate lights remain active.
- Added `verify_approach_signals.gd`: ordinary four-way with nine signal tags produces four posts; all six tested phase times match entry decisions; a divided four-core intersection is unified with four incoming posts and no internal red gate. Existing signal-region, traffic-flow, three-car queue, actor collision and NPC/NPR crossing/startup checks passed.
- Actual Albury rendered review: a junction with twelve raw OSM signal nodes now has four approach lights (previous drawing would emit twenty-four icons). Town total: 71 posts. Actual capture is `tools/tests/output/albury_approach_signals.png`, reproducible with `render_approach_signals.gd -- --play-town <directory>` using a graphical Godot renderer.
- Final 30-second simulated Albury check: all 150 traffic cars moved at least once, 6,552 committed-car samples, no signal-induced stop while committed. Waits still included crossing vehicles, pedestrian reservations, traffic ahead and conflicting movements. This is a focused flow diagnostic, not proof of jam-free full-town traffic. Signal-region inference remains approximate for unusually large or very closely spaced junctions. Restart Play test; existing towns need no rebuild. Original v1.3 files were inspected but not changed.

## 2026-09-28 — Pedestrians finish intersection crossings; clear wagon startup

- Fixed a separate pedestrian signal bug: NPC/NPR crossing permission was released at every OSM vertex or footpath-link transition, including points still inside the carriageway. It now persists across these points until reaching an endpoint outside the mapped surface-road envelope. Crossing reservations retain the traversed segments through completion; the next red signal cannot strand an already-admitted pedestrian, and destination visits cannot start while that crossing is committed. This uses the imported road widths/geometry, not town-specific coordinates.
- Waiting pedestrians near a committed walker's landing point try a small pavement-side step, checked against road boundaries, buildings, water, the owned wagon and other walkers. They do not step into the road to make room. A parked wagon overlapping a crossing is now considered before entry rather than only after a walker reaches it.
- The runtime supplies player/wagon obstacles before population creation. Traffic starts are sampled on legal directed graph edges with at least 160 world units from the player/wagon and 70 between displayed traffic centres, avoiding nearby junction vertices and invalid ground. Placement uses bounded attempts; if a small/crowded map cannot fit a car, it warns and omits that car rather than forcing an overlap. No player start or saved map is moved.
- Focused checks passed for NPC and NPR red-entry rejection, green admission followed by red at a mid-road vertex, reaching the far pavement and releasing traffic; landing yield and rejected unsafe pavement; 20-car startup spacing. Existing signal-region, actor-collision, pedestrian-crossing and walker/bubble checks passed. Actual Albury startup retained all 150 cars, nearest traffic was 434.42 world units from the wagon, and the first forward/reverse steps were actor-clear.
- Scope: verified these reproducible failures, not every possible junction deadlock or long-running congestion case. A blocked/absent safe route still cannot be crossed by ignoring collisions. Restart Play test to recreate traffic with safe startup placement; no town rebuild is required. Known sandbox log/certificate and existing image-loading warnings are unchanged.

## 2026-09-27 — Whole signal-junction permission and actor collision follow-up

- User feedback showed the earlier per-node signal fix was insufficient. Added `runtime_signal_junctions.gd`: infer a bounded, connected ground-road junction around nearby OSM signals and branching nodes (28 mapped metres), plan a legal route out before entry, and retain entry permission across its intermediate/turning/far-side nodes. Release using the actual car position once its rear clears the final inside node, including when the car is subsequently blocked. Separate later signals still apply. No town-specific coordinates, LLM or saved-town rebuild is required.
- Check stopped exit queues near the start of the outgoing edge, not its potentially distant endpoint. Hold conflicting whole-junction paths while allowing spaced followers of the same route and independent opposing straight movements. Keep physical vehicle, player and pedestrian checks active after admission; clear all commitment/route state on jam relocation. Route search is bounded and avoids choosing a dead-end when a legal local exit exists.
- Added player-wagon swept movement and steering checks against traffic cars, NPCs and NPRs using displayed positions and collision layers. Added local traffic-body checks across different OSM routes and NPC/NPR checks against the stopped owned wagon. Aircraft and different bridge/tunnel layers do not become ground obstacles. This prevents pass-through; it is not an impact-damage simulation.
- Crossing forecasts now consider traffic continuing beyond short road edges, recognise stopped red-light cars, and serialize conflicting/opposing narrow pedestrian crossings. Roadside route transitions use crossing checks where they actually cross a vehicle road. Visible traffic lane offsets are shared with collision checks (9.5 pixels each side).
- Focused checks passed: `verify_signal_junction_regions.gd`, `verify_intersection_actor_safety.gd`, existing traffic-flow, crossing and walker/bubble suites. The three-car split-junction queue cleared with a minimum 55-pixel centre gap. The actual Albury footpath check passed (99 roadside walkers, 3 routes held safely).
- `verify_town_signal_flow.gd` exercised 30 simulated seconds in Albury: 255 grouped graph nodes, 8,537 committed-car samples with no signal-induced stop, and 141 of 150 traffic cars moving at least once. Remaining waits included physical vehicles, conflicting movements, red entry signals and occupied exits; this is not proof every car/jam is fixed. Junction grouping is a map-derived inference, not surveyed signal-controller data; unusual closely spaced or very large junctions still need gameplay review.
- Performance limitation: a separate earlier-in-this-iteration 320-agent headless diagnostic measured 56.8 average FPS, with traffic updates 2.12 ms/frame, NPCs 6.96 and NPRs 1.08, before the final whole-junction change. Do not treat this as a final graphical performance result. Known sandbox log/certificate and image-import warnings remain; full runtime verification still has the previously recorded 320-versus-330 NPD fixture assertion.

## 2026-09-27 — Traffic lights govern intersection entry, not the exit road

- Fixed NPC cars stopping inside an intersection when a far-side signal or the signal for the road they were entering showed red. A car now makes the light decision before entry; once admitted on green, its reservation remains valid until the rear has cleared the junction.
- Extended signal commitment to degree-two OSM traffic-signal nodes. OSM commonly maps several stop-line/pedestrian signal nodes around one physical junction rather than one centre node: the Albury graph contains 171 signal nodes and 79 directed signal-to-signal edges shorter than 12 metres. Cars no longer treat each of these closely spaced nodes as a new light while still clearing the same intersection.
- Retained the safety gates before commitment: a green light does not bypass an occupied exit, a conflicting reserved movement, following clearance, pedestrian reservations or the player/owned wagon. After clearing, a genuinely later red light stops the car normally.
- Focused traffic simulation passed for amber/red entry, green admission, a phase change after entry, the complete centre-to-exit node transition, a red far-side signal, a later separate red, an occupied exit and reservation release. Existing progressive-queue, crossing/pedestrian and player-intersection regressions passed. Restart Play test to load this runtime change; existing projects do not need rebuilding.

## 2026-09-27 — Remove invisible building edges from drivable intersections

- Fixed the player wagon abruptly striking an unseen collision edge at some OSM intersections. The generated Albury validation report contains 114 cases where a road centre-line is clear but the road edge is close enough to overlap a solid building footprint; the old centre-line check could therefore approve a route that was narrower than the wagon's full collision rectangle.
- Added a spatially indexed surface-road check using each imported map's own rendered road widths and geometry. The wagon ignores a conflicting ground-building collider only while dense samples across its complete swept rectangle remain inside the union of visible, ordinary ground roads. This supports turning through joined road arms rather than requiring one road segment to contain the whole car.
- Ordinary building collisions remain active off-road and at the road edge. Water and map boundaries are unchanged, and bridge/tunnel layers keep their dedicated entry, corridor and side-boundary rules; footpaths and elevated roads cannot grant the surface-road exception. No town-specific coordinates or LLM interpretation are used, and existing generated towns do not need rebuilding.
- A focused physics regression passed for straight travel and a 45-degree intersection turn through a deliberately conflicting footprint edge, then confirmed the same collider still stops the wagon off-road. Existing player controls, exact building collision, map geometry, environmental water, bridge/tunnel boundary and pedestrian-crossing tests passed. The real Albury runtime loaded successfully; its full verifier then reached its previously recorded unrelated 320-versus-330 NPD fixture assertion.

## 2026-09-27 — NPC/NPR passing and readable conversation bubbles

- Fixed ground NPCs and NPRs walking directly into one another on shared paths. A small spatial-neighbour index now lets walkers detect only nearby characters and steer to consistent opposite passing sides; this avoids an all-against-all population scan each frame.
- Passing remains subordinate to map safety. A sideways candidate is checked against buildings, water and the map boundary, with the opposite side tried if blocked. Walkers on road crossings, bridges or tunnels stay on their legal mapped line and slow briefly instead of sidestepping into another traffic/layer area. A character paused for conversation also remains an obstacle that other walkers attempt to pass.
- Reworked the **NPC/NPR reply bubble** as fixed-size screen interface rather than zoomed world artwork. Its anchor now uses the selected NPC or NPR's actual rendered world height multiplied by the active camera scale, placing the panel above the head with a short speaker-pointing tail rather than over the face. It uses a larger 13-pixel font, opaque cream panel, dark two-pixel border and shadow, and clamps within a HUD-safe screen rectangle so it cannot be cut off by the title or controls. Per the user's clarification, no floating bubble is drawn for the player; the player's **Hi** remains visible in the dialogue interface.
- Focused simulation passed for exact-overlap escape, head-on NPC/NPR passing without overlap, legal crossing slowdown and reply-bubble screen clamping. The existing road-crossing regression passed. A 320-agent headless Albury sample measured NPC updates at 2.17 ms/frame and NPR updates at 0.43 ms/frame; this is a focused diagnostic rather than full graphical gameplay testing. The general Albury runtime check still has its already-recorded ten-NPD fixture shortfall (320 generated versus 330 configured); no new runtime script error was produced before that unrelated assertion.

## 2026-09-27 — Basic NPC and NPR conversation system

- Added the first deterministic conversation interaction for ordinary NPC pedestrians and NPR robots. While outdoors and on foot, press **T** near the closest visible same-level NPC/NPR to begin; traffic cars and NPD drones are not conversation targets.
- The player and selected character pause and turn toward one another. The camera moves to their midpoint and zooms closer while keeping both in frame. The town continues running around them.
- Added one visible dialogue choice, **Hi**, selectable by mouse, **Enter** or **1**. Choosing it displays the NPC/NPR's floating **Hi** reply bubble; the player selection remains in the dialogue interface. Press **T** or **Escape** to end the conversation and restore movement and the normal walking camera.
- The target search is distance limited and rejects conversations through building footprints or across bridge/tunnel layers. This foundation does not call a local LLM, store conversation memory or change gameplay state.
- A complete saved-town runtime check passed T-key selection, participant pausing, camera zoom/framing, clickable choice, NPC/NPR reply bubble and movement/camera restoration. A graphical Albury capture confirmed the fixed-size bubble remained fully visible inside the screen at an edge-clamped position.

## 2026-09-27 — Playable ground-floor entrances and 25% larger characters

- Connected saved Building Creator doors to their matching Interior Designer entry links. On foot, the HUD now identifies a nearby linked entrance; pressing **E** at its green exterior arrow transfers the player to the saved ground-floor arrival point. Returning to the green interior marker and pressing **E** exits at the same exterior arrow. An exterior door without an interior link now displays a direct instruction to complete that link instead of making E appear broken.
- Added a dedicated interior view and movement boundary. The player may walk only inside the saved footprint-shaped floor; concave edges and courtyard holes remain solid boundaries. Outdoor rendering, traffic and NPCs are hidden while indoors, and the town map is disabled until the player exits.
- Increased player and NPC artwork from 6×11 to **7.5×13.75 world units** and increased NPR artwork from 0.5× to **0.625×**, exactly 25%. Feet anchoring, collisions, movement speeds, routes, crossing safety and population settings are unchanged. Cars and NPDs were not resized.
- Focused checks passed for footprint confinement, courtyard blocking, saved E-key entry, correct exterior return and all three requested actor-scale changes. A real saved Creator Studio fixture loaded through the complete playable runtime and passed the entry/view/exit sequence. Rooms, furniture, stairs and upper-floor travel remain pending.

## 2026-09-27 — Clean walking surfaces and Interior Designer floor foundation

- Removed the player's walking footprint trail. Walking on grass no longer creates marks; the occupied wagon still leaves temporary paired tyre marks on grass.
- Activated the first no-code **Interior Designer** stage for buildings that already have a Building Creator entrance. **Create blank ground floor** projects the selected building's actual OSM footprint into metres, preserving concave outlines and courtyard holes rather than substituting a rectangle.
- Creators can add up to 19 upper floors, choose a floor and increase its size from 100% to 300%. Upper floors inherit the footprint shape and resizing scales that outline proportionally. Any value above the original 100% is stored as a creator adjustment and is not represented as surveyed OSM geometry.
- Exterior entrances can be linked to a creator-selected safe arrival point inside the ground-floor footprint. Layouts save in `data/building_interiors.json`, reopen with the town and survive rebuilds; new GUI and CLI projects receive the empty validated contract automatically.
- Focused checks passed for no walking marks, retained tyre marks, irregular footprint/courtyard projection, inside-only entrance placement, upper-floor creation, proportional resizing, persistence, the complete Creator Studio workflow and all 101 CLI/content checks. Playable door transfer, room/wall drawing, stairs and furniture remain later Interior Designer stages.

## 2026-09-27 — Microsoft Paint footprint-template export

- Added **Export footprint for Paint** to Building Creator. After selecting any active imported building, the creator chooses where to save a standard PNG, edits it in Microsoft Paint and imports the finished PNG through the existing exterior-image workflow—without writing code or changing OSM.
- Templates are north-up and retain the footprint's projected real-world proportions. The longest edge is 2,048 pixels; the editable footprint is neutral grey, while concave exterior space and courtyard holes are transparent. The same full image bounds match the runtime UV mapping, so an unchanged Paint canvas returns in alignment automatically.
- The default save location is the selected town's `exports/building_footprints/` folder, but creators can choose another directory. Plain-language completion instructions state that cropping/resizing the canvas breaks automatic alignment; imported artwork remains footprint-clipped and cannot change collision.
- Added a deterministic non-interactive export helper for Codex. A focused L-shaped/hole fixture verified PNG dimensions, proportions and alpha regions; the GUI workflow verified selection, export and instructions. The existing Building Creator checks and all 101 Node/content checks passed. An actual 2,048×1,440 West End Plaza template was exported from Albury OSM feature `115073717` for review.

## 2026-09-27 — West End Plaza Albury Building Creator demo

- Added a top-down 1,024×1,024 plaza-roof asset to the existing Albury test project and attached it to the directly tagged OpenStreetMap **West End Plaza** footprint (`115073717`). The image is clipped to that footprint and does not change its imported geometry or collision.
- Added two creator-selected demonstration entrances on the Dean Street/north and Kiewa Street/east sides. Both snapped to the OSM footprint, passed fixed-footprint/water clearance and linked to nearby pedestrian nodes. These positions are for Building Creator testing and are not represented as OSM-mapped or surveyed doors.
- Added small deterministic SVG-to-PNG and repeatable West End Plaza setup helpers. The OpenAI image generator was attempted first but was unavailable because its current usage limit had been reached; no local LLM or unapproved API fallback was used.
- `validate-town` passed the resulting Albury content pack, including `building_exteriors.json`. Its only warning is that this older saved Albury project predates `map_overrides.json`; rebuilding in Creator Studio can add that unrelated Advanced Map Editor file.

## 2026-09-27 — Building Creator alignment and multiple entrances

- Completed the next Building Creator pass with no-code **Image scale** (50–300%), **Rotation** (−180° to 180°), horizontal offset and vertical offset controls plus one-click alignment reset. Creator preview and Play test use the same transformed texture coordinates while retaining exact footprint clipping and unchanged footprint collision.
- Replaced the single-door record with up to eight stable-ID entrances per building. Creators can add another entrance, select one, move it to another wall or remove it. Moving repeats the wall snap, outside-clearance and pedestrian-link checks while preserving the entrance ID. Existing single-door town files migrate automatically to `entrance_1`.
- Corrected a precision defect exposed by multi-side entrance tests: direct `Geometry2D` containment on longitude values near 149° could classify clear ground south/west of a footprint as inside it. Clearance now translates each polygon to local metres before testing, making all footprint sides consistent without map-specific coordinates or an LLM.
- Updated the schema and Node validation for alignment ranges, safe asset paths, entrance limits, unique IDs and numeric coordinates. Documentation now describes the completed GUI flow and remaining direct-handle/perspective/interior limitations.
- Focused store/renderer checks passed for copied and aligned artwork, identical editor/runtime UV mapping, multiple safe entrances, move/remove, stable IDs, path linking and persistence. The full Creator UI workflow and 101 CLI/content checks passed. Godot emitted only the existing sandbox log/certificate warnings.

## 2026-09-26 — Equal smaller player/NPC scale anchored at the feet

- Corrected the reported mismatch where the player appeared larger than NPCs. The cause was a shared 0.5 multiplier being applied to different base heights: 27 units for the player and 25 for NPCs.
- Player and NPC production sprites now use the same **6×11 world-unit** draw box. Its bottom edge is exactly the actor position, keeping every character anchored at the feet while walking, leaning and changing direction. This makes both groups smaller than the previous pass and guarantees equal displayed height regardless of source-image crop proportions.
- NPR scale remains at the previously requested 50%; cars and NPDs are unchanged. Character collision radius, movement speed, navigation, road-crossing safety, destinations and camera defaults were not changed.
- The actor regression check passed for the shared 11-unit height, feet anchor, all directional player/NPC/NPR assets, balanced NPC catalogue and vehicle variants. Godot emitted only the existing sandbox log/certificate and development image-loading warnings.

## 2026-09-26 — 2.7× walking view and first Building Creator stage

- Increased the recommended/default on-foot camera zoom by 35%, from 2.0× to **2.7×**. The independent in-car default remains **1.5×**, overview-map zoom is unchanged, and an explicit zoom already saved by a creator is preserved.
- Activated the no-code **Building Creator** page. A creator opens a town, selects an active imported footprint, imports a PNG/JPG/JPEG/WebP image, previews it clipped to the exact footprint, chooses a wall for the door and saves the associated green entry arrow. The artwork appears through the same clipped renderer in Play test.
- Imported files are copied—not moved—into `assets/buildings/<stable_building_id>/` with content-hashed names. File type, 25 MB size and 16–4,096 pixel dimensions are checked. PNG/WebP alpha is preserved. Canonical choices live in `data/building_exteriors.json` under `schemas/building_exteriors.schema.json`; Rebuild preserves existing choices and Node imports create/validate the empty contract.
- Door clicks snap to the nearest footprint edge. The outward approach must stay inside the map and outside effective building/fixed-footprint/water geometry; a nearby pedestrian node is recorded within 250 metres when available. The entrance is creator-authored and never presented as an OSM-mapped fact. Artwork and entrance metadata do not alter building collision.
- Focused Building Creator checks passed for copied artwork, stable relative paths, editor/runtime texture loading, footprint clipping data, clear snapped approach, pedestrian linking and persistence. The full Creator UI workflow and 101 CLI/content checks passed. A tiny-town whole-runtime assertion still expects its configured 330 actors but can only spawn 10 on that deliberately small graph; renderer loading itself passed the dedicated focused check.
- Limitations: this first stage supports one bounding-box-filled/clipped image and one entrance per footprint. It does not yet provide crop/rotate/tile controls, per-wall facades, interior rooms or door-transfer gameplay. See `docs/building_creator.md`.

## 2026-09-26 — Advanced Map Editor foundation and smaller NPC/NPR artwork

- Added the first usable no-code **Advanced map editor** page for saved towns. Creators can select an imported building footprint and hide/restore it, draw a rectangular blocked-water area, or cut a rectangular passable-ground hole from incorrectly mapped water. Hidden footprints remain visible in red inside the editor; blue/green corrections are visible on the correction preview. The page includes zoom/pan plus 50-step in-session Undo/Redo.
- Corrections save to the new stable `data/map_overrides.json` contract instead of modifying `source_osm/` or raw `data/map_features.json`. Create, Save, Rebuild and Play apply the effective feature layer before building collisions, navigation, place information and population destinations. A deterministic source fingerprint and stable IDs flag missing source features when an OSM rebuild changes them.
- Blocked-water zones use the existing shared ground-safety pipeline, so the player, owned vehicle, NPC traffic, NPCs and NPRs cannot traverse them; NPDs retain aerial movement. Passable-ground zones affect mapped water only. Node CLI imports now create/validate the empty override contract for Codex compatibility.
- Reduced rendered player, NPC and NPR artwork to **50%** of its prior size. The change is visual only: collision clearance, route nodes, movement speed, safe crossings, destination assignment and population counts are unchanged; cars and NPDs keep their existing size.
- Focused map-override checks passed for raw-source preservation, hidden collision removal, water collision addition, dry holes, save/reload, deterministic fingerprinting and changed-source review. Creator UI passed an end-to-end edit/Undo/Redo/save/rebuild check; actor catalogue checks and 101 CLI/content checks passed.
- Limitations: water drawing is rectangular and saved zones are removed newest-first; direct zone selection/handles, arbitrary polygon reshape, layer filters, custom non-water collision zones and per-actor applicability remain later editor work. This stage does not bypass the pre-existing safety block for an incomplete, ambiguous coastline relation. See `docs/advanced_map_editor.md`.

## 2026-09-26 — Map-derived population destinations

- Added deterministic `data/population_destinations.json` generation during Create, Save and Rebuild. Direct tags on OSM building footprints classify residential, education, health, retail, office, hospitality, civic, recreation, industrial and transport destinations; unclassified buildings and nearby/contained POIs are not assigned an invented use.
- Every destination retains its footprint ID, category source tag, OpenStreetMap attribution and a pedestrian-node link no farther than 250 metres. Exact doors are explicitly left unverified. The new stable data contract is `schemas/population_destinations.schema.json` and older saved towns receive an in-memory equivalent until rebuilt.
- NPCs now plan imported pedestrian-graph trips between reachable activities and a residential home when available. NPR robots plan reachable activity trips using the same walking, obstacle and safe-crossing rules. Destination selection stays within the actor's connected walking-network section; a sparse map with no usable tagged places retains the previous graph-wandering fallback.
- Focused synthetic checks passed for direct-tag classification, truthful unknowns, distance limits, shortest graph routes, disconnected sections and NPC/NPR assignment. Rebuilding the real Albury fixture generated 257 usable destinations across eight categories: 116 residential and 141 activity places. Of 170 ground walkers, 167 received reachable destination travel; the three in destination-free network sections retained safe graph wandering. Actor-art, Creator UI and 101 CLI/content regressions passed.
- Limitations: this stage does not invent schedules, employment, shopping transactions, tenant-level POIs, interior entry or exact door approaches. The Albury check is focused startup/data verification, not extended behaviour or performance testing on every uploaded town. See `docs/population_destinations.md`.

## 2026-09-26 — v1.4 started with directional actor animation

- Began v1.4 from the completed v1.3 mechanics and moved the local development checkout onto its own `v1.4` branch. Updated Creator Studio, generated content metadata, CLI output and the in-game badge to identify v1.4; completed v1.1–v1.3 releases remain separate checkpoints.
- Added static directional atlases for the player, all 18 NPC catalogue identities and NPR robots. Player/NPR atlases provide front, left, right and back views with four walk rows; NPC atlases preserve the light/medium/dark, man/woman and young/adult/older catalogue combinations in four directions. Existing population percentages remain visual-only and do not affect behaviour or persona.
- Player artwork follows WASD facing. NPCs and NPRs face their actual generated walking route, including roadside and crossing paths. The existing top-down NPD artwork rotates with its aerial route; existing car rotation remains unchanged. Drawing changes do not alter collision sizes, pathfinding, speeds or spawn rules.
- Directional source cells use proportional grid boundaries and alpha-cropped cached regions, allowing generated atlases with non-divisible pixel dimensions to remain aligned and readable at gameplay scale. The new bitmap atlases live in `assets/actors/directional/`; runtime town generation does not call an LLM.
- Focused checks passed for genuine transparent padding, four distinct directions, player/NPR walk rows, all static catalogue mappings, gender balance, WASD/cruise/reverse controls, Creator settings and 101 CLI/content checks. The real Albury town launched with 99 checked NPC/NPR roadside routes and two blocked routes safely held. `tools/tests/output/directional_actors_albury.png` was visually inspected at the actual gameplay scale.
- Limitations: each NPC identity has directional poses plus the existing movement bob rather than a unique multi-frame walk cycle; subtle art consistency can be refined later. The Albury capture is a focused rendered check, not extended population/performance testing on every uploaded town.

## 2026-09-20 — Odometer display limited to the car

- User clarified that the odometer should not appear on foot. The ODO/TRIP/RESET panel now starts hidden and displays only while the player occupies the wagon; it remains visible and mouse-resettable while driving or viewing the map from the car. This supersedes the preceding entry's on-foot visibility without changing distance tracking or saved readings.
- Focused display-state checks cover on-foot, driving and map views; actual Albury on-foot and in-car captures were used for visual review. Extended gameplay remains user-tested.

## 2026-09-20 — Working wagon odometer and anytime trip reset

- Added ODO (lifetime) and TRIP A readings below the numbered speedometer. Accepted wagon movement is converted from town pixels to real metres with the saved map scale, including reverse and off-road movement; map panning, walking and external position changes do not count.
- A mouse-clickable **RESET** area is always available in the gameplay HUD, including while driving, on foot and in the overview map. It resets and saves only Trip A, with no stop requirement and no change to car speed or lifetime ODO. The first native button exceeded its intended bounds; the final fixed-size drawn hit area was recaptured and visually verified fully within the panel.
- Odometer progress saves every ten seconds of gameplay and on exit at `saves/vehicle_odometer.json` inside the selected town; a prior copy is kept as `.bak` for recovery. Rebuilding town content leaves the `saves/` folder intact. Capture/verification modes do not write user mileage.
- Focused test passed for two map scales, reverse movement, save/reopen, immediate reset persistence and damaged-save backup recovery. The actual Albury game capture was inspected after the overlap correction. Extended driving, long-session save reliability and other town maps remain user-tested.

## 2026-09-20 — Numbered analog speedometer, acceleration and measured performance

- Cruise selection now changes by **1 km/h per Up/Down press**, superseding the previous 5 km/h steps. The wagon defaults to **7.2 seconds from 0 to 100 km/h**, with a creator-facing acceleration-time setting; the calculation uses each town's pixels-per-metre scale. Shift Reverse and its separate speed cap remain unchanged.
- Added a car-style dial with numbered 0–200 km/h marks, minor ticks, a live needle and actual-speed readout; the selected cruise speed sits in the centre. Reverse uses its own numbered 0–20 scale. The dial is visible while driving, including full-screen play.
- Added a repeatable saved-town performance diagnostic. In this machine's windowed Albury scene with 320 spawned agents, the initial measurement was about **2.7 FPS / 21,000 draw calls**. View-bounded map/population drawing, cached building geometry and indexed traffic lookups reduced the final close-up sample to about **60 FPS / 347 draw calls** over 180 frames. Remote (>900 world px) cars use bounded 0.20-second updates; nearby cars and all NPCs/NPRs remain full-rate. A diagnostic full-rate-all-cars run settled around 32 FPS, so this remote-car budget is a measured tradeoff, not a gameplay-mode switch.
- Passed focused controls, creator-settings, traffic-flow, crossing, remote-update and Albury footpath checks; 101 CLI/content checks passed. An Albury full-map screenshot and the numbered dial were inspected. These are short checks on one computer and one saved town, not extended gameplay, congestion or universal OSM performance proof. The Albury fixture still spawns no NPDs because its saved aerial grid is outside the selected play bounds.

## 2026-09-20 — NPC/NPR footpaths and safer road crossings

- NPC pedestrians and NPR robots now follow road-edge walking corridors derived from each imported road's OSM width/sidewalk tags, using the existing drawn-footpath dimensions. One-sided sidewalk tags remain on the correct physical side in both travel directions. If an offset route or connector is blocked by mapped building/water geometry, the actor waits instead of walking down the vehicle centre line.
- A transition between walking corridors, or an untagged footway that intersects a surface vehicle road, now uses the traffic-gap/reservation check. Signal-tagged crossings wait for the preview walking phase. NPC cars and the player wagon yield to committed ground-level crossings; separate bridge/tunnel traffic does not.
- Town navigation validation now reports how many directed pedestrian links use inferred roadside walking space and explicitly says those are not surveyed pavements.
- Focused crossing, navigation, traffic-flow and player-control checks passed. Imported Howlong, Kingston ACT and Gold Coast OSM crossing checks passed. The actual Albury test project launched; 99 NPC/NPR road-edge routes were checked and two blocked routes were safely held. Extended gameplay/performance and exact footpath accuracy remain user-tested; OSM omissions are still inferred rather than surveyed. Reverse gear and optional player lane/path assistance remain pending.
- Design/limitations: `docs/pedestrian_crossing_parity.md`.

## 2026-09-19 — Cruise-control speed selection follow-up

- Superseded Stage 2's pedal-style Up/Down behaviour with the requested cruise control. Up Arrow raises the target by 5 km/h and Down Arrow lowers it; normal keyboard repeat supports holding either key. The wagon automatically accelerates or decelerates toward the selection and maintains it after release.
- Clamp the cruise target between zero and the creator-selected maximum. Down cannot select reverse. Space cancels cruise and applies the emergency brake; collision, invalid ground and leaving/entering the wagon reset the target to zero.
- The driving HUD now shows actual speed, selected cruise speed and maximum speed together. Creator help and the controls reference use the same wording.
- Focused verification passed for 5 km/h steps, minimum/maximum clamping, automatic speed holding, lowering without reverse, emergency cancellation and 200/235 km/h conversion. The 101-check CLI/content suite, Creator GUI, pedestrian crossing regression and isolated Albury runtime with 320 ground road users/eight collision chunks also passed. Extended driving feel remains user-tested.

## 2026-09-19 — Stage 2 revised player controls

- Replaced arrow-key walking with standard four-direction **WASD** controls. E interaction, M map, F11 full screen and the existing safe collision/crossing rules remain unchanged.
- Revised the wagon so Up Arrow accelerates, Down Arrow decelerates/brakes to zero and Left/Right Arrow steer. Down no longer becomes reverse after stopping; Space remains an emergency brake. Updated all in-game guidance accordingly.
- Added a plain-language **Maximum driving speed** setting in km/h, defaulting to 200. GUI, CLI (`--max-speed-kmh`), JSON schema and migration agree on the 1–400 km/h range. Existing towns missing the field receive 200 km/h when loaded; legacy internal forward/reverse values remain readable but are hidden from creators and no longer determine forward maximum speed.
- Runtime physics converts the selected km/h through that town's saved pixels-per-metre scale, and the HUD uses the inverse of the same conversion. A custom 235 km/h value therefore remains 235 km/h in both movement and display instead of exposing internal units.
- Focused controls, Creator save/reload, 101 CLI/content, crossing and isolated Albury runtime checks passed. The Albury check loaded the migrated 200 km/h default with 320 ground road users and eight collision chunks. Extended feel/balance testing remains with the user; reverse has intentionally not been assigned.
- Controls reference: `docs/player_controls.md`.

## 2026-09-19 — Stage 1 traffic behaviour

- Replaced one-car-only junction ownership with map-independent movement reservations derived from each car's incoming OSM edge and one planned outgoing edge. Safely spaced cars following the same movement can discharge progressively, and opposing straight-through lanes can move together.
- Conflicting turns and merges still wait. Cars also check for a stationary vehicle on their planned outbound arm before entering, hold their reservation until their rear has cleared the junction, and continue clearing if a light changes after commitment.
- Preserved the simple Generational Australian Survival two-axis signal cycle, one-second imported stop behaviour, pedestrian-crossing yield, player/wagon clearance and settings-driven distant jam relocation. No LLM or town-specific intersection coordinates are used.
- Focused traffic checks passed for ordinary following distance, moving and stationary queues, compatible opposing traffic, a conflicting turn, blocked exit, held/released clearance, amber/red/green, a committed signal change, stop control and distant jam recovery. Crossing, actor-diversity and Creator GUI regressions passed; the CLI/content suite remains at 95 checks.
- An isolated Albury copy launched successfully with 150 cars, 150 NPCs and 20 NPRs on the real generated map, with eight collision chunks. Its existing saved aerial graph has no nodes inside the selected map bounds, so the traffic-only copy used zero drones; aerial-grid repair is a separate pending issue. Extended congestion/performance and real council signal timing remain user-tested or unavailable.
- Details and limitations: `docs/traffic_behaviour.md`.

## 2026-09-16 — v1.3 development started

- Began v1.3 from the completed v1.2 feature set. The published v1.1 and v1.2 releases remain preserved in their own repository folders.
- Updated the Godot project, Creator Studio, runtime map badge, CLI and documentation to identify this working copy as v1.3.
- Reordered the planned stages at the user's request: traffic behaviour; revised player controls; directional actor animation (former Stage 5); population destinations (former Stage 4); Advanced Map Editor (former Stage 3); Building Creator; Interior Designer; local-LLM NPC personas; terrain/environment; validation and release.
- This entry starts the new version only. No planned v1.3 gameplay stage has been implemented or verified yet.

## 2026-09-16 — Static NPC and traffic artwork catalogues

- Replaced the unsatisfactory procedural NPC face/clothing composition with 18 complete static pixel-art sprites: Light, Medium and Dark pigmentation groups × man/woman × young adult/adult/older adult. Each includes its own coherent face, hair, body and outfit; gameplay now selects an asset ID and draws that PNG without recolouring or constructing facial features.
- Simplified Creator demographics to **Light**, **Medium** and **Dark** percentages. Equalize remains selected by default. Older seven-range v1.2 values migrate deterministically into the three groups without losing their total, and pigmentation remains visual-only and independent of gender, age, clothing, navigation, intelligence and persona.
- Replaced runtime-tinted traffic artwork with 12 complete static sprites: sedan, wagon and ute bodies in four fixed colours each. Spawn selection is deterministic for a town and the game changes only position/rotation and movement highlights.
- Normalised generated PNG crop bounds around the solid painted vehicle instead of faint transparent glow. Sedans render at 16×34 px, wagons at 16.5×36 px and utes at 17×38 px, preventing inconsistent padding from making some traffic look smaller while preserving real body-class differences.
- Changed recommended camera defaults to **2× on foot** and **1.5× in a car**. Existing explicit per-town values remain unchanged; missing values receive the new defaults.
- Asset generation used the built-in image generator with transparent-background, top-down pixel-art prompts. Focused checks passed: 30 new catalogue PNGs load with genuine transparent padding; old seven-range settings migrate to 30% Light/35% Medium/35% Dark in both Godot and CLI fixtures; Creator GUI save/reload passed; the Node/content suite passed 95 checks; and Kingston launched with 330 agents, 75 women/75 men, 50 NPCs in each age group, three traffic body classes and all 12 static car variants. Actual reviewed gameplay capture: `tools/tests/output/static_actor_catalogue_kingston_normalized.png`. Godot emitted only the existing sandbox log/certificate warnings.

## 2026-09-16 — Independent camera settings and natural NPC faces

- Added a dedicated **Camera view** section to the Creator Studio Game Settings page. Creators can independently set **On-foot character zoom** and **In-car camera zoom** from 0.2× to 3.0×; larger values bring actors and nearby roads closer. Values save per town, reload through the GUI and are also available through `set-settings --character-zoom N --in-car-zoom N`.
- The runtime now treats the two values independently. Entering the wagon applies the in-car value directly rather than multiplying it by the walking zoom; leaving restores the character value. Map overview still uses its own Fit/zoom system. Older town files without the new `camera` group retain 1.0× walking and their existing 0.8× car default until resaved.
- Corrected the reported mask-like NPC faces. The prior rectangular skin-tone overlay covered the source portrait. It is now a pixel-cut face with temples, cheeks, chin, neck, hairline, eyes, nose/mouth and subtle tone-relative shading; creator-selected pigmentation values still control the visible face and hands.
- Follow-up visual review found the first correction was still noticeably simpler than the player. NPC portraits now use the same readability cues as the player: brows, white eyes with pupils, ears, nose, mouth, cheek/jaw depth, neck and hair overlapping the forehead. Inspected replacement capture: `tools/tests/output/npc_face_detailed_kingston.png`.
- Focused verification passed: Creator GUI camera save/reload, 92 CLI/content checks including range rejection, a Kingston play test using 1.65× walking and 1.25× driving zoom, a backward-compatible The Rocks runtime, actor diversity and the existing 330-agent runtime check. `tools/tests/output/npc_face_corrected_kingston.png` is the inspected actual-game capture. Godot emitted only the existing sandbox log/certificate warnings.

## 2026-09-15 — Actor artwork, motion and full-screen view

- Added transparent pixel-art assets in `assets/actors/` for the blue-jacket player, man/woman NPCs, walking NPR, flying NPD, player wagon, and NPC hatchback, sedan, wagon and ute. They are shared by all imported towns and do not alter OSM projection, road navigation or collision dimensions.
- Replaced the runtime's basic actor/car drawings with these sprites. Walking players, NPCs and NPRs bob/lean while moving; waiting walkers stop bobbing. NPR beacons blink, NPD rotors spin and drones hover, and moving wagons/traffic show tyre highlights. Preserved existing primitive drawings as a missing-asset fallback.
- NPCs receive a deterministic 50% man / 50% woman split for even counts (nearest possible for odd counts). Woman NPC artwork has long hair and a subtle adult upper-body shape. Existing shirt, trouser, hair-color and seven creator-selected skin-pigmentation tones remain visual-only and independent of navigation/persona behaviour. No racial identity labels or intelligence associations were introduced.
- NPC traffic now uses four evenly distributed car body styles and five existing randomized paint-color choices. The owned wagon stays white. These styles remain unbranded game depictions, not claims about actual OSM vehicle makes.
- Increased the play-test view from 384×240 to a 640×360 16:9 logical canvas, widened/repositioned its HUD, map controls, centre-coordinate readout and building-popup safe area, and added F11 full-screen/windowed toggle. Creator Studio's separate 1280×800 editor layout is unchanged.
- Focused checks passed in Kingston ACT and The Rocks: 330 runtime agents, 75 women/75 men, 38 hatchbacks, 38 sedans, 37 wagons, 37 utes and five paint choices on each; nine streamed collision chunks. `verify_actor_diversity.gd` checked both odd/even splits, skin-tone independence, body-style balance and genuine transparent PNG alpha. Existing crossing, traffic-flow and Creator UI regressions passed. The graphical Kingston capture exercised actual full-screen mode; `tools/tests/output/actor_art_fullscreen_kingston_v2.png` and `actor_art_crowd_the_rocks_v2.png` show real rendered towns, with the review camera centred on actual agent positions rather than staged actors.
- Limits: image sprites currently use one facing pose with movement transforms, not four-direction frame atlases. NPC age presentation is not assigned yet. Focused startup/render checks are not extended gameplay or performance testing. Godot emitted the previously known sandbox log/certificate warnings without a script failure in passing checks.

## v1.2 development started — 2026-09-13

- Established v1.2 from the clean, published v1.1 repository snapshot without modifying the separate v1.1 release.
- Created a local `v1.2` development branch and updated the Godot project metadata, Creator Studio header, runtime map badge and current-version documentation.
- Stage 1 is a compatibility baseline only. No map-generation, gameplay or content schema behaviour has deliberately changed.
- Focused verification passed: the 72-check CLI/content suite; Creator import/setup/create workflow; OSM navigation; water/bridge/tunnel environment rules; traffic flow; and bridge/tunnel endpoint confinement. An existing Howlong v1.1 project launched through v1.2 with 330 moving road users and six collision chunks.
- Godot emitted sandbox-only log-file and Windows root-certificate warnings during headless checks. Every invoked test returned exit code 0 with no GDScript error. Extended gameplay/performance remains user-tested.

## 2026-09-13 — Stage 2 automatic map-geometry safety

- Added a map-independent spatial audit for road, solid-building and vertical-feature geometry. Ground road segments whose centre line actually enters a solid ground building are excluded from both vehicle and pedestrian navigation. Tangential corner/wall contact is not falsely treated as an interior crossing.
- Retain close but centre-line-clear roads and report their estimated full-width clearance conflicts instead of guessing whether an OSM road width or footprint is wrong. Save detailed conflict records and statistics in `data/navigation_graphs.json`, copy the plain-language warnings into `validation.json`, and summarize exclusions in Creator Studio after Create/Rebuild.
- Separate surface collision and artwork from vertical structures. `building=roof`, bridge-like buildings and positive-minimum-level buildings no longer create ground walls; explicitly underground buildings are also omitted from the surface. Safe-start checks use the same ground-solid classification.
- Explicit bridge/tunnel corridors stay routable. The controlled player and wagon ignore the surface-building layer only while admitted to a crossing corridor, while retaining their mutual collision masks. Ambiguous non-zero-layer roads without an explicit bridge/tunnel are excluded rather than becoming floating traffic routes.
- Kept v1.1 content compatibility by making the new navigation audit block optional in the schema. Rebuilding upgrades a town to Creator v1.2 and writes the new data; the original copied OSM remains unchanged.

### Focused verification

- New synthetic geometry regression passed for ground penetration, tangent handling, close clearance, raised/underground/roof structures, explicit bridge/tunnel routes, ambiguous vertical roads, surface collisions and player/wagon crossing masks.
- The real The Rocks source produced 668 ground-solid buildings, 248 excluded ground pedestrian segments, 658 close-clearance warnings, 50 ambiguous vertical roads and 179 explicit vertical passages. Its vehicle graph required zero road/building exclusions and retained 130 directed bridge plus 117 directed tunnel edges.
- An isolated The Rocks v1.2 rebuild passed content validation and the shared runtime startup/control check with 330 moving road users and nine collision chunks. Navigation, water, Gold Coast, crossing-boundary, Creator UI and 76-check Node/content regressions passed. Headless Godot emitted only the known sandbox log/certificate warnings.
- These are focused correctness and startup checks, not extended city performance or proof that incomplete/mistagged OSM can be repaired automatically. Close-clearance records and excluded ambiguous routes remain review items for the later Advanced Map Editor.

## 2026-09-13 — Stage 3 OSM building and place information

- Added map-independent building descriptions generated solely from tags attached to each imported footprint. Readable fields cover mapped name/use, address including county/country when supplied, operator/brand, levels, opening hours and wheelchair access. A generic `building=yes` truthfully displays **Building type not mapped in OSM** rather than receiving an invented use.
- Play tests now show a compact floating summary when the mouse hovers over a visible building. Clicking pins the fuller details and clicking empty ground closes them. In M map view, dragging still starts on empty ground; a building click selects the footprint. Popups stay between the HUD bars and hide with surface buildings during tunnel/under-bridge isolated views.
- Every quick and pinned popup displays **© OpenStreetMap contributors** plus the source OSM way or relation ID. Imported strings are plain, line-flattened and length-limited. Creator Studio's existing **Inspect** action now uses the same truthful wording and provenance.
- Create/Rebuild writes canonical `data/place_information.json` under a documented schema. The runtime joins it to footprint geometry through stable IDs and uses a spatial grid instead of scanning a whole city on each pointer update. Older projects receive an in-memory fallback and save the file on Rebuild. The Node CLI generates matching data, validates it, summarizes it through `inspect-town` and supports `inspect-building --feature-id` for Codex.

### Focused verification

- Synthetic checks passed for named and unnamed buildings, semantic tags, county/country addresses, flattened imported line breaks, OSM way/relation provenance, overlapping footprints, courtyard holes, underground surface exclusion and hover/pinned wording.
- Godot and Node produced identical The Rocks totals: 731 building/display records including overhead structures, 131 named, 485 specifically classified and 337 addressed. The directly tagged Sydney Opera House resolves as **Arts centre**, OSM relation `9596872`, with OpenStreetMap attribution.
- Creator UI and 87-check Node/content regressions passed. The rebuilt The Rocks project launched with 330 moving road users and nine collision chunks. The actual pinned popup was inspected in `tools/tests/output/building_information_the_rocks_v2.png`; it remained inside the play area with the HUD and source line readable.
- This stage does not assign nearby/contained POIs to a whole building, because one footprint may contain multiple tenants. Creator overrides, multi-tenant place selection, gameplay destinations and custom exterior/interior authoring remain later stages. Extended user interaction/performance remains user-tested.

## v1.1 complete — 2026-09-13

The v1.1 milestone is complete. This release includes the Creator Studio town import/reopen workflow, configurable populations and driving settings, playable town previews, real-world map-centre coordinates, mapped water/land cover, and the final bridge/tunnel corrections below.

- Prevent player cars and walking characters from leaving bridge/tunnel sides; retain safe endpoint entry and exit.
- Show the controlled actor and road against black in tunnels and grey beneath bridges.
- Remove underground road stripes from the surface and restore every bridge span in map overview.
- Focused crossing, rendering and runtime checks passed; the reported map gap was visually checked at its geographic location. Detailed dated results follow.

This closes the v1.1 scope, not the full product roadmap. Advanced editors, the remaining simulation migration, Windows executable export and documented complex crossing/collision limitations remain future work. Extended gameplay/performance testing remains user-led.

## 2026-09-10 — v1.1 Creator Studio foundation

- Created the first **2D Digital World Twin Creator** Godot project at the user-specified v1.1 location without changing the existing v1.3 game.
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

## 2026-09-14 — Metre-scaled roads, parking and footpaths

- Replaced fixed visual road widths with one shared OSM-aware dimension source used by rendering, spawn safety, road/building clearance and bridge/tunnel corridors. Explicit `width`/`est_width` and lane counts take priority; documented class defaults handle sparse maps without an LLM or town-specific rules. The 17×40-pixel wagon now compares against road geometry at the shared 8-pixels-per-metre scale.
- Imported ground-level `amenity=parking` polygons as dedicated surface features. Paved areas receive conservative 2.6-metre bay spacing and 5.2-metre bay-depth guides where geometry permits; grass, gravel and unpaved car parks keep their mapped surface appearance. Underground, rooftop and multi-storey car parks are not painted on the ground.
- Preserved explicit OSM footways and added metre-scaled roadside footpaths from sidewalk tags. When sidewalk data is absent on ordinary urban roads, a documented deterministic default keeps sparse maps usable; `sidewalk=no`, `none` and `separate` are respected.
- Ground-solid building footprints remain authoritative over road, parking and footpath artwork. Parking guides intersecting buildings are omitted, and the renderer's surface lookup masks building interiors. A collision-runtime regression still blocks both the player and car on the exact OSM polygon.
- Corrected the first rendered review after user feedback: OSM ways are now painted in global kerb, asphalt and marking passes so separate ways blend at junctions instead of drawing internal kerbs. Paved parking uses the same asphalt and sits below access roads, removing the mismatched parking entrance seam.

### Focused verification

- Synthetic scale/surface regression and the 87-check Node/content suite passed. Map geometry, Creator UI, exact building collision and 330-agent runtime traffic-flow checks also passed.
- Four independent OSM exports passed without map-specific configuration: Howlong (210 roads, 6 car parks), Gold Coast (1,446 roads, 235 car parks), Sydney Harbour (572 roads, 22 car parks) and Kingston ACT (519 roads, 92 car parks). Generated sidewalk sides and bay guides were bounded and solid-building samples remained masked.
- Isolated Wodonga, Gold Coast and Kingston runtime copies were rebuilt and launched for graphical review; the user's projects and original OSM files were not changed. Actual corrected captures are in `tools/tests/output/stage4_transport_visuals/`.
- These are focused generation, rendering, collision and startup checks. Inferred footpaths and bay guides are stylised defaults rather than surveyed layouts, and extended driving/pedestrian/performance testing remains with the user. Full rules and commands are in `docs/scaled_transport_surfaces.md`.

## 2026-09-15 — Reusable v1.3-style pedestrian crossing safety

- Ported a focused part of v1.3's crossing contract to all generated towns. Walkable OSM ways with explicit crossing tags write `crossing: true` on their directed pedestrian graph edges; the graph and Creator summary record the mapped count. Untagged ordinary streets and crossing point tags alone do not fabricate a road-spanning crossing.
- NPC pedestrians and NPR robots wait for a forecast gap from nearby NPC cars and the occupied player wagon before entering one of these mapped crossing segments. Once a walker commits, a local reservation makes ground NPC traffic yield with artwork-sized clearance until the walker reaches the far side; that legal wait is exempt from jam relocation. Bridge/tunnel traffic stays on a different layer. An eight-second wait tries a non-crossing outgoing OSM route when available; otherwise the walker continues waiting.
- Traffic checks scan committed reservations rather than every pedestrian for every car, avoiding a per-frame multiplication of editable population counts. Older generated towns gain crossing edge metadata through the GUI **Rebuild project** action; original OSM remains unchanged.
- Final regression review exposed a separate short-hop bypass: traffic could finish its last few pixels at an OSM node before checking crossing/signal/junction rules. Endpoint movement now passes through the same safety gate as ordinary movement. A reserved-walker short-hop test passed.

### Focused verification

- Crossing regression passed for an approaching car, occupied wagon, NPR route inheritance, reservation/yield/release, an alternate walk link and a bridge car that must not yield to a surface walker. Existing traffic, navigation, Creator UI and 87 Node/content checks passed.
- Real OSM generation passed with 16 directed mapped crossing edges in Howlong, 106 in Kingston ACT and 1,612 in Gold Coast, without custom map settings or an LLM. Isolated Kingston and Gold Coast test copies regenerated navigation and passed shared runtime startup with 330 agents and nine/six nearby collision chunks. Source files and user projects were preserved.
- This is one gameplay-parity slice, not full v1.3 migration. The preview's procedurally drawn pedestrians still lack physical collision bodies; the player-driven wagon is forecast before a crossing but cannot be forced to brake after a walker commits. Unmapped crossings, venue interiors, population destinations and extended gameplay/performance remain pending. Details: `docs/pedestrian_crossing_parity.md`.

## 2026-09-20 — Reverse, camera-follow and optional player route guidance

- Added Shift to toggle the player's wagon between Drive and Reverse only at or below 2 km/h. A change clears the cruise target; Up/Down set speed within the selected gear, with a creator-editable 20 km/h default reverse maximum. The HUD shows the gear and selected limit. Space and collision/ground safety still stop the wagon.
- Added independent walking/driving camera rotation and soft-guidance controls in Game Settings. Camera rotation follows the current imported road or walking path when identifiable, and the M map stays north-up. The player's held WASD direction is latched while the camera turns, preventing rotation-induced spiralling.
- Soft driving assistance estimates a legal lane using imported road geometry, driving side, one-way direction and bridge/tunnel layer. Soft walking assistance uses pedestrian-route footpaths and roadside fallback corridors. Direct car steering, lateral walking input, reverse gear, route departure and ambiguous/missing geometry suspend correction. Neither assistance changes collision or crossing rules. Existing towns receive missing setting defaults when loaded.
- Focused Godot checks passed for gear-change safety, reverse motion/cap, both driving sides, road/path camera headings, layer separation, manual override, Creator settings save/reload, Albury runtime camera/map, Albury roadside paths, navigation, crossing safety and traffic flow. The 101-check Node/content suite passed. Godot also emitted its known local log/certificate-store warnings during checks; no test assertion failed.
- These checks do not establish perfect lane centring or camera feel across every OSM export or extended gameplay/performance. OSM lane/sidewalk geometry is approximate and ambiguous junctions fall back to manual control. See `docs/player_controls.md` and `docs/route_guidance.md`.

## 2026-09-20 — Withdraw player guidance and camera rotation; retain Reverse

- User testing found that soft guidance moved the walking player to incorrect locations and gameplay performance dropped. Removed the player road/path guidance index, per-frame steering/lookups, rotating camera, camera-relative WASD latching and their Game Settings controls. Walking is again fixed world-aligned WASD; the gameplay camera and M map stay north-up. This supersedes the guidance/camera portion of the preceding entry, not the NPC/NPR footpath and crossing work.
- Retained Shift Drive/Reverse switching, the near-stop safety check, reverse cruise speed and creator-editable reverse maximum. Older experimental setting fields are discarded when a saved town loads; other settings and original OSM data remain intact.
- Focused checks passed: WASD and Shift/reverse control tests; Creator UI save/reload and retirement of experimental keys from an older saved town; crossing-safety regression; real Albury startup with 99 roadside NPC/NPR routes and two safely held blocked routes; the 101-check Node/content suite; and `git diff --check`. Godot emitted its known local certificate-store warning but no script assertion failed. The reported slowdown motivated this rollback; no whole-game performance benchmark or unique root cause was established.

## 2026-09-29 — Local Ollama persona conversations and no-code persona editor

- Replaced the fixed **Hi** choice with a 280-character text box, Send and End controls. T starts a nearby on-foot conversation; Enter/Send asks the local model asynchronously; Escape/End finishes. Only the NPC/NPR has a floating reply bubble, now wrapped and clamped for short multi-line answers.
- Added three default human personas—Friendly Local, Busy Worker and Curious Visitor—which are assigned randomly to NPCs, plus the Civic Robot persona used by NPRs. The canonical `data/personas.json` records the selected model and editable persona fields. Existing towns without the file use the same in-memory defaults; new/rebuilt towns save it.
- Added an enabled **NPCs and personas** Creator Studio page. It detects installed Ollama models and lets a non-technical creator add, edit, save and delete custom NPC or robot personas. Built-in personas can be edited but not deleted. The Codex-friendly `list-personas` CLI reads the same file and never invokes a model.
- Ollama is restricted to `http://127.0.0.1:11434`. The asynchronous adapter receives persona text, the player's message and at most eight current-conversation messages, then returns display text only. It has no game-state references or command/tool interface. Replies are capped at 38 words / 220 characters and conversation memory is not persisted.
- Verification passed: Godot parsed all scripts; Albury's complete runtime passed typed-dialogue UI, pause/camera/bubble and restore checks; the Creator persona page passed four defaults and both custom-persona actions; the 101-check Node/content suite passed; and a real `llama3.2:3b` request returned a natural short reply. The tested cold model load took about a minute, so the first-reply timeout is 90 seconds; later replies should be faster while Ollama keeps the model loaded. This first provider stage supports Ollama only and does not constitute extended gameplay/performance testing.

## 2026-09-29 — Preload the local model at map startup

- User clarified that the loading screen belongs at playable-map startup, not after the first dialogue message. The runtime now holds player/vehicle/population control behind a full-screen local-model panel, sends an empty Ollama generation request for the town's selected model, and opens the map only after the model reports ready.
- The bar uses Godot's indeterminate animation and shows the selected model plus elapsed seconds. Do not invent a percentage: Ollama reports load duration after completion but does not stream an incremental model-loading percentage for this request.
- On failure, keep the user's map safe and show **Retry** and **Continue without conversations**; Escape also continues. Continuing disables typed local dialogue for that map session instead of blocking gameplay. Successful startup keeps the model available for 30 minutes, refreshed by later dialogue requests.
- Reduced the default response-generation ceiling from 48 to 32 tokens to better match short video-game speech and this computer's observed inference speed. The existing 38-word/220-character display cap remains an additional upper bound.
- Verification passed against the installed `llama3.2:3b`: the real startup loader, animated/ready screen states and real short reply completed; the complete Albury runtime handed control to the map after preload; typed-conversation regression and the 101-check Node/content suite passed. Godot's known local log/certificate warnings remain unrelated.
