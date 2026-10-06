# Trader NPCs and confirmed purchases

## Creator workflow

Open a saved town, select **NPCs and personas → Trader NPCs**, and create a trader directly. Paste an outdoor or interior location, optionally provide a name, choose a human persona and select **Place Trader NPC**. You do not need to create a storyline NPC first. The separate **Storyline NPCs** tile lists only storyline characters. Both categories offer the same human persona choices, including Barkeep, Shopkeeper and custom personas. Edit human personas through **Generic NPCs**; **NPR** holds robot personas. No LLM is used by the Creator.

Select an existing trader to edit its name/persona, then use **Apply name / persona to selected NPC**. The stock section below configures trading-open status, trade type, items, stock and prices. Closing the shop does not turn its character into a storyline NPC. **Interior Designer → NPC placement** can also create either category by clicking a clear floor position; save the interior, then configure trader stock here. Back returns to the button hub without discarding edits; save before leaving the main section.

Choose an item from **Inventory items**, set starting stock and whole-Keks selling price, and select **Add / update item**. Select a listed item to edit/remove it. Use the always-visible top floppy-disk **Save personas, traders and town info** button, then reopen Play test. Trading works on placed outdoor/interior NPCs using their existing stable IDs, without map-specific runtime code.

For the Albury example, **Moe** in **The Pub / Ground floor**, building `601183200`, is a Barkeep selling **20 beers at 5 Keks each**. The new menus classify this legacy trader in memory, keeping his stable ID, stock, position, artwork and effective barkeep dialogue. The explicit role/persona alignment is persisted when the creator saves. The beer icon is `assets/inventory/beer.svg`. Beer starts at zero in the player's backpack and is a general item: drinking, alcohol effects, health effects and buyback are not implemented.

## Player workflow

Clear requests such as **Can I buy a beer?**, **I'll take two beers**, **May I have a beer?** or **one beer** now open validated confirmation through a fast deterministic check, without waiting for Ollama. No Keks are spent until acceptance. Negation, past/hypothetical purchases, unavailable stock, price questions and ambiguous multi-item requests do not silently choose a purchase; use Shop to clarify. This helper supports common English wording and creator item names, not universal language understanding.

Stock manifests are prepared from saved inventory at startup and refreshed for requests/accepted sales. Sold-out items are excluded from live LLM stock. Structured output limits proposed IDs to supplied stock IDs; runtime rechecks current availability and the player's stated intent. Generated sale claims/unavailable catalogue references are replaced with stock-grounded replies. Prompt stock is bounded to eight items; fast intent/Shop use the full list. The model never calculates authoritative stock/prices or reports a completed sale. Free-form social dialogue remains model-generated, not a universal factual/hallucination guarantee.

Press **T** near the trader. Type “I'd like to buy one beer” or click **Shop** and choose an item/quantity. Review the exact item, quantity, price and balance, then click **Accept purchase** or **Cancel**. Closing the conversation discards a pending purchase. Shop works without a local model and does not wait for a model response.

The game checks stock, price, quantity (1–99), available Keks and trader identity again at acceptance. A successful sale deducts player Keks, adds player items, reduces trader stock and records trader Keks received in one saved snapshot. No inventory changes while the model is thinking, when it merely suggests a purchase, or when the player cancels. The runtime emits `trade_completed(trade)` only after saving succeeds; future quests may subscribe to this event. The confirmation is cleared before acceptance is delivered, preventing a double click from accepting the same offer twice.

## Files and safety

- Placements: backward-compatible `data/storyline_npcs.json` stores both placed categories, explicitly distinguished by `npc_role: storyline | trader`. This shared backing file keeps interior dragging, validation and runtime loading consistent; the creator lists and creation workflows remain separate. New traders have `trader_npc_` IDs; older IDs stay unchanged. Both use the shared monotonic counter.
- Trading definitions: `data/trader_npcs.json`, schema 1, keyed by placed-character ID. Each profile has `enabled`, `trade_role`, `persona_id`, and `offers` containing `item_id`, `stock`, `price_keks`. Persona stays aligned with the character assignment, not a separate trader-only personality.
- Player and remaining trader inventory: `saves/player_inventory.json`, existing schema 1 plus optional `trader_stock`. Old saves remain readable. Each trader item records `configured_stock` and `remaining`; `_keks_received` records earnings. Changing configured starting stock resets that item's remaining stock; changing price alone does not restock. Automatic restocking is not implemented.
- A complete sibling `.tmp` is flushed and renamed over the save, retaining the existing `.bak` recovery convention. Failed saves roll back in-memory purchase changes. Both sides of a sale share this file; there is no two-file half-sale.
- Storyline allocation now preserves a monotonic `next_npc_number` so new characters do not inherit a removed trader's identity/stock. Orphan profiles stay inert rather than being reassigned.
- Invalid trader files are preserved and not overwritten by the Creator; gameplay disables their trading with a warning. Items removed from the catalogue are not purchasable.

The Ollama adapter has no access to inventories. Trader replies use a bounded JSON schema containing `reply`, `item_id`, `quantity`, supported by [Ollama structured outputs](https://docs.ollama.com/capabilities/structured-outputs). Prices always come from the game, never model-generated values. Partial JSON is not shown in speech bubbles. Ordinary NPC dialogue retains its text streaming. Trader prompts use only the assigned persona to leave room for stock and schema within the bounded context; presets load at map startup and are excluded from ordinary random persona pools. Natural-language recognition depends on the selected local model; Shop is the deterministic fallback, not a promise of universal recognition or instant responses.

## Focused checks

`tools/tests/verify_traders.gd` covers validation, unaccepted/cancelled purchases, price changes, funds/stock, disk reload and replacement, save-failure rollback, Creator field persistence and the actual Albury NPC page, structured intent parsing, and real runtime conversation → confirmation → acceptance → one event. Test purchases write only to a unique test fixture, not Albury saves.

`tools/tests/verify_trader_ollama.gd` performed a live check with installed `llama3.2:3b`: it recognised one beer and returned a complete spoken response in 15.15 seconds. That is a single focused model check, not a latency guarantee. Inventory, Creator UI, saved interior NPC and pub-entry regressions passed. Extended gameplay/performance and alternative models remain user-tested. Existing sandbox log/certificate and image-import warnings remain.

The `--render` trader check also passed, and `docs/screenshots/trader_confirmation_ui.png` was visually inspected for readable fields and in-screen controls. This is an actual Godot UI-test capture, not a town gameplay screenshot or concept art. Deleting, saving, reopening and adding a storyline NPC in the temporary fixture retained a new ID rather than recycling the deleted one.

`verify_creator_tool_tiles.gd` additionally checks separate lists, identical human choices, NPR filtering, Back-preserved drafts, legacy mapping, direct interior trader placement/preview, selection of the new trader's stock editor and the actual Save callback in a temporary directory. Read-only Albury files were compared before/after. Rendered hub/trader-page captures were inspected; extended gameplay remains user-tested.
