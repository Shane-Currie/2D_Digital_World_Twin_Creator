# On-foot sprite collision

The walking player now has an explicit population-contact check. NPCs, NPRs and traffic cars are drawn actors, not Godot physics bodies; a physics collision mask alone cannot stop the player walking through them. Buildings/the owned wagon still use existing physics checks, and interior walls/furniture use existing ground checks.

- Use the player's four-world-unit foot radius (scaled with the character), NPC/NPR foot radii already used by walking/crashes, and traffic's visible lane-offset centre and rotated car dimensions.
- Sweep circles against character circles and rounded car rectangles. Stop at the first contact, with bounded tangent sliding; permit leaving old/spawn overlaps. This is physical contact, not lane guidance, automatic turning or injury/impact damage.
- Filter by the active interior building/floor or outdoor space and matching bridge/tunnel layer. Airborne drones and road/path reservations are not ground obstacles.
- NPC/NPR steps also respect the standing player's feet. Hidden players seated in cars do not leave a second invisible pedestrian obstacle.
- Broad-phase nearby candidates and at most three contacts bound each player check. A secondary physics-body slide is checked again only if it changes the proposed endpoint. Neither sprites nor world bodies may be bypassed by that slide.

Implementation: `scripts/runtime/pedestrians/on_foot_actor_collision.gd`, population callback and walking-player hook. Existing towns load it through the shared Creator preview; close/reopen Play test, with no content rebuild required.

Focused verification: `tools/tests/verify_on_foot_sprite_collisions.gd` covers long sweeps, glancing slide, old-overlap escape, angled lane-centred cars, real player movement, reciprocal walkers, space/floor/layer filtering, drone/hidden-player exclusion and furniture checks. Read-only Albury checks cover all three saved interior storyline actors, including the pub character. Player controls, crossing boundaries, intersection crowds, crash motion, walking avoidance/bubbles and saved pub entry regressions passed. These are focused checks, not extended gameplay or performance certification. Existing headless sandbox log/certificate and image-import warnings remain.
