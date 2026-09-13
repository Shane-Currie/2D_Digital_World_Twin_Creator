# Imported land cover — v1.1 stage, 2026-09-12

Create and Rebuild project now retain closed mapped land areas in `data/map_features.json` as `kind: land_cover`, with original OSM IDs, tags, points and inner rings. The GUI and Node importer read one tag/colour table: `scripts/land_cover/rules.json`. No town coordinates or model calls occur in production classification.

Supported families include grass/meadow, woods/forest, scrub/heath, wetlands, parks/gardens, sand, bare rock/gravel, paved areas and farmland/orchards. Surface car parks are now a dedicated transport feature so their exact boundary, surface and optional inferred bay guides can be rendered consistently; a grass car park remains grass-coloured. Parks are a separate category: a recreation designation does not establish grass everywhere. Untagged ground retains the existing stylised grass fallback, not a claim of mapped vegetation. Tag references: [OSM vegetation](https://wiki.openstreetmap.org/wiki/Vegetation), [land cover versus land use](https://wiki.openstreetmap.org/wiki/Landcover), and [landcover key](https://wiki.openstreetmap.org/wiki/Key:landcover).

Closed ways and joined multipolygons are supported. Incomplete land-cover relations/ways are omitted with a visible import warning; they do not block an otherwise playable town or get speculative closing edges. Missing water still follows its separate safety rules. Suppression of duplicate outer ways is restricted to successful relations of the same category; separately tagged buildings and different inner surfaces survive.

Preview and gameplay share cached surface geometry. Larger broad parks draw below smaller explicit surfaces, with stable IDs breaking ties. Strip decomposition preserves transparent polygon holes without painting out the underlying terrain. Roads, water and buildings retain their own rendering/collision rules; water holes now preserve underlying land-cover art. Areas tagged as elevated, underground, bridges, tunnels or indoor spaces are excluded from ground-cover classification.

Grass stalks and player grass tracks avoid mapped non-grass surfaces. A spatial grid checks cover/buildings; building interiors and roads are not grass. Wetlands/woodland do not invent water depth, tree collisions, access restrictions or new speed penalties. This stage does not implement individual trees, elevation, property fences or road/building conflict repair.

## Focused checks and continuation

- `tools/tests/verify_land_cover.gd`: complete multipart forest with two holes, independent house collision, missing/open boundaries, tag aliases, vertical exclusions, road/house/forest grass-effect exclusions and unchanged building/water collision data for two real sources.
- Run that check first, then `node tools/tests/verify_land_cover.js`: compare IDs, categories and hole counts across Godot and Node for The Rocks and Howlong. Report: `tools/tests/output/land_cover_report.json`.
- Final counts: The Rocks 284 land-cover areas, Howlong 69. Three incomplete land relations in The Rocks are reported and omitted. Saved sources/user projects are preserved; test rebuilds are isolated in `tools/tests/output/land_cover_the_rocks` and `land_cover_howlong`.
- Both rebuilt runtimes passed their brief startup and wagon enter/exit checks with 330 agents and nine/six collision chunks. Creator UI and the 72-check foundation suite passed. Real-map and vehicle-scale captures were visually inspected. Extended gameplay/performance remains user-tested.
- A first navigation-baker approach failed on two narrow complex park shapes. Replaced it with cached strip decomposition; the final The Rocks render has no geometry/script errors. Known sandbox log-file/certificate warnings are unrelated.
- Next planned stage: road-versus-solid-building conflict handling and remaining vertical-geometry validation, followed by grouped traffic signals. Advanced Map Editor, elevation, semantic places/popups and revised player controls remain later stages.

To use this stage: restart Creator Studio, open the saved project, choose **Rebuild project**, then **Play test project**. New imports include land cover automatically.
