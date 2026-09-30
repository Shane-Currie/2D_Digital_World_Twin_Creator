class_name BuildingInteriorStore
extends RefCounted

## Canonical, town-specific interior layouts keyed to stable OSM building IDs.
## Stores footprint-shaped floors and exterior-entrance spawn links.

const SCHEMA_VERSION := 1
const FILE_NAME := "building_interiors.json"
const METRES_PER_LATITUDE_DEGREE := 110540.0
const METRES_PER_LONGITUDE_DEGREE := 111320.0
const MAX_INTERIOR_EDGE_METRES := 2000.0
const MAX_FLOORS := 20
const MIN_FLOOR_SCALE := 1.0
const MAX_FLOOR_SCALE := 3.0


func empty_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "kind": "creator_building_interiors", "buildings": {}}


func load_from_town(town_directory: String) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value):
		return {"ok": true, "data": empty_data(), "created_default": true}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	if not parsed is Dictionary:
		return {"ok": false, "message": "data/%s is damaged or is not valid JSON." % FILE_NAME}
	var validation := validate(parsed)
	if not validation.ok:
		return validation
	return {"ok": true, "data": parsed, "created_default": false}


func save_to_town(town_directory: String, data: Dictionary) -> Dictionary:
	var validation := validate(data)
	if not validation.ok:
		return validation
	var data_directory := town_directory.path_join("data")
	if DirAccess.make_dir_recursive_absolute(data_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	var saved: Dictionary = data.duplicate(true)
	saved["updated_utc"] = Time.get_datetime_string_from_system(true)
	var file := FileAccess.open(data_directory.path_join(FILE_NAME), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save data/%s." % FILE_NAME}
	file.store_string(JSON.stringify(saved, "  "))
	return {"ok": true, "data": saved, "message": "Building interiors saved."}


func create_blank_ground_floor(data: Dictionary, feature: Dictionary) -> Dictionary:
	var feature_id := str(feature.get("id", ""))
	var outer := _points(feature.get("points", []))
	if feature_id.is_empty() or str(feature.get("kind", "")) != "building" or outer.size() < 3:
		return {"ok": false, "message": "Select a valid imported building before creating its interior."}
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if buildings.has(feature_id):
		return {"ok": false, "message": "This building already has an interior. Its saved floor was left unchanged."}
	var origin := _polygon_centre(outer)
	var projected_outer := _project_ring(outer, origin)
	var projected_holes: Array[PackedVector2Array] = []
	for hole_value in feature.get("holes", []):
		var hole := _points(hole_value)
		if hole.size() >= 3:
			projected_holes.append(_project_ring(hole, origin))
	var bounds := _bounds(projected_outer)
	if bounds.size.x <= 0.25 or bounds.size.y <= 0.25 or bounds.size.x > MAX_INTERIOR_EDGE_METRES or bounds.size.y > MAX_INTERIOR_EDGE_METRES:
		return {"ok": false, "message": "This footprint cannot produce a safe editable interior size."}
	var floor := {
		"id": "ground_floor", "name": "Ground floor", "level": 0,
		"layout_source": "creator_blank_from_osm_footprint", "survey_status": "not_surveyed",
		"width_metres": snappedf(bounds.size.x, 0.01), "height_metres": snappedf(bounds.size.y, 0.01),
		"grid_metres": 1.0,
		"footprint_scale": 1.0,
		"boundary_metres": _shifted_values(projected_outer, bounds.position),
		"holes_metres": [], "rooms": [], "furniture": [], "entry_links": []
	}
	for hole in projected_holes:
		floor.holes_metres.append(_shifted_values(hole, bounds.position))
	buildings[feature_id] = {
		"feature_id": feature_id,
		"name": str(feature.get("tags", {}).get("name", "Unnamed building")),
		"floors": [floor]
	}
	var updated: Dictionary = data.duplicate(true)
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "record": buildings[feature_id], "message": "Blank ground floor created from the building footprint."}


func add_upper_floor(data: Dictionary, feature_id: String) -> Dictionary:
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Create the ground floor before adding an upper floor."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	if floors.is_empty() or floors.size() >= MAX_FLOORS:
		return {"ok": false, "message": "This building cannot contain more than %d editable floors." % MAX_FLOORS}
	var level := floors.size()
	var floor: Dictionary = floors[0].duplicate(true)
	floor["id"] = "floor_%d" % level
	floor["name"] = "Floor %d" % (level + 1)
	floor["level"] = level
	floor["layout_source"] = "creator_copy_of_footprint_shape"
	floor["survey_status"] = "creator_adjusted"
	floor["rooms"] = []
	floor["furniture"] = []
	floor["entry_links"] = []
	floors.append(floor)
	record["floors"] = floors
	buildings[feature_id] = record
	var updated: Dictionary = data.duplicate(true)
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "floor_id": floor.id, "message": "%s added using the building footprint shape." % floor.name}


