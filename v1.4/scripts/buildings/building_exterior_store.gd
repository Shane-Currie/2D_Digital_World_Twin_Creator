class_name BuildingExteriorStore
extends RefCounted

## Town-specific exterior artwork and entrance choices keyed to stable OSM IDs.
## Source OSM geometry is never edited.

const SCHEMA_VERSION := 1
const FILE_NAME := "building_exteriors.json"
const MAX_IMAGE_BYTES := 25 * 1024 * 1024
const MAX_IMAGE_DIMENSION := 4096
const MAX_ENTRANCES_PER_BUILDING := 8
const SUPPORTED_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const METRES_PER_LATITUDE_DEGREE := 110540.0
const METRES_PER_LONGITUDE_DEGREE := 111320.0


func empty_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "kind": "creator_building_exteriors", "buildings": {}}


func load_from_town(town_directory: String) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value):
		return {"ok": true, "data": empty_data(), "created_default": true}
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not read data/%s." % FILE_NAME}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "data/%s is damaged or is not valid JSON." % FILE_NAME}
	var migrated := _migrate_data(parsed)
	var validation := validate(migrated)
	if not validation.ok:
		return validation
	return {"ok": true, "data": migrated, "created_default": false}


func save_to_town(town_directory: String, data: Dictionary) -> Dictionary:
	var saved: Dictionary = _migrate_data(data)
	var validation := validate(saved)
	if not validation.ok:
		return validation
	for record_value in saved.get("buildings", {}).values():
		var record: Dictionary = record_value
		var relative_path := str(record.get("exterior", {}).get("relative_path", ""))
		if not relative_path.is_empty() and not FileAccess.file_exists(town_directory.path_join(relative_path)):
			return {"ok": false, "message": "A selected building exterior image is missing. Import that image again before saving."}
	var data_directory := town_directory.path_join("data")
	if DirAccess.make_dir_recursive_absolute(data_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	saved["updated_utc"] = Time.get_datetime_string_from_system(true)
	var file := FileAccess.open(data_directory.path_join(FILE_NAME), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save data/%s." % FILE_NAME}
	file.store_string(JSON.stringify(saved, "  "))
	return {"ok": true, "data": saved, "message": "Building exterior choices saved."}


func validate(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or str(data.get("kind", "")) != "creator_building_exteriors":
		return {"ok": false, "message": "The building exterior file uses an unsupported format."}
	if not data.get("buildings", {}) is Dictionary:
		return {"ok": false, "message": "The building exterior file is incomplete."}
	for feature_id in data.buildings:
		var record = data.buildings[feature_id]
		if not record is Dictionary or str(record.get("feature_id", "")) != str(feature_id):
			return {"ok": false, "message": "Building exterior %s has an invalid stable ID." % str(feature_id)}
		if record.has("exterior"):
			var exterior: Dictionary = record.exterior
			var relative_path := str(exterior.get("relative_path", "")).replace("\\", "/")
			if relative_path.is_empty() or relative_path.begins_with("/") or relative_path.contains(":") or relative_path.split("/").has("..") or str(exterior.get("display_mode", "")) != "clip_to_footprint":
				return {"ok": false, "message": "Building exterior %s has invalid artwork information." % str(feature_id)}
			if float(exterior.get("scale_percent", 100.0)) < 50.0 or float(exterior.get("scale_percent", 100.0)) > 300.0:
				return {"ok": false, "message": "Building exterior %s has an invalid image scale." % str(feature_id)}
			if absf(float(exterior.get("rotation_degrees", 0.0))) > 180.0:
				return {"ok": false, "message": "Building exterior %s has an invalid image rotation." % str(feature_id)}
			if absf(float(exterior.get("offset_x_percent", 0.0))) > 100.0 or absf(float(exterior.get("offset_y_percent", 0.0))) > 100.0:
				return {"ok": false, "message": "Building exterior %s has an invalid image alignment." % str(feature_id)}
		var doors = record.get("doors", [])
		if not doors is Array or doors.size() > MAX_ENTRANCES_PER_BUILDING:
			return {"ok": false, "message": "Building exterior %s has too many entrances." % str(feature_id)}
		var door_ids: Dictionary = {}
		for door_value in doors:
			if not door_value is Dictionary:
				return {"ok": false, "message": "Building exterior %s has invalid entrance information." % str(feature_id)}
			var door: Dictionary = door_value
			var door_id := str(door.get("id", ""))
			if door_id.is_empty() or door_ids.has(door_id):
				return {"ok": false, "message": "Building exterior %s has duplicate entrance IDs." % str(feature_id)}
			door_ids[door_id] = true
			for key in ["longitude", "latitude", "outside_longitude", "outside_latitude"]:
				if not door.has(key) or not door[key] is float and not door[key] is int:
					return {"ok": false, "message": "Building exterior %s has an invalid door position." % str(feature_id)}
	return {"ok": true}


func import_exterior(town_directory: String, data: Dictionary, feature_id: String, source_path: String) -> Dictionary:
	if feature_id.is_empty():
		return {"ok": false, "message": "Select a building footprint before importing artwork."}
	if not FileAccess.file_exists(source_path):
		return {"ok": false, "message": "The selected artwork file could not be found."}
	var extension := source_path.get_extension().to_lower()
	if extension not in SUPPORTED_EXTENSIONS:
		return {"ok": false, "message": "Choose a PNG, JPG, JPEG or WebP image."}
	if FileAccess.get_file_as_bytes(source_path).size() > MAX_IMAGE_BYTES:
		return {"ok": false, "message": "Choose an exterior image smaller than 25 MB."}
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return {"ok": false, "message": "Creator Studio could not read that image."}
	if image.get_width() < 16 or image.get_height() < 16 or image.get_width() > MAX_IMAGE_DIMENSION or image.get_height() > MAX_IMAGE_DIMENSION:
		return {"ok": false, "message": "Exterior images must be between 16 and 4,096 pixels on each side."}
	var safe_id := _safe_id(feature_id)
	var asset_directory := town_directory.path_join("assets").path_join("buildings").path_join(safe_id)
	if DirAccess.make_dir_recursive_absolute(asset_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create this building's artwork folder."}
	var file_name := "exterior_%s.%s" % [FileAccess.get_md5(source_path).left(12), extension]
	var destination := asset_directory.path_join(file_name)
	var copy_error := DirAccess.copy_absolute(source_path, destination)
	if copy_error != OK:
		return {"ok": false, "message": "Creator Studio could not copy the exterior image into the town project."}
	var updated: Dictionary = _migrate_data(data)
	var buildings: Dictionary = updated.get("buildings", {}).duplicate(true)
	var record: Dictionary = buildings.get(feature_id, {"feature_id": feature_id}).duplicate(true)
	var normalized_town := town_directory.replace("\\", "/").trim_suffix("/")
	var normalized_destination := destination.replace("\\", "/")
	record["exterior"] = {
		"relative_path": normalized_destination.trim_prefix(normalized_town + "/"),
		"source_name": source_path.get_file(), "width": image.get_width(), "height": image.get_height(),
		"display_mode": "clip_to_footprint", "scale_percent": 100.0,
		"rotation_degrees": 0.0, "offset_x_percent": 0.0, "offset_y_percent": 0.0
	}
	buildings[feature_id] = record
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "record": record, "message": "Exterior artwork imported and clipped to the selected footprint."}


func set_exterior_transform(data: Dictionary, feature_id: String, scale_percent: float, rotation_degrees: float, offset_x_percent: float, offset_y_percent: float) -> Dictionary:
	var updated := _migrate_data(data)
	var buildings: Dictionary = updated.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id) or not buildings[feature_id].has("exterior"):
		return {"ok": false, "message": "Import exterior artwork before changing its alignment."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var exterior: Dictionary = record.exterior.duplicate(true)
	exterior["scale_percent"] = clampf(scale_percent, 50.0, 300.0)
	exterior["rotation_degrees"] = clampf(rotation_degrees, -180.0, 180.0)
	exterior["offset_x_percent"] = clampf(offset_x_percent, -100.0, 100.0)
	exterior["offset_y_percent"] = clampf(offset_y_percent, -100.0, 100.0)
	record["exterior"] = exterior
	buildings[feature_id] = record
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "record": record}


func set_door(data: Dictionary, feature: Dictionary, requested_location: Dictionary, features: Array, bounds: Dictionary, navigation: Dictionary = {}, replace_index: int = -1) -> Dictionary:
	var feature_id := str(feature.get("id", ""))
	var ring := _points(feature.get("points", []))
	if feature_id.is_empty() or ring.size() < 3:
		return {"ok": false, "message": "Select a valid building footprint first."}
	var origin := _polygon_centre(ring)
	var requested := Vector2(float(requested_location.longitude), float(requested_location.latitude))
	var requested_metres := _to_metres(requested, origin)
	var metres_ring := PackedVector2Array()
	for point in ring:
		metres_ring.append(_to_metres(point, origin))
	var door_metres := metres_ring[0]
	var best_distance := INF
	var door_segment_index := 0
	for index in range(metres_ring.size() - 1):
		var candidate := Geometry2D.get_closest_point_to_segment(requested_metres, metres_ring[index], metres_ring[index + 1])
		var distance := candidate.distance_to(requested_metres)
		if distance < best_distance:
			best_distance = distance
			door_metres = candidate
			door_segment_index = index
	var segment_direction := metres_ring[door_segment_index].direction_to(metres_ring[door_segment_index + 1])
	var first_normal := Vector2(-segment_direction.y, segment_direction.x)
	var second_normal := -first_normal
	# Prefer the side on which the creator clicked, but test both. This remains
	# correct for concave footprints where a bounds-centre direction can point
	# through another part of the same building.
	var requested_direction := door_metres.direction_to(requested_metres)
	var normals := [first_normal, second_normal]
	if requested_direction.dot(second_normal) > requested_direction.dot(first_normal):
		normals = [second_normal, first_normal]
	var door_location := _from_metres(door_metres, origin)
	var outside := Vector2.INF
	for clearance in [2.0, 3.5, 5.0, 7.5]:
		for normal in normals:
			var candidate_location := _from_metres(door_metres + normal * clearance, origin)
			# The arrow stands outside every solid footprint, including the selected
			# building. The door itself remains snapped to that footprint's edge.
			if _location_is_clear(candidate_location, features, bounds):
				outside = candidate_location
				break
		if outside != Vector2.INF:
			break
	if outside == Vector2.INF:
		return {"ok": false, "message": "Creator Studio could not find a clear exterior approach at that wall. Choose another side of the building."}
	var navigation_link := _nearest_pedestrian_node(outside, navigation)
	var door: Dictionary = {
		"longitude": door_location.x, "latitude": door_location.y,
		"outside_longitude": outside.x, "outside_latitude": outside.y,
		"entry_arrow": "outside_points_to_door", "approach_verified_clear": true,
		"entrance_source": "creator_selected"
	}
	if not navigation_link.is_empty():
		door["pedestrian_node_id"] = int(navigation_link.id)
		door["route_link_distance_metres"] = float(navigation_link.distance_metres)
	var updated: Dictionary = _migrate_data(data)
	var buildings: Dictionary = updated.get("buildings", {}).duplicate(true)
	var record: Dictionary = buildings.get(feature_id, {"feature_id": feature_id}).duplicate(true)
	var doors: Array = record.get("doors", []).duplicate(true)
	if replace_index >= 0 and replace_index < doors.size():
		door["id"] = str(doors[replace_index].get("id", "entrance_%d" % (replace_index + 1)))
		doors[replace_index] = door
	else:
		if doors.size() >= MAX_ENTRANCES_PER_BUILDING:
			return {"ok": false, "message": "A building can currently have up to %d entrances." % MAX_ENTRANCES_PER_BUILDING}
		door["id"] = _next_entrance_id(doors)
		doors.append(door)
	record["doors"] = doors
	record.erase("door")
	buildings[feature_id] = record
	updated["buildings"] = buildings
	var warning := "" if not navigation_link.is_empty() else " No pedestrian route node is within 250 metres, so interior path linking still needs attention."
	return {"ok": true, "data": updated, "record": record, "door_index": replace_index if replace_index >= 0 else doors.size() - 1, "message": "Entrance and clear green entry arrow placed.%s" % warning}


func remove_door(data: Dictionary, feature_id: String, door_index: int) -> Dictionary:
	var updated := _migrate_data(data)
	var buildings: Dictionary = updated.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Select a building entrance first."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var doors: Array = record.get("doors", []).duplicate(true)
	if door_index < 0 or door_index >= doors.size():
		return {"ok": false, "message": "Select a valid entrance first."}
	doors.remove_at(door_index)
	record["doors"] = doors
	buildings[feature_id] = record
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "record": record, "message": "Selected entrance removed."}


func remove_record(data: Dictionary, feature_id: String) -> Dictionary:
	var updated: Dictionary = _migrate_data(data)
	var buildings: Dictionary = updated.get("buildings", {}).duplicate(true)
	buildings.erase(feature_id)
	updated["buildings"] = buildings
	return updated


func _migrate_data(data: Dictionary) -> Dictionary:
	var updated: Dictionary = data.duplicate(true)
	var buildings: Dictionary = updated.get("buildings", {}).duplicate(true)
	for feature_id in buildings:
		var record: Dictionary = buildings[feature_id].duplicate(true)
		if record.has("exterior"):
			var exterior: Dictionary = record.exterior.duplicate(true)
			exterior["scale_percent"] = float(exterior.get("scale_percent", 100.0))
			exterior["rotation_degrees"] = float(exterior.get("rotation_degrees", 0.0))
			exterior["offset_x_percent"] = float(exterior.get("offset_x_percent", 0.0))
			exterior["offset_y_percent"] = float(exterior.get("offset_y_percent", 0.0))
			record["exterior"] = exterior
		if record.has("door") and not record.has("doors"):
			var legacy_door: Dictionary = record.door.duplicate(true)
			legacy_door["id"] = "entrance_1"
			record["doors"] = [legacy_door]
		record.erase("door")
		if not record.has("doors"):
			record["doors"] = []
		buildings[feature_id] = record
	updated["buildings"] = buildings
	return updated


func _next_entrance_id(doors: Array) -> String:
	var used: Dictionary = {}
	for door_value in doors:
		used[str(door_value.get("id", ""))] = true
	var number := 1
	while used.has("entrance_%d" % number):
		number += 1
	return "entrance_%d" % number


func _nearest_pedestrian_node(location: Vector2, navigation: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 250.0
	for node_value in navigation.get("pedestrian", {}).get("nodes", []):
		var node: Dictionary = node_value
		var node_location := Vector2(float(node.get("longitude", 0.0)), float(node.get("latitude", 0.0)))
		var distance := _to_metres(node_location, location).length()
		if distance < best_distance:
			best_distance = distance
			best = {"id": int(node.get("id", -1)), "distance_metres": snappedf(distance, 0.01)}
	return best


func _location_is_clear(location: Vector2, features: Array, bounds: Dictionary) -> bool:
	if location.x < float(bounds.get("west", -INF)) or location.x > float(bounds.get("east", INF)) or location.y < float(bounds.get("south", -INF)) or location.y > float(bounds.get("north", INF)):
		return false
	for feature_value in features:
		var feature: Dictionary = feature_value
		var kind := str(feature.get("kind", ""))
		if kind not in ["building", "fixed_footprint", "water"]:
			continue
		var outer := _points(feature.get("points", []))
		if outer.size() < 3 or not _polygon_contains_location(outer, location):
			continue
		var in_hole := false
		for hole_value in feature.get("holes", []):
			var hole := _points(hole_value)
			if hole.size() >= 3 and _polygon_contains_location(hole, location):
				in_hole = true
				break
		if not in_hole:
			return false
	return true


func _polygon_contains_location(points: PackedVector2Array, location: Vector2) -> bool:
	# Geometry2D loses useful precision when longitude values near ±150 degrees
	# are passed directly. Translate into local metres before the containment
	# check so every side of a footprint behaves consistently.
	var local := PackedVector2Array()
	for point in points:
		local.append(_to_metres(point, location))
	if local.size() > 2 and local[0].is_equal_approx(local[local.size() - 1]):
		local.remove_at(local.size() - 1)
	return local.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2.ZERO, local)


func _points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		if value is Vector2:
			result.append(value)
		elif value is Array and value.size() >= 2:
			result.append(Vector2(float(value[0]), float(value[1])))
	if result.size() > 2 and not result[0].is_equal_approx(result[result.size() - 1]):
		result.append(result[0])
	return result


func _polygon_centre(points: PackedVector2Array) -> Vector2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds.get_center()


func _to_metres(location: Vector2, origin: Vector2) -> Vector2:
	var longitude_scale := METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y))
	return Vector2((location.x - origin.x) * longitude_scale, (origin.y - location.y) * METRES_PER_LATITUDE_DEGREE)


func _from_metres(location: Vector2, origin: Vector2) -> Vector2:
	var longitude_scale := METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y))
	return Vector2(origin.x + location.x / longitude_scale, origin.y - location.y / METRES_PER_LATITUDE_DEGREE)


func _safe_id(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_") if not result.is_empty() else "building"
