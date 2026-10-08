# Stairs and playable upper floors

Current UI update (2026-10-07): floor creation and sizing use separate **Add floor**
and **Floor size** tiles. Stairs support held right-mouse drag/angle rotation and optional
automatic matching placement on an existing floor above/below. A blocked matching
point stays pending for manual placement or Cancel. Top actions are **Undo / Cancel /
Save**. NPC/interior multi-file failures now restore previous owned metadata; this
supersedes the older partial-save description below. See [Editor tools](editor_usability.md).

## Creator workflow

1. Open **Interior Designer** and choose the building. Keep its existing ground-floor exterior entrance link.
2. Open **Stairs** and choose an existing destination or **New upper floor (create automatically)**. The new-floor option copies the footprint shape, not furniture, walls, textures or entrances. The separate **Floors → Add upper floor** control remains available.
3. Select **Place paired stairs**. Click a clear point on the current floor; the preview switches to the destination. Click its matching point there. Completing a new-floor pair creates that playable floor and raises the building's exterior count if necessary. It never lowers an already taller OSM/creator exterior.
4. Drag either stair platform with the left mouse button to move that endpoint independently. **Hold the right mouse button and drag left/right to rotate** with a live angle preview (one degree per horizontal pixel). Release applies one undoable edit; a blocked red-X angle leaves the original unchanged. A quick right-click still turns 90°. The same held gesture works before placement. Cancel/Esc/tool/floor changes abandon an unfinished rotation; only the selected floor's endpoint rotates. Select a pair in the list to remove both endpoints. **Cancel placement**, **Esc**, Back, or a manual building/floor change discards unfinished placement; a half-pair is never saved.
5. Use the always-visible **Save interior layout** button and reopen Play test. It saves both the completed new floor/stairs and exterior count, merging into the latest exterior design without replacing its artwork, name or entrances. Cancel, Esc, Back, a manual building/floor change, or Save during unfinished placement discards its temporary new floor. If the exterior write fails after saving the interior, the UI explains the partial save and retains the height update for retry.

Editable interiors remain limited to 20 floors; exterior artwork remains visually capped at 10 even when the saved count is higher. Merely setting an exterior height still does not create or overwrite playable interiors. Removing stairs does not delete their floors or shrink the building.

New floors copy the width, height, resize scale, boundary and courtyard holes of the level directly below, not always the ground floor. They remain blank: no copied furniture, walls, room names, paint or entrances. Existing floors are not automatically resized or overwritten.

Wheel/−/Reset/+ zoom and empty-floor dragging work as before. Invalid placements show a red X and inline guidance, leaving the original endpoint intact. Both endpoints must fit the floor and avoid courtyard holes, internal walls (including their door openings), furniture, exterior arrival points, other stairs and authored NPCs. Furniture/wall/NPC placement must also leave existing stairs clear. Each passable 1.4 × 2.4 m platform now reserves a 1.6 × 2.6 m envelope: a 10 cm artwork gap per side rather than the earlier 65 cm margin. The central arrival still leaves room for the player; runtime validates the actual player's clearance. These are illustrative game dimensions, not surveyed stair specifications.

## Play

Walk to the stairs and press **E**. The HUD names the destination; the arrow points up or down. Standing/walking on the platform alone does not change floors. The destination uses its own collision geometry, floor textures, furniture, room fog and NPC/NPR/trader placements. Upstairs characters support the existing T conversation system.

Stairs never turn the upstairs landing into an exterior exit. Descend to the ground floor and return to its original green exit marker to leave at the same exterior position. Discovered rooms are retained across floor changes and building revisits for this running game session; discovery is not saved between launches. Unseen stair platforms remain hidden by room fog. Stairs cannot be activated through internal walls or during a conversation. Blocked/occupied destinations leave the player and current floor unchanged; do not force a teleport into an NPC.

## Canonical data and focused checks

Optional `buildings[feature_id].stairs` lives in `data/building_interiors.json`:

```json
{"id":"stairs_1","from":{"floor_id":"ground_floor","x_metres":6,"y_metres":9},"to":{"floor_id":"floor_1","x_metres":6,"y_metres":9}}
```

Stable IDs belong to the building, not a floor array index. At most 40 pairs connect distinct existing floors; endpoints use local metres. Resizing one floor scales only its endpoints and rejects unsafe results. Old interiors without `stairs` remain valid; no content migration or LLM is required. Godot storage/schema and the Node `validate-town` companion validate pairs and landing geometry.

Run `tools/tests/verify_interior_stairs.gd` in Godot for store, UI gesture and real E-handler checks, and `node tools/tests/verify_interior_stairs.js` for CLI validation. `-- --render` adds read-only Albury Pub captures under `docs/screenshots/interior_stairs_albury_*.png`: stair pairs/upper-floor demo edits exist only in memory, with saved-file hash checking. Play pictures use actual pub geometry and the production floor/character renderer with a labelled test overlay, not a claim that the saved pub has already been furnished upstairs.

This stage uses E-triggered floor transfers, not animated stair climbing, lifts or autonomous NPC travel between floors. Existing rooms can intentionally be locked; creators still need to connect rooms/doors so players can reach their stairs. General floor-route reachability analysis and extended gameplay/FPS testing remain later work.
