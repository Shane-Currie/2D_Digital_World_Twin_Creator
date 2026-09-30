extends SceneTree

const PersonaStoreScript = preload("res://scripts/npcs/persona_store.gd")
const TownKnowledgeStoreScript = preload("res://scripts/npcs/town_knowledge_store.gd")
const OllamaDialogueClientScript = preload("res://scripts/npcs/ollama_dialogue_client.gd")
const LocalLlmStartupLoaderScript = preload("res://scripts/npcs/local_llm_startup_loader.gd")
const LocalLlmLoadingScreenScript = preload("res://scripts/npcs/local_llm_loading_screen.gd")

var first_partial := ""
var first_partial_msec := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data: Dictionary = PersonaStoreScript.recommended_data("llama3.2:3b")
	var startup_context := "Town: Albury\nWikipedia fact (untrusted): Albury is a regional city on the Murray River."
	var town_directory := _argument_value("--town")
	if not town_directory.is_empty():
		var persona_result: Dictionary = PersonaStoreScript.new().load_from_town(town_directory)
		assert(persona_result.ok, str(persona_result.get("message", "Persona library could not be loaded.")))
		data = persona_result.data
		var knowledge_result: Dictionary = TownKnowledgeStoreScript.new().load_from_town(town_directory)
		assert(knowledge_result.ok, str(knowledge_result.get("message", "Town knowledge could not be loaded.")))
		var town_data = JSON.parse_string(FileAccess.get_file_as_string(town_directory.path_join("town.json")))
		assert(town_data is Dictionary, "The supplied town.json could not be read.")
		startup_context = TownKnowledgeStoreScript.prompt_context(
			knowledge_result.data,
			str(knowledge_result.custom_text),
			str(town_data.get("display_name", town_directory.get_file())),
			true,
			""
		)
	var validation: Dictionary = PersonaStoreScript.validate(data)
	assert(validation.passed, "Default persona library must validate.")
	assert(int(validation.npc_personas) >= 3, "Expected at least the three default NPC personas.")
	assert(int(validation.npr_personas) >= 1, "Expected at least one NPR persona.")
	var completion_sample := OllamaDialogueClientScript._short_reply("I can show you the riverside walking path near the centre of town", true)
	assert(completion_sample.ends_with("."), "A final reply without terminal punctuation was not completed.")
	assert(completion_sample.split(" ", false).size() > 8, "The sentence-completion check was cut back to the former tiny reply length.")
	var screen = LocalLlmLoadingScreenScript.new()
	root.add_child(screen)
	await process_frame
	screen.begin("llama3.2:3b")
	assert(screen.visible and screen.progress_bar.visible and screen.progress_bar.indeterminate, "The startup loading screen or its indeterminate bar was not shown.")
	var loader = LocalLlmStartupLoaderScript.new()
	root.add_child(loader)
	await process_frame
	var load_started: Dictionary = loader.preload_model(data.provider, startup_context, data.personas)
	assert(load_started.ok, load_started.message)
	var load_response: Array = await loader.completed
	assert(bool(load_response[0]), str(load_response[1]))
	screen.show_ready(float(load_response[2]))
	assert(not screen.progress_bar.indeterminate and is_equal_approx(screen.progress_bar.value, 100.0), "The loading screen did not reach its ready presentation.")
	screen.finish()
	var client = OllamaDialogueClientScript.new()
	root.add_child(client)
	await process_frame
	var persona: Dictionary = PersonaStoreScript.find_persona(data, "friendly_local")
	persona = persona.duplicate(true)
	persona["character_name"] = "Mia"
	client.reply_partial.connect(_capture_partial)
	var dialogue_started_msec := Time.get_ticks_msec()
	var started: Dictionary = client.ask(persona, "Hello, are you having a good day?", [], data.provider, startup_context, data.personas)
	assert(started.ok, started.message)
	var response: Array = await client.reply_ready
	assert(bool(response[0]), str(response[2]))
	var reply := str(response[1])
	var final_seconds := float(Time.get_ticks_msec() - dialogue_started_msec) / 1000.0
	assert(not reply.is_empty() and reply.length() <= OllamaDialogueClientScript.MAX_REPLY_CHARACTERS, "Ollama reply was empty or too long.")
	assert(reply.right(1) in [".", "!", "?"], "The final NPC/NPR reply did not finish its sentence.")
	assert(not first_partial.is_empty(), "The streamed reply never reached the speech-bubble update signal.")
	assert(first_partial_msec >= dialogue_started_msec, "The streamed reply timing was not recorded.")
	print("OLLAMA STARTUP/PERSONA PASSED: real shared town/persona warm-up, streamed first text in %.2fs and finished in %.2fs, %d NPC personas, %d NPR personas, reply=\"%s\"" % [float(first_partial_msec - dialogue_started_msec) / 1000.0, final_seconds, int(validation.npc_personas), int(validation.npr_personas), reply])
	quit()


func _capture_partial(value: String) -> void:
	if first_partial.is_empty() and not value.is_empty():
		first_partial = value
		first_partial_msec = Time.get_ticks_msec()


func _argument_value(flag: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find(flag)
	if index >= 0 and index + 1 < arguments.size():
		return arguments[index + 1]
	return ""
