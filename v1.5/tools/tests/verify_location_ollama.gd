extends SceneTree

const Notes = preload("res://scripts/npcs/locations/location_notes_store.gd")
const Personas = preload("res://scripts/npcs/persona_store.gd")
const Dialogue = preload("res://scripts/npcs/ollama_dialogue_client.gd")
const Loader = preload("res://scripts/npcs/local_llm_startup_loader.gd")
var ready_result := false
var success := false
var detail := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(100).timeout.connect(func(): printerr("Live location check timed out."); quit(1))
	var town := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var notes := Notes.new().load_from_town(town)
	var interiors: Dictionary = preload("res://scripts/interiors/building_interior_store.gd").new().load_from_town(town).data
	var library: Dictionary = Personas.new().load_from_town(town).data
	var provider: Dictionary = library.provider.duplicate(true)
	provider.timeout_seconds = 30.0
	provider.max_reply_tokens = 64
	var prefix := Dialogue.catalog_system_prompt([], "Town: Albury.\n" + Notes.summary(notes.data, notes.texts))
	var loader := Loader.new()
	root.add_child(loader)
	loader.completed.connect(func(ok, message, seconds): ready_result = true; success = ok; detail = message; print("LIVE VENUE WARMUP: %.2fs; %s" % [seconds, message]))
	var started := loader.preload_model(provider, "", [], prefix)
	if not started.ok: printerr(started.message); quit(1); return
	while not ready_result: await create_timer(0.1).timeout
	if not success: printerr(detail); quit(1); return
	var adapter := Dialogue.new()
	root.add_child(adapter)
	adapter.reply_ready.connect(func(ok, reply, message): ready_result = true; success = ok and reply.to_lower().contains("without judgement"); detail = reply if ok else message)
	for space in ["interior", "outdoors"]:
		ready_result = false
		success = false
		var location := {"space": space, "building_id": "601183200" if space == "interior" else "", "floor_id": "ground_floor" if space == "interior" else ""}
		var context := Notes.conversation_context(notes.data, notes.texts, location, interiors, "What is the pub motto?")
		var persona := Personas.find_persona(library, "civic_robot" if space == "interior" else "friendly_local").duplicate(true)
		persona.character_name = "Test NPR" if space == "interior" else "Test resident"
		var beginning := Time.get_ticks_msec()
		var asking := adapter.ask(persona, "What is the exact motto of The Pub?", [], provider, context, [], {}, prefix)
		if not asking.ok: printerr(asking.message); quit(1); return
		while not ready_result: await create_timer(0.1).timeout
		if not success: printerr("LIVE VENUE FAILED (%s): %s" % [space, detail]); quit(1); return
		print("LIVE VENUE %s PASSED: %.2fs; %s" % [space, float(Time.get_ticks_msec()-beginning)/1000.0, detail])
	adapter.queue_free()
	loader.queue_free()
	await process_frame
	print("LIVE LOCATION OLLAMA PASSED: startup prefix, indoor NPR and outdoor NPC repeat the uploaded pub motto; no town or inventory writes.")
	quit()
