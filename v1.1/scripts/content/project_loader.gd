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
		if geographic_points.size() < 2:
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
	if not source_files.is_empty() and (features.is_empty() or features[0].get("node_ids", []).is_empty() or not preserves_osm_node_tags):
		var refreshed: Dictionary = OsmImporterScript.new().parse_files(source_files)
		if refreshed.get("ok", false):
			features = refreshed.features
			import_statistics = refreshed.statistics
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
			"warnings": []
		},
		"runtime_profile": runtime_profile,
		"runtime_ready": str(runtime_profile.get("template_status", "")) in ["preview_ready", "ready"],
		"navigation_ready": navigation_ready,
		"building_collisions_ready": building_collisions_ready
	}


func resolve_project_directory(selected_directory: String) -> Dictionary:
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