func resize_floor(data: Dictionary, feature_id: String, floor_id: String, scale_value: float) -> Dictionary:
	var safe_scale := clampf(scale_value, MIN_FLOOR_SCALE, MAX_FLOOR_SCALE)
	if not is_equal_approx(safe_scale, scale_value):
		return {"ok": false, "message": "Choose an interior size from 100% to 300%."}
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Create the building interior before changing its size."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	var found := false
	for index in floors.size():
		var floor: Dictionary = floors[index].duplicate(true)
		if str(floor.get("id", "")) != floor_id:
			continue
		var old_scale := float(floor.get("footprint_scale", 1.0))
		if old_scale <= 0.0:
			old_scale = 1.0
		var ratio := safe_scale / old_scale
		floor["boundary_metres"] = _scaled_values(floor.get("boundary_metres", []), ratio)
		var holes: Array = []
		for hole in floor.get("holes_metres", []):
			holes.append(_scaled_values(hole, ratio))
		floor["holes_metres"] = holes
		var links: Array = floor.get("entry_links", []).duplicate(true)
		for link_index in links.size():
			var link: Dictionary = links[link_index].duplicate(true)
			link["spawn_x_metres"] = snappedf(float(link.get("spawn_x_metres", 0.0)) * ratio, 0.01)
			link["spawn_y_metres"] = snappedf(float(link.get("spawn_y_metres", 0.0)) * ratio, 0.01)
			links[link_index] = link
		floor["entry_links"] = links
		floor["width_metres"] = snappedf(float(floor.get("width_metres", 0.0)) * ratio, 0.01)
		floor["height_metres"] = snappedf(float(floor.get("height_metres", 0.0)) * ratio, 0.01)
		floor["footprint_scale"] = safe_scale
		floor["survey_status"] = "not_surveyed" if is_equal_approx(safe_scale, 1.0) and int(floor.get("level", 0)) == 0 else "creator_adjusted"
		floors[index] = floor
		found = true
		break
	if not found:
		return {"ok": false, "message": "The selected floor could not be found."}
	record["floors"] = floors
	buildings[feature_id] = record
	var updated: Dictionary = data.duplicate(true)
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "message": "Floor size changed to %d%% while preserving its footprint shape." % int(round(safe_scale * 100.0))}


func set_entry_spawn(data: Dictionary, feature_id: String, exterior_entrance_id: String, position_metres: Vector2) -> Dictionary:
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Create the blank ground floor before placing its entry point."}
	if exterior_entrance_id.is_empty():
		return {"ok": false, "message": "Choose an exterior entrance to connect."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	if floors.is_empty():
		return {"ok": false, "message": "This building does not have an editable ground floor."}
	var floor: Dictionary = floors[0].duplicate(true)
	if not _position_inside_floor(position_metres, floor):
		return {"ok": false, "message": "Place the entry point inside the floor and outside any courtyard opening."}
	var links: Array = floor.get("entry_links", []).duplicate(true)
	var link := {
		"id": "entry_%s" % _safe_id(exterior_entrance_id),
		"exterior_entrance_id": exterior_entrance_id,
		"floor_id": "ground_floor",
		"spawn_x_metres": snappedf(position_metres.x, 0.01),
		"spawn_y_metres": snappedf(position_metres.y, 0.01),
		"placement_source": "creator_selected"
	}
	var replaced := false
	for index in links.size():
		if str(links[index].get("exterior_entrance_id", "")) == exterior_entrance_id:
			links[index] = link
			replaced = true
			break
	if not replaced:
		links.append(link)
	floor["entry_links"] = links
	floors[0] = floor
	record["floors"] = floors
	buildings[feature_id] = record
	var updated: Dictionary = data.duplicate(true)
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "record": record, "message": "Interior entry point linked to %s." % exterior_entrance_id}


func validate_location(data: Dictionary, location: Dictionary) -> Dictionary:
	if str(location.get("space", "")) != "interior":
		return {"ok": false, "message": "This is not an interior building location."}
	var feature_id := str(location.get("building_id", ""))
	var floor_id := str(location.get("floor_id", ""))
	if feature_id.is_empty() or floor_id.is_empty():
		return {"ok": false, "message": "The interior location needs a stable building and floor ID."}
	var record: Dictionary = data.get("buildings", {}).get(feature_id, {})
	if record.is_empty():
		return {"ok": false, "message": "The selected building no longer has a saved interior."}
	var floor := floor_by_id(record, floor_id)
	if floor.is_empty():
		return {"ok": false, "message": "The selected interior floor no longer exists."}
	var position := Vector2(float(location.get("x_metres", -INF)), float(location.get("y_metres", -INF)))
	if not is_finite(position.x) or not is_finite(position.y) or not _position_inside_floor(position, floor):
		return {"ok": false, "message": "Choose a location inside the floor and outside any courtyard opening."}
	return {"ok": true, "record": record, "floor": floor, "position_metres": position}


