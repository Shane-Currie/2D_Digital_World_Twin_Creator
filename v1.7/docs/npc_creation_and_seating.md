# NPC artwork and seating

Separate-part walking rigs and the ready-to-use **Test walking** window: [NPC body-parts animation](npc_body_parts.md). Existing frame/sitting artwork remains supported at the same character scale.

## Creator controls

Open **NPCs and personas → NPC creator**. The 18 read-only built-in humans cover
man/woman, young adult/middle aged/elderly and light/medium/dark pigmentation.
These appearance attributes do not determine personality or behaviour. Generic
human spawning retains equal numbers of men and women; NPRs remain robots.

Choose **New frame animation**, name it, set its attributes and upload individual
standing, walking or sitting images for Front/Left/Right/Back. Each slot accepts
1–8 PNG/WebP/JPEG files, filename-sorted for animation. Transparent PNG is best.
Maximum 4096×4096 pixels and 20 MB per image; 100 custom creations per town.
Uploads are copied, never moved or executed. A custom creation needs a front
standing image before Save. Missing views fall back to standing artwork rather
than pretending a standing person is sitting. The sitting hip-anchor control
helps align custom poses with the actual game chair shown in the preview.

**Morpheus** is included, not labelled an example, and its display name can be
changed without changing its ID. As of 8 October, built-in humans/player/Morpheus
use the requested illustrated cutout style with separate head/torso/limbs and
four standing/walking/seated directions. Skin pigmentation, gender and age
choices retain their existing stable IDs. Uploaded custom art remains supported.
Use **New Animated NPC** for an editable copy of a chosen built-in skeleton.
The main character has light skin, brown hair, a red jacket and blue jeans.

Generic, storyline and trader humans always use Animated NPC. Legacy static
flags migrate automatically while names, personas, stock and locations remain
unchanged. There is no NPC type selector. The main character also always
animates when walking; **Game settings → Character artwork** shows its status.

Storyline/trader placement offers random built-ins, explicitly selected built-in
attributes, or a saved custom creation. Select artwork, apply the placement and
use the persistent top **Save**. Switching role tools preserves appearance
drafts. If changing a creation's attributes after assigning it, reselect/apply
that creation on its placed NPCs so their saved attributes agree. **Delete item**
can remove unused custom records, including unfinished drafts; it does not
delete uploaded files or permit removing artwork still assigned to an NPC.

Generic NPC placement now includes an illustrated live preview and a direct
selector for all 18 built-in identities. Changing the identity updates the
age/gender/pigmentation fields together; custom creations also preview their
copied artwork. Random placement remains available.

## Seats and toilets

Open **Interior designer → Seat direction**, select a chair/stool/toilet and
drag the blue arrow tip. Release commits one Undo step; Cancel abandons a drag.
Save retains the direction independently of furniture rotation. Angles select
the nearest Front/Left/Right/Back seated profile. Default direction follows
furniture rotation; 0° front, 90° left, 180° back, 270° right.

In play, approach an accessible chair/stool/toilet and press **E to sit**.
Press **E again to stand**. WASD cannot move a seated character. Reach/standing
use the actual player radius, room discovery, walls and actor occupancy. Only
the selected cushion/bowl is exempted; cubicle walls stay solid. If there is no
clear standing position, the player remains seated and receives a message.
Talking or opening/closing the map does not unlock seated movement.

Seated rendering excludes faint transparent padding and uses the matching
standing view as its scale reference. The player's seated drawing is calibrated
for its approved folded-leg artwork; neither the standing scale nor bitmap
files change. Bar stools taper furniture clearance only during the final half
metre of the sit/stand route; floor boundaries, walls and cubicle partitions
keep full player-radius checks. This is not a general walking collision bypass.

This is the first player furniture interaction. Autonomous NPC seating,
NPC furniture schedules, animated sit-down transitions and toilet-use/stat
effects are **not implemented**. Existing collision/identification remains.

## Files and verification

- Town metadata: `npc_creations.json`; copied art:
  `assets/npcs/custom/<stable_creation_id>/`; placements: `storyline_npcs.json`.
- Built-in artwork: `assets/actors/custom/morpheus_v16.png`,
  `generic_seated[_left|_right|_back]_v16.png`, `player_seated_v16.png`.
- Furniture stores optional `seat_direction_degrees` in `building_interiors.json`.
- `creator-cli.js validate-town` validates the same catalogue and references;
  all creator/runtime functions are deterministic and require no local LLM.
- Focused checks: `verify_npc_creation.gd`, `verify_player_seating.gd`,
  `verify_pub_seating_scale.gd`, `verify_npc_creations.js`.
  Exact results/limitations are in CHANGELOG.md.

Progress captures use production actors and actual furniture in disposable
fixtures at the runtime's 8 px/m. They are not screenshots of modifications to
the user's saved pub and do not establish whole-map performance.

The revised Pub scale check additionally reads the actual saved Albury Pub
without changing it. It verifies 27 accessible existing seats, including all
nine bar stools. Chair `furniture_16` is too close to the saved floor boundary
for full player clearance and needs moving inward in the Interior Designer.

## Artwork provenance

The imagegen skill selected bitmap assets rather than replacing the existing
renderer with vector silhouettes. Built-in image generation was used, with
transparent-background outputs and reference-based edits for matching views.
Original generated files were preserved; chosen PNGs were copied into the
shared asset folder above. No local Ollama model authored these assets.

Prompt set summary: (1) dark-skinned, bald, sunglasses/long black coat character,
standing/three walking steps/seated, four matching directions; (2) eighteen
existing light/medium/dark, man/woman, three-age identities seated on furniture,
then matched left/right/back views; (3) existing brown-haired blue-jacket player
seated front/left/right/back, transparent, no baked-in chair. Seated poses use
bent hips/knees for actual chairs/toilets, never a ground-sit. Atlas row bounds
are explicitly mapped where generated spacing is unequal; no bitmap changes
were made after the user's artwork approval.
