class_name MapGeometryValidator
extends RefCounted

## Audits imported OSM geometry before navigation is generated. The rules are
## deliberately deterministic: ambiguous ground roads are never allowed to pass
## through a solid building merely because their two-dimensional lines overlap.

const METRES_PER_LATITUDE_DEGREE := 110540.0
const METRES_PER_LONGITUDE_DEGREE := 111320.0
const GRID_SIZE_METRES := 100.0
const MAX_REPORTED_CLEARANCE_CONFLICTS := 200
const MAX_REPORTED_VERTICAL_ROADS := 200
const RoadDimensionsScript = preload("res://scripts/roads/road_dimensions.gd")


func analyse(features: Array) -> Dictionary:
	var origin := _origin(features)
	var buildings: Array[Dictionary] = []
	var building_grid: Dictionary = {}
	var non_ground_buildings := 0
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) not in ["building", "fixed_footprint"]:
			continue
		if not building_blocks_ground(feature):
			non_ground_buildings += 1
			continue
		var outer := _project_ring(feature.get("points", []), origin)
		if outer.size() < 3:
			continue
		var holes: Array[PackedVector2Array] = []
		for hole_value in feature.get("holes", []):
			var hole := _project_ring(hole_value, origin)
			if hole.size() >= 3:
				holes.append(hole)
		var record := {
			"id": str(feature.get("id", "unknown")),
			"outer": outer,
			"holes": holes,
			"bounds": _polygon_bounds(outer)
		}
		var building_index := buildings.size()
		buildings.append(record)
		_index_building(building_grid, building_index, record.bounds)

	var blocked_segments: Array[Dictionary] = []
	var blocked_lookup: Dictionary = {}
	var clearance_conflicts: Array[Dictionary] = []
	var clearance_conflict_count := 0
	var unclassified_vertical_roads: Array[String] = []
	var unclassified_vertical_count := 0
	var explicit_vertical_passages := 0
	for feature_value in features:
		var road: Dictionary = feature_value
		if str(road.get("kind", "")) != "road":
			continue
		var tags: Dictionary = road.get("tags", {})
		if not _potential_navigation_route(tags):
			continue
		var vertical_context := road_vertical_context(tags)
		if vertical_context == "unclassified_vertical":
			unclassified_vertical_count += 1
			if unclassified_vertical_roads.size() < MAX_REPORTED_VERTICAL_ROADS:
				unclassified_vertical_roads.append(str(road.get("id", "unknown")))
			continue
		if vertical_context != "ground":
			explicit_vertical_passages += 1
			continue
		var points: Array = road.get("points", [])
		var half_width := road_half_width_metres(tags)
		for segment_index in range(points.size() - 1):
			var first := _project_point(points[segment_index], origin)
			var second := _project_point(points[segment_index + 1], origin)
			if first.is_equal_approx(second):
				continue
			var segment_bounds := Rect2(first, second - first).abs().grow(half_width)
			var candidate_indices := _candidate_buildings(building_grid, segment_bounds)
			var blocking_building_ids: Array[String] = []
			var nearby_building_ids: Array[String] = []
			for building_index in candidate_indices:
				var building: Dictionary = buildings[building_index]
				if not building.bounds.grow(half_width).intersects(segment_bounds, true):
					continue
				if _segment_enters_solid(first, second, building.outer, building.holes):
					blocking_building_ids.append(str(building.id))
				elif _segment_boundary_distance(first, second, building.outer, building.holes) < half_width:
					nearby_building_ids.append(str(building.id))
			var segment_key := segment_key(str(road.get("id", "unknown")), segment_index)
			if not blocking_building_ids.is_empty():
				blocking_building_ids.sort()
				blocked_lookup[segment_key] = true
				blocked_segments.append({
					"key": segment_key,
					"road_id": str(road.get("id", "unknown")),
					"segment_index": segment_index,
					"building_ids": blocking_building_ids,
					"resolution": "excluded_from_ground_navigation"
				})
			elif not nearby_building_ids.is_empty():
				clearance_conflict_count += 1
				if clearance_conflicts.size() < MAX_REPORTED_CLEARANCE_CONFLICTS:
					nearby_building_ids.sort()
					clearance_conflicts.append({
						"road_id": str(road.get("id", "unknown")),
						"segment_index": segment_index,
						"building_ids": nearby_building_ids,
						"resolution": "route_retained_centreline_clear"
					})

	var warnings: Array[String] = []
	if not blocked_segments.is_empty():
		warnings.append("Creator Studio found %d ground-road segment(s) passing through solid building footprints and excluded those segments from walking and vehicle pathfinding. Review the listed OSM feature IDs in navigation_graphs.json." % blocked_segments.size())
	if clearance_conflict_count > 0:
		warnings.append("Creator Studio found %d road edge(s) close enough to overlap a building visually, but their centre-lines remain clear. They were retained and recorded for later map-editor review." % clearance_conflict_count)
	if unclassified_vertical_count > 0:
		warnings.append("Creator Studio excluded %d road way(s) with a non-zero OSM layer but no explicit bridge, tunnel or covered-passage tag. This prevents ambiguous elevated traffic." % unclassified_vertical_count)

	return {
		"schema_version": 1,
		"kind": "map_geometry_validation",
		"blocked_segment_lookup": blocked_lookup,
		"blocked_segments": blocked_segments,
		"clearance_conflicts": clearance_conflicts,
		"unclassified_vertical_roads": unclassified_vertical_roads,
		"statistics": {
			"ground_solid_buildings": buildings.size(),
			"non_ground_buildings": non_ground_buildings,
			"blocked_ground_road_segments": blocked_segments.size(),
			"road_clearance_conflicts": clearance_conflict_count,
			"unclassified_vertical_roads": unclassified_vertical_count,
			"explicit_vertical_passages": explicit_vertical_passages
		},
		"warnings": warnings
	}


