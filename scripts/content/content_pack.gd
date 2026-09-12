class_name ContentPackWriter
extends RefCounted

const CONTENT_SCHEMA_VERSION := 1
const CREATOR_VERSION := "1.1"
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const NavigationBuilderScript = preload("res://scripts/navigation/osm_navigation_builder.gd")
const BuildingCollisionBuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")
const REQUIRED_RUNTIME_FEATURES := [
	"walking_player", "player_driven_wagon", "npc_pedestrians", "npc_traffic",
	"traffic_signals_and_intersections", "traffic_jam_recovery", "cbd_population_targets",
	"osm_roads_and_buildings", "building_collisions", "venues_and_interiors",
	"property_boundaries", "breakable_fences", "camera_and_minimap", "saveable_game_settings",
	"not_playable_robots", "non_playable_drones", "aerial_navigation", "grass_and_surface_tracks"
]

## Writes a town as ordinary JSON and copied source files. No scripts are imported.
func save_town(
	workspace_path: String,
	display_name: String,
	source_files: PackedStringArray,
	import_result: Dictionary,
	cbd_bounds: Dictionary,
	start_location: Dictionary,
	game_settings: Dictionary = {}
) -> Dictionary:
	var validation := validate_town(display_name, import_result, cbd_bounds, start_location)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0], "validation": validation}
	var settings_to_save: Dictionary = game_settings if not game_settings.is_empty() else GameSettingsStoreScript.recommended_settings()
	var settings_validation: Dictionary = GameSettingsStoreScript.validate(settings_to_save)
	if not settings_validation.passed:
		return {"ok": false, "message": settings_validation.errors[0], "validation": settings_validation}

	var town_id := _safe_id(display_name)
	var absolute_workspace := _absolute_path(workspace_path)
	var town_directory := absolute_workspace.path_join(town_id)
	var source_directory := town_directory.path_join("source_osm")
	var data_directory := town_directory.path_join("data")

	var directory_error := DirAccess.make_dir_recursive_absolute(source_directory)
	if directory_error != OK:
		return {"ok": false, "message": "Creator Studio could not create the town folder."}
	DirAccess.make_dir_recursive_absolute(data_directory)

	var copied_sources: Array[String] = []
	for index in source_files.size():
		var source_path := source_files[index]
		var safe_name := "%02d_%s" % [index + 1, source_path.get_file()]
		var destination := source_directory.path_join(safe_name)
		var copy_result := _copy_file(source_path, destination)
		if copy_result != OK:
			return {"ok": false, "message": "Could not copy %s into the town project." % source_path.get_file()}
		copied_sources.append("source_osm/%s" % safe_name)

	var town_data := {
		"schema_version": CONTENT_SCHEMA_VERSION,
		"creator_version": CREATOR_VERSION,
		"kind": "digital_world_twin_town",
		"id": town_id,
		"display_name": display_name.strip_edges(),
		"created_utc": Time.get_datetime_string_from_system(true),
		"source": {"format": "osm_xml", "files": copied_sources, "original_files": Array(source_files)},
		"map_bounds": import_result.bounds,
		"cbd": {"type": "bounding_box", "bounds": cbd_bounds},
		"starting_location": start_location,
		"statistics": import_result.statistics
	}

	var feature_data: Array[Dictionary] = []
	for feature in import_result.features:
		var serialised_points: Array[Array] = []
		for point_value in feature.points:
			serialised_points.append([point_value.x, point_value.y])
		var serialised_holes: Array[Array] = []
		for hole_value in feature.get("holes", []):
			var serialised_hole: Array[Array] = []
			for point_value in hole_value:
				serialised_hole.append([point_value.x, point_value.y])
			serialised_holes.append(serialised_hole)
		feature_data.append({
			"id": str(feature.id),
			"kind": feature.kind,
			"tags": feature.tags,
			"node_ids": feature.get("node_ids", []),
			"node_tags": feature.get("node_tags", {}),
			"points": serialised_points,
			"holes": serialised_holes,
			"geometry_quality": feature.get("geometry_quality", "osm_source"),
			"source_relation_id": feature.get("source_relation_id", "")
		})

	var write_error := _write_json(town_directory.path_join("town.json"), town_data)
	if write_error != OK:
		return {"ok": false, "message": "Could not save town.json."}
	write_error = _write_json(data_directory.path_join("map_features.json"), {
		"schema_version": CONTENT_SCHEMA_VERSION,
		"preserves_osm_node_tags": true,
		"features": feature_data
	})
	if write_error != OK:
		return {"ok": false, "message": "Could not save the map feature index."}
	var settings_result: Dictionary = GameSettingsStoreScript.save_to_town(
		town_directory,
		settings_to_save
	)
	if not settings_result.ok:
		return {"ok": false, "message": settings_result.message}
	var collision_result := _write_building_collisions(data_directory, import_result.features, import_result.bounds)
	if not collision_result.ok:
		return collision_result
	validation["building_collisions"] = collision_result.summary
	for warning in collision_result.warnings:
		validation.warnings.append(warning)
	var navigation_result := _write_navigation(data_directory, import_result.features, cbd_bounds, start_location, settings_to_save)
	if not navigation_result.ok:
		return navigation_result
	validation["navigation"] = navigation_result.summary
	for warning in navigation_result.warnings:
		validation.warnings.append(warning)
	write_error = _write_json(town_directory.path_join("runtime_profile.json"), _runtime_profile())
	if write_error != OK:
		return {"ok": false, "message": "Could not save the playable-game feature profile."}
	_write_json(town_directory.path_join("validation.json"), validation)

	return {
		"ok": true,
		"message": "Town project created successfully.",
		"town_directory": town_directory,
		"validation": validation
	}


