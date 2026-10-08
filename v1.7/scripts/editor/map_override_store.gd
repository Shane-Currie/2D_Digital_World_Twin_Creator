class_name MapOverrideStore
extends RefCounted

## Persistent, town-specific corrections layered over generated OSM features.
## Original and copied OSM files are never edited.

const SCHEMA_VERSION := 1
const FILE_NAME := "map_overrides.json"
const SUPPORTED_ZONE_MODES := ["blocked_water", "allowed_ground"]
const Footprints = preload("res://scripts/editor/building_footprint_editor.gd")


func empty_data(features: Array = [], bounds: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"kind": "creator_map_overrides",
		"source_fingerprint": source_fingerprint(features, bounds),
		"hidden_feature_ids": [],
		"zones": [],
		"notes": {
			"blocked_water": "Creator-authored water blocks all ground actors; NPDs remain aerial.",
			"allowed_ground": "Creator-authored passable ground corrects mapped water only and does not erase buildings."
		}
	}


func load_from_town(town_directory: String, features: Array = [], bounds: Dictionary = {}) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value):
		return {"ok": true, "data": empty_data(features, bounds), "created_default": true, "warnings": []}
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not read data/%s." % FILE_NAME}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "data/%s is damaged or is not valid JSON." % FILE_NAME}
	var validation := validate(parsed)
	if not validation.ok:
		return validation
	var data: Dictionary = parsed.duplicate(true)
	var warnings: Array[String] = []
	var current_fingerprint := source_fingerprint(features, bounds)
	if not features.is_empty() and not str(data.get("source_fingerprint", "")).is_empty() and str(data.source_fingerprint) != current_fingerprint:
		warnings.append("The OSM feature list changed since these map corrections were saved. Creator Studio will reapply matching stable IDs and report missing ones.")
	return {"ok": true, "data": data, "created_default": false, "warnings": warnings}