static func building_blocks_ground(feature: Dictionary) -> bool:
	return building_vertical_context(feature) == "ground"


static func building_vertical_context(feature: Dictionary) -> String:
	if str(feature.get("kind", "")) not in ["building", "fixed_footprint"]:
		return "not_building"
	var tags: Dictionary = feature.get("tags", {})
	var building_value := str(tags.get("building", "")).to_lower()
	if building_value in ["roof", "bridge"]:
		return "overhead"
	var location := str(tags.get("location", "")).to_lower()
	if location in ["underground", "underwater"]:
		return "underground"
	if location == "overground":
		return "overhead"
	for key in ["building:min_level", "min_level"]:
		var minimum_level := str(tags.get(key, ""))
		if minimum_level.is_valid_float() and float(minimum_level) > 0.0:
			return "overhead"
	var level := str(tags.get("level", ""))
	if level.is_valid_float() and float(level) < 0.0:
		return "underground"
	return "ground"


func road_vertical_context(tags: Dictionary) -> String:
	if _tag_enabled(tags.get("bridge", "")):
		return "bridge"
	if _tag_enabled(tags.get("tunnel", "")):
		return "tunnel"
	var layer_text := str(tags.get("layer", "0"))
	var layer := int(layer_text) if layer_text.is_valid_int() else 0
	var location := str(tags.get("location", "")).to_lower()
	return "unclassified_vertical" if layer != 0 or location in ["underground", "underwater", "overground"] else "ground"


func road_half_width_metres(tags: Dictionary) -> float:
	return RoadDimensionsScript.half_width_metres(tags)


func _potential_navigation_route(tags: Dictionary) -> bool:
	var highway := str(tags.get("highway", "")).to_lower()
	if highway.is_empty() or highway in ["construction", "proposed", "raceway", "platform", "corridor"]:
		return false
	if str(tags.get("access", "")).to_lower() in ["no", "private"]:
		return false
	return not _tag_enabled(tags.get("indoor", ""))


func segment_key(road_id: String, segment_index: int) -> String:
	return "%s:%d" % [road_id, segment_index]


func _origin(features: Array) -> Vector2:
	var west := INF
	var south := INF
	var east := -INF
	var north := -INF
	for feature_value in features:
		var feature: Dictionary = feature_value
		for point_value in feature.get("points", []):
			var point := _value_to_point(point_value)
			west = minf(west, point.x)
			east = maxf(east, point.x)
			south = minf(south, point.y)
			north = maxf(north, point.y)
	return Vector2.ZERO if west == INF else Vector2((west + east) * 0.5, (south + north) * 0.5)


func _project_ring(values: Array, origin: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		var point := _project_point(value, origin)
		if result.is_empty() or result[result.size() - 1].distance_to(point) > 0.02:
			result.append(point)
	if result.size() > 2 and result[0].distance_to(result[result.size() - 1]) <= 0.02:
		result.remove_at(result.size() - 1)
	return result


func _project_point(value: Variant, origin: Vector2) -> Vector2:
	var point := _value_to_point(value)
	return Vector2(
		(point.x - origin.x) * METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y)),
		(origin.y - point.y) * METRES_PER_LATITUDE_DEGREE
	)


