# NPC body-parts animation

## Test it yourself

1. Restart Creator Studio from the v1.6 folder and open your town project.
2. Open **NPCs and personas → NPC creator**. Choose one of the 18 built-in animated humans and press **Test walking** directly.
3. To customise it, press **New Animated NPC**. Give it your own name. The creation copies ten genuinely separate illustrated pieces for each of Front, Left, Right and Back; it does not slice the old full-body bitmap.
4. Press **Test walking**. The NPC walks and turns through all four views using the game's population renderer. **WASD** moves the normal player for comparison; **Esc** or the window close button closes the test.
5. Try **Walk preview** in the editor. Untick it to align pieces: left-drag a joint/body part, or hold right mouse and drag horizontally to rotate. **Cancel/Esc** abandons a held gesture; **Undo** reverses a committed edit. Top **Save** keeps the creation in your town.

The test does not change town placement, inventory or dialogue and does not need Ollama. Copied and uploaded parts go in your town's `assets/npcs/custom/<stable_id>/parts/`. Rigs retain the existing 7.5 × 13.75-world-unit maximum character envelope, feet anchored at the actor position, preserving proportions. Editing part sizes changes proportions inside that envelope, not the world's character scale or collision radius.

The shared library uses the illustrated cutout style requested on 8 October: 18 age/gender/pigmentation variants plus the player and bundled Morpheus. All human NPCs use animated artwork. The player has light skin, brown hair, a red jacket and blue jeans. Human appearance remains independent of persona, behaviour and conversation. Original pixel-art sources and uploaded creations are retained, not destructively repainted.

## Your artwork

Choose a view/slot, then **Upload part**. Transparent PNG/WebP is recommended; each image must decode, contain artwork, be at most 1024 pixels per side and 4 MB. Ten slots are torso, head, left/right upper arm, forearm including hand, thigh, and shin including foot. Left/right means the character's limbs.

**Import view** accepts up to ten files named `head.png`, `torso.png`, `left_upper_arm.png`, `left_forearm.png`, `right_upper_arm.png`, `right_forearm.png`, `left_thigh.png`, `left_shin.png`, `right_thigh.png`, `right_shin.png`. A matching `front_`, `left_`, `right_` or `back_` prefix is optional. Duplicate/unknown files reject the batch before copying. Single-slot uploads may have any filename. Original files are never moved or overwritten.

Width/height fit the image to the part. Pivot percentages locate its joint within the image. Preset joints work immediately; moving a parent moves its children. Layer controls which piece draws in front; Mirror reverses one image. Walk cycles/sec and Stride control the gait without keyframes. Reset view layout restores joints/sizes while retaining uploaded images.

All ten **Front** images are required before Save. Incomplete other directions explicitly fall back to Front. The tool does not invent hidden/back artwork or split a flat character picture automatically.

## Use in your town

The main character and generic, storyline and trader humans all animate when walking. There is no Static NPC or Static main-character selector. Old static/missing animation settings migrate in memory automatically and are persisted on normal Save; simply loading a town does not rewrite its files. **Game settings → Character artwork** shows the animated status. Characters swing their arms/legs when walking and rest when stationary; sitting and disabled movement do not play walking animation.

Save a creation, then select it through Generic NPC, Storyline NPC or Trader NPC placement. All three use animated artwork automatically. Named placed NPCs currently stand at their assigned location; this stage does not add roaming schedules. **Test walking** lets you test immediately regardless of placement behaviour. NPR remains robotic. **New frame animation** preserves multi-image uploads for custom walking/seated views; a single flat image does not automatically become a skeleton or gain missing walking frames.

Built-in humans/player/Morpheus have four seated cutout profiles, anchored at the seat hip without shrinking the upper body. Existing E sit/stand works on chairs, stools and toilets; no autonomous seating or new toilet effects are added. Custom creations still use their separately uploaded seated images through **Sprite frames**; arbitrary uploaded walking rigs do not magically gain a sitting pose. Switching back to Sprite frames requires normal front standing artwork before Save; rig settings/images are retained.

## Data and checks

Optional `rig` data lives in `data/npc_creations.json` alongside metadata/frame poses. Version 1 supports four views, ten parent-relative joint records and image/position/size/pivot/angle/layer/mirror settings. Optional bounded atlas regions remain supported for old custom records but are not used for the new shared library. Schema and Godot/Node validation agree. Runtime uses hierarchical transforms, opposing limb swings and bending knees/elbows, with shared textures/eight-frame gait geometry rather than separate nodes per NPC. This is not a baked sprite exporter or a full-town performance result.

The editable source is `scripts/npcs/rigging/npc_rig_starter.gd`. Run `tools/npc_creations/build_cutout_library.gd` with Godot to rebuild only the versioned shared `assets/actors/cutout_v16/` library (20 identities / 800 separate view-part PNGs). Ordinary creators do not need to rebuild or run commands. The library/index is bundled, not generated at game startup. New custom characters copy parts into the selected town before editing.

`game_settings.json.character_art.npc_type`, `player_type` and human placement `appearance.animation_type` save as `animated`. Readers accept legacy `static` for migration, not as a selectable mode. CLI: `node tools/creator-cli.js set-settings --town <town> --npc-type animated --player-type animated`. Actual-player regression: `Godot_v4.7.2-stable_win64.exe --path . --script tools/tests/verify_player_animation.gd -- --render`.

```text
Godot_v4.7.2-stable_win64.exe --headless --path . --script tools/tests/verify_npc_rig.gd
Godot_v4.7.2-stable_win64.exe --path . --script tools/tests/verify_npc_rig.gd -- --render
node tools/tests/verify_npc_rig.js <RIG FIXTURE directory printed by the Godot check>
Godot_v4.7.2-stable_win64.exe --path . --script tools/tests/verify_npc_animation_types.gd -- --render
node tools/tests/verify_npc_animation_types.js <ANIMATION FIXTURE directory printed by the Godot check>
```

Rendered checks use disposable creations and the actual saved Albury Pub floor read-only, verifying its unchanged hash. Captures: `docs/screenshots/npc_body_parts_*.png`. Checks cover imports, validation, hierarchy, current scale, editing/Cancel/Undo/Save/reopen, four-direction movement, actual player WASD and two-size editor fields. Existing sandbox log/certificate and bundled image/export warnings remain; extended gameplay/FPS and exported executable testing remain outside these checks.
