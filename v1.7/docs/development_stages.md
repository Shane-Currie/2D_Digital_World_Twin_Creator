# Current v1.6 stage order

This preserves the order presented to the user on 2026-10-07. These are review
checkpoints, not scheduled background jobs. Preserve completed versions and
user-town files; record actual checks in CHANGELOG.md.

| Stage | Work | Status |
|---|---|---|
| 1 | Coherent solid roof/wall corners following irregular OSM footprints, without obstructing roads/neighbours | Implemented; focused Albury/geometry checks passed. Illustrative fitted 2.5D; visual approval remains user-reviewed. |
| 2 | Easier roof/wall alignment, texture sizing and separately editable facades | Implemented roof/default/front/left controls and live preview; focused persistence/gesture/legacy/clearance checks recorded in changelog. Individual-edge facades are not implemented. |
| 3 | Place stairs and connect playable interior floors so upstairs NPCs are reachable | Implemented; paired stair placement/dragging, E-only transfers, floor-specific NPCs, safe landings and preserved ground entries. Focused checks passed; extended play remains user-tested. |
| 3a | Connect adjacent building interiors through a shared-wall door | Implemented; paired placement/dragging, locks, same-level E travel and separate outside exits. No gaps/corner contacts; focused geometry/UI/runtime/CLI and read-only Albury Pub checks passed. |
| 4 | Indoor NPC/NPR activity and furniture interactions beyond identifying objects | First slice implemented: NPC artwork creation/directional poses, seat-direction arrows and player E sit/stand. Autonomous NPC seating/schedules and further interactions remain pending. |
| 5 | Measure loading/FPS and test buildings, trees and collisions across maps | Pending extended performance stage; earlier focused checks are not a substitute. |

Later backlog: hills/elevation, linked-map travel, crash damage, trader restocking
and selling items back. Tiered building parts, camera parallax and full exterior
occlusion remain unimplemented; they are not silently included in stages 1–2.

Stage 2 usage/data: [Building artwork editor](building_artwork_editor.md).
2026-10-07 feedback correction: Building Creator now uses four separate tool
buttons and one full-height workspace at a time. Map/facade doors and their
ground-floor arrival links can be placed/dragged in Building Creator. This is
a Stage 2 usability correction; Stage 3 stairs is now implemented. Its new-floor
destination also creates the playable floor and raises the exterior count on
Save. Bathroom tiles/walk-in cubicles/urinals are available; shared-wall building
doors are now implemented. Usage: [Connecting neighbouring interiors](connected_buildings.md).

2026-10-07 follow-up completed: single-purpose editor tools, larger map workspaces,
Undo/Cancel/Save, new rectangular outdoor footprints, rotated/optional matching
stairs, and Albury neighbour discovery. The authorized usability review is ended
at the user's request. Corner handles now resize placed furniture/custom objects
with matching collisions. Usage and focused checks: [Editor tools](editor_usability.md).
This does not start Stage 4 or mark v1.6 complete.

2026-10-07 later authorisation supersedes the preceding Stage 4 deferral for its
first slice only: NPC creator and player seating are now implemented. The user
approved the artwork and asked to wrap up, then stopped the review agent.
The agent is interrupted; no background work or next stage is scheduled.
Usage and remaining scope: [NPC artwork and seating](npc_creation_and_seating.md).
