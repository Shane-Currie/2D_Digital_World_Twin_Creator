extends SceneTree

const CreatorStudioScript = preload("res://scripts/app/creator_studio.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	assert(not arguments.is_empty(), "Pass a Creator Studio town directory.")
	var source_town := arguments[0]
	var town_argument_index := arguments.find("--town")
	if town_argument_index >= 0 and town_argument_index + 1 < arguments.size():
		source_town = arguments[town_argument_index + 1]
	var test_town := OS.get_temp_dir().path_join("world_twin_persona_editor_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(test_town.path_join("data"))
	assert(DirAccess.copy_absolute(source_town.path_join("data/personas.json"), test_town.path_join("data/personas.json")) == OK, "Could not prepare the persona editor fixture.")
	assert(DirAccess.copy_absolute(source_town.path_join("data/town_knowledge.json"), test_town.path_join("data/town_knowledge.json")) == OK, "Could not prepare the town-knowledge fixture.")
	var navigation_file := FileAccess.open(test_town.path_join("data/navigation_graphs.json"), FileAccess.WRITE)
	navigation_file.store_string(JSON.stringify({"pedestrian": {"nodes": [{"id": 0, "latitude": -36.08, "longitude": 146.92}]}}))
	navigation_file.close()
	var creator = CreatorStudioScript.new()
	root.add_child(creator)
	await process_frame
	creator.loaded_project_directory = test_town
	creator._show_personas_page()
	await process_frame
	await process_frame
	var initial_count: int = creator.persona_option.item_count
	assert(initial_count >= 4, "Expected at least three NPC personas and one NPR persona.")
	for required_id in ["friendly_local", "busy_worker", "curious_visitor", "civic_robot"]:
		assert(not creator.persona_store.find_persona(creator.persona_data, required_id).is_empty(), "Missing required random-pool persona %s." % required_id)
	assert(creator.persona_model_option.item_count >= 1, "The model selector was not created.")
	assert(creator.wikipedia_url_edit != null and creator.town_text_dialog != null, "The optional Wikipedia/text controls were not created.")
	assert(creator.persona_page_scroll != null, "The persona configuration was not placed in a scrolling page.")
	assert(_find_button(creator.persona_page_scroll, "Save town information") != null, "The always-visible town-information save action was not created beside the URL status.")
	assert(creator.town_wikipedia_status_label.text.contains("No Wikipedia") or creator.town_wikipedia_status_label.text.contains("Cached"), "The optional Wikipedia state was not explained.")
	assert(creator.storyline_coordinate_edit != null and creator.storyline_name_edit != null and creator.storyline_persona_option != null and creator.storyline_npc_option != null, "The outdoor Storyline NPC creator was not shown.")
	assert(_find_button(creator.persona_page_scroll, "Place storyline NPC") != null, "The no-code Storyline NPC placement action was not created.")
	var scroll_bar: VScrollBar = creator.persona_page_scroll.get_v_scroll_bar()
	assert(scroll_bar.max_value > scroll_bar.page, "The persona page does not provide enough vertical scroll range to reach its lower controls.")
	var save_button := _find_button(creator.persona_page_scroll, "Save personas and town info")
	assert(save_button != null, "The persona and town-information save button was not found.")
	creator.persona_page_scroll.ensure_control_visible(save_button)
	await process_frame
	await process_frame
	assert(creator.persona_page_scroll.get_global_rect().intersects(save_button.get_global_rect()), "Scrolling could not bring the save button into view.")
	creator.wikipedia_url_edit.text = "https://en.wikipedia.org/wiki/Albury"
	creator._on_wikipedia_url_submitted(creator.wikipedia_url_edit.text)
	var saved_knowledge = JSON.parse_string(FileAccess.get_file_as_string(test_town.path_join("data/town_knowledge.json")))
	assert(saved_knowledge is Dictionary and str(saved_knowledge.wikipedia.url) == creator.wikipedia_url_edit.text, "Pressing Enter did not save the Wikipedia URL.")
	creator._new_npc_persona()
	assert(creator.persona_option.item_count == initial_count + 1, "The no-code custom NPC action did not add a persona.")
	var custom_npc_id := str(creator.persona_option.get_item_metadata(creator.persona_option.selected))
	creator.persona_name_edit.text = "Helpful Town Guide"
	creator._save_persona_form()
	creator._refresh_storyline_persona_choices(custom_npc_id)
	assert(str(creator.storyline_persona_option.get_item_metadata(creator.storyline_persona_option.selected)) == custom_npc_id, "A custom human persona was not available to the storyline NPC creator.")
	creator._new_npr_persona()
	assert(creator.persona_option.item_count == initial_count + 2, "The no-code custom NPR action did not add a persona.")
	creator.storyline_coordinate_edit.text = "-36.08000000, 146.92000000"
	creator.storyline_name_edit.text = "Avery Test"
	creator._refresh_storyline_persona_choices(custom_npc_id)
	creator._place_storyline_npc()
	assert(creator.storyline_npc_option.item_count == 1, "A pasted latitude and longitude did not create an outdoor Storyline NPC.")
	var saved_storyline = JSON.parse_string(FileAccess.get_file_as_string(test_town.path_join("data/storyline_npcs.json")))
	assert(saved_storyline is Dictionary and saved_storyline.npcs.size() == 1, "The Storyline NPC was not saved in canonical town data.")
	assert(str(saved_storyline.npcs[0].display_name) == "Avery Test", "The creator-provided Storyline NPC name was not saved.")
	assert(str(saved_storyline.npcs[0].persona_id) == custom_npc_id, "The creator-selected custom persona was not linked to the Storyline NPC.")
	assert(str(saved_storyline.npcs[0].appearance.mode) == "random_static_asset", "The first-stage random artwork contract was not saved.")
	var saved_personas = JSON.parse_string(FileAccess.get_file_as_string(test_town.path_join("data/personas.json")))
	assert(not creator.persona_store.find_persona(saved_personas, custom_npc_id).is_empty(), "Placing the character did not persist its custom persona library entry.")
	creator.queue_free()
	DirAccess.remove_absolute(test_town.path_join("data/personas.json"))
	DirAccess.remove_absolute(test_town.path_join("data/town_knowledge.json"))
	DirAccess.remove_absolute(test_town.path_join("data/storyline_npcs.json"))
	DirAccess.remove_absolute(test_town.path_join("data/navigation_graphs.json"))
	DirAccess.remove_absolute(test_town.path_join("data"))
	DirAccess.remove_absolute(test_town)
	print("PERSONA EDITOR PASSED: persona controls, town knowledge, scrolling, and named outdoor Storyline NPC placement are available.")
	quit()


func _find_button(node: Node, button_text: String) -> Button:
	if node is Button and str(node.text) == button_text:
		return node
	for child in node.get_children():
		var match := _find_button(child, button_text)
		if match != null:
			return match
	return null
