extends SceneTree

const Lore = preload("res://scripts/npcs/lore/game_lore_store.gd")
const Runtime = preload("res://scripts/runtime/town_runtime.gd")
const Personas = preload("res://scripts/npcs/persona_store.gd")
const Dialogue = preload("res://scripts/npcs/ollama_dialogue_client.gd")
const Loader = preload("res://scripts/npcs/local_llm_startup_loader.gd")
var received := false
var successful := false
var detail := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(100).timeout.connect(func(): printerr("LIVE GAME LORE TIMED OUT"); quit(1))
	var library := Personas.recommended_data()
	var provider: Dictionary = library.provider.duplicate(true)
	provider.timeout_seconds = 30.0
	provider.temperature = 0.0
	var runtime := Runtime.new()
	runtime.town = {"display_name":"Test town"}
	runtime.game_lore_text = FileAccess.get_file_as_string(Lore.EXAMPLE_PATH)
	runtime._prepare_dialogue_context()
	var loader := Loader.new()
	root.add_child(loader)
	loader.completed.connect(func(ok, message, seconds): received = true; successful = ok; detail = message; print("LORE WARMUP %.2fs: %s" % [seconds,message]))
	var started := loader.preload_model(provider,"",[],runtime.prepared_dialogue_system)
	if not started.ok: printerr(started.message); quit(1); return
	while not received: await create_timer(0.1).timeout
	if not successful: printerr(detail); quit(1); return
	var adapter := Dialogue.new()
	root.add_child(adapter)
	adapter.reply_ready.connect(func(ok, reply, message): received = true; successful = ok; detail = reply if ok else message)
	var cases := [
		{"id":"civic_robot","question":"Are you allowed to harm humans, and what service do you provide?","location":"You are inside The Pub, ground floor, in Test town."},
		{"id":"friendly_local","question":"Why do some residents distrust the counselling robots?","location":"You are outdoors on a street in Test town."}
	]
	for item in cases:
		received = false
		var began := Time.get_ticks_msec()
		var persona := Personas.find_persona(library,item.id).duplicate(true)
		persona.character_name = "Test robot" if item.id == "civic_robot" else "Test resident"
		var asking := adapter.ask(persona,item.question,[],provider,item.location,[],{},runtime.prepared_dialogue_system)
		if not asking.ok: printerr(asking.message); quit(1); return
		while not received: await create_timer(0.1).timeout
		if not successful: printerr(detail); quit(1); return
		print("LIVE LORE %s %.2fs: %s" % [item.id,float(Time.get_ticks_msec()-began)/1000.0,detail])
		var lower := detail.to_lower()
		if item.id == "civic_robot":
			assert((lower.contains("not") or lower.contains("never") or lower.contains("cannot")) and (lower.contains("harm") or lower.contains("hurt")) and (lower.contains("counsel") or lower.contains("support")))
		else:
			assert(lower.contains("trust") or lower.contains("fear") or lower.contains("concern") or lower.contains("sceptic") or lower.contains("worr"))
		assert(detail.split(" ",false).size() <= 28 and not lower.contains("motto"), "Lore replies must stay short and not invent a motto.")
	adapter.queue_free()
	loader.queue_free()
	runtime.free()
	await process_frame
	print("LIVE GAME LORE PASSED: installed llama3.2:3b used startup lore for indoor NPR non-harm/counselling and outdoor NPC divided public attitudes. No town or player writes.")
	quit()
