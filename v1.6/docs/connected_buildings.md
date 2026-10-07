# Connecting neighbouring interiors

Current UI update (2026-10-07): this tile is named **Next-door link**. Neighbour
labels begin with stable building IDs, including Albury **601183201**; the
ground-floor creation action is shown only when needed. Top Undo/Cancel/Save and
the full-height map are shared with other tools. See [Editor tools](editor_usability.md).

Open **Interior Designer → Connecting doors** after selecting a building and floor.

1. Choose a neighbour. Only imported footprints sharing a wall are offered: no gaps, roads between them, or corner-only contact.
2. If needed, choose **Create neighbour's ground floor**. This creates a blank interior without replacing an existing one. For upstairs connections, create the matching level in both buildings first.
3. Select **Place connecting door**, then click the shared wall. Both door sides and their indoor arrival points are created together.
4. Drag either wall marker or its green arrival circle to move the pair along that wall. Invalid drops show a red X/inline explanation and leave the saved position unchanged. Esc/Back/building/floor changes cancel placement.
5. Select a door to lock/unlock or remove both sides. Green means unlocked; red means locked. Use the always-visible top Save before Play test.

In play, walk near the indoor marker and press **E**. The player transfers directly into the neighbouring interior, never outdoors. E also returns through the same door. The active building name, floor, NPC/NPR/trader selection and location conversation context follow the destination. Each building keeps its own furniture, floor IDs and outside entrance. A building without an outside entrance has no invented exit: return through its connecting door. Upstairs doors are not outside exits.

## Data and checks

Optional town-level `building_connections` in `data/building_interiors.json` stores one stable ID and geographic shared-wall anchor, a lock state, and `from`/`to` endpoints. Each endpoint records building/floor IDs, wall-local metres, inward normal and an arrival one metre inside. Older files without this field remain valid. Floor resizing changes only that floor's local anchor and recomputes its fixed arrival inset; it does not change OSM geography or the other building.

GUI and runtime use `scripts/interiors/connections/building_connections.gd`; `tools/interiors/validate-building-connections.js` is the command-line companion used by `validate-town`. Effective map corrections are respected: hiding/removing a referenced building prevents saving/playing a broken link. Structural store validation is complemented by mapped-geometry validation on GUI Save and runtime startup. Geographic adjacency uses double-precision scalar coordinates before local projection; its 1 mm tolerance is numerical precision, not a gap-bridging option. Shared contact must provide at least 1.8 m of wall, with doors kept away from its ends.

Both arrival envelopes must avoid courtyards, walls, full furniture artwork, stairs, outside arrivals, other doors and authored NPCs. Later edits also protect these arrivals. Current destination actors and actual player collision size are checked before travel; failed transfers leave the current occupied floor/building/player state unchanged. Interaction requires a clear indoor path to the marker; a previously revealed door cannot be used through an internal wall.

New imports retain optional high-precision building `precise_points` in the map index, without changing existing rendered/collision vectors. Older projects recover this precision automatically from retained `source_osm` XML using stable node IDs; no LLM, online service or town-specific code is needed. If required source nodes are unavailable, unverified footprints are not offered for connection. Play test checks saved links before opening the game, as well as at runtime startup.

Focused checks: `tools/tests/verify_building_connections.gd` exercises geometry, editing, creation, dragging, locks, resize/save/reload, real E handling, destination occupants, conversation guard, room-discovery return and separate exterior bookkeeping. Add `-- --render` to capture labelled production-layer/actor fixtures. `verify_building_connections.js` accepts the emitted `connection_fixture.json` and checks Godot/Node agreement plus CLI rejection of gaps and hidden buildings. Actual Albury Pub 601183200 and neighbour 601183201 were checked read-only with an in-memory door: the furnished pub and saved-file hash remain unchanged.

Current limits: same-level paired E transfers, not a merged/seamlessly visible interior. No automatic NPC travel through these doors, animated door opening, cross-level bridge, or global accessibility guarantee. Creators can lock the sole route to an interior; route/accessibility warnings remain future work. Progress images are focused synthetic play fixtures, not a saved alteration to Albury. Extended gameplay/FPS testing remains with the user.
