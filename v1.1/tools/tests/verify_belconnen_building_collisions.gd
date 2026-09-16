extends SceneTree

const ImporterScript = preload("res://scripts/towns/osm_importer.gd")
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const ContentPackScript = preload("res://scripts/content/content_pack.gd")
const CollisionRuntimeScript = preload("res://scripts/collisions/building_collision_runtime.gd")
const COOPER_LODGE_OSM_ID := "297173255"
# Exterior ground beside Cooper Lodge's Telita Street frontage. The building has
# no tagged entrance node in the current OSM extract, so this is not presented as
# a surveyed doorway position.
const COOPER_LODGE_START := Vector2(149.08255, -35.23931)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_msec()
	var source := ProjectSettings.globalize_path("res://data/towns/belconnen/source_osm/belconnen_university_town_centre.osm")
	assert(FileAccess.file_exists(source), "Download the bounded Belconnen test source before running this check.")
	var imported: Dictionary = ImporterScript.new().parse_files(PackedStringArray([source]))
	assert(imported.ok, imported.message)
	assert(imported.statistics.buildings > 100, "The Belconnen sample did not contain enough real building footprints for this test.")
	var cbd := _central_bounds(imported.bounds, 0.42)
	var cooper_lodge := _find_feature(imported.features, COOPER_LODGE_OSM_ID)
	assert(not cooper_lodge.is_empty(), "The expanded Belconnen sample does not contain Cooper Lodge.")
	assert(str(cooper_lodge.get("tags", {}).get("name", "")) == "Cooper Lodge")
	var starting_result: Dictionary = SpawnSafetyScript.create_starting_location(
		{"longitude": COOPER_LODGE_START.x, "latitude": COOPER_LODGE_START.y}, imported.features
	)
	assert(starting_result.ok, "The Cooper Lodge exterior start or its nearby wagon position was unsafe.")
	starting_result.starting_location["label"] = "Cooper Lodge, University of Canberra"
	starting_result.starting_location["osm_building_id"] = COOPER_LODGE_OSM_ID
	starting_result.starting_location["placement"] = "exterior_near_telita_street"
	starting_result.starting_location["entrance_verified"] = false
	var workspace := ProjectSettings.globalize_path("res://../test")
	var save_result: Dictionary = ContentPackScript.new().save_town(
		workspace,
		"Belconnen Collision Test",
		PackedStringArray([source]),
		imported,
		cbd,
		starting_result.starting_location
	)
	assert(save_result.ok, save_result.message)
	var collision_path: String = save_result.town_directory.path_join("data").path_join("building_collisions.json")
	var collision_data := _read_json(collision_path)
	assert(collision_data.kind == "building_collision_index")
	assert(collision_data.statistics.collision_buildings > 100)
	var review_building := _find_feature(collision_data.buildings, COOPER_LODGE_OSM_ID)
	assert(not review_building.is_empty(), "Cooper Lodge did not receive generated collision data.")

	var runtime = CollisionRuntimeScript.new()
	get_root().add_child(runtime)
	assert(runtime.setup(collision_data).ok)
	var inside_metres := _interior_point(review_building.outer_metres)
	var scale: float = collision_data.runtime_scale.pixels_per_metre
	var inside_world := inside_metres * scale
	runtime.update_streaming(inside_world)
	await physics_frame
	await physics_frame
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.position = inside_world
	var inside_hits := runtime.get_world_2d().direct_space_state.intersect_point(query)
	assert(not inside_hits.is_empty(), "The selected Belconnen footprint was not solid in Godot physics.")
	var courtyard_building := _choose_courtyard_building(collision_data.buildings)
	assert(not courtyard_building.is_empty(), "Belconnen multipolygon courtyards were not preserved.")
	var courtyard_metres := _interior_point(courtyard_building.holes_metres[0])
	runtime.update_streaming(courtyard_metres * scale)
	await physics_frame
	await physics_frame
	query.position = courtyard_metres * scale
	var courtyard_hits := runtime.get_world_2d().direct_space_state.intersect_point(query)
	assert(courtyard_hits.is_empty(), "An OSM inner courtyard was incorrectly filled with collision.")
	var start_geo := Vector2(float(starting_result.starting_location.longitude), float(starting_result.starting_location.latitude))
	var projection: Dictionary = collision_data.projection
	var open_metres := Vector2(
		(start_geo.x - float(projection.origin_longitude)) * float(projection.longitude_metres_per_degree),
		(float(projection.origin_latitude) - start_geo.y) * float(projection.latitude_metres_per_degree)
	)
	runtime.update_streaming(open_metres * scale)
	await physics_frame
	await physics_frame
	query.position = open_metres * scale
	var open_hits := runtime.get_world_2d().direct_space_state.intersect_point(query)
	assert(open_hits.is_empty(), "The safe open Belconnen start was incorrectly made solid.")

	var report := {
		"passed": true,
		"tested_utc": Time.get_datetime_string_from_system(true),
		"source": {
			"file": "data/towns/belconnen/source_osm/belconnen_university_town_centre.osm",
			"api_bbox": [149.055, -35.245, 149.090, -35.225],
			"description": "Bounded Belconnen Town Centre and University of Canberra collision test; not the whole ACT district.",
			"attribution": "© OpenStreetMap contributors, ODbL 1.0",
			"copyright_url": "https://www.openstreetmap.org/copyright"
		},
		"osm_statistics": imported.statistics,
		"collision_statistics": collision_data.statistics,
		"projection": collision_data.projection,
		"review_building": {
			"osm_id": review_building.id,
			"vertices": review_building.outer_metres.size(),
			"area_square_metres": review_building.area_square_metres,
			"inside_collision_hits": inside_hits.size()
		},
		"courtyard_review": {
			"osm_id": courtyard_building.id,
			"inner_rings": courtyard_building.holes_metres.size(),
			"courtyard_collision_hits": courtyard_hits.size()
		},
		"open_start_collision_hits": open_hits.size(),
		"starting_location": starting_result.starting_location,
		"streamed_chunks_at_probe": runtime.loaded_chunks.size(),
		"generated_town": save_result.town_directory,
		"elapsed_milliseconds": Time.get_ticks_msec() - started
	}
	var report_directory := ProjectSettings.globalize_path("res://data/towns/belconnen/reports")
	DirAccess.make_dir_recursive_absolute(report_directory)
	var report_path := report_directory.path_join("building_collision_validation.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("BELCONNEN BUILDING COLLISIONS PASSED: ", JSON.stringify(report))
	quit(0)


func _find_feature(features: Array, feature_id: String) -> Dictionary:
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("id", "")) == feature_id:
			return feature
	return {}


