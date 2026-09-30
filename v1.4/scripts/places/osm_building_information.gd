class_name OsmBuildingInformation
extends RefCounted

## Builds truthful, compact descriptions from tags attached directly to an OSM
## building footprint. It also provides a spatial lookup for runtime hover/click
## selection. No remote lookup or LLM is involved.

const SOURCE_ATTRIBUTION := "© OpenStreetMap contributors"
const INDEX_CELL_PIXELS := 256.0
const MAX_TEXT_LENGTH := 120
const MapGeometryValidatorScript = preload("res://scripts/validation/map_geometry_validator.gd")

var records_by_feature_id: Dictionary = {}
var indexed_footprints: Array[Dictionary] = []
var footprint_cells: Dictionary = {}


func build(features: Array) -> Dictionary:
	var places: Array[Dictionary] = []
	var named_count := 0
	var specifically_classified_count := 0
	var addressed_count := 0
	for feature_value in features:
		var feature: Dictionary = feature_value
		if not is_building_feature(feature):
			continue
		var record := describe_feature(feature)
		places.append(record)
		if str(record.name) != "Unnamed building":
			named_count += 1
		if bool(record.has_specific_type):
			specifically_classified_count += 1
		if not str(record.address).is_empty():
			addressed_count += 1
	return {
		"ok": true,
		"data": {
			"schema_version": 1,
			"kind": "osm_building_place_information",
			"source_attribution": SOURCE_ATTRIBUTION,
			"information_scope": "osm_tags_on_selected_footprint",
			"places": places,
			"statistics": {
				"building_footprints": places.size(),
				"named_buildings": named_count,
				"specifically_classified_buildings": specifically_classified_count,
				"addressed_buildings": addressed_count
			}
		}
	}


func setup_spatial_index(features: Array, place_data: Dictionary, geographic_to_world: Callable) -> void:
	records_by_feature_id.clear()
	indexed_footprints.clear()
	footprint_cells.clear()
	for record_value in place_data.get("places", []):
		var record: Dictionary = record_value
		records_by_feature_id[str(record.get("feature_id", ""))] = record
	for feature_value in features:
		var feature: Dictionary = feature_value
		if not is_building_feature(feature):
			continue
		if str(feature.get("kind", "")) != "overhead_structure" and MapGeometryValidatorScript.building_vertical_context(feature) == "underground":
			continue
		var outer := _world_ring(feature.get("points", []), geographic_to_world)
		if outer.size() < 3:
			continue
		var holes: Array[PackedVector2Array] = []
		for hole_value in feature.get("holes", []):
			var hole := _world_ring(hole_value, geographic_to_world)
			if hole.size() >= 3:
				holes.append(hole)
		var feature_id := str(feature.get("id", ""))
		var record: Dictionary = records_by_feature_id.get(feature_id, describe_feature(feature))
		records_by_feature_id[feature_id] = record
		var bounds := _polygon_bounds(outer)
		var index := indexed_footprints.size()
		indexed_footprints.append({
			"feature_id": feature_id,
			"outer": outer,
			"holes": holes,
			"bounds": bounds,
			"area": absf(_signed_area(outer))
		})
		_index_footprint(index, bounds)


func building_at(world_position: Vector2) -> Dictionary:
	var cell := _cell(world_position)
	var best: Dictionary = {}
	var best_area := INF
	for index_value in footprint_cells.get(_cell_key(cell), []):
		var footprint: Dictionary = indexed_footprints[int(index_value)]
		if not footprint.bounds.has_point(world_position):
			continue
		if not Geometry2D.is_point_in_polygon(world_position, footprint.outer):
			continue
		var inside_hole := false
		for hole_value in footprint.holes:
			if Geometry2D.is_point_in_polygon(world_position, hole_value):
				inside_hole = true
				break
		if inside_hole:
			continue
		if float(footprint.area) < best_area:
			best_area = float(footprint.area)
			best = records_by_feature_id.get(str(footprint.feature_id), {})
	return best


func record_for_feature(feature_id: String) -> Dictionary:
	return records_by_feature_id.get(feature_id, {})