func validate_town(display_name: String, import_result: Dictionary, cbd_bounds: Dictionary, start_location: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if display_name.strip_edges().is_empty():
		errors.append("Enter a town name.")
	if not import_result.get("ok", false):
		errors.append("Read valid OSM files before creating the town.")
	if cbd_bounds.is_empty():
		errors.append("Draw the CBD area on the map.")
	if start_location.is_empty():
		errors.append("Click the player's starting location on the map.")
	elif import_result.get("ok", false):
		var spawn_validation: Dictionary = SpawnSafetyScript.validate_starting_location(start_location, import_result.features)
		if not spawn_validation.ok:
			errors.append(spawn_validation.message)

	if import_result.get("ok", false):
		for import_warning in import_result.get("warnings", []):
			warnings.append(str(import_warning))
		var bounds: Dictionary = import_result.bounds
		if not cbd_bounds.is_empty() and not _bounds_contains_bounds(bounds, cbd_bounds):
			errors.append("The CBD area must stay inside the imported map.")
		if not start_location.is_empty() and not _bounds_contains_location(bounds, start_location):
			errors.append("The starting location must stay inside the imported map.")
		if not start_location.is_empty() and start_location.has("vehicle") and not _bounds_contains_location(bounds, start_location.vehicle):
			errors.append("The player's vehicle starting location must stay inside the imported map.")
		if import_result.statistics.buildings == 0:
			warnings.append("No buildings were found. The town can be saved, but building editing will be unavailable.")
		if import_result.statistics.roads == 0:
			warnings.append("No roads were found. Traffic generation will not be possible.")
		if int(import_result.statistics.get("unresolved_water_relations", 0)) > 0:
			errors.append("This OSM export contains incomplete water boundaries that could not be placed safely. Creator Studio will not build a playable project that might allow driving over unknown water. Export this area again with complete OSM water data; a later map-editor stage will also allow a manual correction.")

	return {
		"schema_version": CONTENT_SCHEMA_VERSION,
		"passed": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"checks": {
			"town_name": not display_name.strip_edges().is_empty(),
			"osm_imported": import_result.get("ok", false),
			"cbd_selected": not cbd_bounds.is_empty(),
			"start_selected": not start_location.is_empty(),
			"water_safely_resolved": int(import_result.get("statistics", {}).get("unresolved_water_relations", 0)) == 0
		}
	}


func update_town(town_directory: String, display_name: String, import_result: Dictionary, cbd_bounds: Dictionary, start_location: Dictionary, game_settings: Dictionary = {}) -> Dictionary:
	var validation := validate_town(display_name, import_result, cbd_bounds, start_location)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0], "validation": validation}
	var settings_to_save: Dictionary = game_settings
	if settings_to_save.is_empty():
		settings_to_save = GameSettingsStoreScript.load_from_town(town_directory).settings
	var settings_validation: Dictionary = GameSettingsStoreScript.validate(settings_to_save)
	if not settings_validation.passed:
		return {"ok": false, "message": settings_validation.errors[0], "validation": settings_validation}
	var town_path := town_directory.path_join("town.json")
	if not FileAccess.file_exists(town_path):
		return {"ok": false, "message": "The selected project is missing town.json."}
	var town_file := FileAccess.open(town_path, FileAccess.READ)
	if town_file == null:
		return {"ok": false, "message": "Creator Studio could not read town.json."}
	var parsed = JSON.parse_string(town_file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "town.json is damaged or incomplete."}
	var town: Dictionary = parsed
	town["display_name"] = display_name.strip_edges()
	town["updated_utc"] = Time.get_datetime_string_from_system(true)
	town["map_bounds"] = import_result.bounds
	town["cbd"] = {"type": "bounding_box", "bounds": cbd_bounds}
	town["starting_location"] = start_location
	town["statistics"] = import_result.statistics
	var write_error := _write_json(town_path, town)
	if write_error != OK:
		return {"ok": false, "message": "Creator Studio could not update town.json."}
	var feature_write_error := _write_map_features(town_directory.path_join("data").path_join("map_features.json"), import_result.features)
	if feature_write_error != OK:
		return {"ok": false, "message": "Creator Studio could not update the map feature index."}
	var settings_result: Dictionary = GameSettingsStoreScript.save_to_town(town_directory, settings_to_save)
	if not settings_result.ok:
		return {"ok": false, "message": settings_result.message}
	var collision_result := _write_building_collisions(town_directory.path_join("data"), import_result.features, import_result.bounds)
	if not collision_result.ok:
		return collision_result
	validation["building_collisions"] = collision_result.summary
	for warning in collision_result.warnings:
		validation.warnings.append(warning)
	var navigation_result := _write_navigation(town_directory.path_join("data"), import_result.features, cbd_bounds, start_location, settings_to_save)
	if not navigation_result.ok:
		return navigation_result
	validation["navigation"] = navigation_result.summary
	for warning in navigation_result.warnings:
		validation.warnings.append(warning)
	var profile_error := _write_json(town_directory.path_join("runtime_profile.json"), _runtime_profile())
	if profile_error != OK:
		return {"ok": false, "message": "Creator Studio could not update the playable-game feature profile."}
	_write_json(town_directory.path_join("validation.json"), validation)
	return {"ok": true, "message": "Project changes and pathfinding saved.", "town_directory": town_directory, "validation": validation}


