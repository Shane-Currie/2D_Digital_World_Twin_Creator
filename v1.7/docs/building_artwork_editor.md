# Roof and facade artwork editing

Current UI update (2026-10-07): **Align artwork** contains preview alignment;
**Upload artwork**, **Export footprint**, **Building style**, **Doors** and
**Entry link** are separate tiles. Top actions are **Undo / Cancel / Save**.
The rendering/data workflow below is unchanged. See [Editor tools](editor_usability.md).

Open a saved town in **Building Creator** and click a footprint or load a saved
building. Choose the **Artwork** tool button, then **Roof**, **Default walls**,
**Front** or **Left**. The floppy-disk Save remains at the top. **Back** returns
to the tool buttons and full-height town map without discarding pending edits.

- **Left-drag the live artwork preview** to align the selected texture.
- **Right-drag** rotates it; a right-click turns it 15 degrees.
- **Wheel over this preview** changes texture size. **View −/Fit/+** controls the
  preview without changing texture size. The town map is a separate workspace,
  not a second preview stacked below the artwork.
- Fine numeric rotation and offsets remain available. **Reset image alignment**
  resets only alignment; **Use default for this surface** removes that surface's
  custom artwork/material/alignment reference while retaining other surfaces,
  floors, names and doors. Copied images remain on disk for recovery/reimport.
- Wall choices include preview images for brick, concrete and glass, or upload
  a PNG/JPEG/WebP for the selected surface. Roof uploads use the existing full
  footprint artwork workflow. Use clean wall tiles without painted doors;
  usable doors and their blank window bays are composed separately.
- Click **Save building design**, then reopen Play test to use saved changes.

**Front** and **Left** mean camera-facing facade groups, not street names or
individual surveyed wall segments. Irregular buildings can have several edges
in a group; this stage does not edit each edge independently or create windows,
doors, interiors or extra floors from uploaded pixels.

The live preview uses the production renderer on the selected footprint only.
Selecting a facade frames its visible wall surfaces so a long building does not
leave an unusably tiny wall preview. It deliberately omits neighbours/traffic;
use Play test for actual placement, attached-wall occlusion and road clearance.
Roof view shows the whole building. Existing authored roof rotations are retained
until the creator changes/resets them, including Albury Pub's saved −55 degrees.

## Click-and-drag entrances

1. Choose **Entrances**. Select an entrance in the list, or **Add another
   entrance** and click/drag near an outside wall on the town map.
2. Existing numbered door pictures on the map are draggable. Empty-space
   dragging still pans. Alternatively choose **Facade / drag doorway artwork**:
   click a visible wall to add a doorway or drag an existing numbered door.
   Front/Left/All sides and View −/Fit/+ help reach it. Wheel zooms the doorway
   view; it does **not** edit roof/wall texture size in this mode.
3. Choose **Link / drag interior arrival** and click/drag a clear point inside
   the ground floor. Drag its green/blue selected marker to reposition it.
   If there is no interior, explicitly **Create blank ground floor** first;
   existing furnished floors are never recreated by this action.
4. **Save building design** saves exterior metadata and staged interior links.
   Reopen Play test, approach the linked doorway and press **E** to enter.

The list shows whether each doorway is linked to Ground floor. A pedestrian
path association is not an interior link. Outside moves retain the stable
entrance ID and its independent indoor arrival. Intentional removal also
removes that doorway's entry links, preventing legacy repair from attaching
them to a different door. No new schema or scripts in content packs are needed.

Door artwork is the existing shared detailed entry asset, fitted to the actual
wall by the production renderer. Moving it moves the real saved doorway/green
approach anchor, not just a decorative image. It cannot be pasted over a roof.
The facade preview omits neighbours, but accepted exterior placement checks the
effective town features/bounds for a clear approach. Blocked drops show a red X
and leave the previous door/arrival intact, without placement-error popups.
Only camera-facing walls have visible facade artwork; use the map for rear
entrances. Interior links currently enter the ground floor, not upper floors.

Focused check: `tools/tests/verify_building_door_editor.gd`. It verifies two
window sizes, mouse placement/drags, stable IDs, safe rejection, temporary-file
save/reload and runtime playable-entry recognition. Albury screenshots are
read-only; the saved pub retains its existing roof artwork/alignment. This is
not an extended gameplay/performance result.

## Data and inheritance

Optional fields in `data/building_exteriors.json`, keyed by existing stable IDs:

```json
{
  "feature_id": "way/123",
  "roof_alignment": {"rotation_degrees": 15},
  "wall_alignment": {"scale_percent": 125},
  "wall_material": "concrete",
  "facades": {
    "front": {
      "material": "glass",
      "alignment": {"scale_percent": 150, "offset_x_percent": 10}
    },
    "left": {"material": "brick"}
  }
}
```

Existing uploaded roofs retain alignment in their legacy `exterior` object;
`roof_alignment` applies to generic roofs. Default wall alignment/material/upload
applies to both groups unless that group overrides it. A group alignment is a
complete transform; absent values use 100% scale/zero rotation/offset. Removing
the group override restores inheritance. Choosing a built-in material replaces
that surface's image reference; uploading an image overrides its material.

Texture scale is 50–300%, rotation −180–180 degrees and offsets −100–100%.
Wall offsets use repeating texture-tile UV units; roof offsets use the whole
roof image frame. Generic materials wrap; uploaded roof canvases remain clamped.
Wall uploads share the existing copied building-asset path/format/25 MB/16–4096
pixel limits. Save refuses missing facade images; invalid metadata is preserved
and reported rather than silently rewritten. No source OSM, collision, entrance
coordinates or furnished interiors are resized by texture edits.

`node tools/creator-cli.js validate-town --town "TOWN_DIRECTORY" --json` checks
the new fields alongside existing metadata; schema references are in
`schemas/building_exteriors.schema.json`. Creator/runtime use
`scripts/buildings/building_artwork_settings.gd` for the same inheritance/UVs.

## Focused checks

`tools/tests/verify_building_artwork_editor.gd` checks optional/legacy fields,
independent materials/alignment, inheritance, copied images, save/reload,
unsafe/missing/malformed rejection and actual Albury mouse controls without saving
that town. Dragging uses the real surface UV basis; cached geometry/textures stay
unchanged during UV-only edits. This avoids re-decoding images or rebuilding a
town for each mouse event, but is not a full-game FPS benchmark.

`-- --render` captures `building_artwork_editor_albury.png` and the separately
labelled synthetic `building_artwork_facades_demo.png` under `docs/screenshots/`.
The capture instance removes its warning popup; production warnings remain.
Existing building-height/clearance, exterior persistence, Creator UI and Node
foundation/extra facade-validation checks are the regressions for this stage.
