# Bathroom assets

In **Interior Designer → Flooring**, select white ceramic, grey slate or cream/teal checker tiles. Drag to paint; Shift-click fills the room. They use the existing continuous metre-space texture painter, not per-object stamps.

In **Furniture**, choose **Bathroom** or search for cubicle/urinal. Two teal/grey cubicles are 1.8 × 2.8 m with an open approximately 1.14 m doorway. The player can walk in: sides, rear, front jambs, swung-open door and toilet have separate solid parts. Parts rotate/scale with the saved artwork dimensions. Item placement still reserves the entire artwork envelope to prevent overlapping fixtures. These are illustrative game sizes, not surveyed/compliance-certified facilities.

The wall urinal is 0.55 × 0.9 m; the trough urinal is 2.8 × 0.45 m. Their length was doubled after user feedback; collision and artwork match. They remain static, click-to-identify objects. Closing/locking cubicle doors and using toilets/urinals are not implemented.

Shared vector assets: `assets/interiors/bathroom/`. Built-in art resolves by catalogue ID; uploaded art retains its existing safe town-relative path. The same assets render in the furniture thumbnails, designer and play floor. GUI, Godot validation, schema and Node validation accept the new IDs.

Focused check: `tools/tests/verify_bathroom_assets.gd` checks paint/placement, save/load, icons, editor/runtime art, identification, solid fixture contacts, actual default player clearance, rotated cubicle clearances and the real player's `_move_on_foot` entering, stopping at the toilet and walking out. Add `-- --render` for `docs/screenshots/bathroom_cubicle_outside_revision2.png` and `bathroom_cubicle_inside_revision2.png`. These fresh before/after captures supersede the earlier `bathroom_assets_v16.png` demonstration, which manually positioned the character and used undersized clearance probes. No saved Albury bathroom or full gameplay/performance result is claimed.

Lesson: a character drawn inside an object is not proof of walk-in access. Test the default player's actual collision radius and movement handler. Use new image filenames after a revision rather than relying on clients to refresh an overwritten preview.
