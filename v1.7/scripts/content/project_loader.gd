class_name CreatorProjectLoader
extends RefCounted

const OsmImporterScript = preload("res://scripts/towns/osm_importer.gd")


func load_project(town_directory: String) -> Dictionary:
	var resolved := resolve_project_directory(town_directory)
	if not resolved.ok:
		return resolved
	town_directory = str(resolved.town_directory)
	var town_path := town_directory.path_join("town.json")
	var features_path := town_directory.path_join("data").path_join("map_features.json")
	if not FileAccess.file_exists(town_path):
		return {"ok": false, "message": "Choose a project folder containing town.json."}
	if not FileAccess.file_exists(features_path):
		return {"ok": false, "message": "This project is missing data/map_features.json."}

	var town_result := _read_json(town_path)
	if not town_result.ok:
		return town_result
	var feature_result := _read_json(features_path)
	if not feature_result.ok:
		return feature_result
	var town: Dictionary = town_result.data
	var preserves_osm_node_tags := bool(feature_result.data.get("preserves_osm_node_tags", false))
	var stored_features: Array = feature_result.data.get("features", [])
	var import_statistics: Dictionary = town.get("statistics", {})
	var features: Array[Dictionary] = []
	for stored_feature in stored_features:
		if not stored_feature is Dictionary:
			continue
		var geographic_points: Array[Vector2] = []
		for stored_point in stored_feature.get("points", []):
			if stored_point is Array and stored_point.size() >= 2:
				geographic_points.append(Vector2(float(stored_point[0]), float(stored_point[1])))
		# A mapped natural=tree is a point, not a two-point way.
		var minimum_points := 1 if str(stored_feature.get("kind", "")) == "tree" else 2
		if geographic_points.size() < minimum_points:
			continue
		var geographic_holes: Array[Array] = []
		for stored_hole in stored_feature.get("holes", []):
			var geographic_hole: Array[Vector2] = []
			for stored_point in stored_hole:
				if stored_point is Array and stored_point.size() >= 2:
					geographic_hole.append(Vector2(float(stored_point[0]), float(stored_point[1])))
			if geographic_hole.size() >= 3:
				geographic_holes.append(geographic_hole)
		features.append({
			"id": str(stored_feature.get("id", "")),
			"kind": str(stored_feature.get("kind", "")),
			"tags": stored_feature.get("tags", {}),
			"node_ids": stored_feature.get("node_ids", []),
			"node_tags": stored_feature.get("node_tags", {}),
			"points": geographic_points,
			"precise_points": stored_feature.get("precise_points", []),
			"holes": geographic_holes
		})

	var source_files := PackedStringArray()
	for relative_source in town.get("source", {}).get("files", []):
		var source_path := town_directory.path_join(str(relative_source))
		if FileAccess.file_exists(source_path):
			source_files.append(source_path)
	var original_source_files := PackedStringArray()
	for original_source in town.get("source", {}).get("original_files", []):
		var original_path := str(original_source)
		if FileAccess.file_exists(original_path):
			original_source_files.append(original_path)
	# Older v1.1 packs did not retain OSM node identities in map_features.json.
	# Re-reading their copied sources prevents bridges/tunnels from being joined
	# merely because their coordinates cross.
	var source_bounds: Dictionary = {}
	if not source_files.is_empty() and (features.is_empty() or features[0].get("node_ids", []).is_empty() or not preserves_osm_node_tags):
		var refreshed: Dictionary = OsmImporterScript.new().parse_files(source_files)
		if refreshed.get("ok", false):
			features = refreshed.features
			import_statistics = refreshed.statistics
			source_bounds = refreshed.bounds
	# Older imports could save another town's metadata over this project's
	# unchanged geometry. Do not frame Albury using Gold Coast coordinates.
	# Recover in memory only; the creator explicitly saves any repaired setup.
	var feature_bounds := _feature_bounds(features)
	var saved_bounds: Dictionary = town.get("map_bounds", {})
	var recovery_message := ""
	if not feature_bounds.is_empty() and not _bounds_overlap(saved_bounds, feature_bounds):
		if source_bounds.is_empty() and not source_files.is_empty():
			var source_result: Dictionary = OsmImporterScript.new().parse_files(source_files)
			if source_result.get("ok", false): source_bounds = source_result.bounds
		var recovered_bounds := source_bounds if _bounds_overlap(source_bounds, feature_bounds) else feature_bounds
		town["map_bounds"] = recovered_bounds.duplicate(true)
		recovery_message = "Recovered the map view: saved map bounds did not match this project's geometry."
		var cbd_bounds: Dictionary = town.get("cbd", {}).get("bounds", {})
		if not _bounds_inside(recovered_bounds, cbd_bounds):
			town["cbd"] = {"type": "bounding_box", "bounds": {}}
		var saved_start: Dictionary = town.get("starting_location", {})
		if not _location_inside(recovered_bounds, saved_start) or not _location_inside(recovered_bounds, saved_start.get("vehicle", {})):
			town["starting_location"] = {}
		recovery_message += " Check Town name, CBD area and Player start, then Save before Play test. Existing content and files have not been changed."
	var runtime_profile: Dictionary = {}
	var runtime_path := town_directory.path_join("runtime_profile.json")
	if FileAccess.file_exists(runtime_path):
		var runtime_result := _read_json(runtime_path)
		if runtime_result.ok:
			runtime_profile = runtime_result.data
	var navigation_path := town_directory.path_join("data").path_join("navigation_graphs.json")
	var navigation_ready := FileAccess.file_exists(navigation_path)
	var building_collisions_path := town_directory.path_join("data").path_join("building_collisions.json")
	var building_collisions_ready := FileAccess.file_exists(building_collisions_path)

	return {
		"ok": true,
		"message": "Project loaded successfully.",
		"recovery_message": recovery_message,
		"town_directory": town_directory,
		"town": town,
		"source_files": source_files,
		"original_source_files": original_source_files,
		"import_result": {
			"ok": true,
			"message": "",
			"features": features,
			"bounds": town.get("map_bounds", {}),
			"statistics": import_statistics,
			"recovery_message": recovery_message,
			"warnings": []
		},
		"runtime_profile": runtime_profile,
		"runtime_ready": str(runtime_profile.get("template_status", "")) in ["preview_ready", "ready"],
		"navigation_ready": navigation_ready,
		"building_collisions_ready": building_collisions_ready
	}


