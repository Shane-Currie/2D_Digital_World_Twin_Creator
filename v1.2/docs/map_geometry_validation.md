# Automatic map-geometry safety

Creator Studio v1.2 checks every imported map for conflicts between roads, solid buildings and vertically separated features. The check is deterministic: it uses the uploaded OSM geometry and tags, with no LLM, town-specific coordinates or manual coding.

## What the builder does

- Ordinary ground-level buildings become solid surface collision in their actual OSM footprint shape.
- `building=roof`, bridge-like buildings and buildings with a positive minimum level are treated as overhead structures, not ground walls.
- Buildings explicitly tagged below ground are omitted from the surface collision and surface artwork.
- A ground road segment whose centre line passes through a solid ground building is removed from both generated vehicle and pedestrian paths. The source road and building are preserved unchanged for later review.
- A road that comes close enough for its estimated full width to touch a building, while its centre line remains clear, stays routable and is recorded as a clearance warning. Creator Studio does not guess whether the OSM width or footprint is wrong.
- Explicit OSM bridges and tunnels keep their separate route layer. While the controlled player or wagon is inside a valid crossing corridor, its collision mask ignores surface buildings but continues to collide with the other controlled actor.
- A non-zero `layer` or `location` value without an explicit bridge or tunnel is not enough evidence to create a floating or underground route. Such roads are excluded and reported.

The spatial check uses a local map grid, so it does not compare every road to every building. This keeps the same rules practical on ordinary town and city exports.

## Where results are saved

After **Create town project** or **Rebuild project**:

- `data/navigation_graphs.json` contains the detailed geometry-validation statistics, excluded segment records and close-clearance records.
- `validation.json` contains the same plain-language warnings alongside the other project checks.
- `data/building_collisions.json` contains only ground-solid building collision and records how many non-ground structures were skipped.

Creator Studio also summarizes excluded and ambiguous routes in the setup screen after a build. The original OSM files in `source_osm/` are copied, never rewritten.

## Limits and correction path

The builder can safely classify what the OSM file actually describes. It cannot prove the intended layout when tags or geometry are missing or incorrect. Conservative exclusions prevent traffic from being sent through a known solid building, but an excluded route can leave a disconnected network. Close-clearance warnings remain playable because automatically deleting a merely adjacent road could remove a valid narrow street, covered passage or mapped footpath.

The planned Advanced Map Editor will provide a no-code way to hide an incorrect footprint, add or remove collision, or explicitly correct a vertical relationship. Until then, correct the source OSM/export and rebuild when an important route is excluded.

## Focused developer check

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_map_geometry.gd
```

The synthetic check covers a ground conflict, a close but clear road, overhead and underground buildings, explicit bridge/tunnel travel, ambiguous vertical roads and player/wagon crossing collision masks. The real The Rocks regression exercises the same logic on dense coastal geometry.
