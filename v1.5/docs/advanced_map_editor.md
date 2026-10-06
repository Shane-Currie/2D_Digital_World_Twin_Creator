# Advanced Map Editor — first usable stage

The Advanced Map Editor is an optional no-code correction layer for a saved town. It does not edit the original `.osm` file or the copy under `source_osm/`.

Open a town project, choose **Advanced map editor**, then use these first-stage tools:

- **Hover for OSM details**: move the mouse over a building footprint. A floating card shows only details attached directly to that footprint, including the building/business name, mapped use, street address, levels/floors, height, operator/brand, opening hours, wheelchair access, phone and website when those tags are present. It always identifies OpenStreetMap and the source way/relation. Missing information is omitted rather than guessed.
- **Select building**: click an imported footprint, then hide an incorrect footprint or restore a previously hidden one. Hidden footprints remain visible in red while editing so they can always be selected again.
- **Draw blocked water**: drag a blue rectangle over missing water. It becomes impassable to the player, owned vehicle, traffic, NPCs and NPRs. Aerial NPDs remain able to fly over it.
- **Draw passable ground**: drag a green rectangle wholly within water that OSM mapped incorrectly. It creates a dry hole in that water polygon; it does not erase a building.
- **Remove newest water correction**: removes the latest saved or newly drawn water zone. Repeat it to step backwards through older zones.
- **Undo/Redo**: reverses edits made since the editor page was opened.
- **Select location and copy coordinates**: click an outdoor map point to show a magenta crosshair and copy `latitude, longitude` to the Windows clipboard. Paste this value into **NPCs and personas → Outdoor storyline NPCs**. The placement tool performs its own ground/building/water validation before saving.
- **Save corrections and rebuild**: saves the correction data and regenerates collisions, pathfinding, place information and NPC/NPR destinations.

Corrections are stored in `data/map_overrides.json` using stable source feature IDs and creator zone IDs. A source fingerprint identifies the OSM feature set that was active when they were saved. Rebuild rereads the original OSM, reapplies matching corrections and reports feature IDs that no longer exist instead of silently applying them elsewhere.

The raw imported geometry remains in `data/map_features.json`. Generated runtime files use an effective in-memory view with the saved corrections applied. This separation makes a correction reversible and preserves source attribution.

## Current limits

This is the first editor slice, not the completed editor. Water corrections are axis-aligned rectangles; arbitrary polygon reshape, direct zone selection/edit handles, feature/layer filters, custom non-water collision zones and per-actor collision choices are later work. Zones can currently be removed newest-first. The current ground-zone policy intentionally applies to all ground actors together; NPDs remain aerial. A passable-ground zone must be centred on an existing mapped water polygon or it is flagged as having no gameplay effect.

Hover lookup uses a map-independent spatial index so pointer movement does not rescan every footprint in a large town. The editor corrects known mistakes selected by a creator. It does not make absent or ambiguous geographic evidence automatically true, and it does not use an LLM.
