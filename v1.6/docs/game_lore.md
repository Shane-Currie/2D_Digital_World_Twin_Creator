# Game settings tools and optional game lore

Game Settings now opens a simple button hub, matching the Interior Designer/NPC tools. Pages: Town population, Road rules, Skin pigmentation tones, Camera view, Player vehicle, Traffic jam recovery, Game lore and Recommended settings. Back preserves current form values; the floppy-disk Save remains above the scroll area. Leaving the main section still requires saving ordinary settings.

## Add lore without code

1. Open or create your town, then select **Game Settings → Game lore**. For another saved town, choose its folder at the top and Load.
2. Choose **Upload / replace .txt**, or **Use example lore**. The copied text and metadata save immediately. Preview the text on the page.
3. Reopen **Play test project**. Lore loads once at startup and joins the same shared prompt used to warm Ollama and talk to every indoor/outdoor NPC/NPR, including placed/storyline/trader characters. Normal conversations remain available without lore.
4. **Remove lore** detaches it from future conversations without deleting copied files. Restart Play test after changing/removing it. Upload the original/edited text again to replace it; don't edit the hashed copy directly.

Use non-empty UTF-8 `.txt` (UTF-8 BOM is also accepted), no larger than 64 KB. Word documents, binary, empty, oversized, unsafe paths and malformed metadata are rejected/preserved with inline feedback. Missing/changed copied text produces a startup warning and is skipped rather than stopping the game. The lore editor follows the selected town path, so it cannot silently upload into the previously selected town after the field changes.

## Example

Source: `data/examples/game_lore_world_at_risk.txt`. The fictional world faces the threat of World War Three, which has not yet begun. Civil unrest and anxiety prompted deployment of NPRs offering counselling only. They are programmed not to harm humans, not armed enforcers. Some residents appreciate them, others distrust them. Opinions are personal and independent of skin pigmentation, gender and age.

The example is opt-in, not silently installed in existing user towns. Its fictional non-harm policy is conversation background; it does not add or change a gameplay combat, AI enforcement or damage system.

## Data and dialogue boundaries

`data/game_lore.json` (schema 1) holds `{ "schema_version": 1, "lore": {} }` when absent/removed, or a `lore` entry with `relative_path`, `sha256` and `original_filename`. The only accepted active text path is `data/game_lore/<sha256>.txt`, with the digest matching the content. Imports copy rather than move the source, write the text before committing metadata, and keep prior copies recoverable. See `schemas/game_lore.schema.json`. Codex can inspect/edit documented data and use `node tools/creator-cli.js validate-town --town "TOWN_DIRECTORY" --json`; optional lore metadata/text checks also run there.

The complete bounded file loads into RAM, not into every LLM request. Up to 1,200 characters enter the shared warmed prefix; longer text also supplies a locally selected query-relevant excerpt (up to 650 characters). Put essential world rules at the beginning. This avoids extra model summarisation calls and keeps town/location/persona context usable in the existing 2,048-token dialogue context; a very long book is not guaranteed to be fully understood at once.

Lore is labelled fictional background, separate from Wikipedia/current location and persona. It is never executed or allowed to write saves/invent authoritative stock or powers. Trader transactions still require the existing allowlisted validation and player acceptance. Prompt guidance discourages invented events/mottos and asks for one short sentence; LLM factuality and completeness remain model-dependent, not guaranteed.

## Focused verification

- `verify_game_lore.gd`: copy/replace/remove, source retention, BOM, empty/binary/size/path/hash/corrupt checks, startup cache, identical NPC/NPR/warm-up prefix, long-file excerpts, eight tiles, Back drafts and example preview in a disposable town. `--render` captures the real menu/page under `docs/screenshots/game_settings_tool_tiles.png` and `game_lore_editor.png`.
- `verify_game_lore.js`: optional lore validation parity in the CLI.
- Existing Creator UI/save/settings and location/trader conversation regressions passed; 105 Node foundation checks passed.
- `verify_game_lore_ollama.gd`: final installed `llama3.2:3b` check used the shared startup prefix. Warm-up 0.60 s, indoor NPR response 2.17 s, outdoor human response 3.00 s. No town/player writes. Initial tests produced an invented motto/overlong answer; tightened lore guidance removed those in the final focused check. A compound question still omitted the distrust portion under the short-response constraint, so direct questions were used to check both behaviours. Do not generalise these results to all models, prompts or hardware.

No completed releases, source OSM, user town data or building geometry were changed. Existing sandbox log/certificate and development image-loading/export warnings remain; no Windows release export or full-game performance test.
