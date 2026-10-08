extends SceneTree

class TestStudio:
	extends "res://scripts/app/creator_studio.gd"
	var launched: Array[String] = []
	func _launch_playable_preview(path: String) -> void: launched.append(path)
	func _save_workspace_preference(_path: String) -> void: pass
	func _save_recent_project(_path: String) -> void: pass

var studio
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	for i in 5: await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1; push_error(message)
		if studio.section_history_kind != "":
			var now: Dictionary = studio._section_snapshot()
			var before: Dictionary = studio.section_saved_snapshot
			for key in now:
				if now[key] != before.get(key): print("DIFFERENCE ", key)
func button_named(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := button_named(child, text)
		if found != null: return found
	return null
func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("SAVED NAVIGATION TIMEOUT"); quit(2))
	studio = load("res://scenes/creator_studio.tscn").instantiate()
	studio.set_script(TestStudio); root.add_child(studio); await frames()
	studio._show_town_import_page(); await frames()
	studio._on_osm_files_selected(PackedStringArray([ProjectSettings.globalize_path("res://tools/tests/fixtures/tiny_town.osm")]))
	studio._scan_osm_files()
	studio._on_cbd_changed(studio.imported_town.bounds)
	for feature in studio.imported_town.features:
		if str(feature.kind) != "road": continue
		for point in feature.points:
			studio.map_canvas._set_start_from_screen(studio.map_canvas._geographic_to_screen(point))
			if not studio.selected_start.is_empty(): break
		if not studio.selected_start.is_empty(): break
	studio.town_name_edit.text = "Navigation fixture"
	studio.town_name_edit.text_changed.emit("Navigation fixture")
	studio.workspace_edit.text = ProjectSettings.globalize_path("res://tools/tests/output/saved-navigation-%s" % OS.get_process_id())
	check(studio._create_town_project(), "Create valid navigation fixture")
	var directory: String = studio.loaded_project_directory
	if directory.is_empty(): quit(1); return
	var house: Dictionary = studio.imported_town.features.filter(func(f): return str(f.kind) == "building")[0]
	var blank: Dictionary = studio.building_interior_store.create_blank_ground_floor(studio.building_interior_store.empty_data(), house)
	check(blank.ok and studio.building_interior_store.save_to_town(directory, blank.data).ok, "Valid blank interior for section checks")
	for entry in [["_show_town_import_page","import_tools_navigation"],["_show_game_settings_page","settings_tools_navigation"],["_show_advanced_map_editor_page","editor_tools_navigation"],["_show_building_creator_page","building_tools_navigation"],["_show_interior_designer_page","interior_tools_navigation"],["_show_personas_page","npc_tools_navigation"],["_show_inventory_page",""]]:
		studio.call(entry[0]); await frames()
		check(not studio._section_is_dirty(), "Fresh section clean: " + entry[0])
		if not str(entry[1]).is_empty():
			var tools = studio.get(entry[1])
			for id in tools.pages:
				tools.open_page(id); await frames()
				check(not studio._section_is_dirty(), "Tool selection not a content change: %s / %s" % [entry[0], id])
				tools.back_button.pressed.emit(); await frames()
				check(tools.current_page.is_empty(), "Back returns to tool hub: " + id)
		studio._save_active_section(); await frames()
		check(studio.section_save_succeeded and not studio._section_is_dirty(), "Save leaves section clean: " + entry[0])
		studio.message_dialog.hide()
	studio._load_existing_project(directory); await frames()
	studio.sidebar_navigation_buttons.import.pressed.emit(); await frames()
	check(studio.loaded_project_directory == directory and not studio.imported_town.is_empty(), "Sidebar Import resumes existing town setup")
	check(not is_instance_valid(studio.new_town_dialog) or not studio.new_town_dialog.visible, "Editing existing town does not offer session clearing")
	studio.town_name_edit.text = "Edited town name"
	studio.town_name_edit.text_changed.emit("Edited town name")
	studio.sidebar_navigation_buttons.settings.pressed.emit(); await frames()
	check(is_instance_valid(studio.section_leave_dialog) and studio.section_leave_dialog.visible, "Real edit triggers Save/Discard/Stay")
	studio.section_leave_dialog.get_ok_button().pressed.emit(); await frames()
	check(studio.section_history_kind == "settings", "Popup Save navigates to requested menu")
	check(not studio.section_leave_dialog.visible, "Successful Save dismisses leave prompt")
	check(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("town.json"))).display_name == "Edited town name", "Popup Save persists actual name change")
	studio.sidebar_navigation_buttons.import.pressed.emit(); await frames()
	studio.import_tools_navigation.open_page("player"); await frames()
	var old_start: Dictionary = studio.selected_start.duplicate(true)
	var road: Dictionary = studio.imported_town.features.filter(func(f): return str(f.kind) == "road")[0]
	studio.map_canvas._set_start_from_screen(studio.map_canvas._geographic_to_screen(road.points[-1])); await frames()
	check(studio.selected_start != old_start and not studio.selected_start.is_empty(), "Existing town player/start location can be changed from Import")
	studio.create_town_button.pressed.emit(); await frames()
	check(studio.section_save_succeeded and not studio._section_is_dirty(), "Header Save persists changed existing-town start and clears dirty state")
	check(JSON.stringify(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("town.json"))).starting_location) == JSON.stringify(studio.selected_start), "Saved player/car locations match edited locations")
	studio.sidebar_navigation_buttons.settings.pressed.emit(); await frames()
	check(studio.section_history_kind == "settings" and not studio.section_leave_dialog.visible, "Leaving after header Save needs no second Save prompt")
	# Every main menu, from every other main menu, via real sidebar buttons.
	var menu_labels := ["Import a town", "Play test project", "Game settings", "Advanced map editor", "Building Creator", "Interior designer", "NPCs and personas", "Inventory items", "System setup"]
	for viewport_size in [Vector2i(1280,800), Vector2i(1600,900)]:
		root.size = viewport_size; root.content_scale_size = viewport_size; await frames()
		for source in menu_labels:
			for target in menu_labels:
				var source_button := main_menu_button(source)
				source_button.pressed.emit(); await frames()
				main_menu_button(target).pressed.emit(); await frames()
				check(not studio.section_leave_dialog.visible and not studio.message_dialog.visible, "Clean navigation %s -> %s at %s" % [source,target,viewport_size])
	# NPC artwork selection and human/robot switching are browsing, not edits.
	main_menu_button("NPCs and personas").pressed.emit(); await frames()
	studio.npc_tools_navigation.open_page("creation"); await frames()
	check(studio.npc_tools_navigation.current_page == "creation", "NPC creator browsing test uses visible actual tool")
	for i in mini(3, studio.npc_creation_editor.list.item_count):
		studio.npc_creation_editor._select(i); await frames()
		check(not studio._section_is_dirty(), "Viewing another NPC template is not unsaved data")
	studio.npc_tools_navigation.open_page("robot_personas"); await frames()
	studio.persona_name_edit.text = "Robot persona changed"
	studio._record_section_edit()
	check(studio._section_is_dirty(), "Real robot persona edit still guarded")
	main_menu_button("Inventory items").pressed.emit(); await frames()
	check(studio.section_leave_dialog.visible, "Actual changed persona opens leave prompt")
	studio.section_leave_dialog.get_cancel_button().pressed.emit(); await frames()
	check(studio.section_history_kind == "npcs" and studio.persona_name_edit.text == "Robot persona changed" and not studio.section_leave_dialog.visible, "Stay retains current persona and closes prompt")
	check(not studio.section_pending_navigation.is_valid(), "Stay cancels stale destination")
	main_menu_button("Inventory items").pressed.emit(); await frames()
	studio.section_leave_dialog.get_ok_button().pressed.emit(); await frames()
	check(studio.section_history_kind == "inventory" and not studio.message_dialog.visible and not studio.section_leave_dialog.visible, "Save changed robot persona then navigate without covering dialog")
	check(studio.PersonaStoreScript.find_persona(studio.persona_store.load_from_town(directory).data,"civic_robot").name == "Robot persona changed", "Popup persona Save persists changed content")
	studio.inventory_editor.name_edit.text = "Discard this name"
	studio._record_section_edit()
	main_menu_button("Game settings").pressed.emit(); await frames()
	studio.section_leave_dialog.custom_action.emit("discard"); await frames()
	check(studio.section_history_kind == "settings" and not studio.section_leave_dialog.visible, "Discard restores draft and navigates")
	# Exercise save-success feedback windows (building/map) during navigation.
	for menu in ["Building Creator", "Advanced map editor"]:
		main_menu_button(menu).pressed.emit(); await frames()
		studio.building_exterior_data = studio.BuildingHeightProfile.set_floors(studio.building_exterior_data, str(house.id), 3 if menu == "Building Creator" else 4).data
		studio._record_section_edit()
		main_menu_button("Game settings").pressed.emit(); await frames()
		check(studio.section_leave_dialog.visible, "Changed building height requires save: " + menu)
		studio.section_leave_dialog.get_ok_button().pressed.emit(); await frames()
		check(studio.section_history_kind == "settings" and not studio.message_dialog.visible and not studio.section_leave_dialog.visible, "Save success popup does not block requested menu: " + menu)
	# Failed Save must retain data, even after an earlier successful Save.
	studio._show_inventory_page(); await frames()
	studio.inventory_editor.name_edit.text = "Must stay open"
	studio._record_section_edit()
	studio.section_save_callback = func(): studio._set_status("Deliberate test save failure; existing content unchanged.")
	main_menu_button("Game settings").pressed.emit(); await frames()
	studio.section_leave_dialog.get_ok_button().pressed.emit(); await frames()
	check(studio.section_history_kind == "inventory" and studio.inventory_editor.name_edit.text == "Must stay open" and not studio.section_save_succeeded, "Failed Save retains edited section, no stale success flag")
	check(studio.section_leave_dialog.visible and studio.status_label.text.contains("Deliberate test save failure"), "Failed Save explains cause and keeps navigation prompt available")
	studio.section_leave_dialog.get_cancel_button().pressed.emit(); await frames()
	studio._load_existing_project(directory); await frames()
	studio._show_play_test_page(); await frames()
	button_named(studio.content_area, "Play current project").pressed.emit(); await frames()
	check(studio.launched.size() == 1 and studio.launched[0] == directory, "Play action targets current project without real user-save writes")
	button_named(studio.content_area, "Back to town setup").pressed.emit(); await frames()
	check(studio.loaded_project_directory == directory and studio.import_tools_navigation != null, "Play Back retains current town setup")
	studio.queue_free(); await frames()
	print("SAVED NAVIGATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func main_menu_button(label: String) -> Button:
	var key: String = {"Import a town":"import","Play test project":"play","Game settings":"settings","System setup":"system"}.get(label, "")
	return studio.sidebar_navigation_buttons[key] if not key.is_empty() else button_named(studio, label)
