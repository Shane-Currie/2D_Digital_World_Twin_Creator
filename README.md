# 2D Digital World Twin Creator

This repository preserves completed releases in separate version folders:

| Version | Status | Open the application |
|---|---|---|
| [`v1.1`](v1.1/) | Completed release | Run `v1.1/Start Creator Studio.cmd` |
| [`v1.2`](v1.2/) | Completed release | Run `v1.2/Start Creator Studio.cmd` |
| [`v1.3`](v1.3/) | Completed release | Run `v1.3/Start Creator Studio.cmd` |
| [`v1.4`](v1.4/) | Completed release | Run `v1.4/Start Creator Studio.cmd` |
| [`v1.5`](v1.5/) | Completed release | Run `v1.5/Start Creator Studio.cmd` |
| [`v1.6`](v1.6/) | Completed release | Run `v1.6/Start Creator Studio.cmd` |

Creator Studio is a no-code Godot application that turns OpenStreetMap `.osm` files into editable, playable 2D town projects. Creators can import a map, select the CBD and safe starting location, choose local road rules and population settings, build collision and navigation data, and launch a play test.

Each version is self-contained. Read the `README.md` and `CHANGELOG.md` inside that version folder for its exact features, instructions and limitations. A compatible Godot installation is currently required by the development launcher; it detects Godot or provides plain-language setup help.

v1.5 adds expanded interior editing, creator tool hubs, trader NPC inventories/purchases, interior generic NPC/NPR placement and venue-reference text for local Ollama conversations. The local LLM handles character dialogue only; deterministic game code validates and commits accepted trades. See [v1.5 instructions](v1.5/README.md) and [release changes](v1.5/CHANGELOG.md).

v1.6 adds footprint-preserving building heights and exterior designs, environment detail/tree collisions, easier building/interior editing, stairs/connected buildings, bathroom assets, player seating and illustrated animated NPC/player artwork with editable body parts and a walking test. Existing local Ollama persona/lore/location dialogue and validated trader purchases remain included. See [v1.6 instructions](v1.6/README.md) and [release changes](v1.6/CHANGELOG.md) for focused verification and limits.

Active development continues locally in v1.7. Completed releases remain preserved; v1.7 is not part of this release push.
