extends SceneTree

const StoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const CatalogScript = preload("res://scripts/interiors/interior_furniture_catalog.gd")
const LibraryScript = preload("res://scripts/interiors/interior_furniture_library.gd")
const CanvasScript = preload("res://scripts/interiors/interior_floor_canvas.gd")
const RuntimeLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const ObjectBubbleScript = preload("res://scripts/interiors/runtime_object_identification_bubble.gd")


func _initialize() -> void:
	assert(CatalogScript.all().size() == 12, "The first furniture library should contain 12 examples.")
	assert(CatalogScript.thumbnail_texture(CatalogScript.definition("single_bed")) != null, "The furniture drop-down thumbnail could not be generated.")
	var store = StoreScript.new()
	var data := store.empty_data()
	data.buildings["test_building"] = {
		"feature_id": "test_building",
		"name": "Furniture test building",
		"floors": [{
			"id": "ground_floor", "name": "Ground floor", "level": 0,
			"layout_source": "creator_blank_from_osm_footprint", "survey_status": "not_surveyed",
			"width_metres": 20.0, "height_metres": 15.0, "grid_metres": 1.0, "footprint_scale": 1.0,
			"boundary_metres": [[0.0, 0.0], [20.0, 0.0], [20.0, 15.0], [0.0, 15.0]],
			"holes_metres": [], "rooms": [], "furniture": [],
			"entry_links": [{
				"id": "entry_front", "exterior_entrance_id": "front", "floor_id": "ground_floor",
				"spawn_x_metres": 2.0, "spawn_y_metres": 2.0, "placement_source": "creator_selected"
			}]
		}]
	}
	var table_result: Dictionary = store.place_furniture(data, "test_building", "ground_floor", "dining_table", Vector2(7.0, 7.0), 0.0)
	assert(table_result.ok, str(table_result.get("message", "")))
	data = table_result.data
	var overlap_result: Dictionary = store.place_furniture(data, "test_building", "ground_floor", "dining_chair", Vector2(7.0, 7.0), 0.0)
	assert(not overlap_result.ok, "Overlapping furniture was accepted.")
	var outside_result: Dictionary = store.place_furniture(data, "test_building", "ground_floor", "sofa", Vector2(0.2, 0.2), 45.0)
	assert(not outside_result.ok, "Furniture extending through an exterior wall was accepted.")
	var entry_result: Dictionary = store.place_furniture(data, "test_building", "ground_floor", "bar_stool", Vector2(2.0, 2.0), 0.0)
	assert(not entry_result.ok, "Furniture blocking an interior arrival point was accepted.")
	var sofa_result: Dictionary = store.place_furniture(data, "test_building", "ground_floor", "sofa", Vector2(12.0, 7.0), 90.0)
	assert(sofa_result.ok, str(sofa_result.get("message", "")))
	data = sofa_result.data
	assert(StoreScript.object_description(data.buildings.test_building.floors[0].furniture[1]) == "It's a sofa.", "Furniture did not retain its click-to-identify object type.")
	var library = LibraryScript.new()
	var temporary_town := OS.get_temp_dir().path_join("dwt_creator_v15_custom_furniture_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(temporary_town)
	var source_image_path := temporary_town.path_join("creator_chair.png")
	var source_image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	source_image.fill(Color(0, 0, 0, 0))
	source_image.fill_rect(Rect2i(8, 8, 32, 32), Color("#a35275"))
	assert(source_image.save_png(source_image_path) == OK, "The custom furniture fixture image could not be written.")
	var custom_import: Dictionary = library.import_creation(temporary_town, library.empty_data(), source_image_path, "Pink armchair", "chair", 0.9, 0.9)
	assert(custom_import.ok and custom_import.definition.collision, str(custom_import.get("message", "Custom furniture import failed.")))
	assert(FileAccess.file_exists(temporary_town.path_join(str(custom_import.definition.image_path))), "Imported furniture artwork was not copied into the town.")
	var custom_result: Dictionary = store.place_furniture(data, "test_building", "ground_floor", str(custom_import.definition.id), Vector2(17.0, 4.0), 0.0, custom_import.definition)
	assert(custom_result.ok and custom_result.data.buildings.test_building.floors[0].furniture[2].collision, str(custom_result.get("message", "Custom furniture placement failed.")))
	data = custom_result.data
	assert(store.validate(data).ok, "Saved furniture failed canonical validation.")
	var blocked_storyline := store.validate_location(data, {"space": "interior", "building_id": "test_building", "floor_id": "ground_floor", "x_metres": 12.0, "y_metres": 7.0})
	assert(not blocked_storyline.ok, "A storyline NPC location inside furniture was accepted.")
	var runtime = RuntimeLayerScript.new()
	get_root().add_child(runtime)
	runtime.set_town_directory(temporary_town)
	var floor: Dictionary = data.buildings.test_building.floors[0]
	var opened: Dictionary = runtime.open_floor(data.buildings.test_building, floor, floor.entry_links[0], 10.0)
	assert(opened.ok, str(opened.get("message", "")))
	assert(runtime._texture_for_item(data.buildings.test_building.floors[0].furniture[2]) != null, "The copied custom furniture picture did not load in the playable interior.")
	assert(not runtime.is_traversable(Vector2(120.0, 70.0), 2.0), "Runtime walking passed through the sofa collision.")
	assert(runtime.is_traversable(Vector2(170.0, 120.0), 2.0), "Clear runtime floor space was incorrectly blocked.")
	assert(str(runtime.furniture_at_world(Vector2(170.0, 40.0)).get("object_type", "")) == "chair", "The clicked custom furniture was not identified.")
	var canvas = CanvasScript.new()
	canvas.size = Vector2(520, 420)
	get_root().add_child(canvas)
	canvas.set_floor(floor)
	canvas.zoom_in()
	assert(canvas.view_zoom > 1.0, "Interior Designer zoom-in did not change the map view.")
	canvas.reset_view()
	assert(is_equal_approx(canvas.view_zoom, 1.0), "Interior Designer reset did not restore the fitted map view.")
	var player_marker := Node2D.new()
	get_root().add_child(player_marker)
	var bubble = ObjectBubbleScript.new()
	get_root().add_child(bubble)
	bubble.show_object(player_marker, StoreScript.object_description(data.buildings.test_building.floors[0].furniture[2]))
	assert(bubble.visible and bubble.message == "It's a chair.", "Clicking furniture did not create the player object-identification bubble.")
	var removed: Dictionary = store.remove_furniture(data, "test_building", "ground_floor", str(table_result.furniture_id))
	assert(removed.ok and removed.data.buildings.test_building.floors[0].furniture.size() == 2, "Furniture removal did not preserve the remaining items.")
	print("INTERIOR FURNITURE PASSED: illustrated list, zoom/pan view, 12 built-ins, copied custom artwork with automatic collision, click identification, placement safety and runtime collision.")
	quit(0)