func first_named_record() -> Dictionary:
	for footprint in indexed_footprints:
		var record: Dictionary = records_by_feature_id.get(str(footprint.feature_id), {})
		if str(record.get("name", "Unnamed building")) != "Unnamed building":
			return record
	return records_by_feature_id.values()[0] if not records_by_feature_id.is_empty() else {}


func world_centre_for_feature(feature_id: String) -> Vector2:
	for footprint in indexed_footprints:
		if str(footprint.feature_id) == feature_id:
			var bounds: Rect2 = footprint.bounds
			return bounds.get_center()
	return Vector2.INF


static func is_building_feature(feature: Dictionary) -> bool:
	return str(feature.get("kind", "")) in ["building", "fixed_footprint", "overhead_structure"]


static func describe_feature(feature: Dictionary) -> Dictionary:
	var tags: Dictionary = feature.get("tags", {})
	var feature_id := str(feature.get("id", "unknown"))
	var name := _first_text(tags, ["name", "addr:housename"])
	if name.is_empty():
		name = "Unnamed building"
	var category := _category(tags)
	var address := _address(tags)
	var operator_name := _first_text(tags, ["operator", "brand"])
	var levels := _first_text(tags, ["building:levels", "levels"])
	var opening_hours := _first_text(tags, ["opening_hours"])
	var wheelchair := _wheelchair_text(_first_text(tags, ["wheelchair"]))
	var source_element := _source_element(feature_id)
	var has_specific_type := str(category.source_tag) not in ["", "building=yes"]
	var details: Array[Dictionary] = [{"label": "Mapped use", "value": str(category.label), "source_tag": str(category.source_tag)}]
	for detail in [
		{"label": "Address", "value": address, "source_tag": "addr:*"},
		{"label": "Operator", "value": operator_name, "source_tag": "operator/brand"},
		{"label": "Levels", "value": levels, "source_tag": "building:levels"},
		{"label": "Opening hours", "value": opening_hours, "source_tag": "opening_hours"},
		{"label": "Wheelchair access", "value": wheelchair, "source_tag": "wheelchair"}
	]:
		if not str(detail.value).is_empty():
			details.append(detail)
	return {
		"feature_id": feature_id,
		"name": _safe_text(name),
		"category": str(category.label),
		"category_source_tag": str(category.source_tag),
		"has_specific_type": has_specific_type,
		"address": address,
		"operator": operator_name,
		"levels": levels,
		"opening_hours": opening_hours,
		"wheelchair_access": wheelchair,
		"details": details,
		"source_element": source_element,
		"source_reference": "%s %s" % [str(source_element.type), str(source_element.id)],
		"source_attribution": SOURCE_ATTRIBUTION,
		"information_scope": "tags_on_this_footprint"
	}


static func brief_popup_lines(record: Dictionary) -> Array[String]:
	var lines: Array[String] = [_truncate(str(record.get("name", "Unnamed building")), 42)]
	lines.append("Mapped use: %s" % _truncate(str(record.get("category", "Building type not mapped in OSM")), 39))
	var address := str(record.get("address", ""))
	if not address.is_empty():
		lines.append("Address: %s" % _truncate(address, 43))
	lines.append("Source: %s" % SOURCE_ATTRIBUTION)
	lines.append("%s · Click to keep open" % str(record.get("source_reference", "OSM feature")))
	return lines


static func detailed_popup_lines(record: Dictionary) -> Array[String]:
	var lines: Array[String] = ["PINNED · %s" % _truncate(str(record.get("name", "Unnamed building")), 36)]
	lines.append("Mapped use: %s" % _truncate(str(record.get("category", "Building type not mapped in OSM")), 39))
	for key_and_label in [
		["address", "Address"],
		["operator", "Operator"],
		["levels", "Levels"],
		["opening_hours", "Hours"],
		["wheelchair_access", "Wheelchair access"]
	]:
		var value := str(record.get(str(key_and_label[0]), ""))
		if not value.is_empty() and lines.size() < 7:
			lines.append("%s: %s" % [str(key_and_label[1]), _truncate(value, 43)])
	lines.append("Source: %s" % SOURCE_ATTRIBUTION)
	lines.append("%s · Click empty ground to close" % str(record.get("source_reference", "OSM feature")))
	return lines


