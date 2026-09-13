# Creator Studio development guidance

- This project is **2D Digital World Twin Creator v1.2**, based on the completed v1.1 release. Follow the root rolling requirements log as well as this file, and preserve the separate v1.1 folder and published release.
- The interface is for creative, non-technical users. Every required workflow needs a GUI path with plain-language feedback; do not require users to edit code, JSON, environment variables or commands.
- Creators choose the directory where their game files are saved. Do not silently redirect a valid selected directory.
- Keep canonical projects in documented, versioned, human-readable content files. GUI and CLI operations must agree, and important state must not exist only inside the GUI.
- Local LLMs have one role only: NPC persona dialogue during play. Never use a local model for town generation, artwork, interiors, persona authoring, code or Creator Studio operations.
- Keep imported files untrusted and copy them into explicit content folders. Do not execute scripts from a content pack.
- Maintain `CHANGELOG.md` with implemented behaviour, focused verification and material limitations.
- Generated games must retain the complete v1.3 gameplay family: walking player, player-driven wagon, NPC pedestrians and traffic, signals/intersections, traffic recovery, map/building collisions, venues/interiors, boundaries/fences and camera/minimap. Generalise these systems; do not silently discard features merely because a new town lacks town-specific content.
- Keep creator-editable population values in `game_settings.json`, with player driving and NPC traffic-recovery values in their own named sections. GUI and CLI validation must enforce the same ranges.
- Town import, projection, navigation and collision generation must be deterministic and work without a local LLM, Codex or town-specific code. Local LLMs remain restricted to NPC dialogue during play.
- `preview_ready` means the shared functional town preview is launchable, not that every v1.3 system is complete. Keep `preview_limitations` accurate and do not mark Node-only imports playable before Godot has generated their navigation data.
- The active Belconnen test start is Cooper Lodge at the University of Canberra. Preserve its safe exterior provenance (`osm_building_id` 297173255, `entrance_verified: false`) until verified entrance or interior data is deliberately added; do not silently invent a doorway.