func _write_map_features(path_value: String, features: Array) -> Error:
	var feature_data: Array[Dictionary] = []
	for feature_value in features:
		var feature: Dictionary = feature_value
		var serialised_points: Array = []
		for point_value in feature.get("points", []):
			serialised_points.append([point_value.x, point_value.y])
		var serialised_holes: Array = []
		for hole_value in feature.get("holes", []):
			var serialised_hole: Array = []
			for point_value in hole_value:
				serialised_hole.append([point_value.x, point_value.y])
			serialised_holes.append(serialised_hole)
		feature_data.append({
			"id": str(feature.get("id", "")),
			"kind": str(feature.get("kind", "")),
			"tags": feature.get("tags", {}),
			"node_ids": feature.get("node_ids", []),
			"node_tags": feature.get("node_tags", {}),
			"points": serialised_points,
			"holes": serialised_holes
		})
	return _write_json(path_value, {"schema_version": CONTENT_SCHEMA_VERSION, "preserves_osm_node_tags": true, "features": feature_data})


func _runtime_profile() -> Dictionary:
	return {
		"schema_version": CONTENT_SCHEMA_VERSION,
		"runtime_family": "2d_digital_world_twin",
		"required_features": REQUIRED_RUNTIME_FEATURES,
		"template_status": "preview_ready",
		"play_mode": "creator_studio_shared_runtime",
		"capabilities": {
			"building_collision_data": "ready",
			"building_collision_streaming_loader": "ready",
			"map_rendering": "ready",
			"walking_and_wagon": "preview_ready",
			"generational_survival_player_and_wagon": "ready",
			"graph_population_movement": "preview_ready",
			"driving_side_lane_positioning": "preview_ready",
			"traffic_following_spacing": "preview_ready",
			"basic_intersection_reservations": "preview_ready",
			"traffic_player_vehicle_avoidance": "preview_ready",
			"traffic_jam_recovery": "preview_ready",
			"osm_traffic_controls": "preview_ready",
			"traffic_control_graphics": "preview_ready",
			"osm_water_placement": "preview_ready",
			"osm_land_cover": "preview_ready",
			"bridge_water_crossings": "preview_ready",
			"tunnel_layer_visibility": "preview_ready",
			"water_movement_blocking": "preview_ready",
			"smooth_vehicle_heading": "preview_ready",
			"skin_pigmentation_visuals": "preview_ready",
			"saved_driving_values": "preview_ready",
			"grass_surface_tracks": "preview_ready",
			"camera_and_overview": "preview_ready"
		},
		"preview_limitations": [
			"ambiguous_or_missing_osm_water_geometry_requires_a_complete_export_or_future_map_editor_override",
			"unmapped_ground_retains_stylised_grass_not_verified_land_cover",
			"land_cover_does_not_infer_tree_collisions_wetland_depth_or_access_rights",
			"detailed_turn_corridors_and_compatible_signal_movements",
			"venues_and_interiors",
			"property_boundaries_and_breakable_fences",
			"save_game_progress"
		]
	}


