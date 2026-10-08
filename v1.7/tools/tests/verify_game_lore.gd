extends SceneTree

const Lore = preload("res://scripts/npcs/lore/game_lore_store.gd")
const Runtime = preload("res://scripts/runtime/town_runtime.gd")
const Personas = preload("res://scripts/npcs/persona_store.gd")
const Dialogue = preload("res://scripts/npcs/ollama_dialogue_client.gd")
const Loader = preload("res://scripts/npcs/local_llm_startup_loader.gd")

func _initialize() -> void:
	call_deferred("_run")

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file.close()

func _capture(filename: String) -> void:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/"+filename)) == OK)

func _run() -> void:
	create_timer(45).timeout.connect(func(): printerr("GAME LORE CHECK TIMED OUT"); quit(1))
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/game-lore-%s" % OS.get_process_id())
	assert(DirAccess.make_dir_recursive_absolute(temporary) == OK)
	var store := Lore.new()
	assert(store.load_from_town(temporary).ok and store.load_from_town(temporary).text.is_empty())
	var original := FileAccess.get_file_as_string(Lore.EXAMPLE_PATH)
	assert(original.length() <= Lore.MAX_PROMPT_CHARACTERS and original.contains("counselling services only") and original.contains("not to harm humans"))
	var imported := store.import_text(temporary,Lore.EXAMPLE_PATH)
	assert(imported.ok and imported.text == original and store.load_from_town(temporary).text == original)
	assert(FileAccess.get_file_as_string(Lore.EXAMPLE_PATH) == original)
	var first_copy: String = temporary.path_join(imported.data.lore.relative_path)
	var metadata := FileAccess.get_file_as_string(temporary.path_join(Lore.FILE_NAME))
	_write(temporary.path_join("empty.txt"),"")
	var binary := FileAccess.open(temporary.path_join("binary.txt"),FileAccess.WRITE)
	binary.store_buffer(PackedByteArray([1,0,255]))
	binary.close()
	_write(temporary.path_join("oversized.txt"),"x".repeat(65537))
	for filename in ["empty.txt","binary.txt","oversized.txt","absent.txt"]:
		assert(not store.import_text(temporary,temporary.path_join(filename)).ok)
		assert(FileAccess.get_file_as_string(temporary.path_join(Lore.FILE_NAME)) == metadata)
	_write(temporary.path_join("signature.txt"),String.chr(0xfeff)+"UTF-8 Windows lore.")
	assert(store.import_text(temporary,temporary.path_join("signature.txt")).ok)
	assert(store.load_from_town(temporary).text == "UTF-8 Windows lore.")
	assert(store.import_text(temporary,Lore.EXAMPLE_PATH).ok, "Replacing metadata failed.")
	assert(store.remove_from_town(temporary).ok and store.load_from_town(temporary).text.is_empty())
	assert(FileAccess.file_exists(first_copy), "Removal must keep the copied file recoverable.")
	_write(temporary.path_join(Lore.FILE_NAME),'{"schema_version":1,"lore":{"relative_path":"../unsafe.txt"}}')
	var invalid := FileAccess.get_file_as_string(temporary.path_join(Lore.FILE_NAME))
	assert(not store.load_from_town(temporary).ok and not store.import_text(temporary,Lore.EXAMPLE_PATH).ok)
	assert(FileAccess.get_file_as_string(temporary.path_join(Lore.FILE_NAME)) == invalid)
	_write(temporary.path_join(Lore.FILE_NAME),JSON.stringify(Lore.empty_data()))
	assert(store.import_text(temporary,Lore.EXAMPLE_PATH).ok)
	_write(first_copy,"Edited without reuploading.")
	assert(store.load_from_town(temporary).text.is_empty() and not store.load_from_town(temporary).warnings.is_empty())
	assert(store.import_text(temporary,Lore.EXAMPLE_PATH).ok)
	# Prepare the actual shared prompt and inspect requests for both actor kinds.
	var runtime := Runtime.new()
	runtime.town = {"display_name":"Test town"}
	runtime.game_lore_text = store.load_from_town(temporary).text
	runtime._prepare_dialogue_context()
	assert(runtime.prepared_dialogue_system.contains(original) and runtime.prepared_dialogue_system.contains("fictional GAME LORE"))
	var library := Personas.recommended_data()
	var adapter := Dialogue.new()
	root.add_child(adapter)
	for id in ["friendly_local","civic_robot"]:
		var persona := Personas.find_persona(library,id)
		assert(adapter.ask(persona,"Why are robots here?",[],library.provider,"You are in Test town.",[],{},runtime.prepared_dialogue_system).ok)
		var payload: Dictionary = JSON.parse_string(adapter.request_body)
		assert(payload.messages[0].content == runtime.prepared_dialogue_system and payload.messages[0].content.contains("not to harm humans"))
		adapter.cancel()
	var loader := Loader.new()
	root.add_child(loader)
	assert(loader.preload_model(library.provider,"",[],runtime.prepared_dialogue_system).ok)
	assert(loader.warmup_prompts[0] == runtime.prepared_dialogue_system)
	loader.cancel()
	var cached := runtime.game_lore_text
	assert(store.remove_from_town(temporary).ok and runtime.game_lore_text == cached, "Gameplay must use its startup cache, not reread disk each turn.")
	assert(Lore.query_context(original,"robots").is_empty())
	assert(Lore.query_context("Background. ".repeat(200)+"Moon gardens supply oxygen.","moon gardens oxygen").contains("Moon gardens"))
	runtime.game_lore_text = ""
	runtime._prepare_dialogue_context()
	assert(not runtime.prepared_dialogue_system.contains("<game_lore>"))
	# Actual Creator page, disposable project; no user town data is saved.
	_write(temporary.path_join("town.json"),'{}')
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio.last_created_directory = temporary
	studio._show_game_settings_page()
	await process_frame
	var menu = studio.settings_tools_navigation
	assert(menu.tiles.get_child_count() == 8 and not menu.pages.has("trees") and menu.hub_scroll.visible)
	assert(studio.settings_controls.size() == 24)
	if OS.get_cmdline_user_args().has("--render"): await _capture("game_settings_tool_tiles.png")
	menu.open_page("camera")
	studio.settings_controls["camera.character_zoom"].value = 1.65
	menu.back_button.pressed.emit()
	menu.open_page("camera")
	assert(studio.settings_controls["camera.character_zoom"].value == 1.65, "Back lost settings edits.")
	menu.open_page("lore")
	var editor = studio.game_lore_editor
	editor.example_button.pressed.emit()
	assert(editor.preview.text == original and store.load_from_town(temporary).text == original)
	menu.show_home()
	menu.open_page("lore")
	assert(editor.preview.text == original)
	if OS.get_cmdline_user_args().has("--render"): await _capture("game_lore_editor.png")
	editor.remove_button.pressed.emit()
	assert(editor.preview.text.is_empty() and store.load_from_town(temporary).text.is_empty())
	studio.settings_town_edit.text = temporary.path_join("missing")
	studio._load_game_settings()
	assert(editor.upload_button.disabled and editor.example_button.disabled)
	studio.queue_free()
	adapter.queue_free()
	loader.queue_free()
	runtime.free()
	await process_frame
	print("GAME LORE PASSED: safe optional UTF-8 copy/replace/remove, corrupt/path/size/hash rejection, startup cache and identical NPC/NPR/warm-up prefix, query excerpts, 8 settings tiles, Back drafts and example preview. User towns untouched.")
	quit()
