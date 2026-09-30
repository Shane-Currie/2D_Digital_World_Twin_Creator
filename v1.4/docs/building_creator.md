# Building Creator — first usable stage

The Building Creator lets a non-technical creator add a custom exterior and entrance to an imported building without changing OpenStreetMap or writing Godot code.

## Workflow

1. Open or create a town, then choose **Building Creator**.
2. Click an active building footprint on the map. A footprint hidden in Advanced Map Editor must be restored first.
3. To make new artwork in Microsoft Paint, choose **Export footprint for Paint**, select a save location, then open the exported transparent PNG. Its grey area is the exact editable footprint; transparent areas are outside the building or an open courtyard.
4. Paint over the grey footprint and save the result as PNG. Keep the canvas dimensions unchanged—do not crop or resize it—so it aligns automatically when returned to Creator Studio.
5. Choose **Choose exterior image** and select the painted PNG, or select another PNG, JPG/JPEG or WebP image between 16 and 4,096 pixels per side and no larger than 25 MB.
6. Use **Image scale**, **Rotation**, **Move left/right** and **Move up/down** to align or crop the image inside the footprint. **Reset image alignment** returns to 100%, 0° and centred.
7. Choose **Add another entrance**, then click near the preferred wall. Select any saved entrance to move or remove it. A building may have up to eight entrances.
8. Review the clipped preview and select **Save building design**.

Creator Studio copies the image into the town's `assets/buildings/<stable_building_id>/` folder. The original image is not moved. In both the editor preview and Play test, the image is clipped to the exact effective OSM footprint. Courtyard holes remain open and building collision continues to use the generated footprint geometry.

Footprint templates default to the town's `exports/building_footprints/` folder, although the creator can save elsewhere. The PNG is north-up, uses the footprint's real map proportions, has a longest edge of 2,048 pixels and preserves transparent exterior/courtyard space. It is only a working art template and does not change the town until the creator imports the finished image. A deterministic command equivalent is available at `tools/export_building_footprint.gd` for Codex and focused checks.

Each requested door snaps to the nearest footprint edge. Creator Studio searches outward from that wall and only accepts an entry-arrow position that is within the map and outside buildings, fixed footprints and mapped/creator-authored water. It saves a nearby pedestrian graph node when one is within 250 metres. Moving an entrance preserves its stable entrance ID and repeats all clearance/link checks. This link is preparation for interior and destination routing; it does not claim that OSM mapped the door.

## Stored data

`data/building_exteriors.json` is the canonical stable-ID override file. Imported files use content-hashed names so rebuilding the town cannot silently substitute a different image. Image alignment and an array of stable entrance IDs are stored with the footprint. Older single-door records migrate automatically to `entrance_1`. `schemas/building_exteriors.schema.json` documents the data contract. Create and Rebuild preserve existing designs; they create an empty file only for an older project that does not have one.

## Current limits

- One exterior image fills one footprint bounding box and is clipped at its edges. Numeric scale/rotation/offset controls are available, but there are no direct drag handles, perspective warp, per-wall facade layers or tiling controls yet.
- A door and green approach arrow render in the game. Once Interior Designer links that stable entrance to a ground-floor arrival point, the player can stand at the exterior arrow and press **E** to enter.
- Up to eight entrances are supported per building. Entrance names, lock/access rules and interior destinations belong to the Interior Designer stage.
- The editor validates image type, file size and dimensions. PNG/WebP alpha is preserved; JPG has no transparency.
- Direct template alignment assumes Microsoft Paint retains the exported canvas dimensions. Cropping or resizing is still recoverable with the scale/rotation/offset controls, but it no longer guarantees one-step alignment.
- Door clearance uses available mapped geometry. Missing or inaccurate source obstacles remain a map-data/editor-review limitation.

Focused checks cover real-proportion transparent PNG export including concave exteriors/courtyard holes, copied assets, stable paths, aligned/clipped editor and runtime UV mapping, multiple snapped entrances, move/remove, pedestrian-node linking, legacy migration, save/reload and the full GUI workflow. Door clearance uses local-metre geometry to avoid longitude precision failures on Australian and other high-longitude maps. Extended visual review across user artwork and large uploaded cities remains user testing.