static func _category(tags: Dictionary) -> Dictionary:
	for key in ["amenity", "healthcare", "shop", "office", "tourism", "leisure", "industrial", "craft", "public_transport", "railway"]:
		var value := _safe_text(tags.get(key, ""))
		if not value.is_empty() and value != "yes":
			return {"label": _friendly_category(key, value), "source_tag": "%s=%s" % [key, value]}
	var building := _safe_text(tags.get("building", ""))
	if building.is_empty() or building == "yes":
		return {"label": "Building type not mapped in OSM", "source_tag": "building=yes" if building == "yes" else ""}
	return {"label": _humanise(building), "source_tag": "building=%s" % building}


static func _friendly_category(key: String, value: String) -> String:
	var known := {
		"arts_centre": "Arts centre", "community_centre": "Community centre",
		"fire_station": "Fire station", "police": "Police station",
		"doctors": "Medical clinic", "dentist": "Dental clinic",
		"place_of_worship": "Place of worship", "townhall": "Town hall",
		"fuel": "Fuel station", "fast_food": "Fast food",
		"train_station": "Train station"
	}
	if known.has(value):
		return str(known[value])
	var label := _humanise(value)
	if key == "shop":
		return "%s shop" % label
	if key == "office":
		return "%s office" % label
	return label


static func _address(tags: Dictionary) -> String:
	var first_line := " ".join(PackedStringArray([
		_safe_text(tags.get("addr:housenumber", "")),
		_safe_text(tags.get("addr:street", ""))
	])).strip_edges()
	var locality_parts := PackedStringArray()
	for key in ["addr:suburb", "addr:city", "addr:county", "addr:state", "addr:postcode", "addr:country"]:
		var value := _safe_text(tags.get(key, ""))
		if not value.is_empty() and not locality_parts.has(value):
			locality_parts.append(value)
	var locality := ", ".join(locality_parts)
	if first_line.is_empty():
		return _truncate(locality, MAX_TEXT_LENGTH)
	return _truncate(first_line if locality.is_empty() else "%s, %s" % [first_line, locality], MAX_TEXT_LENGTH)


static func _source_element(feature_id: String) -> Dictionary:
	if feature_id.begins_with("relation:"):
		return {"type": "OSM relation", "id": feature_id.get_slice(":", 1)}
	if feature_id.begins_with("way:"):
		return {"type": "OSM way", "id": feature_id.get_slice(":", 1)}
	return {"type": "OSM way", "id": feature_id}


static func _first_text(tags: Dictionary, keys: Array) -> String:
	for key_value in keys:
		var value := _safe_text(tags.get(str(key_value), ""))
		if not value.is_empty():
			return value
	return ""


static func _wheelchair_text(value: String) -> String:
	match value.to_lower():
		"yes": return "Mapped as accessible"
		"limited": return "Mapped as limited"
		"no": return "Mapped as not accessible"
	return _humanise(value) if not value.is_empty() else ""


static func _humanise(value: String) -> String:
	return _safe_text(value).replace("_", " ").capitalize()


static func _safe_text(value: Variant) -> String:
	var text := str(value).replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()
	while text.contains("  "):
		text = text.replace("  ", " ")
	return _truncate(text, MAX_TEXT_LENGTH)


static func _truncate(value: String, maximum: int) -> String:
	return value if value.length() <= maximum else value.left(maxi(1, maximum - 1)).strip_edges() + "…"


func _world_ring(values: Array, geographic_to_world: Callable) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for value in values:
		var point: Vector2 = geographic_to_world.call(value)
		if ring.is_empty() or not ring[ring.size() - 1].is_equal_approx(point):
			ring.append(point)
	if ring.size() > 2 and ring[0].is_equal_approx(ring[ring.size() - 1]):
		ring.remove_at(ring.size() - 1)
	return ring


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	return bounds


func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size():
		var first := polygon[index]
		var second := polygon[(index + 1) % polygon.size()]
		area += first.x * second.y - second.x * first.y
	return area * 0.5


func _index_footprint(index: int, bounds: Rect2) -> void:
	var first := _cell(bounds.position)
	var last := _cell(bounds.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := _cell_key(Vector2i(x, y))
			if not footprint_cells.has(key):
				footprint_cells[key] = []
			footprint_cells[key].append(index)


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / INDEX_CELL_PIXELS), floori(point.y / INDEX_CELL_PIXELS))


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