func _write_building_collisions(data_directory: String, features: Array, map_bounds: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(data_directory)
	var build_result: Dictionary = BuildingCollisionBuilderScript.new().build(features, map_bounds)
	if not build_result.ok:
		return {"ok": false, "message": build_result.message}
	var collision_data: Dictionary = build_result.data
	var write_error := _write_json(data_directory.path_join("building_collisions.json"), collision_data)
	if write_error != OK:
		return {"ok": false, "message": "Creator Studio could not save the building collisions."}
	return {
		"ok": true,
		"summary": collision_data.statistics,
		"warnings": collision_data.warnings
	}


func _write_navigation(data_directory: String, features: Array, cbd_bounds: Dictionary, start_location: Dictionary, game_settings: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(data_directory)
	var build_result: Dictionary = NavigationBuilderScript.new().build(features, cbd_bounds, start_location, game_settings)
	if not build_result.ok:
		return {"ok": false, "message": build_result.message}
	var navigation_data: Dictionary = build_result.data
	var write_error := _write_json(data_directory.path_join("navigation_graphs.json"), navigation_data)
	if write_error != OK:
		return {"ok": false, "message": "Creator Studio could not save the generated pathfinding networks."}
	return {
		"ok": true,
		"summary": {
			"generated": true,
			"vehicle_nodes": navigation_data.vehicle.nodes.size(),
			"vehicle_edges": navigation_data.vehicle.edges.size(),
			"pedestrian_nodes": navigation_data.pedestrian.nodes.size(),
			"pedestrian_edges": navigation_data.pedestrian.edges.size(),
			"aerial_nodes": navigation_data.aerial.nodes.size(),
			"aerial_edges": navigation_data.aerial.edges.size(),
			"vehicle_cbd_reachable": navigation_data.access.vehicle.cbd_reachable,
			"pedestrian_cbd_reachable": navigation_data.access.pedestrian.cbd_reachable,
			"traffic_signal_nodes": int(navigation_data.vehicle.get("traffic_control_counts", {}).get("traffic_signals", 0)),
			"stop_sign_nodes": int(navigation_data.vehicle.get("traffic_control_counts", {}).get("stop", 0)),
			"give_way_nodes": int(navigation_data.vehicle.get("traffic_control_counts", {}).get("give_way", 0))
		},
		"warnings": navigation_data.warnings
	}


func _safe_id(display_name: String) -> String:
	var result := display_name.strip_edges().to_lower()
	var safe := ""
	for character in result:
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			safe += character
		elif character in [" ", "-", "_"] and not safe.ends_with("_"):
			safe += "_"
	return safe.trim_suffix("_") if safe != "" else "untitled_town"


func _absolute_path(path_value: String) -> String:
	if path_value.begins_with("user://") or path_value.begins_with("res://"):
		return ProjectSettings.globalize_path(path_value)
	return path_value


func _copy_file(source_path: String, destination_path: String) -> Error:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		return FileAccess.get_open_error()
	destination.store_buffer(source.get_buffer(source.get_length()))
	return OK


func _write_json(path_value: String, data: Variant) -> Error:
	var file := FileAccess.open(path_value, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t") + "\n")
	return OK


func _bounds_contains_bounds(outer: Dictionary, inner: Dictionary) -> bool:
	return inner.west >= outer.west and inner.east <= outer.east and inner.south >= outer.south and inner.north <= outer.north


func _bounds_contains_location(bounds: Dictionary, location: Dictionary) -> bool:
	return location.longitude >= bounds.west and location.longitude <= bounds.east and location.latitude >= bounds.south and location.latitude <= bounds.north
