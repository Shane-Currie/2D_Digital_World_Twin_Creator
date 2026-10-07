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
	assert(studio.create_town_button.icon != null and studio.create_town_button.get_parent().get_parent().get_parent().get_parent() == studio.content_area, "The always-visible top save button or floppy-disk icon is missing from town setup.")
	assert(studio.sidebar_navigation_buttons.play.text.begins_with("✗") and studio.sidebar_navigation_buttons.import.text.begins_with("✗"), "The left menu did not show incomplete Play test requirements.")
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
	assert(not studio.vehicle_start_button.disabled and studio.vehicle_rotation_control != null, "The explicit car-start controls did not become available.")
	studio.vehicle_rotation_control.value = 90.0
	assert(studio.selected_start.vehicle.rotation_degrees == 90.0 and studio.map_canvas.start_location.vehicle.rotation_degrees == 90.0, "The car direction control did not update the saved start and directional preview.")

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
	var saved_start_town: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(studio.last_created_directory.path_join("town.json")))
	assert(saved_start_town.starting_location.vehicle.rotation_degrees == 90.0, "The custom car starting direction was lost on project creation.")
	assert(studio.create_town_button.text == "Save project changes")
	assert(studio.sidebar_navigation_buttons.play.text.begins_with("✓") and studio.sidebar_navigation_buttons.import.text.begins_with("✓"), "The left menu did not turn completed Play test requirements green.")
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
	assert(studio.map_canvas.osm_hover_card != null and studio.map_canvas.osm_hover_label != null, "The Import town map is missing the shared OSM building hover card.")
	var enriched_hover_building := building.duplicate(true)
	enriched_hover_building.tags["addr:housenumber"] = "10"
	enriched_hover_building.tags["addr:street"] = "Example Street"
	enriched_hover_building.tags["building:levels"] = "2"
	enriched_hover_building.tags["operator"] = "Fixture Business"
	studio.map_canvas._show_osm_building_hover(enriched_hover_building, Vector2(350, 250))
	assert(studio.map_canvas.osm_hover_card.visible and studio.map_canvas.osm_hover_label.text.contains("Street address: 10 Example Street") and studio.map_canvas.osm_hover_label.text.contains("© OpenStreetMap contributors"), "The Import town map did not display the shared OSM details.")
	studio.map_canvas._clear_building_hover()
	assert(not studio.map_canvas.osm_hover_card.visible, "The Import town OSM card did not close.")

	studio._show_advanced_map_editor_page()
	await process_frame
	assert(studio.content_area.find_child("TopSaveButton", true, false) != null, "Advanced Map Editor is missing its always-visible top save button.")
	assert(studio.editor_map_canvas != null, "The Advanced map editor did not open for a loaded town.")
	assert(studio.editor_map_canvas.osm_hover_card != null and studio.editor_map_canvas.osm_hover_label != null, "The Advanced Map Editor OSM hover card is missing.")
	studio.editor_map_canvas.size = Vector2(700, 500)
	var building_centre_geo := (Vector2(building.points[0]) + Vector2(building.points[1]) + Vector2(building.points[2]) + Vector2(building.points[3])) / 4.0
	var building_centre_screen: Vector2 = studio.editor_map_canvas._geographic_to_screen(building_centre_geo)
	assert(str(studio.editor_map_canvas._building_at_screen(building_centre_screen).get("id", "")) == str(building.id), "The hover spatial index did not find the building beneath the mouse.")
	studio.editor_map_canvas._update_building_hover(building_centre_screen)
	assert(studio.editor_map_canvas.osm_hover_card.visible and studio.editor_map_canvas.osm_hover_label.text.contains("Name: Fixture House"), "Moving the pointer over a footprint did not open the shared OSM card.")
	studio.editor_map_canvas._show_osm_building_hover(enriched_hover_building, building_centre_screen)
	assert(studio.editor_map_canvas.osm_hover_card.visible and studio.editor_map_canvas.osm_hover_label.text.contains("Name: Fixture House") and studio.editor_map_canvas.osm_hover_label.text.contains("Street address: 10 Example Street") and studio.editor_map_canvas.osm_hover_label.text.contains("Levels / floors: 2") and studio.editor_map_canvas.osm_hover_label.text.contains("Operator / brand: Fixture Business") and studio.editor_map_canvas.osm_hover_label.text.contains("© OpenStreetMap contributors"), "The floating hover card did not show the building's direct OSM details.")
	studio.editor_map_canvas._show_osm_building_hover(enriched_hover_building, Vector2(695, 495))
	assert(studio.editor_map_canvas.osm_hover_card.position.x >= 0.0 and studio.editor_map_canvas.osm_hover_card.position.y >= 0.0 and studio.editor_map_canvas.osm_hover_card.position.x + studio.editor_map_canvas.osm_hover_card.size.x <= studio.editor_map_canvas.size.x and studio.editor_map_canvas.osm_hover_card.position.y + studio.editor_map_canvas.osm_hover_card.size.y <= studio.editor_map_canvas.size.y, "The building hover card escaped the visible map at its lower-right edge: position=%s size=%s canvas=%s" % [studio.editor_map_canvas.osm_hover_card.position, studio.editor_map_canvas.osm_hover_card.size, studio.editor_map_canvas.size])
	studio.editor_map_canvas._clear_building_hover()
	assert(not studio.editor_map_canvas.osm_hover_card.visible, "The OSM hover card did not close after leaving a building footprint.")
	studio._set_editor_mode(studio.TownMapCanvasScript.EditMode.COPY_COORDINATES)
	assert(studio.editor_map_canvas.edit_mode == studio.TownMapCanvasScript.EditMode.COPY_COORDINATES, "The storyline coordinate picker did not activate.")
	studio.editor_map_canvas.coordinates_picked.emit({"latitude": -36.00425, "longitude": 146.00675})
	assert(studio.editor_coordinate_status_label.text.contains("-36.00425000, 146.00675000"), "The selected latitude and longitude were not prepared for copying.")
	studio._on_editor_building_selected(building)
	studio._toggle_editor_building()
	assert(str(building.id) in studio.editor_overrides.hidden_feature_ids, "The selected building was not marked hidden.")
	studio._on_editor_zone_drawn({
		"mode": "blocked_water",
		"points": [[146.0002, -36.0098], [146.0004, -36.0098], [146.0004, -36.0096], [146.0002, -36.0096], [146.0002, -36.0098]],
		"applies_to": ["player", "vehicle", "npc", "npr"], "source": "creator_authored"
	})
	assert(studio.editor_overrides.zones.size() == 1, "A drawn blocked-water correction was not retained.")
	studio._editor_undo()
	assert(studio.editor_overrides.zones.is_empty(), "Undo did not remove the latest correction.")
	studio._editor_redo()
	assert(studio.editor_overrides.zones.size() == 1, "Redo did not restore the correction.")
	studio._remove_latest_editor_zone()
	assert(studio.editor_overrides.zones.is_empty(), "The newest saved correction could not be removed without code.")
	studio._editor_undo()
	assert(studio.editor_overrides.zones.size() == 1, "Undo did not restore a removed correction.")
	studio._save_map_editor_changes()
	assert(studio.message_dialog.title == "Map corrections saved", studio.message_dialog.dialog_text)
	var saved_overrides: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(studio.loaded_project_directory.path_join("data/map_overrides.json")))
	assert(str(building.id) in saved_overrides.hidden_feature_ids, "The hidden building correction was not saved.")
	assert(saved_overrides.zones.size() == 1, "The water correction was not saved.")
	var rebuilt_collisions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(studio.loaded_project_directory.path_join("data/building_collisions.json")))
	assert(rebuilt_collisions.water_areas.any(func(area): return str(area.id).begins_with("creator:")), "Saved blocked water did not reach rebuilt collision data.")
	# Restore the footprint before exercising the Building Creator. Its earlier
	# hidden-state save remains verified above.
	studio._on_editor_building_selected(building)
	studio._toggle_editor_building()
	studio._save_map_editor_changes()
	assert(str(building.id) not in studio.editor_overrides.hidden_feature_ids)
	studio._show_building_creator_page()
	await process_frame
	assert(studio.building_map_canvas != null, "Building Creator did not open for the loaded town.")
	assert(studio.building_map_canvas.osm_hover_card != null and studio.building_map_canvas.osm_hover_label != null, "The Building Creator map is missing the shared OSM building hover card.")
	studio.building_map_canvas.size = Vector2(700, 500)
	studio.building_map_canvas._show_osm_building_hover(enriched_hover_building, Vector2(350, 250))
	assert(studio.building_map_canvas.osm_hover_card.visible and studio.building_map_canvas.osm_hover_label.text.contains("Levels / floors: 2") and studio.building_map_canvas.osm_hover_label.text.contains("© OpenStreetMap contributors"), "The Building Creator map did not display the shared OSM details.")
	studio.building_map_canvas._clear_building_hover()
	studio._on_building_creator_selected(building)
	studio.building_custom_name_edit.text = "Fixture Community Centre"
	studio.building_custom_name_edit.text_changed.emit(studio.building_custom_name_edit.text)
	assert(studio.building_exterior_data.buildings[str(building.id)].custom_name == "Fixture Community Centre", "The custom footprint name was not retained.")
	assert(studio.custom_building_option.item_count == 2, "The custom building did not appear in the quick-load dropdown.")
	studio._on_custom_building_selected(1)
	assert(str(studio.building_selected_feature.id) == str(building.id) and studio.building_custom_name_edit.text == "Fixture Community Centre", "Quick-load did not restore the building's settings and name.")
	assert(not studio.building_export_button.disabled and not studio.building_import_button.disabled and not studio.building_door_button.disabled, "Building tools did not activate after footprint selection.")
	var exported_template_path: String = studio.loaded_project_directory.path_join("exports/building_footprints/fixture_house_template.png")
	studio._on_building_footprint_path_selected(exported_template_path)
	assert(FileAccess.file_exists(exported_template_path), "Building Creator did not export the selected footprint as a Paint-ready PNG.")
	assert(studio.message_dialog.title == "Footprint template exported" and studio.message_dialog.dialog_text.contains("Microsoft Paint"), "The footprint export did not provide plain-language Paint instructions.")
	studio.message_dialog.hide()
	studio._on_building_exterior_image_selected(ProjectSettings.globalize_path("res://assets/actors/car_sedan_blue_v3.png"))
	assert(studio.building_exterior_data.buildings.has(str(building.id)), "The custom exterior was not retained by the Building Creator.")
	studio.building_scale_control.value = 140
	studio.building_rotation_control.value = 15
	studio.building_offset_x_control.value = 10
	assert(is_equal_approx(float(studio.building_exterior_data.buildings[str(building.id)].exterior.scale_percent), 140.0), "The no-code artwork scale control did not update the preview data.")
	var building_points: Array = building.points
	var preferred_door: Vector2 = building_points[1].lerp(building_points[2], 0.5)
	studio._on_building_door_requested({"longitude": preferred_door.x, "latitude": preferred_door.y})
	assert(studio.building_exterior_data.buildings[str(building.id)].doors.size() == 1, "The creator-selected entrance was not snapped and retained.")
	var second_door: Vector2 = building_points[2].lerp(building_points[3], 0.5)
	studio._begin_building_door_placement()
	studio._on_building_door_requested({"longitude": second_door.x, "latitude": second_door.y})
	assert(studio.building_exterior_data.buildings[str(building.id)].doors.size() == 2, "The GUI did not add a second entrance.")
	studio.building_entrance_option.select(1)
	studio._remove_selected_building_entrance()
	assert(studio.building_exterior_data.buildings[str(building.id)].doors.size() == 1, "The GUI did not remove the selected entrance.")
	studio._save_building_designs()
	var saved_exteriors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(studio.loaded_project_directory.path_join("data/building_exteriors.json")))
	assert(saved_exteriors.buildings.has(str(building.id)), "The stable-ID building design was not saved.")
	assert(saved_exteriors.buildings[str(building.id)].custom_name == "Fixture Community Centre", "The creator name was not persisted with the building design.")
	assert(FileAccess.file_exists(studio.loaded_project_directory.path_join(saved_exteriors.buildings[str(building.id)].exterior.relative_path)), "The copied town artwork is missing.")
	assert(studio.building_save_button.icon != null and studio.building_save_button.get_parent().get_parent().get_parent().get_parent() == studio.content_area, "Building Creator save is not fixed above its scrolling tools.")
	studio.message_dialog.hide()
	studio._show_interior_designer_page()
	await process_frame
	assert(studio.interior_floor_canvas != null and studio.interior_create_button != null, "Interior Designer did not open for the designed building.")
	assert(studio.interior_building_option.get_item_text(0).begins_with("Fixture Community Centre"), "The Interior Designer did not use the saved Creator building name.")
	assert(studio.interior_summary_label.text.begins_with("Fixture Community Centre"), "The Interior Designer summary retained the old OSM name.")
	assert(studio.interior_save_button.icon != null, "Interior Designer is missing its visible floppy-disk save button.")
	var initial_floor_material_count: int = studio.interior_floor_material_option.item_count
	var light_oak_icon_found := false
	for material_index in studio.interior_floor_material_option.item_count:
		if str(studio.interior_floor_material_option.get_item_metadata(material_index)) == "floor_light_oak": light_oak_icon_found = studio.interior_floor_material_option.get_item_icon(material_index) != null
	assert(studio.interior_floor_material_option != null and initial_floor_material_count >= 4 and light_oak_icon_found, "The floor-paint list does not show the eraser and three illustrated floorboards.")
	assert(studio.interior_paint_floor_button != null and studio.interior_floor_material_name_edit != null and studio.interior_import_floor_material_button != null, "The no-code floor painting or custom-upload controls are missing.")
	assert(studio.interior_furniture_catalog_option.item_count >= 12 and studio.interior_furniture_catalog_option.get_item_icon(0) != null, "The furniture drop-down does not show illustrated items.")
	assert(studio.interior_furniture_category_option != null and studio.interior_furniture_category_option.item_count >= 8 and studio.interior_furniture_search_edit != null, "Furniture category and search controls are missing.")
	var pub_category_index := -1
	for category_index in studio.interior_furniture_category_option.item_count:
		if str(studio.interior_furniture_category_option.get_item_metadata(category_index)) == "Pub": pub_category_index = category_index
	assert(pub_category_index >= 0, "The Pub furniture category is missing.")
	studio.interior_furniture_category_option.select(pub_category_index)
	studio._populate_interior_furniture_options()
	var pub_ids: Array[String] = []
	for option_index in studio.interior_furniture_catalog_option.item_count:
		pub_ids.append(str(studio.interior_furniture_catalog_option.get_item_metadata(option_index)))
	assert("bar_counter" in pub_ids and "dining_table" in pub_ids and "single_bed" not in pub_ids, "Pub filtering did not include shared hospitality items or exclude residential-only furniture.")
	studio.interior_furniture_category_option.select(0)
	studio.interior_furniture_search_edit.text = "wardrobe"
	studio._populate_interior_furniture_options()
	assert(studio.interior_furniture_catalog_option.item_count == 1 and str(studio.interior_furniture_catalog_option.get_item_metadata(0)) == "wardrobe", "Furniture search did not narrow the illustrated list by item name.")
	studio.interior_furniture_search_edit.clear()
	studio._populate_interior_furniture_options()
	assert(studio.interior_zoom_label != null and studio.interior_zoom_label.text == "100%", "The Interior Designer zoom display is missing.")
	studio._create_blank_interior_floor()
	var interior_feature_id := str(building.id)
	assert(studio.interior_data.buildings.has(interior_feature_id), "The footprint-shaped interior was not created.")
	studio.interior_floor_material_option.select(1)
	studio._begin_interior_floor_painting()
	assert(studio.interior_floor_canvas.painting_floor, "The Paint floor control did not start drag painting.")
	var paint_point := Vector2(float(studio.interior_data.buildings[interior_feature_id].floors[0].width_metres) * 0.5, float(studio.interior_data.buildings[interior_feature_id].floors[0].height_metres) * 0.5)
	studio._on_interior_floor_paint_requested([paint_point], false)
	assert(studio.interior_data.buildings[interior_feature_id].floors[0].flooring.cells.size() > 0, "Creator Studio did not retain the drag-painted floor cells.")
	studio.interior_floor_material_name_edit.text = "Creator test floor"
	studio._on_interior_floor_material_image_selected(ProjectSettings.globalize_path("res://assets/actors/car_sedan_blue_v3.png"))
	assert(studio.interior_floor_material_data.items.size() >= 1 and studio.interior_floor_material_option.item_count >= initial_floor_material_count, "Creator Studio did not copy and list an uploaded floor texture.")
	assert(studio.interior_draw_wall_button != null and studio.interior_wall_option != null and studio.interior_add_door_button != null and studio.interior_lock_door_button != null and studio.interior_room_name_edit != null, "The no-code internal wall, doorway-lock or room-name controls are missing.")
	assert("click any wall" in studio.interior_add_door_button.text.to_lower(), "The doorway control still tells creators to use only the list-selected wall.")
	studio._begin_interior_wall_placement()
	assert(studio.interior_floor_canvas.placing_wall, "The Draw internal wall control did not start two-click wall placement.")
	studio.interior_room_name_edit.text = "Test room"
	studio._begin_interior_room_label_placement()
	assert(studio.interior_floor_canvas.placing_room_label, "The Place room name control did not start map placement.")
	studio.interior_floor_canvas.zoom_in()
	assert(studio.interior_floor_canvas.view_zoom > 1.0 and studio.interior_zoom_label.text != "100%", "The Interior Designer zoom controls did not update the map.")
	studio.interior_floor_canvas.reset_view()
	var ground_floor: Dictionary = studio.interior_data.buildings[interior_feature_id].floors[0]
	assert(ground_floor.boundary_metres.size() == building.points.size() - 1, "The ground floor did not preserve the footprint outline.")
	studio._add_interior_floor()
	assert(studio.interior_data.buildings[interior_feature_id].floors.size() == 2, "The no-code Add upper floor control failed.")
	studio.interior_size_control.value = 150.0
	studio._resize_interior_floor()
	assert(is_equal_approx(float(studio.interior_data.buildings[interior_feature_id].floors[1].footprint_scale), 1.5), "The no-code floor size control failed.")
	studio.interior_floor_option.select(0)
	studio._on_interior_floor_selected(0)
	ground_floor = studio.interior_data.buildings[interior_feature_id].floors[0]
	studio._on_interior_spawn_requested(Vector2(float(ground_floor.width_metres) * 0.5, float(ground_floor.height_metres) * 0.5))
	assert(studio.interior_data.buildings[interior_feature_id].floors[0].entry_links.size() == 1, "The interior entry link was not retained.")
	studio.interior_custom_name_edit.text = "Creator test chair"
	studio.interior_custom_type_edit.text = "chair"
	studio.interior_custom_category_edit.text = "Medical clinic"
	studio.interior_custom_width_control.value = 0.8
	studio.interior_custom_depth_control.value = 0.8
	studio._on_interior_furniture_image_selected(ProjectSettings.globalize_path("res://assets/actors/car_sedan_blue_v3.png"))
	assert(studio.interior_custom_catalog_data.items.size() == 1 and "Medical clinic" in studio.interior_custom_catalog_data.items[0].usage_categories, "Creator Studio did not retain the uploaded furniture or its custom category.")
	assert(studio.interior_furniture_catalog_option.item_count == 1 and studio.interior_furniture_catalog_option.get_item_icon(0) != null, "The uploaded furniture picture did not appear under its new custom category.")
	var custom_category_available := false
	for category_index in studio.interior_custom_category_option.item_count:
		if str(studio.interior_custom_category_option.get_item_metadata(category_index)) == "Medical clinic": custom_category_available = true
	assert(custom_category_available, "A creator-authored furniture category was not reusable for later uploads.")
	studio._refresh_interior_furniture_category_options("All items")
	studio._populate_interior_furniture_options()
	assert(studio.interior_furniture_catalog_option.item_count == 17, "All items did not restore the 16 built-in and uploaded furniture catalogue.")
	assert(bool(studio.interior_custom_catalog_data.items[0].collision), "Uploaded furniture did not automatically enable collision.")
	studio._save_interior_layouts()
	var saved_interiors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(studio.loaded_project_directory.path_join("data/building_interiors.json")))
	assert(saved_interiors.buildings[interior_feature_id].floors.size() == 2, "The multi-floor interior layout was not saved.")
	assert(saved_interiors.buildings[interior_feature_id].name == "Fixture Community Centre", "The renamed exterior did not synchronise to the saved interior display name.")
	assert(saved_interiors.buildings[interior_feature_id].floors[0].entry_links[0].exterior_entrance_id == saved_exteriors.buildings[interior_feature_id].doors[0].id, "Renaming the building broke its stable exterior-to-interior entrance link.")
	assert(FileAccess.file_exists(studio.loaded_project_directory.path_join("data/interior_floor_materials.json")), "The custom floor-material catalogue was not saved.")

	studio._show_game_settings_page()
	await process_frame
	assert(studio.content_area.find_child("TopSaveButton", true, false) != null, "Game settings is missing its always-visible top save button.")
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
	assert(is_equal_approx(studio.settings_controls["camera.character_zoom"].value, 2.7), "The confirmed 2.7× on-foot default was not restored.")
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

	print("CREATOR UI PASSED: setup/settings, Advanced Map Editor, Building Creator and multi-floor Interior Designer workflow.")
	studio.queue_free()
	quit(0)
