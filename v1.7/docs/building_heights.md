# Building heights and raised-roof perspective

v1.6 Stage 1 adds visual height to imported building footprints. It works from the map data without an LLM and does not replace the ground footprint with a rectangle.

## Quick setup

1. Open your saved town in Creator Studio v1.6.
2. Open **Advanced map editor → Set building heights**.
3. Enter **Total floors (ground floor included)** and choose **Apply floors — click buildings**.
4. Click each building you want to change. Dragging pans instead of applying heights. Wheel and visible zoom buttons work as before.
5. Use **Review → Undo/Redo** if needed. **Restore OSM/default** removes only the height override; click the buildings to restore.
6. Click the always-visible floppy-disk **Save corrections and rebuild**, then **Play test project**. Unsaved map-editor height edits are not used by the game.

For an individual building, use **Building Creator**, select its footprint or saved-design dropdown, set **Total floors**, and choose a design. Options include Brick, Rendered concrete, Shopfront, Glass office and Industrial; Automatic retains the existing generated classification. Upload roof artwork through the existing exterior-image button, or **Upload wall artwork** for a repeating one-floor wall strip. Save with the top floppy-disk button. The editor preview remains a flat footprint; Play test shows raised roofs and floor walls.

## Automatic counts and provenance

Priority is creator `total_floors`, then a usable OSM `building:levels`, then one floor. This stage supports positive whole counts from 1 through 200. Malformed, ambiguous, zero or out-of-range source counts receive a review message instead of silent coercion. Hover cards distinguish rendered count/source from raw OSM information.

Ground floor is included. `height` is a different field measured in metres, and `roof:levels` is separate; neither is converted into extra floors. See the [OSM building:levels documentation](https://wiki.openstreetmap.org/wiki/Key:building:levels). Missing data does not prove a building is really single-storey: one floor is the game's explicit fallback.

## Artwork and saved files

Original generic materials live in `assets/buildings/styles/` in v1.6. Imported PNG/JPEG/WebP images are copied into the town's `assets/buildings/<safe_feature_id>/` folder; source files are not moved. Images must be 16–4096 pixels on each edge and at most 25 MB. Roof/default-wall/front/left texture alignment, sizing, materials and uploads now have a live preview; see [Building artwork editor](building_artwork_editor.md). A wall image repeats along its facade; doors retain their separate saved position and artwork. Editing each individual polygon edge is not implemented.

`data/building_exteriors.json` stores optional `total_floors`, `building_style` and `wall` alongside existing `exterior`, `custom_name` and `doors`. Stable OSM IDs remain unchanged. Example metadata:

```json
{
  "feature_id": "way/123",
  "total_floors": 4,
  "building_style": "brick"
}
```

Codex can edit this documented file and run `node tools/creator-cli.js validate-town --town "TOWN_DIRECTORY" --json`. Godot uses the same validation limits. Height edits are not baked into imported OSM or generated collision shapes.

## Current scope

- Gameplay uses a compact **fitted-solid raised-roof perspective**. The visual base and roof are matching transformed OSM outlines; every corresponding corner rises by the same fixed vector, so roof/base edges are parallel rather than independently squeezed. Fit the visible prism inside the original footprint and retain a low ground foundation. Only camera-facing front/left facades show. Roof artwork uses its own projected UV frame; roofs, facades and door art remain disjoint. Source ground geometry/collisions remain unchanged.
- Full counts up to 200 are saved, but exterior visual height is capped at **10 floors**. Window rows adapt to available facade depth instead of squeezing every floor into a small wall. Narrow/concave buildings get further bounded projection; original courtyard holes remain open. Concave clipping, shared-wall fills and foundation connectors can change the visible pieces: this is illustrative 2.5D, not a literal full-footprint, metre-height 3D extrusion or a dynamically camera-relative renderer.
- Collision, road clearance, door locations, navigation and interiors remain on their existing ground geometry. Map overview stays flat for accurate footprint selection.
- Roof holes remain open. Separate tiered `building:part` heights, camera-dependent perspective and actor occlusion fading are not implemented. Actors retain their existing foreground drawing order for visibility.
- Exterior floor counts never create/delete furnished interior floors; the interior editor retains its independent 20-floor limit.
- Saved exterior doors have detailed frame, glass, panels, hinges, handle and threshold artwork. Door size now derives directly from the shared player artwork box: target height 115% of the character draw height, width half the door height. Tiny footprints/insufficient wall space reduce it further; artwork is confined to the wall and cannot cover the projected roof. This supersedes the rejected arbitrary artwork-percentage sizes. Green arrows remain compact and do not cover the door. Saved interaction coordinates/collisions and uploaded roof alignment remain unchanged.
- When buildings touch along the camera-facing left side, hide the shared side if the neighbour is the same height or taller. For a lower neighbour, show only the upper exposed portion. Compare effective OSM/default/creator floor counts, including counts beyond the exterior cap. Split partially shared sides into contact sections; real gaps remain visible. This is a fixed-view height-based occlusion approximation, not full 3D occlusion or tiered building-part support.
- Hidden side corners that meet a visible front continue that front's texture rows to the shared boundary, rather than leaving a roof-coloured triangle. The connector is removed from the hidden roof fill; actual projected roof, ground boundaries and roof/facade separation remain intact.
- The solid-building projection stage is implemented in `building_height_geometry.gd`: raw prism corners now share a consistent rise vector. Rotated shared corners include the low foundation reveal in their facade connector. A small boundary rounding guard and cached triangle drawing avoid large-world-coordinate clipping slivers. True 3D meshes, tiered parts, camera parallax and full occlusion remain later work.
- Generated tree placement now protects saved and automatically resolved doorway approaches. A clear generated entrance must not become obstructed when decorative verge trees are cached afterward; source tree positions are never relocated to compensate.
- Focused tests and Albury screenshots are not a guarantee of arbitrary-size city performance or real facade accuracy. The user handles extended play/performance testing.

## Verified pictures

- `screenshots/building_solid_geometry_albury.png`: current actual Albury fitted-solid stage, with the saved 20-floor building and production actors.
- `screenshots/building_solid_geometry_pub_door.png`: current saved pub entrance and player scale, without the editor warning dialog.
- `screenshots/building_solid_geometry_join.png`: current attached-building join fixture. These filenames are separate from older captures to prevent stale previews; the screenshot harness removes the popup only in its read-only capture instance, not in production.
- `screenshots/building_height_editor.png`: actual Creator Studio with Albury loaded.
- `screenshots/building_height_albury.png`: actual Albury renderer with the saved 20-floor building `601183203` and production character/vehicle sizes. This is a scale/placement check, not a running population/LLM session.
- `screenshots/building_height_visuals.png`: actual renderer on a synthetic 1/4/20-floor test fixture with nearby roads and neighbours. It is not a surveyed town scene or concept art.
- `screenshots/building_exterior_door.png`: the actual saved pub entrance beside the production player character.
- `screenshots/building_shared_walls.png`: actual renderer on labelled equal-height, lower-neighbour and separated-building fixtures; not a real town.
- `screenshots/building_shared_wall_join.png`: close engine-rendered equal-height fixture checking the formerly grey front seam; not a real town.

Reproduce with Godot: `--path "V1.6_DIRECTORY" --script res://tools/tests/verify_building_heights.gd -- --render`. The check does not save changes to the user's town.
