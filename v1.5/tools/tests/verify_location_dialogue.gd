extends SceneTree

const Notes = preload("res://scripts/npcs/locations/location_notes_store.gd")
const Policy = preload("res://scripts/npcs/traders/trader_dialogue_policy.gd")
const Service = preload("res://scripts/npcs/traders/trade_service.gd")
const Store = preload("res://scripts/npcs/storyline_npc_store.gd")
const Personas = preload("res://scripts/npcs/persona_store.gd")
const Catalog = preload("res://scripts/inventory/item_catalog_store.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
const Runtime = preload("res://scripts/runtime/town_runtime.gd")
const Dialogue = preload("res://scripts/npcs/ollama_dialogue_client.gd")

class TestInventory extends RefCounted:
	var trader_stock: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(45).timeout.connect(func(): printerr("LOCATION DIALOGUE test timed out."); quit(1))
	var real := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/location_dialogue_%d" % OS.get_process_id())
	var reference := real.path_join("data/location_notes/601183200.txt")
	var store := Notes.new()
	var imported := store.import_text(temporary, reference, "601183200", "The Pub", Notes.empty_data())
	assert(imported.ok)
	var loaded := store.load_from_town(temporary)
	assert(loaded.ok and loaded.texts["601183200"].contains("A pub to enjoy a beer without judgement"))
	assert(not store.import_text(temporary, reference, "../unsafe", "bad", loaded.data).ok)
	var invalid: Dictionary = loaded.data.duplicate(true)
	invalid.locations["601183200"].relative_path = "../outside.txt"
	assert(not store.save_to_town(temporary, invalid).ok)
	assert(store.load_from_town(temporary).ok)
	for invalid_kind in ["empty", "binary", "oversized"]:
		var source_path := temporary.path_join(invalid_kind + ".txt")
		var source := FileAccess.open(source_path, FileAccess.WRITE)
		if invalid_kind == "binary": source.store_buffer(PackedByteArray([0,255]))
		elif invalid_kind == "oversized": source.store_string("x".repeat(Notes.MAX_BYTES + 1))
		source.close()
		assert(not store.import_text(temporary, source_path, "601183200", "The Pub", loaded.data).ok)
	assert(store.load_from_town(temporary).texts["601183200"].contains("without judgement"))
	var interiors: Dictionary = preload("res://scripts/interiors/building_interior_store.gd").new().load_from_town(real).data
	var inside := Notes.conversation_context(loaded.data, loaded.texts, {"space": "interior", "building_id": "601183200", "floor_id": "ground_floor"}, interiors, "What is the pub motto?")
	assert(inside.contains("inside this venue") and inside.contains("Ground floor") and inside.contains("without judgement"))
	var outside := Notes.conversation_context(loaded.data, loaded.texts, {"space": "outdoors"}, interiors, "What is the pub motto?")
	assert(outside.contains("outdoors") and outside.contains("without judgement"))
	var unrelated := Notes.conversation_context(loaded.data, loaded.texts, {"space": "outdoors"}, interiors, "Nice weather today")
	assert(not unrelated.contains("without judgement"))
	# Generic/NPR GUI placement and preview, without saving into the user's town.
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio._load_existing_project(real)
	studio._show_interior_designer_page()
	for i in studio.interior_eligible_features.size():
		if str(studio.interior_eligible_features[i].id) == "601183200": studio.interior_building_option.select(i); studio._on_interior_building_selected(i)
	assert(studio.interior_location_notes_preview.text.contains("without judgement"))
	if OS.get_cmdline_user_args().has("--render"):
		studio.interior_tools_navigation.open_page("notes")
		for frame in 5: await process_frame
		studio.interior_tools_navigation.page_scroll.scroll_vertical = 200
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/interior_location_notes.png")) == OK)
	studio.interior_tools_navigation.open_page("npcs")
	var placed: Array = []
	for role_index in [2,3]:
		studio.interior_npc_role_option.select(role_index)
		studio._refresh_interior_npc_personas()
		assert(str(studio.interior_npc_persona_option.get_item_metadata(1)) == ("civic_robot" if role_index == 3 else "friendly_local"))
		studio.interior_npc_name_edit.text = "Location test %d" % role_index
		studio._begin_interior_npc_placement()
		var count: int = studio.storyline_npc_data.npcs.size()
		for x in range(2,50,2):
			for y in range(2,40,2):
				studio._on_interior_storyline_location_requested(Vector2(x,y))
				if studio.storyline_npc_data.npcs.size() > count: break
			if studio.storyline_npc_data.npcs.size() > count: break
		assert(studio.storyline_npc_data.npcs.size() == count + 1)
		placed.append(studio.storyline_npc_data.npcs.back().duplicate(true))
	assert(placed[0].npc_role == "generic" and placed[1].npc_role == "npr" and placed[1].actor_kind == "npr" and placed[1].appearance.npc_asset == "npr")
	var library: Dictionary = Personas.new().load_from_town(real).data
	var records := Store.empty_data()
	records.npcs = placed
	assert(Store.new().save_to_town(temporary, records, {}, [], library, interiors).ok)
	assert(Store.new().load_from_town(temporary, {}, [], library, interiors).ok)
	var robot_with_human := records.duplicate(true)
	robot_with_human.npcs[1].persona_id = "friendly_local"
	assert(not Store.validate(robot_with_human, {}, [], library, false, interiors).passed)
	var pop := Population.new()
	root.add_child(pop)
	pop.set_process(false)
	pop.set_persona_library(library)
	pop.set_storyline_npcs(records)
	pop._add_storyline_npcs({}, 8.0)
	pop.set_active_interior("601183200", "ground_floor")
	assert(pop.agents.size() == 2 and pop.agents[0].kind == "person" and pop.agents[1].kind == "robot")
	assert(pop.conversation_target_persona(1).actor_kind == "npr")
	assert(pop._agent_in_active_space(pop.agents[1]))
	# Location follows the actor's actual building/floor, not role or persona.
	for agent in pop.agents:
		var actor_context := Notes.conversation_context(loaded.data, loaded.texts, agent, interiors, "Where are we?")
		assert(actor_context.contains("The Pub") and actor_context.contains("inside this venue") and actor_context.contains("Ground floor"))
	var saved_actors: Dictionary = Store.new().load_from_town(real, {}, [], library, interiors).data
	for actor in saved_actors.npcs:
		if str(actor.get("building_id", "")) == "601183200" and str(actor.get("space", "")) == "interior":
			var actor_context := Notes.conversation_context(loaded.data, loaded.texts, actor, interiors, "Where are we?")
			assert(actor_context.contains("The Pub") and actor_context.contains("inside this venue"), str(actor.name))
	# Live stock and fast intent tests are independent of model choice/latency.
	var inventory := TestInventory.new()
	var catalog := Catalog.default_data()
	var profile := {"enabled": true, "trade_role": "Barkeep", "offers": [{"item_id": "beer", "stock": 3, "price_keks": 5}, {"item_id": "water", "stock": 0, "price_keks": 2}]}
	var stock := Service.context(inventory, "moe", profile, catalog)
	assert(stock.items.size() == 1 and stock.items[0].item_id == "beer")
	for text in ["Can I buy a beer?", "I'd like a beer please", "I'll take one beer", "one beer", "May I have one beer?"]:
		assert(Policy.classify(text, stock, catalog).get("quantity", 0) == 1, text)
	assert(Policy.classify("two beers please", stock, catalog).get("quantity", 0) == 2)
	for text in ["I don't want to buy beer", "I bought beer yesterday", "If I buy beer", "How much does beer cost?", "Do you have beer?"]:
		assert(not Policy.classify(text, stock, catalog).has("item_id"), text)
	assert(not Policy.classify("buy 4 beers", stock, catalog).has("item_id"))
	assert(not Policy.classify("I would like to know the pub motto", stock, catalog).get("handled", false))
	assert(Policy.validate_reply("I sell cocktails", {}, stock, catalog).reply == Policy.stock_reply(stock))
	assert(Policy.validate_reply("Water is available", {}, stock, catalog).reply == Policy.stock_reply(stock))
	assert(Policy.validate_reply("Here you go", {"item_id": "water", "quantity": 1}, stock, catalog).suggestion.is_empty())
	assert(Policy.validate_reply("Certainly", {"item_id": "beer", "quantity": 1}, stock, catalog, "I don't want beer").suggestion.is_empty())
	inventory.trader_stock = {"moe": {"beer": {"configured_stock": 3, "remaining": 0}}}
	stock = Service.context(inventory, "moe", profile, catalog)
	assert(stock.items.is_empty() and Dialogue.trade_schema(stock).properties.item_id.enum == [""])
	assert(not Policy.classify("buy beer", stock, catalog).has("item_id"))
	var runtime := Runtime.new()
	runtime.player_inventory = inventory
	runtime.item_catalog_data = catalog
	runtime.trader_data = {"traders": {"moe": profile}}
	runtime.location_notes_data = loaded.data
	runtime.location_note_texts = loaded.texts
	runtime.town = {"display_name": "Albury"}
	runtime.persona_data = library
	runtime._prepare_dialogue_context()
	assert(runtime.prepared_dialogue_system.contains("without judgement") and runtime.trader_contexts.moe.items.is_empty())
	var adapter := Dialogue.new()
	root.add_child(adapter)
	var ask := adapter.ask(library.personas[0], "What is the pub motto?", [], library.provider, inside, library.personas, {}, runtime.prepared_dialogue_system)
	assert(ask.ok)
	var payload: Dictionary = JSON.parse_string(adapter.request_body)
	assert(payload.messages[0].content == runtime.prepared_dialogue_system and payload.messages.back().content.contains("inside this venue") and payload.options.num_ctx == 2048)
	adapter.cancel()
	adapter.queue_free()
	runtime.free()
	pop.queue_free()
	studio.queue_free()
	await process_frame
	print("LOCATION DIALOGUE PASSED: safe text copy/cache, inside/outside motto context, generic/NPR UI placement/save/filter/artwork/runtime visibility, live sold-out stock, purchase phrasing/negation/counts, guarded replies and shared startup/request prefix.")
	quit()