func _central_bounds(bounds: Dictionary, proportion: float) -> Dictionary:
	var centre_x := (float(bounds.west) + float(bounds.east)) * 0.5
	var centre_y := (float(bounds.south) + float(bounds.north)) * 0.5
	var half_width := (float(bounds.east) - float(bounds.west)) * proportion * 0.5
	var half_height := (float(bounds.north) - float(bounds.south)) * proportion * 0.5
	return {"west": centre_x - half_width, "south": centre_y - half_height, "east": centre_x + half_width, "north": centre_y + half_height}


func _choose_courtyard_building(buildings: Array) -> Dictionary:
	for building_value in buildings:
		var building: Dictionary = building_value
		if not building.get("holes_metres", []).is_empty():
			return building
	return {}


func _interior_point(values: Array) -> Vector2:
	var polygon := PackedVector2Array()
	for value in values:
		polygon.append(Vector2(float(value[0]), float(value[1])))
	var triangles := Geometry2D.triangulate_polygon(polygon)
	assert(triangles.size() >= 3)
	return (polygon[triangles[0]] + polygon[triangles[1]] + polygon[triangles[2]]) / 3.0


func _read_json(path_value: String) -> Dictionary:
	var file := FileAccess.open(path_value, FileAccess.READ)
	assert(file != null, "Could not read %s" % path_value)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary)
	return parsed