func _value_to_point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	return bounds


func _index_building(grid: Dictionary, building_index: int, bounds: Rect2) -> void:
	var first := Vector2i(floori(bounds.position.x / GRID_SIZE_METRES), floori(bounds.position.y / GRID_SIZE_METRES))
	var last_point := bounds.position + bounds.size
	var last := Vector2i(floori(last_point.x / GRID_SIZE_METRES), floori(last_point.y / GRID_SIZE_METRES))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := "%d,%d" % [x, y]
			if not grid.has(key):
				grid[key] = []
			grid[key].append(building_index)


func _candidate_buildings(grid: Dictionary, bounds: Rect2) -> Array[int]:
	var unique: Dictionary = {}
	var first := Vector2i(floori(bounds.position.x / GRID_SIZE_METRES), floori(bounds.position.y / GRID_SIZE_METRES))
	var last_point := bounds.position + bounds.size
	var last := Vector2i(floori(last_point.x / GRID_SIZE_METRES), floori(last_point.y / GRID_SIZE_METRES))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for building_index in grid.get("%d,%d" % [x, y], []):
				unique[int(building_index)] = true
	var result: Array[int] = []
	for building_index in unique:
		result.append(int(building_index))
	result.sort()
	return result


func _segment_enters_solid(first: Vector2, second: Vector2, outer: PackedVector2Array, holes: Array) -> bool:
	# Split the road at every footprint boundary crossing, then inspect the
	# midpoint of each interval. This detects even narrow buildings without
	# treating a road that merely touches a corner or follows a wall as blocked.
	var fractions: Array[float] = [0.0, 1.0]
	_append_intersection_fractions(fractions, first, second, outer)
	for hole_value in holes:
		_append_intersection_fractions(fractions, first, second, hole_value)
	fractions.sort()
	var unique: Array[float] = []
	for fraction in fractions:
		if unique.is_empty() or absf(fraction - unique[unique.size() - 1]) > 0.00001:
			unique.append(fraction)
	for index in range(unique.size() - 1):
		var midpoint := (unique[index] + unique[index + 1]) * 0.5
		if _point_in_solid(first.lerp(second, midpoint), outer, holes):
			return true
	return false


func _point_in_solid(point: Vector2, outer: PackedVector2Array, holes: Array) -> bool:
	if not Geometry2D.is_point_in_polygon(point, outer):
		return false
	for hole_value in holes:
		if Geometry2D.is_point_in_polygon(point, hole_value):
			return false
	return true


func _append_intersection_fractions(fractions: Array[float], first: Vector2, second: Vector2, ring: PackedVector2Array) -> void:
	var length_squared := first.distance_squared_to(second)
	if length_squared <= 0.000001:
		return
	for index in ring.size():
		var intersection = Geometry2D.segment_intersects_segment(first, second, ring[index], ring[(index + 1) % ring.size()])
		if intersection != null:
			var point: Vector2 = intersection
			fractions.append(clampf((point - first).dot(second - first) / length_squared, 0.0, 1.0))


func _segment_boundary_distance(first: Vector2, second: Vector2, outer: PackedVector2Array, holes: Array) -> float:
	var result := _segment_ring_distance(first, second, outer)
	for hole_value in holes:
		result = minf(result, _segment_ring_distance(first, second, hole_value))
	return result


func _segment_ring_distance(first: Vector2, second: Vector2, ring: PackedVector2Array) -> float:
	var distance := INF
	for index in ring.size():
		var edge_first: Vector2 = ring[index]
		var edge_second: Vector2 = ring[(index + 1) % ring.size()]
		if Geometry2D.segment_intersects_segment(first, second, edge_first, edge_second) != null:
			return 0.0
		distance = minf(distance, first.distance_to(Geometry2D.get_closest_point_to_segment(first, edge_first, edge_second)))
		distance = minf(distance, second.distance_to(Geometry2D.get_closest_point_to_segment(second, edge_first, edge_second)))
		distance = minf(distance, edge_first.distance_to(Geometry2D.get_closest_point_to_segment(edge_first, first, second)))
		distance = minf(distance, edge_second.distance_to(Geometry2D.get_closest_point_to_segment(edge_second, first, second)))
	return distance


func _tag_enabled(value: Variant) -> bool:
	var text := str(value).to_lower()
	return not text.is_empty() and text not in ["no", "false", "0"]
