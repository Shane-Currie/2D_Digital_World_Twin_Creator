# Editor tools and object resizing — 2026-10-07

## Import and play a town — v1.7

1. Open Import a town → Town name to name your project.
2. Open Map files, choose your .osm file(s), then Read files and show preview.
3. Draw the CBD in CBD area. In Player start, click clear ground; a separate safe car start is generated. Car start lets you move and rotate it.
4. Set Driving side, then choose the Save folder. Missing requirements remain visible below the workspace; the top Save creates or updates the project.
5. Open Play test project in the left menu, then Play current project. A fully configured unsaved town is created and launched in one action. Choose saved project opens another saved town directly for testing.

Back returns to the tool buttons without losing selections and stops hidden placement tools. Map wheel zoom and left-drag pan remain available. Reading a replacement OSM starts a new project; it does not overwrite the previously loaded town. Failed reads retain that town, but Play is blocked until the new selection is read successfully or another saved project is opened. If a project name already exists in the chosen save folder, choose a different name/folder or open the existing project to edit it.

## Resize a placed object

1. Open Interior Designer, choose a building/floor, then Furniture.
2. Click the placed object. Four green squares appear on its corners.
3. Hold the left mouse button on a square and drag outward or inward. The opposite corner stays anchored; rotation is retained. Live dimensions show the new size.
4. Release to apply. A red X means the size is blocked; the original object stays intact. Drag the body to move, right-click to rotate, and Shift to copy.
5. Use Undo to reverse a completed resize, Cancel/Esc to abandon an active gesture, and the top Save to persist it.

Built-in furniture and uploaded objects use the same handles. Each placement has its own dimensions; resizing does not edit the image, catalogue default or other copies. Artwork and collision scale together, including hollow toilet-cubicle partitions. Each side must remain 0.11–20 m. Crossing the opposite anchor does not flip the object. Walls, objects, doors, stair landings, courtyard holes and authored NPCs must remain clear. Handles do not resize NPCs, stairs, walls or building footprints.

## Delete a placed item

Select an interior item on the canvas or in its placed-item list, then press Delete or click **Delete item** in the fixed Save header. The button appears only for an explicit, current selection. Undo restores the deletion; Save keeps it. Delete in a text field still deletes text.

This covers placed furniture/custom objects, walls, wall doors, room labels, stair pairs, connecting-door pairs and placed NPC/NPR/traders. Removing a wall also removes its door records. Paired doors/stairs remove both ends; character deletion removes its placement and matching trader stock profile. Floors, source maps, personas and uploaded artwork remain intact. Changing tools/floors/buildings or pressing Cancel clears the target. Other exterior/map/catalogue records retain their existing section-specific removal controls.

## Simplified tools

Select one clearly named tile at a time; Back returns to its hub without discarding edits. Building Creator separates upload from alignment and doors from entry links. Interior Designer keeps the selected building/floor visible, with separate paint, furniture, stairs, walls and other pages. Tools hides the left controls to enlarge the canvas. Wheel/+/− zoom; Fit frames the floor; drag empty floor to pan.

For existing buildings, select an active footprint and Create interior if it has no ground floor. For a new outdoor building, use New building and drag a rectangle on clear ground. These creator-tagged overrides are not OSM claims and do not replace source geometry. Minimum sides are 2 m, up to 1,000 rectangles per map; arbitrary polygon reshaping is not implemented.

Next-door link lists stable IDs first, including Albury Pub's neighbour 601183201. Create its ground floor if required, then place a connecting door on the genuine shared wall. Gaps/corner-only contacts remain ineligible. Stairs can rotate; enable the matching-point checkbox to attempt automatic partner placement on the selected existing upper/lower floor. If blocked, choose another destination point or Cancel.

## Save and history

Single-line text, number and dropdown fields stay compact across the main
sections and tool pages. Wrapped help and genuine multiline notes remain
multiline; file-picker windows are untouched. Short zoom buttons retain their
small widths so small-window maps remain visible.

NPCs and personas → Town information has a visible **Upload text file…** action
under **Custom town notes (.txt)**, with filename and preview. Upload copies the
source, Remove detaches it without deleting the copy, Undo restores the draft,
and the top Save persists the optional reference.

NPCs and personas → Trader stock lists the selected trader's items beneath
**Add / update item**. Edit **Quantity** and **Keks each** directly on a row, or
use its **Remove** button. Added items appear immediately; adding an existing
item updates it rather than duplicating it. Use the top Save to persist stock
and prices. Undo restores a removed row. This does not bypass purchase
confirmation or change live trade validation.

The fixed top bar contains Undo, Cancel, Save and saved/unsaved status. Undo retains up to 30 in-session snapshots in the current section, including form drafts and supported tree/lore/reference changes. Save preserves history, so Undo after Save is possible; Save again to persist the restored draft. Leaving a dirty section offers Save/Discard/Stay. Failed multi-file NPC/interior saves roll back owned metadata; rollback failure is explicitly reported, not hidden.

Undo is not an OS undo or a persistent version archive: it does not undo generated map rebuilds, restore source maps, delete uploads or cross into another section. Source and copied assets remain available. Imported town/location references restore their snapshot text/metadata safely; malformed or missing required files can prevent restoration with an explicit message.

## Starting a new town in v1.7

**Import a town** resumes the current town setup so you can edit its name,
CBD and player/car starts. It does not clear a loaded project.
Use **New town** in its Save header, or **Home**, to start a fresh session;
these ask before closing the current project session.
Choose **Keep current project** to cancel, or return and save unsaved work first.
**Start new town** discards session edits and Undo history, not saved files.
Home returns to Welcome; New town opens empty setup. The chosen save folder is
retained, but the previous town's save/play targets are detached. Reopen saved
work with **Open previous project**. **Back to town setup** within Play test
resumes the current project without starting a new session.

Leaving a genuinely edited section offers Save / Discard / Stay. A successful
Save continues to the menu you selected; a failed Save keeps your edits open
and explains the issue. Browsing NPC human/robot tools or viewing a different
artwork template alone is not an unsaved content change.

## Review and focused evidence

An explicitly authorized independent agent reviewed the editor sources. Applied recommendations included single-purpose tiles, bounded image thumbnails/full-height maps, removal of empty/duplicate actions, stable-ID selector restoration, safe draft history and unsaved-navigation/save/import protection. The user then ended the review and requested focus on corner handles; no background review is scheduled.

`verify_furniture_resize.gd -- --render`: 36 checks, real editor gestures/store/runtime collisions in disposable fixtures, before/after images. `verify_editor_usability.gd`: 37 UI/footprint/stair/Albury checks, including lower-floor and blocked matching stairs; saved Albury hash unchanged. `verify_editor_history.gd`: 32 checks, including late-failure metadata rollback. Component/reference tests: 45/47 checks. See CHANGELOG.md for regressions, warnings and limits. These are focused checks, not a full gameplay/performance audit.