static func floor_by_id(record: Dictionary, floor_id: String) -> Dictionary:
	for value in record.get("floors", []):
		if value is Dictionary and str(value.get("id", "")) == floor_id:
			return value
	return {}


func validate(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or str(data.get("kind", "")) != "creator_building_interiors" or not data.get("buildings", {}) is Dictionary:
		return {"ok": false, "message": "The building interior file uses an unsupported or incomplete format."}
	for feature_id in data.buildings:
		var record = data.buildings[feature_id]
		if not record is Dictionary or str(record.get("feature_id", "")) != str(feature_id):
			return {"ok": false, "message": "Interior %s has an invalid stable building ID." % str(feature_id)}
		var floors = record.get("floors", [])
		if not floors is Array or floors.is_empty() or floors.size() > MAX_FLOORS:
			return {"ok": false, "message": "Interior %s must contain between 1 and %d floors." % [str(feature_id), MAX_FLOORS]}
		var floor_ids: Dictionary = {}
		for floor_index in floors.size():
			if not floors[floor_index] is Dictionary:
				return {"ok": false, "message": "Interior %s has invalid floor data." % str(feature_id)}
			var floor: Dictionary = floors[floor_index]
			var floor_id := str(floor.get("id", ""))
			var width := float(floor.get("width_metres", 0.0))
			var height := float(floor.get("height_metres", 0.0))
			var scale_value := float(floor.get("footprint_scale", 1.0))
			if floor_id.is_empty() or floor_ids.has(floor_id) or int(floor.get("level", -1)) != floor_index:
				return {"ok": false, "message": "Interior %s has an invalid or duplicate floor ID." % str(feature_id)}
			if width <= 0.25 or height <= 0.25 or width > MAX_INTERIOR_EDGE_METRES or height > MAX_INTERIOR_EDGE_METRES or scale_value < MIN_FLOOR_SCALE or scale_value > MAX_FLOOR_SCALE or _points(floor.get("boundary_metres", [])).size() < 3:
				return {"ok": false, "message": "Interior %s has invalid floor dimensions or boundary." % str(feature_id)}
			floor_ids[floor_id] = true
			var link_ids: Dictionary = {}
			for link_value in floor.get("entry_links", []):
				if not link_value is Dictionary:
					return {"ok": false, "message": "Interior %s has invalid entry data." % str(feature_id)}
				var link: Dictionary = link_value
				var link_id := str(link.get("id", ""))
				var position := Vector2(float(link.get("spawn_x_metres", -INF)), float(link.get("spawn_y_metres", -INF)))
				if link_id.is_empty() or link_ids.has(link_id) or str(link.get("exterior_entrance_id", "")).is_empty() or not _position_inside_floor(position, floor):
					return {"ok": false, "message": "Interior %s has an invalid or duplicate entry link." % str(feature_id)}
				link_ids[link_id] = true
	return {"ok": true}


func _position_inside_floor(position: Vector2, floor: Dictionary) -> bool:
	var outer := _points(floor.get("boundary_metres", []))
	if outer.size() < 3 or not Geometry2D.is_point_in_polygon(position, outer):
		return false
	for hole_value in floor.get("holes_metres", []):
		var hole := _points(hole_value)
		if hole.size() >= 3 and Geometry2D.is_point_in_polygon(position, hole):
			return false
	return true


func _points(values: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		if value is Vector2:
			result.append(value)
		elif value is Array and value.size() >= 2:
			result.append(Vector2(float(value[0]), float(value[1])))
	if result.size() > 2 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


func _polygon_centre(points: PackedVector2Array) -> Vector2:
	return _bounds(points).get_center()


func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _project_ring(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var longitude_scale := METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y))
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2((point.x - origin.x) * longitude_scale, (origin.y - point.y) * METRES_PER_LATITUDE_DEGREE))
	return result


func _shifted_values(points: PackedVector2Array, offset: Vector2) -> Array:
	var result: Array = []
	for point in points:
		result.append([snappedf(point.x - offset.x, 0.01), snappedf(point.y - offset.y, 0.01)])
	return result


func _scaled_values(values: Variant, ratio: float) -> Array:
	var result: Array = []
	for point in _points(values):
		result.append([snappedf(point.x * ratio, 0.01), snappedf(point.y * ratio, 0.01)])
	return result


func _safe_id(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_") if not result.is_empty() else "entrance"
