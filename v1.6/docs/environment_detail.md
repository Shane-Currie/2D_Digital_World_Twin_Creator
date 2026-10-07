# Environment artwork and town tree choices

Open a saved town, then in **Advanced map editor → Trees**, select Mapped / mixed,
Broadleaf, Gum tree (eucalypt), Conifer, or upload a named transparent PNG.
Selections/uploads save immediately. Reopen Play test to apply changes.
Albury's saved test project now selects gum trees; other towns retain mapped/mixed.

Custom PNGs are copied into `assets/environment/trees/<sha256>.png` in the selected
town, never moved. Maximum 2048 pixels per side, 8 MB, 32 custom entries per town.
Invalid, empty, fully opaque or damaged images are rejected with inline feedback.
Transparent padding is trimmed for display; aspect ratio is retained inside the
same safe tree envelope. Missing/changed copies warn and fall back to mapped art.
Re-upload from the source to repair a damaged copy. Old uploads remain recoverable.

Optional `data/environment_settings.json` stores the selected style and catalogue;
see `schemas/environment_settings.schema.json`. A corrupt metadata file is
preserved, not silently replaced. CLI inspection/selection/validation:

```
node tools/creator-cli.js get-tree-settings --town "TOWN_DIRECTORY" --json
node tools/creator-cli.js set-tree-style --town "TOWN_DIRECTORY" --style eucalypt --json
node tools/creator-cli.js validate-town --town "TOWN_DIRECTORY" --json
```

## Placement and detail

- Individual ground-level OSM `natural=tree` nodes and `natural=tree_row` ways
  are now retained by both importers. Rebuild older saved projects from their
  original copied OSM to add individually mapped tree positions. Existing wood,
  grass and water effects work without this tree-data rebuild.
- Default tree size is illustrative. Valid `diameter_crown` metres replaces the
  fallback, bounded to 2–14 m. `leaf_type=needleleaved` selects conifer artwork in
  mapped mode. The town choice overrides artwork, not source tags/species facts.
  OSM references: [trees](https://wiki.openstreetmap.org/wiki/Tag:natural%3Dtree),
  [crown diameter](https://wiki.openstreetmap.org/wiki/Key:diameter_crown).
- Whole crowns/shadows/wind margins must stay clear of buildings, roads,
  sidewalks, parking, water and map edges. Obstructing mapped trees are omitted,
  not moved. Tree nodes duplicated by a row are deduplicated at the same position.
- Deterministic decorative trees fill mapped **woodland** at roughly 9 m grid
  spacing, and mapped **grass** much more sparsely at roughly 24 m. Whole artwork
  stays inside the respective usable cover. Known pitches, tracks and playgrounds
  are excluded so grass sports surfaces do not become forests. Parks alone still
  do not imply trees.
- Clear grassy roadside verges also get sparse trees (24 m sampling / 18 m local
  separation) along ground-level streets, never bridge/tunnel approaches. Where
  OSM omits grass tags, these use the game's grass fallback only near roads,
  not across all untagged land. Tagged paving, other cover and mapped obstacles
  remain protected. These are explicitly game decorations, not surveyed tree
  positions; a tree appears only where its full crown/shadow/wind envelope fits.
  This is how Dean Street gains sparse trees without town-specific logic.
- Grass uses multiscale patches, fine grain and blade highlights. Untagged ground
  remains a stylised grass fallback, not a geographic land-cover assertion. Hard
  paving/sand/rock retain their original categories/colours.
- Water keeps existing polygons, island holes and collision rules. GPU ripples,
  glints and shoreline highlights are visual effects, not water-boundary repair.
  Bridge/tunnel passability remains governed by existing validated corridors.
- Wind/water animate in independent GPU materials; camera detail uses bounded
  tree cell caches (96) and a 1,400-visible-tree cap. Wide/overview views omit fine
  trees and reduce fine surface effects. Environment layers hide in tunnel views.
  Tree trunk collisions are enabled as described below. No extended gameplay/FPS
  claim is made.

## Solid trunks

All accepted mapped, row, woodland, grass and roadside trees share circular ground
trunks. Built-in or custom artwork choices do not disable collision. The radius
is an illustrative 0.18–0.45 m, based on the display crown size, not surveyed OSM
trunk data. Leaves/shadows/wind remain non-solid; uploaded tree artwork should
use a bottom-centred trunk to match the existing ground anchor.

The walking player slides around trunks; the car stops on contact and clears its
cruise target. Swept physics prevents passing through a narrow trunk at speed.
NPC/NPR detours and displaced-agent impact checks use the same trunk geometry.
Ground trees do not collide with actors on separate bridge/tunnel levels or in
interior spaces. Existing water boundaries, road/building collision waivers and
damage rules are unchanged; tree destruction/damage is not introduced.

Physics uses a dedicated layer, independent of drawing/overview limits. Nearby
bodies are streamed in a one-cell buffer around both player and owned car, so map
panning/hiding effects never unload nearby solid trunks. Remote NPC queries use
the same bounded deterministic placement cache without city-wide physics bodies.
Trees are omitted where their artwork would cover the saved player/car starts;
no starts or OSM coordinates are moved. Reopen Play test to apply the update.

## Focused verification

`verify_tree_settings.gd` / `.js` cover safe uploads, saved gum/custom choices,
path/format rejection, unchanged placements, Creator preview and Back persistence.
The tree controls now live only in the Advanced Map Editor's existing tool hub;
selection/uploads still save immediately. No game-settings tree tile remains.
`verify_environment_detail.gd -- --render` captures original Albury data with
production player scale and checks clearance, streaming determinism, overview
detail, water and tree motion, and tunnel visibility. Existing environmental-water
and Creator UI/lore regressions remain the compatibility checks.
The grass/bushland fixture compares equal-area plots, excludes a grass playing
field, and verifies stable cache regeneration. The actual Albury check covers
Dean Street's clear verges. One-point OSM trees survive saved-project reopening;
the loader no longer drops them under its old two-point-way minimum.

`verify_tree_collisions.gd` checks player/swept car contacts, driving stop/cruise,
canopy clearance, NPC detours/impact sweeps, style/custom-art independence,
overview/panning, body reuse/unloading/revisiting and interior/grade separation.
It audits an actual Albury Dean Street window read-only. Optional `-- --render`
captures a production car stopped at a trunk near the Dean/Young Street area,
with mapped building-footprint clearance checked.

The initial rounded gum art was rejected by the user. The replacement is original
SVG artwork with exposed pale branching bark, an open canopy and hanging narrow
leaves, based on the supplied visual reference's structural traits. It is stylised,
not an exact botanical species identification or copied reference illustration.
