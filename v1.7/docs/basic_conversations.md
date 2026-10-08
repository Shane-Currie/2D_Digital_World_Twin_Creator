# Local Ollama persona conversations

## Playing

1. Start Ollama, then Play test a town.
2. Startup loads personas, town information, venue text, live trader stock and the selected model before control is enabled. Optional Wikipedia refresh happens first. A one-token chat warms the same bounded town/venue/stock prefix reused in conversations. Only the assigned persona and current location/relevant excerpts are added per request, avoiding a huge persona catalogue that could evict facts. Warm-up cannot pre-generate future replies or guarantee instant responses. The bar remains indeterminate because Ollama does not expose incremental loading percentages.
3. Walk close to an NPC pedestrian or NPR robot and press **T**.
4. Type a short message in the box and press **Enter** or **Send**.
5. The local model's short reply streams into a bubble above the NPC/NPR as words are generated. Only the NPC/NPR needs a speech bubble.
6. Continue typing, or press **Escape** / **End** to finish.

If startup loading fails, the screen explains the problem and offers **Retry** or **Continue without conversations**. Escape also continues without conversations. The town remains playable, but typed local dialogue stays unavailable until Ollama is started and the map is reopened.

Conversation starts while the player is on foot, either outdoors or on the same creator-authored interior floor as a placed storyline NPC. Outdoor targets must be nearby, on the surface level and visible without a building footprint between them. Interior targets are isolated by stable building and floor IDs, so they never appear on the street or another floor. Cars and NPD drones cannot be selected. Every NPC receives a distinct town-seeded random first name and surname; NPRs receive distinct random serial names. The target pauses, the camera frames both characters, and normal movement resumes afterwards. The latest two messages (one prior exchange) are kept only for the current conversation; conversation memory is not saved.

## Creator Studio

Generic NPCs and NPR robots can now also be placed on interior floors. They use the same conversation flow and know their current building/floor. Upload optional building references through **Interior Designer → Location notes**; both indoor and street characters can refer to the text. See [venue notes and placement](location_notes.md).

Open a town project, then select **NPCs and personas**. The page detects installed Ollama models, provides three randomly assigned human NPC personas and one NPR robot persona, and lets a non-technical creator add, edit and delete personas in the random pools. It saves the selected model and persona library in `data/personas.json`.

The included personas are Friendly Local, Busy Worker, Curious Visitor and Civic Robot. Existing towns without a persona file receive the same defaults in memory and save them through the editor or the next project rebuild.

### Outdoor and interior storyline NPCs

1. Open **Advanced map editor**.
2. Select **Select location and copy coordinates**, then click the desired outdoor point. The map shows a crosshair and copies the value as `latitude, longitude`.
3. For an interior location instead, open **Interior Designer**, select the building/floor, choose **Select and copy interior location**, then click a clear floor point.
4. Open **NPCs and personas**, scroll to **Storyline NPCs**, and choose **Paste copied location**.
5. Optionally enter a permanent character name. Leave it blank to generate a random name.
6. Choose a saved human NPC persona, including one created with **New NPC persona**, or keep **Random compatible NPC persona**.
7. Select **Place storyline NPC**.

Creator Studio applies the existing water/building/route checks to outdoor points. Interior points must reference an existing stable building/floor and remain inside its usable footprint outside courtyard holes. An accepted NPC receives a stable ID and exact geographic or local-interior location. Its creator-provided or randomly generated name and selected/random human persona are saved permanently; current persona edits are saved at placement time. Its existing static appearance is selected randomly once. It remains at the chosen location in Play test and uses the same typed local-LLM conversation flow. Selectable artwork templates and imported custom artwork remain later stages.

### Optional town knowledge

The same page has two independent optional inputs:

- Paste the exact HTTPS Wikipedia article URL for the town. On the next map startup, Creator Studio requests that article's complete lead summary, records the resolved title, URL, language, retrieval time and Wikipedia attribution, and stores the cache in `data/town_knowledge.json`.
- Import a UTF-8 plain-text `.txt` file with extra creator-written town information. Creator Studio validates and copies it to `data/town_knowledge/custom_town_information.txt`, so the town does not depend on the original file remaining on the computer. The page provides Replace and Remove controls.

Select **Save town information** beside the Wikipedia status after entering or clearing the URL; pressing Enter in the URL field does the same thing. **Save personas and town info** also saves it. Imported or removed text is saved immediately.

Neither source is required. NPCs always receive the current Creator Studio project town name, so they can identify where the game is taking place even with no Wikipedia URL or while offline. With both optional sources empty, map startup proceeds directly to the normal Ollama warm-up. With one source configured, only that extra source is used. Wikipedia is refreshed once at map startup, never once per conversation; the optional request times out after 12 seconds, then the previous verified cache is used when available and the map remains playable.

The complete accepted source text is loaded and retained in the town-knowledge cache, but it is not copied wholesale into every model request. Ordinary small talk sends only the town identity. A town-related question deterministically selects one relevant, bounded sentence from each available source. This avoids repeatedly evaluating a long article while keeping the complete cached source available for later questions.

Wikipedia and creator notes are labelled separately. Both are treated as untrusted reference material, not as instructions, and cannot change the game. Ordinary roaming characters continue to receive random names and random-pool personas independently of saved storyline NPCs.

## Safety and limitations

Ollama is contacted only at `http://127.0.0.1:11434`; no cloud model address is used. The optional Wikipedia summary is fetched by Creator Studio itself from the exact creator-supplied Wikipedia hostname; the local LLM receives cached text but receives no browser or web-search tool. The dialogue adapter receives the startup-loaded persona library, the selected NPC's random name/persona ID, bounded relevant town references, the player's message and a small conversation history. It returns plain display text only and has no reference to movement, inventory, saves, scripts or world-state functions. The model is asked for one complete sentence of at most 28 words and receives 40–64 generation tokens so it can reach the sentence ending. Presentation remains bounded to 32 words / 260 characters and adds final punctuation if a model still stops without it; model text cannot directly perform gameplay actions.

The selected model must already be installed in Ollama. Startup performs a real one-token chat warm-up using the same compact town-and-persona catalogue prompt as gameplay and asks Ollama to keep the model available for two hours; it does not create an NPC conversation. On this PC, the real Albury library (six NPC and four NPR personas) produced first visible reply text in 2.42 seconds and finished in 3.98 seconds after that warm-up. Startup itself can take noticeably longer on slower hardware because the work has deliberately moved before player control. If Ollama is unavailable, the game remains playable through the explicit continue option.
