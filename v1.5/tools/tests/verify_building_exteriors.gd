extends SceneTree

const StoreScript = preload("res://scripts/buildings/building_exterior_store.gd")
const FootprintExporterScript = preload("res://scripts/buildings/building_footprint_exporter.gd")
const CanvasScript = preload("res://scripts/towns/map_canvas.gd")
const CollisionBuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")
const RendererScript = preload("res://scripts/runtime/runtime_world_renderer.gd")


func _initialize() -> void:
	var store = StoreScript.new()
	var town_directory := ProjectSettings.globalize_path("res://tools/tests/output/building-exterior-town")
	var feature := {
		"id": "way/house-1", "kind": "building", "tags": {"building": "house"},
		"points": [[149.001, -35.009], [149.002, -35.009], [149.002, -35.008], [149.001, -35.008], [149.001, -35.009]],
		"holes": []
	}
	var features: Array[Dictionary] = [feature]
	var bounds := {"west": 149.0, "south": -35.01, "east": 149.01, "north": -35.0}
	var data: Dictionary = store.empty_data()
	var template_feature := {
		"id": "way/l-shaped-shop", "kind": "building", "tags": {"name": "Test Shop"},
		"points": [[149.001, -35.008], [149.003, -35.008], [149.003, -35.009], [149.002, -35.009], [149.002, -35.010], [149.001, -35.010], [149.001, -35.008]],
		"holes": [[[149.0013, -35.0082], [149.0017, -35.0082], [149.0017, -35.0086], [149.0013, -35.0086], [149.0013, -35.0082]]]
	}
	var footprint_exporter = FootprintExporterScript.new()
	var template_path := town_directory.path_join("exports/building_footprints/test_shop_template.png")
	var template_result: Dictionary = footprint_exporter.export_png(template_feature, template_path)
	assert(template_result.ok, str(template_result.get("message", "")))
	assert(maxi(int(template_result.width), int(template_result.height)) == 2048, "The template did not use the expected Paint-friendly maximum dimension.")
	assert(int(template_result.width) != int(template_result.height), "Real footprint proportions were flattened into a square template.")
	var template_image := Image.load_from_file(template_path)
	assert(template_image != null and not template_image.is_empty(), "The exported footprint PNG could not be reopened.")
	var outside_pixel := template_image.get_pixel(roundi(template_image.get_width() * 0.75), roundi(template_image.get_height() * 0.75))
	var hole_pixel := template_image.get_pixel(roundi(template_image.get_width() * 0.25), roundi(template_image.get_height() * 0.20))
	var inside_pixel := template_image.get_pixel(roundi(template_image.get_width() * 0.25), roundi(template_image.get_height() * 0.75))
	assert(outside_pixel.a < 0.05, "The area outside a concave footprint is not transparent.")
	assert(hole_pixel.a < 0.05, "The footprint courtyard/hole is not transparent.")
	assert(inside_pixel.a > 0.95, "The editable footprint area is not visible in the exported template.")
	assert(footprint_exporter.suggested_file_name(template_feature) == "test_shop_way_l_shaped_shop_footprint_template.png")
	var image_path := ProjectSettings.globalize_path("res://assets/actors/car_sedan_blue_v3.png")
	var import_result: Dictionary = store.import_exterior(town_directory, data, "way/house-1", image_path)
	assert(import_result.ok, str(import_result.get("message", "")))
	data = import_result.data
	var relative_path := str(data.buildings["way/house-1"].exterior.relative_path)
	assert(relative_path.begins_with("assets/buildings/way_house_1/"), "The copied image was not placed in the selected building's town folder.")
	assert(FileAccess.file_exists(town_directory.path_join(relative_path)), "The imported exterior image was not copied into the town.")
	var alignment_result: Dictionary = store.set_exterior_transform(data, "way/house-1", 135.0, 25.0, -12.0, 8.0)
	assert(alignment_result.ok)
	data = alignment_result.data
	assert(is_equal_approx(float(data.buildings["way/house-1"].exterior.scale_percent), 135.0))

	var navigation := {"pedestrian": {"nodes": [{"id": 77, "longitude": 149.00204, "latitude": -35.0085}]}}
	var door_result: Dictionary = store.set_door(
		data, feature, {"longitude": 149.002, "latitude": -35.0085},
		features, bounds, navigation
	)
	assert(door_result.ok, str(door_result.get("message", "")))
	data = door_result.data
	var door: Dictionary = data.buildings["way/house-1"].doors[0]
	assert(is_equal_approx(float(door.longitude), 149.002), "The entrance did not snap to the selected footprint's eastern wall.")
	assert(float(door.outside_longitude) > float(door.longitude), "The entry arrow was not placed outside the footprint.")
	assert(int(door.pedestrian_node_id) == 77, "The entrance did not retain its nearby pedestrian graph link.")
	assert(bool(door.approach_verified_clear), "The saved entrance was not marked as clearance checked.")
	var first_door_id := str(door.id)
	assert(store._location_is_clear(Vector2(149.0015, -35.0091), features, bounds), "Local-metre clearance failed south of a high-longitude footprint.")
	assert(store._location_is_clear(Vector2(149.0009, -35.0085), features, bounds), "Local-metre clearance failed west of a high-longitude footprint.")
	var second_result: Dictionary = store.set_door(
		data, feature, {"longitude": 149.0015, "latitude": -35.009},
		features, bounds, navigation
	)
	assert(second_result.ok, str(second_result.get("message", "A second valid entrance was not added.")))
	assert(second_result.data.buildings["way/house-1"].doors.size() == 2, "A second valid entrance was not added.")
	data = second_result.data
	var move_result: Dictionary = store.set_door(
		data, feature, {"longitude": 149.0015, "latitude": -35.008},
		features, bounds, navigation, 0
	)
	assert(move_result.ok and move_result.data.buildings["way/house-1"].doors.size() == 2)
	assert(str(move_result.data.buildings["way/house-1"].doors[0].id) == first_door_id, "Moving an entrance changed its stable ID.")
	data = move_result.data
	var remove_result: Dictionary = store.remove_door(data, "way/house-1", 1)
	assert(remove_result.ok and remove_result.data.buildings["way/house-1"].doors.size() == 1, "The selected entrance was not removed.")
	data = remove_result.data

	var save_result: Dictionary = store.save_to_town(town_directory, data)
	assert(save_result.ok, str(save_result.get("message", "")))
	var loaded: Dictionary = store.load_from_town(town_directory)
	assert(loaded.ok and loaded.data.buildings.has("way/house-1"), "The stable-ID building design did not reload.")
	assert(str(loaded.data.buildings["way/house-1"].exterior.display_mode) == "clip_to_footprint")

	var canvas = CanvasScript.new()
	root.add_child(canvas)
	canvas.set_map_data({"features": features, "bounds": bounds})
	canvas.set_building_exterior_data(loaded.data, town_directory)
	assert(canvas.building_exterior_textures.has("way/house-1"), "The map preview did not load the copied custom exterior.")
	var preview_uv: Vector2 = canvas._aligned_exterior_uv(Vector2(0.25, 0.75), loaded.data.buildings["way/house-1"].exterior)
	assert(not preview_uv.is_equal_approx(Vector2(0.25, 0.75)), "Artwork alignment did not affect the clipped preview mapping.")
	canvas.queue_free()
	var collisions: Dictionary = CollisionBuilderScript.new().build(features, bounds)
	assert(collisions.ok)
	var renderer = RendererScript.new()
	root.add_child(renderer)
	renderer.setup(features, collisions.data, bounds, loaded.data, town_directory)
	assert(renderer.building_exterior_textures.has("way/house-1"), "The playable renderer did not load the copied custom exterior.")
	assert(renderer.building_exterior_data.buildings["way/house-1"].doors.size() == 1, "The playable renderer did not receive the saved entrances.")
	assert(renderer._aligned_exterior_uv(Vector2(0.25, 0.75), loaded.data.buildings["way/house-1"].exterior).is_equal_approx(preview_uv), "Creator and gameplay artwork alignment differ.")
	renderer.queue_free()

	print("BUILDING EXTERIORS PASSED: Paint PNG footprint export, copied/aligned artwork, shared clipped UVs, multiple safe entrances, move/remove, pedestrian link and persistence.")
	quit(0)