func save_to_town(town_directory: String, data: Dictionary, features: Array = [], bounds: Dictionary = {}) -> Dictionary:
	var validation := validate(data)
	if not validation.ok:
		return validation
	var saved: Dictionary = data.duplicate(true)
	saved["source_fingerprint"] = source_fingerprint(features, bounds)
	saved["updated_utc"] = Time.get_datetime_string_from_system(true)
	var data_directory := town_directory.path_join("data")
	var directory_error := DirAccess.make_dir_recursive_absolute(data_directory)
	if directory_error != OK:
		return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	var file := FileAccess.open(data_directory.path_join(FILE_NAME), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save data/%s." % FILE_NAME}
	# Shared-wall tests require the original double precision, not rounded vectors.
	file.store_string(JSON.stringify(saved, "  ", true, true))
	return {"ok": true, "data": saved, "message": "Map corrections saved."}


func validate(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or str(data.get("kind", "")) != "creator_map_overrides":
		return {"ok": false, "message": "The map corrections use an unsupported format."}
	if not data.get("hidden_feature_ids", []) is Array or not data.get("zones", []) is Array:
		return {"ok": false, "message": "The map corrections are incomplete."}
	var seen_zone_ids: Dictionary = {}
	if not data.get("custom_buildings", []) is Array or data.get("custom_buildings", []).size() > 1000: return {"ok": false, "message": "Use at most 1,000 custom building footprints."}
	var building_ids: Dictionary = {}
	for feature in data.get("custom_buildings", []):
		if not feature is Dictionary or not Footprints.valid(feature) or building_ids.has(str(feature.get("id", ""))): return {"ok": false, "message": "A custom building footprint is invalid or has a duplicate ID."}
		building_ids[str(feature.id)] = true
	for zone_value in data.get("zones", []):
		if not zone_value is Dictionary:
			return {"ok": false, "message": "A map correction zone is invalid."}
		var zone: Dictionary = zone_value
		var zone_id := str(zone.get("id", ""))
		if zone_id.is_empty() or seen_zone_ids.has(zone_id):
			return {"ok": false, "message": "Every map correction zone needs a unique stable ID."}
		seen_zone_ids[zone_id] = true
		if str(zone.get("mode", "")) not in SUPPORTED_ZONE_MODES:
			return {"ok": false, "message": "Map correction %s has an unsupported type." % zone_id}
		if not zone.get("points", []) is Array or zone.points.size() < 4:
			return {"ok": false, "message": "Map correction %s needs a closed area." % zone_id}
	return {"ok": true}


func apply(features: Array, data: Dictionary) -> Dictionary:
	var validation := validate(data)
	if not validation.ok:
		return validation
	features = features.duplicate(true)
	for custom in data.get("custom_buildings", []):
		if features.any(func(value): return str(value.get("id", "")) == str(custom.id)):
			return {"ok": false, "message": "A custom building ID conflicts with a source feature."}
		var feature: Dictionary = custom.duplicate(true)
		feature["points"] = Array(_points(feature.points))
		features.append(feature)
	var source_ids: Dictionary = {}
	for feature_value in features:
		var feature: Dictionary = feature_value
		source_ids[str(feature.get("id", ""))] = true
	var hidden_lookup: Dictionary = {}
	var unresolved_hidden: Array[String] = []
	for id_value in data.get("hidden_feature_ids", []):
		var feature_id := str(id_value)
		hidden_lookup[feature_id] = true
		if not source_ids.has(feature_id):
			unresolved_hidden.append(feature_id)
	var effective: Array[Dictionary] = []
	for feature_value in features:
		var feature: Dictionary = feature_value
		if hidden_lookup.has(str(feature.get("id", ""))):
			continue
		effective.append(feature.duplicate(true))

	var allowed_zones: Array[Dictionary] = []
	var blocked_count := 0
	for zone_value in data.get("zones", []):
		var zone: Dictionary = zone_value
		var points := _points(zone.get("points", []))
		if points.size() < 4:
			continue
		if str(zone.mode) == "blocked_water":
			blocked_count += 1
			effective.append({
				"id": "creator:%s" % str(zone.id),
				"kind": "water",
				"tags": {"natural": "water", "source": "creator_override", "creator_override": "blocked_water"},
				"node_ids": [], "node_tags": {}, "points": Array(points), "holes": [],
				"geometry_quality": "creator_authored_override"
			})
		else:
			allowed_zones.append({"id": str(zone.id), "points": points, "centre": _polygon_centre(points)})

	var applied_allowed := 0
	var unmatched_allowed: Array[String] = []
	for zone in allowed_zones:
		var matched := false
		for feature in effective:
			if str(feature.get("kind", "")) != "water":
				continue
			var outer := _points(feature.get("points", []))
			if outer.size() < 3 or not Geometry2D.is_point_in_polygon(zone.centre, outer):
				continue
			var holes: Array = feature.get("holes", []).duplicate(true)
			holes.append(Array(zone.points))
			feature["holes"] = holes
			matched = true
			applied_allowed += 1
		if not matched:
			unmatched_allowed.append(str(zone.id))

	var warnings: Array[String] = []
	if not unresolved_hidden.is_empty():
		warnings.append("%d hidden source feature(s) no longer exist and need creator review." % unresolved_hidden.size())
	if not unmatched_allowed.is_empty():
		warnings.append("%d passable-ground zone(s) are not centred on mapped water and have no gameplay effect." % unmatched_allowed.size())
	return {
		"ok": true,
		"features": effective,
		"warnings": warnings,
		"unresolved_hidden_feature_ids": unresolved_hidden,
		"unmatched_allowed_zone_ids": unmatched_allowed,
		"statistics": {
			"hidden_features": hidden_lookup.size() - unresolved_hidden.size(),
			"blocked_water_zones": blocked_count,
			"applied_allowed_ground_zones": applied_allowed,
			"unresolved_overrides": unresolved_hidden.size() + unmatched_allowed.size()
		}
	}


func source_fingerprint(features: Array, bounds: Dictionary) -> String:
	var feature_ids := PackedStringArray()
	for feature_value in features:
		var feature: Dictionary = feature_value
		feature_ids.append("%s:%s" % [str(feature.get("kind", "")), str(feature.get("id", ""))])
	feature_ids.sort()
	var bounds_text := "%.8f,%.8f,%.8f,%.8f" % [
		float(bounds.get("west", 0.0)), float(bounds.get("south", 0.0)),
		float(bounds.get("east", 0.0)), float(bounds.get("north", 0.0))
	]
	return (bounds_text + "\n" + "\n".join(feature_ids)).sha256_text()


func _points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		if value is Vector2:
			result.append(value)
		elif value is Array and value.size() >= 2:
			result.append(Vector2(float(value[0]), float(value[1])))
		elif value is Dictionary:
			result.append(Vector2(float(value.get("longitude", 0.0)), float(value.get("latitude", 0.0))))
	if result.size() > 2 and not result[0].is_equal_approx(result[result.size() - 1]):
		result.append(result[0])
	return result


func _polygon_centre(points: PackedVector2Array) -> Vector2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds.get_center()
