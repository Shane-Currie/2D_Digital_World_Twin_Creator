extends SceneTree

const FIXTURE := "res://tools/tests/fixtures/tiny_town.osm"
const SettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")


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
	assert(studio.settings_controls.has("skin_tone_distribution.light_percent"), "The light skin pigmentation control is missing.")
	assert(studio.settings_controls.has("skin_tone_distribution.dark_percent"), "The dark skin pigmentation control is missing.")
	assert(not studio.settings_controls.has("skin_tone_distribution.very_dark_percent"), "The superseded seven-tone controls are still visible.")
	assert(studio.settings_controls.has("camera.character_zoom"), "The on-foot camera zoom control is missing from Game Settings.")
	assert(studio.settings_controls.has("driving.camera_zoom_multiplier"), "The in-car camera zoom control is missing from Game Settings.")
	assert(studio.settings_controls.has("driving.max_speed_kmh"), "The creator-facing maximum speed control is missing from Game Settings.")
	assert(studio.settings_controls.has("driving.zero_to_hundred_seconds"), "The 0–100 acceleration-time control is missing from Game Settings.")
	assert(studio.settings_controls.has("driving.reverse_max_speed_kmh"), "The reverse speed limit is missing from Game Settings.")
	assert(not studio.settings_controls.has("guidance.walking_strength_percent") and not studio.settings_controls.has("guidance.driving_strength_percent"), "The withdrawn soft guidance controls remain visible.")
	assert(not studio.settings_controls.has("driving.forward_speed"), "Internal world-speed units are still exposed to creators.")
	assert(studio.equalize_skin_tones_button.button_pressed, "Equalize should be selected by default.")
	assert(studio.skin_tone_total_label.text.contains("100%"), "The skin tone total is not shown.")
	studio.settings_controls["skin_tone_distribution.medium_percent"].value = 25
	assert(not studio.equalize_skin_tones_button.button_pressed, "Manual tone editing did not turn Equalize off.")
	assert(studio.skin_tone_total_label.text.contains("must be 100%"), "The skin tone total did not update.")
	assert(studio.settings_controls["population.robot_count"].value == 20)
	assert(studio.settings_controls["population.cbd_robot_percent"].value == 100)
	assert(studio.settings_controls["population.drone_count"].value == 10)
	assert(studio.settings_controls["population.cbd_drone_percent"].value == 90)
	studio._restore_recommended_settings()
	studio.settings_controls["camera.character_zoom"].value = 1.65
	studio.settings_controls["driving.camera_zoom_multiplier"].value = 1.25
	studio.settings_controls["driving.max_speed_kmh"].value = 235
	studio.settings_controls["driving.zero_to_hundred_seconds"].value = 7.4
	studio.settings_controls["driving.reverse_max_speed_kmh"].value = 25
	studio._save_game_settings()
	studio._load_game_settings()
	assert(is_equal_approx(studio.settings_controls["camera.character_zoom"].value, 1.65), "The chosen walking zoom was not saved and reloaded.")
	assert(is_equal_approx(studio.settings_controls["driving.camera_zoom_multiplier"].value, 1.25), "The chosen car zoom was not saved and reloaded.")
	assert(is_equal_approx(studio.settings_controls["driving.max_speed_kmh"].value, 235.0), "The chosen maximum km/h was not saved and reloaded.")
	assert(is_equal_approx(studio.settings_controls["driving.zero_to_hundred_seconds"].value, 7.4), "The chosen 0–100 time was not saved and reloaded.")
	assert(is_equal_approx(studio.settings_controls["driving.reverse_max_speed_kmh"].value, 25.0), "The reverse limit was not saved and reloaded.")
	var settings_path: String = studio.last_created_directory.path_join("game_settings.json")
	var legacy_settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	legacy_settings["guidance"] = {"walking_enabled": true, "driving_enabled": true, "walking_strength_percent": 35, "driving_strength_percent": 50}
	legacy_settings["camera"]["rotate_while_walking"] = true
	legacy_settings["camera"]["rotate_while_driving"] = true
	var legacy_file := FileAccess.open(settings_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_settings, "\t") + "\n")
	legacy_file.close()
	var migrated: Dictionary = SettingsStoreScript.load_from_town(studio.last_created_directory)
	assert(migrated.ok and not migrated.settings.has("guidance") and not migrated.settings.camera.has("rotate_while_walking") and not migrated.settings.camera.has("rotate_while_driving"), "Older experimental guidance settings were not retired on load.")
	assert(is_equal_approx(float(migrated.settings.driving.reverse_max_speed_kmh), 25.0), "Removing guidance also lost the chosen Reverse limit.")
	studio._load_game_settings()
	studio._save_game_settings()
	assert(not FileAccess.get_file_as_string(settings_path).contains("guidance"), "Saving did not remove withdrawn settings from the test town.")
	studio._show_message("Readable message", "This deliberately long plain-language message must wrap inside the dialog so a creator can read every part of it without text extending off the window.")
	assert(studio.message_dialog.get_label().autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Long messages do not wrap.")

	print("CREATOR UI PASSED: setup, road side, camera zoom, reverse limit and settings save/reload.")
	studio.queue_free()
	quit(0)
