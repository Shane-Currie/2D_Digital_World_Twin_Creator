extends SceneTree

const TraderStore = preload("res://scripts/npcs/traders/trader_store.gd")
const StorylineStore = preload("res://scripts/npcs/storyline_npc_store.gd")
const PersonaStore = preload("res://scripts/npcs/persona_store.gd")

func _initialize() -> void:
	call_deferred("_run")

func _ids(choice: OptionButton) -> Array:
	var result: Array = []
	for i in choice.item_count: result.append(str(choice.get_item_metadata(i)))
	return result

func _capture(path: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	assert(image.save_png(path) == OK)

func _run() -> void:
	print("Tool tiles test process: ", OS.get_process_id())
	create_timer(45).timeout.connect(func():
		printerr("Tool tiles test timed out after an assertion or unfinished check.")
		quit(1))
	var directory := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var before := FileAccess.get_file_as_string(directory.path_join("data/storyline_npcs.json"))
	var before_traders := FileAccess.get_file_as_string(directory.path_join("data/trader_npcs.json"))
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio._load_existing_project(directory)
	studio._show_personas_page()
	var expected_traders: Array = []
	for npc in studio.storyline_npc_data.npcs:
		if TraderStore.npc_role(npc, studio.trader_editor.data) == "trader": expected_traders.append(str(npc.id))
	await process_frame
	var menu = studio.npc_tools_navigation
	assert(menu.tiles.get_child_count() == 6 and menu.hub_scroll.visible and not menu.back_button.visible)
	if OS.get_cmdline_user_args().has("--render"):
		await _capture(ProjectSettings.globalize_path("res://docs/screenshots/npc_tool_tiles.png"))
	menu.open_page("storyline")
	assert(menu.back_button.visible and studio.npc_placement_panel.is_visible_in_tree())
	assert(not _ids(studio.storyline_npc_option).has("storyline_npc_004"), "Moe still appears as a storyline NPC.")
	var storyline_personas := _ids(studio.storyline_persona_option)
	assert(not storyline_personas.has("civic_robot") and storyline_personas.has("trader_barkeep"))
	studio.storyline_name_edit.text = "Storyline draft"
	menu.back_button.pressed.emit()
	menu.open_page("trader")
	assert(studio.placed_npc_role == "trader" and _ids(studio.storyline_npc_option) == expected_traders)
	assert(_ids(studio.storyline_persona_option) == storyline_personas, "Trader placement has different persona options.")
	assert(_ids(studio.trader_editor.npc_choice) == expected_traders)
	assert(not _ids(studio.trader_editor.persona_choice).has("civic_robot"))
	studio._select_placed_npc_for_edit(0)
	if OS.get_cmdline_user_args().has("--render"):
		await _capture(ProjectSettings.globalize_path("res://docs/screenshots/trader_tool_page.png"))
	for i in studio.storyline_persona_option.item_count:
		if str(studio.storyline_persona_option.get_item_metadata(i)) == "friendly_local": studio.storyline_persona_option.select(i)
	studio._update_placed_npc_identity()
	studio.trader_editor._flush_profile()
	assert(studio.trader_editor.data.traders.storyline_npc_004.persona_id == "friendly_local", "Stock form reverted the placement persona.")
	studio.storyline_name_edit.text = "Trader draft"
	menu.show_home()
	menu.open_page("storyline")
	assert(studio.storyline_name_edit.text == "Storyline draft", "Back discarded a placement draft.")
	menu.open_page("trader")
	assert(studio.storyline_name_edit.text == "Trader draft")
	menu.open_page("npr")
	assert(studio.persona_new_npr_button.visible and not studio.persona_new_npc_button.visible)
	assert(_ids(studio.persona_option).has("civic_robot"))
	for index in studio.persona_visible_indices:
		assert(studio.persona_data.personas[index].actor_kind == "npr", "Human persona appeared in NPR tools.")
	for i in studio.persona_option.item_count:
		if str(studio.persona_option.get_item_metadata(i)) == "civic_robot":
			studio.persona_option.select(i)
			studio._on_persona_selected(i)
	studio.persona_name_edit.text = "Robot draft"
	menu.show_home()
	menu.open_page("generic")
	assert(not _ids(studio.persona_option).has("civic_robot"))
	menu.open_page("npr")
	assert(studio.persona_name_edit.text == "Robot draft", "NPR edits were lost or assigned to the wrong human persona.")
	studio._show_interior_designer_page()
	await process_frame
	menu = studio.interior_tools_navigation
	assert(menu.tiles.get_child_count() == 8 and menu.hub_scroll.visible)
	assert(studio.interior_building_option.is_visible_in_tree() and studio.interior_save_button.is_visible_in_tree())
	for i in studio.interior_eligible_features.size():
		if str(studio.interior_eligible_features[i].id) == "601183200":
			studio.interior_building_option.select(i)
			studio._on_interior_building_selected(i)
	if OS.get_cmdline_user_args().has("--render"):
		await _capture(ProjectSettings.globalize_path("res://docs/screenshots/interior_tool_tiles.png"))
	menu.open_page("floors")
	studio.interior_size_control.value = 175
	menu.back_button.pressed.emit()
	menu.open_page("floors")
	assert(studio.interior_size_control.value == 175, "Back reset floor settings.")
	menu.open_page("npcs")
	studio.interior_npc_role_option.select(1)
	studio.interior_npc_name_edit.text = "Tile test trader"
	studio._begin_interior_npc_placement()
	var before_count: int = studio.storyline_npc_data.npcs.size()
	var found := false
	for x in range(2, 50, 2):
		for y in range(2, 40, 2):
			studio._on_interior_storyline_location_requested(Vector2(x,y))
			if studio.storyline_npc_data.npcs.size() > before_count:
				found = true
				break
		if found: break
	assert(found, "No staged interior trader was created through the NPC tool.")
	var added: Dictionary = studio.storyline_npc_data.npcs.back()
	assert(added.npc_role == "trader" and str(added.id).begins_with("trader_npc_") and added.location.floor_id == "ground_floor")
	assert(studio.interior_trader_data.traders.has(str(added.id)))
	assert(studio.interior_floor_canvas.interior_npcs.size() >= 2, "Interior trader was not visible for dragging.")
	assert(FileAccess.get_file_as_string(directory.path_join("data/storyline_npcs.json")) == before)
	assert(FileAccess.get_file_as_string(directory.path_join("data/trader_npcs.json")) == before_traders)
	var classified := TraderStore.classify_placements({"npcs": [{"id": "legacy", "persona_id": "friendly_local"}, {"id": "ordinary", "npc_role": "storyline", "persona_id": "friendly_local"}]}, {"traders": {"legacy": {"enabled": true, "persona_id": "trader_barkeep", "offers": []}}})
	assert(classified.npcs[0].npc_role == "trader" and classified.npcs[0].persona_id == "trader_barkeep" and classified.npcs[1].npc_role == "storyline")
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/tool_tiles_%d" % OS.get_process_id())
	var library := TraderStore.shared_personas(PersonaStore.new().load_from_town(directory).data)
	assert(PersonaStore.new().save_to_town(temporary, library).ok)
	var saved := StorylineStore.new().save_to_town(temporary, studio.storyline_npc_data, {}, [], library, studio.interior_data)
	assert(saved.ok, "Roles/interior trader did not save.")
	var reloaded := StorylineStore.new().load_from_town(temporary, {}, [], library, studio.interior_data)
	assert(reloaded.ok and reloaded.data.npcs.back().npc_role == "trader")
	assert(TraderStore.new().save_to_town(temporary, studio.interior_trader_data, reloaded.data, preload("res://scripts/inventory/item_catalog_store.gd").default_data(), library).ok)
	assert(DirAccess.copy_absolute(directory.path_join("data/building_interiors.json"), temporary.path_join("data/building_interiors.json")) == OK)
	# Exercise the actual sticky Save callback on a disposable town directory.
	studio.loaded_project_directory = temporary
	studio._show_personas_page()
	studio.npc_tools_navigation.open_page("trader")
	assert(_ids(studio.storyline_npc_option).has(str(added.id)))
	studio._refresh_storyline_npc_controls(str(added.id))
	assert(studio.trader_editor.selected_id == str(added.id), "New trader's stock editor selected a different character.")
	studio._select_placed_npc_for_edit(studio.storyline_npc_option.selected)
	studio.storyline_name_edit.text = "Saved tile trader"
	studio._update_placed_npc_identity()
	studio._save_persona_library()
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(temporary.path_join("data/storyline_npcs.json")))
	assert(disk.npcs.back().display_name == "Saved tile trader" and disk.npcs.back().npc_role == "trader")
	assert(FileAccess.get_file_as_string(directory.path_join("data/storyline_npcs.json")) == before)
	assert(FileAccess.get_file_as_string(directory.path_join("data/trader_npcs.json")) == before_traders)
	var customised := TraderStore.shared_personas(PersonaStore.recommended_data())
	for entry in customised.personas:
		if entry.id == "trader_barkeep": entry.greeting = "Creator-edited greeting"
	assert(TraderStore.persona("trader_barkeep", customised).greeting == "Creator-edited greeting")
	studio.queue_free()
	await process_frame
	print("CREATOR TOOL TILES PASSED: hubs/Back/Save, drafts, NPC/NPR filters, separate trader/storyline lists, identical human personas, legacy identity/persona/stock mapping, interior trader creation/visibility and temporary persistence; Albury unchanged.")
	quit()
