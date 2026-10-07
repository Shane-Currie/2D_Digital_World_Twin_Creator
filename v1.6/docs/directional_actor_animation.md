# Directional actor animation

Player and NPC production artwork now shares one 7.5×13.75-world-unit drawing box, a 25% increase over the preceding 6×11 box. The box ends at local Y=0, so the actor position always represents the feet and source-sheet proportions cannot make the player taller than NPCs or make either float. NPR artwork also increased by 25%, from 0.5 to 0.625 of its source drawing size. These are visual changes only; collision clearance, walking speed, route selection and crossing rules remain unchanged. Cars and NPD drones retain their prior size.

Creator v1.4 replaces the former front-facing-only character presentation with static directional atlases. Movement still comes from the generated OSM navigation graphs; artwork does not choose routes or change collision.

| Actor | Directional presentation |
| --- | --- |
| Player | Front, left, right and back views with four walk frames per direction |
| NPCs | Four views for all 18 fixed tone/gender/age identities; the existing movement bob remains |
| NPR robots | Four views with four walk frames per direction and the existing beacon blink |
| NPD drones | The existing top-down drone rotates toward its current aerial route; rotor and hover motion remain |
| Cars | Existing body-specific sprites continue rotating with road travel |

The atlas loader uses proportional cell boundaries, so source images do not need dimensions exactly divisible by their row/column count. Each cell is alpha-cropped at load time and cached. This keeps actors readable at the existing gameplay size without changing their collision dimensions.

The bitmap atlases were created during development with OpenAI's built-in image-generation tool using the existing static actors as identity/style references. They are stored under `assets/actors/directional/` and are consumed locally at runtime. Town creation, navigation and gameplay do not call an LLM.

Focused verification checks genuine transparent padding, all four direction cells, all player/NPR walk rows, the 18-person catalogue mapping and the existing population balance. Visual checks must still be performed in a real generated town at normal and creator-selected zoom values; this stage does not claim hand-authored sub-pixel animation or unique multi-frame walks for every NPC identity.
