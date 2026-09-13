extends SceneTree

const FIXTURE := "res://tools/tests/fixtures/tiny_town.osm"


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var packed_scene: PackedScene = load("res://scenes/creator_studio.tscn")
	var studio: Control = packed_scene.instantiate()
	root.add_child(studio)
	await process_frame
	studio._show_town_import_page()
	await process_frame

	assert(studio.start_button != null, "The dedicated start-step button is missing.")
	assert(studio.start_button.text == "Choose start on map")
	assert(studio.start_button.disabled, "Start should wait until the CBD is drawn.")
	assert(studio.map_zoom_label.text == "100%")
	assert(studio.find_child("MapPreviewPanel", true, false).clip_contents, "The preview panel does not clip zoomed map drawing.")
	assert(studio.find_child("MapCanvasClip", true, false).clip_contents, "The map canvas does not have a dedicated clipping boundary.")
	assert(studio.setup_driving_side_option != null, "The setup road-side choice is missing.")
	assert(studio.creation_readiness_label != null, "The create-project readiness explanation is missing.")
	assert(not studio.create_town_button.disabled, "Create must remain clickable so it can explain an incomplete setup.")
	assert(studio.rebuild_project_button != null and studio.rebuild_project_button.disabled, "Rebuild should wait until an existing project is loaded.")
	studio.setup_driving_side_option.select(1)
	studio.setup_driving_side_option.item_selected.emit(1)
	assert(studio.selected_driving_side == "right", "The setup road-side choice was not stored.")

	var imported: Dictionary = studio.importer.parse_files(PackedStringArray([FIXTURE]))
	assert(imported.ok)
	var imported_road: Dictionary = imported.features.filter(func(feature): return feature.kind == "road")[0]
	assert(str(imported_road.node_tags.get("5", {}).get("highway", "")) == "traffic_signals", "Tagged OSM traffic-control nodes were not retained by the GUI importer.")
	studio.imported_town = imported
	studio.map_canvas.set_map_data(imported)
	studio._on_cbd_changed({"west": 146.002, "south": -36.007, "east": 146.008, "north": -36.003})
	assert(not studio.start_button.disabled, "The start button did not activate after CBD selection.")
	studio.start_button.pressed.emit()
	assert(studio.map_canvas.edit_mode == studio.TownMapCanvasScript.EditMode.SET_START)
	assert(studio.start_button.text.contains("click map"), "The button did not explain the next action.")

	studio.map_canvas.size = Vector2(700, 500)
	var safe_screen_point: Vector2 = studio.map_canvas._geographic_to_screen(Vector2(146.007, -36.0035))
	studio.map_canvas._set_start_from_screen(safe_screen_point)
	assert(not studio.selected_start.is_empty(), "Clicking a safe point did not set the player start.")
	assert(studio.selected_start.has("vehicle"), "A safe vehicle start was not generated.")

	# Reproduce a different-map setup where the save location is chosen last.
	studio.town_name_edit.text = "Different Map Test"
	studio.workspace_edit.text = ""
	studio._refresh_create_button()
	assert(studio.creation_readiness_label.text.contains("save directory"), "The UI did not identify the missing save directory.")
	studio.workspace_edit.text = ProjectSettings.globalize_path("res://tools/tests/output/creator-ui-test-projects")
	studio._refresh_create_button()
	assert(studio.creation_readiness_label.text.begins_with("Ready."), "A complete different-map setup was not recognised as ready.")
	assert(not studio.create_town_button.disabled, "Create remained grey after every setup step was complete.")
	assert(not studio.play_test_button.disabled, "Play test must be clickable so it can explain that the project must be created first.")
	studio.town_name_edit.text = ""
	studio._refresh_create_button()
	studio._play_current_project()
	assert(studio.message_dialog.title == "Finish setup before Play test", "Play test did not report incomplete setup conditions.")
	assert(studio.message_dialog.dialog_text.contains("town name"), "Play test did not name the incomplete town-name condition.")
	studio.message_dialog.hide()
	studio._create_town_project()
	assert(studio.message_dialog.title == "Finish the town setup", "Clicking Create did not explain the missing setup item.")
	assert(studio.message_dialog.dialog_text.contains("town name"), "The create explanation did not identify the missing town name.")
	studio.message_dialog.hide()
	studio.town_name_edit.text = "Different Map Test"
	studio._refresh_create_button()
	studio._play_current_project()
	assert(studio.message_dialog.title == "Town project created", "Play test did not automatically create a fully configured town.")
	assert(not studio.last_created_directory.is_empty(), "The automatic create-before-play workflow did not save a project.")
	assert(studio.create_town_button.text == "Save project changes")
	studio.message_dialog.hide()

	var original_zoom: float = studio.map_canvas.view_zoom
	studio._zoom_map_in()
	assert(studio.map_canvas.view_zoom > original_zoom, "The map + button did not zoom in.")
	assert(studio.map_zoom_label.text == "125%")
	studio._reset_map_zoom()
	assert(is_equal_approx(studio.map_canvas.view_zoom, 1.0))

	var building: Dictionary = imported.features.filter(func(feature): return feature.kind == "building")[0]
	assert(building.points[0] == building.points[building.points.size() - 1], "Fixture must include a normal closed OSM polygon.")
	assert(studio.map_canvas._screen_polygon(building.points).size() == building.points.size() - 1, "Duplicate closing node was not removed before drawing.")
	studio._on_building_selected(building)
	assert(studio.building_information.text.contains("Fixture House"))
	assert(studio.building_information.text.contains("© OpenStreetMap contributors"))
	assert(studio.building_information.text.contains("OSM way 100"))

	studio._show_game_settings_page()
	await process_frame
	assert(studio.driving_side_option != null, "The Game settings road-side choice is missing.")
	assert(studio.settings_controls.has("skin_tone_distribution.medium_percent"), "Skin pigmentation controls are missing.")
	assert(studio.settings_controls.has("skin_tone_distribution.very_dark_percent"), "The full skin pigmentation range is missing.")
	assert(studio.equalize_skin_tones_button.button_pressed, "Equalize should be selected by default.")
	assert(studio.skin_tone_total_label.text.contains("100%"), "The skin tone total is not shown.")
	studio.settings_controls["skin_tone_distribution.medium_percent"].value = 25
	assert(not studio.equalize_skin_tones_button.button_pressed, "Manual tone editing did not turn Equalize off.")
	assert(studio.skin_tone_total_label.text.contains("must be 100%"), "The skin tone total did not update.")
	assert(studio.settings_controls["population.robot_count"].value == 20)
	assert(studio.settings_controls["population.cbd_robot_percent"].value == 100)
	assert(studio.settings_controls["population.drone_count"].value == 10)
	assert(studio.settings_controls["population.cbd_drone_percent"].value == 90)
	studio._show_message("Readable message", "This deliberately long plain-language message must wrap inside the dialog so a creator can read every part of it without text extending off the window.")
	assert(studio.message_dialog.get_label().autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Long messages do not wrap.")

	print("CREATOR UI PASSED: start workflow, create readiness, clipping/zoom, road side, skin tone controls and total validation.")
	studio.queue_free()
	quit(0)