func _feature_bounds(features: Array[Dictionary]) -> Dictionary:
	var bounds := {"west": INF, "east": -INF, "south": INF, "north": -INF}
	for feature in features:
		for point: Vector2 in feature.get("points", []):
			if not point.is_finite(): continue
			bounds.west = minf(bounds.west, point.x)
			bounds.east = maxf(bounds.east, point.x)
			bounds.south = minf(bounds.south, point.y)
			bounds.north = maxf(bounds.north, point.y)
	return bounds if _valid_bounds(bounds) else {}


func _valid_bounds(bounds: Dictionary) -> bool:
	for key in ["west", "east", "south", "north"]:
		if not bounds.has(key) or not is_finite(float(bounds[key])): return false
	return float(bounds.west) < float(bounds.east) and float(bounds.south) < float(bounds.north)


func _bounds_overlap(first: Dictionary, second: Dictionary) -> bool:
	if not _valid_bounds(first) or not _valid_bounds(second): return false
	return float(first.west) <= float(second.east) and float(first.east) >= float(second.west) and float(first.south) <= float(second.north) and float(first.north) >= float(second.south)


func _bounds_inside(outer: Dictionary, inner: Dictionary) -> bool:
	if not _valid_bounds(outer) or not _valid_bounds(inner): return false
	return float(inner.west) >= float(outer.west) and float(inner.east) <= float(outer.east) and float(inner.south) >= float(outer.south) and float(inner.north) <= float(outer.north)


func _location_inside(bounds: Dictionary, location: Dictionary) -> bool:
	if not _valid_bounds(bounds) or not location.has("longitude") or not location.has("latitude"): return false
	var longitude := float(location.longitude)
	var latitude := float(location.latitude)
	return is_finite(longitude) and is_finite(latitude) and longitude >= float(bounds.west) and longitude <= float(bounds.east) and latitude >= float(bounds.south) and latitude <= float(bounds.north)


func resolve_project_directory(selected_directory: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(selected_directory):
		return {"ok": false, "message": "This project folder is no longer available. Choose an existing saved town folder."}
	if FileAccess.file_exists(selected_directory.path_join("town.json")):
		return {"ok": true, "town_directory": selected_directory}
	var candidates: Array[String] = []
	for child_name in DirAccess.get_directories_at(selected_directory):
		var child_path := selected_directory.path_join(child_name)
		if FileAccess.file_exists(child_path.path_join("town.json")):
			candidates.append(child_path)
	if candidates.size() == 1:
		return {"ok": true, "town_directory": candidates[0]}
	if candidates.size() > 1:
		return {"ok": false, "message": "This folder contains more than one town project. Open it and choose the specific town folder you want to use."}
	return {"ok": false, "message": "Choose a town project folder containing town.json, or its immediate parent folder."}


func _read_json(path_value: String) -> Dictionary:
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not read %s." % path_value.get_file()}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "%s is damaged or is not valid project data." % path_value.get_file()}
	return {"ok": true, "data": parsed}
