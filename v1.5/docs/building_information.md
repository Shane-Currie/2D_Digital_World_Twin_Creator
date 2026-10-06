# OSM building information

Creator Studio turns tags attached directly to each imported building footprint into a short, readable description. It performs this locally and deterministically; no LLM, web lookup or town-specific rule is involved.

## Using it

On every outdoor town map in Creator Studio, hover over a building footprint to display a floating OSM details card beside the mouse. This includes the **Import a town** preview, **Advanced Map Editor** and **Building Creator**. The shared card follows the pointer, stays inside its own map panel and closes when the pointer leaves the footprint. Future outdoor pages that reuse the same town-map component inherit the feature automatically.

Interior floor maps are intentionally separate: they contain creator-authored rooms and furniture rather than OSM building footprints, so they do not show an OSM footprint card.

During **Play test project**:

- Hover the mouse over a visible building for a quick summary.
- Click the building to pin its fuller details.
- Click empty ground to close the pinned popup.
- In the M map, drag from empty ground to pan. Clicking a footprint opens it instead of moving the map.

The popup stays within the playable area rather than covering the top or bottom HUD. It is hidden during tunnel and under-bridge isolated views, where surface buildings are not visible.

Creator Studio's existing **Inspect** tool now presents the same category, address and source wording before play testing.

## Information shown

Where available, the description can show:

- the building or place name;
- mapped use from `amenity`, `healthcare`, `shop`, `office`, `tourism`, `leisure`, `industrial`, `craft`, public-transport or building tags;
- street address, suburb/city, county, state, postcode and country;
- operator or brand;
- building levels/floors, mapped height, opening hours and mapped wheelchair access;
- a directly tagged phone number or website;
- the source OSM way or relation ID.

Every quick and pinned popup visibly says **© OpenStreetMap contributors**. Imported text is displayed as plain text, flattened to one line per field and length-limited before it reaches the HUD.

If OSM only says `building=yes`, the application displays **Building type not mapped in OSM**. It never converts a missing tag into a guessed business, house, culture, owner, address or accessibility claim.

## Saved data and scope

Create/Rebuild writes `data/place_information.json` under the contract in `schemas/place_information.schema.json`. It contains stable feature IDs, the selected readable fields, their source tags, statistics and attribution. Geometry remains in `data/map_features.json`; the runtime joins the records by feature ID and creates a spatial selection index so dense maps do not scan every building for every mouse movement.

Only tags on the selected footprint are represented as facts in this stage. A nearby or contained point of interest is not automatically assigned to the whole building, because a single building can contain many tenants. Direct footprint uses can now become NPC/NPR route targets through `population_destinations.json`; creator overrides, multi-tenant selection and custom exterior/interior editing remain later stages.

Older projects still display an in-memory version of the information when played, but selecting **Rebuild project** is required to save the canonical `place_information.json` file.

## Focused checks

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tools/tests/verify_building_information.gd
node tools/tests/verify_foundation.js
```

The synthetic check covers trustworthy unknown wording, direct semantic tags, county/country addresses, levels, height, contact tags, unsafe line breaks, source IDs, overlapping buildings, courtyard holes and quick/pinned/editor-hover text. The Creator UI regression checks the Import preview, Advanced Map Editor and Building Creator maps, including the map-independent spatial hover index, floating card contents, attribution, edge containment and closing behaviour. The real The Rocks regression verifies the directly mapped Sydney Opera House as an OSM relation and the runtime popup is visually checked in the actual generated map.
