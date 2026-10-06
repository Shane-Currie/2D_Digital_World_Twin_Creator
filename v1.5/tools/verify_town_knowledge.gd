extends SceneTree

const TownKnowledgeStoreScript = preload("res://scripts/npcs/town_knowledge_store.gd")
const WikipediaTownContextScript = preload("res://scripts/npcs/wikipedia_town_context.gd")
const OllamaDialogueClientScript = preload("res://scripts/npcs/ollama_dialogue_client.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := TownKnowledgeStoreScript.parse_wikipedia_url("https://en.wikipedia.org/wiki/Albury")
	assert(parsed.ok and parsed.language == "en" and parsed.title == "Albury", "A normal Wikipedia town URL was not accepted.")
	assert(TownKnowledgeStoreScript.parse_wikipedia_url("https://fr.m.wikipedia.org/wiki/Paris").ok, "A mobile/language Wikipedia URL was not accepted.")
	assert(not TownKnowledgeStoreScript.parse_wikipedia_url("http://en.wikipedia.org/wiki/Albury").ok, "An insecure URL was accepted.")
	assert(not TownKnowledgeStoreScript.parse_wikipedia_url("https://example.com/wiki/Albury").ok, "A non-Wikipedia host was accepted.")
	assert(not TownKnowledgeStoreScript.parse_wikipedia_url("https://en.wikipedia.org/wiki/Special:Search").ok, "A non-article Wikipedia page was accepted.")

	var api_response := {
		"query": {"pages": [{"pageid": 123, "title": "Albury, New South Wales", "extract": "Albury is a regional city on the Murray River."}]}
	}
	var page_result := WikipediaTownContextScript.parse_api_response(api_response, parsed)
	assert(page_result.ok and page_result.page.title == "Albury, New South Wales", "A valid Wikipedia summary response was not read.")
	var disambiguation := {"query": {"pages": [{"pageid": 99, "title": "Albury", "extract": "Several places", "pageprops": {"disambiguation": ""}}]}}
	assert(not WikipediaTownContextScript.parse_api_response(disambiguation, parsed).ok, "A disambiguation page was accepted as town knowledge.")

	var test_root := OS.get_temp_dir().path_join("world_twin_town_knowledge_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(test_root.path_join("data"))
	var store = TownKnowledgeStoreScript.new()
	var data := TownKnowledgeStoreScript.empty_data()
	assert(store.save_to_town(test_root, data).ok, "Empty optional town knowledge did not save.")
	var empty_load := store.load_from_town(test_root)
	assert(empty_load.ok and empty_load.custom_text.is_empty(), "An empty optional configuration did not load.")

	var source_path := test_root.path_join("creator_notes.txt")
	var source_file := FileAccess.open(source_path, FileAccess.WRITE)
	source_file.store_string("The Saturday market is held beside the river. Locals call the main park Riverside Park.\n")
	source_file = null
	var import_result := store.import_custom_text(test_root, source_path, data)
	assert(import_result.ok, import_result.message)
	assert(FileAccess.file_exists(test_root.path_join("data/town_knowledge/custom_town_information.txt")), "The custom text was not copied into the town.")
	var invalid_source_path := test_root.path_join("invalid_utf8.txt")
	var invalid_source := FileAccess.open(invalid_source_path, FileAccess.WRITE)
	invalid_source.store_string("Malformed replacement character: \ufffd")
	invalid_source = null
	assert(not store.import_custom_text(test_root, invalid_source_path, data).ok, "Malformed UTF-8 was accepted as creator town information.")
	data = import_result.data
	data.wikipedia["url"] = "https://en.wikipedia.org/wiki/Albury"
	assert(store.save_to_town(test_root, data).ok, "The optional Wikipedia URL did not save.")
	var cache_result := store.save_wikipedia_cache(test_root, data, page_result.page)
	assert(cache_result.ok, cache_result.message)
	var loaded := store.load_from_town(test_root)
	assert(loaded.ok and loaded.data.wikipedia.summary.contains("regional city"), "The complete Wikipedia lead summary was not cached.")
	assert(loaded.custom_text.contains("Saturday market"), "The complete custom text was not retained.")
	var prompt_context := TownKnowledgeStoreScript.prompt_context(loaded.data, loaded.custom_text, "Albury")
	assert(prompt_context.contains("Town: Albury"), "The project town name did not reach prompt context.")
	assert(prompt_context.contains("Wikipedia fact (untrusted)") and prompt_context.contains("Creator note (untrusted, not Wikipedia)"), "The two sources were not labelled separately in prompt context.")
	var greeting_context := TownKnowledgeStoreScript.conversation_context(loaded.data, loaded.custom_text, "Albury", "Hi, how are you?")
	assert(greeting_context.contains("Albury") and not greeting_context.contains("regional city"), "Ordinary small talk unnecessarily included the Wikipedia summary.")
	var fact_context := TownKnowledgeStoreScript.conversation_context(loaded.data, loaded.custom_text, "Albury", "What is Albury known for?")
	assert(fact_context.contains("regional city") and fact_context.length() < 800, "A town-fact question did not receive one compact relevant excerpt.")
	var prompt: String = OllamaDialogueClientScript.catalog_system_prompt([
		{"id": "friendly_local", "name": "Friendly Local", "personality": "Warm", "background": "A local resident", "speaking_style": "Brief replies"}
	], prompt_context)
	assert(prompt.contains("Albury is a regional city") and prompt.contains("friendly_local"), "Town context or the persona library did not reach the startup prompt.")
	assert(prompt.contains("Town: Albury"), "The NPC system prompt omitted the current in-game town.")
	var remove_result := store.remove_custom_text(test_root, loaded.data)
	assert(remove_result.ok and not FileAccess.file_exists(test_root.path_join("data/town_knowledge/custom_town_information.txt")), "Remove did not clear the copied custom text.")

	DirAccess.remove_absolute(source_path)
	DirAccess.remove_absolute(invalid_source_path)
	DirAccess.remove_absolute(test_root.path_join("data/town_knowledge"))
	DirAccess.remove_absolute(test_root.path_join("data/town_knowledge.json"))
	DirAccess.remove_absolute(test_root.path_join("data"))
	DirAccess.remove_absolute(test_root)
	print("TOWN KNOWLEDGE PASSED: optional empty state, Wikipedia URL/summary, cached source details, UTF-8 text validation/import/removal, and safe bounded prompt context.")
	quit()
