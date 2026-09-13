class_name BuildingCollisionBuilder
extends RefCounted

## Converts geographic OSM building outlines into metre-scale collision data.
## Artwork is deliberately not involved: the imported footprint is authoritative.

const METRES_PER_LATITUDE_DEGREE := 110540.0
const METRES_PER_LONGITUDE_DEGREE := 111320.0
const DEFAULT_PIXELS_PER_METRE := 8.0
const CHUNK_SIZE_METRES := 256.0
const MINIMUM_BUILDING_AREA_SQUARE_METRES := 0.25
const MapGeometryValidatorScript = preload("res://scripts/validation/map_geometry_validator.gd")
const RoadDimensionsScript = preload("res://scripts/roads/road_dimensions.gd")


func build(features: Array, map_bounds: Dictionary, pixels_per_metre: float = DEFAULT_PIXELS_PER_METRE) -> Dictionary:
	if map_bounds.is_empty():
		return {"ok": false, "message": "Building collisions need valid map boundaries."}
	var origin := Vector2(
		(float(map_bounds.west) + float(map_bounds.east)) * 0.5,
		(float(map_bounds.south) + float(map_bounds.north)) * 0.5
	)
	var buildings: Array[Dictionary] = []
	var water_areas: Array[Dictionary] = []
	var water_crossings: Array[Dictionary] = []
	var warnings: Array[String] = []
	var skipped := 0
	var non_ground_structures := 0
	var convex_piece_count := 0
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) not in ["building", "fixed_footprint"]:
			continue
		if not MapGeometryValidatorScript.building_blocks_ground(feature):
			non_ground_structures += 1
			continue
		var outer := _project_and_clean(feature.get("points", []), origin)
		if not _is_usable_polygon(outer):
			skipped += 1
			warnings.append("Building %s has an incomplete or invalid outline and was not given collision." % str(feature.get("id", "unknown")))
			continue
		var holes: Array[PackedVector2Array] = []
		for hole_value in feature.get("holes", []):
			var hole := _project_and_clean(hole_value, origin)
			if _is_usable_polygon(hole) and Geometry2D.is_point_in_polygon(hole[0], outer):
				holes.append(hole)
		var building_bounds := _polygon_bounds(outer)
		var centre: Vector2 = building_bounds.position + building_bounds.size * 0.5
		var serialised_holes: Array[Array] = []
		for hole in holes:
			serialised_holes.append(_serialise_polygon(hole))
		# A safe upper estimate avoids running physics decomposition while the
		# content file is being generated; actual pieces are created per chunk.
		convex_piece_count += maxi(1, outer.size() - 2)
		buildings.append({
			"id": str(feature.get("id", "")),
			"kind": "fixed_building_footprint",
			"outer_metres": _serialise_polygon(outer),
			"holes_metres": serialised_holes,
			"bounds_metres": {
				"x": building_bounds.position.x,
				"y": building_bounds.position.y,
				"width": building_bounds.size.x,
				"height": building_bounds.size.y
			},
			"area_square_metres": _usable_area(outer, holes),
			"chunk": [floori(centre.x / CHUNK_SIZE_METRES), floori(centre.y / CHUNK_SIZE_METRES)],
			"source": "osm_footprint",
			"vertical_context": "ground"
		})
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) == "water":
			var water_outer := _project_and_clean(feature.get("points", []), origin)
			if not _is_usable_polygon(water_outer):
				warnings.append("Water area %s has an incomplete or invalid outline and was not made blocking." % str(feature.get("id", "unknown")))
				continue
			var water_holes: Array[Array] = []
			for hole_value in feature.get("holes", []):
				var water_hole := _project_and_clean(hole_value, origin)
				if _is_usable_polygon(water_hole) and Geometry2D.is_point_in_polygon(water_hole[0], water_outer):
					water_holes.append(_serialise_polygon(water_hole))
			var water_bounds := _polygon_bounds(water_outer)
			water_areas.append({
				"id": str(feature.get("id", "")),
				"outer_metres": _serialise_polygon(water_outer),
				"holes_metres": water_holes,
				"bounds_metres": {
					"x": water_bounds.position.x,
					"y": water_bounds.position.y,
					"width": water_bounds.size.x,
					"height": water_bounds.size.y
				},
				"source": "osm_water"
			})
		elif str(feature.get("kind", "")) == "road":
			var road_tags: Dictionary = feature.get("tags", {})
			var crossing_kind := "bridge" if _tag_enabled(road_tags.get("bridge", "")) else ("tunnel" if _tag_enabled(road_tags.get("tunnel", "")) else "")
			if crossing_kind.is_empty():
				continue
			var crossing_points := _project_and_clean(feature.get("points", []), origin)
			if crossing_points.size() < 2:
				continue
			water_crossings.append({
				"id": str(feature.get("id", "")),
				"kind": crossing_kind,
				"points_metres": _serialise_polygon(crossing_points),
				"half_width_metres": _road_half_width_metres(road_tags),
				"layer": int(str(road_tags.get("layer", "0"))) if str(road_tags.get("layer", "0")).is_valid_int() else 0,
				"source": "osm_road"
			})
	var data := {
		"schema_version": 1,
		"kind": "building_collision_index",
		"projection": {
			"method": "local_equirectangular_metres",
			"origin_longitude": origin.x,
			"origin_latitude": origin.y,
			"y_axis": "south",
			"longitude_metres_per_degree": METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y)),
			"latitude_metres_per_degree": METRES_PER_LATITUDE_DEGREE
		},
		"runtime_scale": {"pixels_per_metre": pixels_per_metre},
		"chunk_size_metres": CHUNK_SIZE_METRES,
		"buildings": buildings,
		"water_areas": water_areas,
		"water_crossings": water_crossings,
		"statistics": {
			"source_footprints": buildings.size() + skipped + non_ground_structures,
			"collision_buildings": buildings.size(),
			"skipped_invalid": skipped,
			"non_ground_structures": non_ground_structures,
			"estimated_convex_pieces": convex_piece_count,
			"blocking_water_areas": water_areas.size(),
			"water_crossings": water_crossings.size()
		},
		"warnings": warnings
	}
	return {"ok": true, "message": "Building collisions generated.", "data": data}


func _tag_enabled(value: Variant) -> bool:
	var text := str(value).to_lower()
	return not text.is_empty() and text not in ["no", "false", "0"]


func _road_half_width_metres(tags: Dictionary) -> float:
	return RoadDimensionsScript.half_width_metres(tags)


func geographic_to_local_metres(location: Vector2, projection: Dictionary) -> Vector2:
	return Vector2(
		(location.x - float(projection.origin_longitude)) * float(projection.longitude_metres_per_degree),
		(float(projection.origin_latitude) - location.y) * float(projection.latitude_metres_per_degree)
	)


func _project_and_clean(geographic_points: Array, origin: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var longitude_scale := METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y))
	for point_value in geographic_points:
		var geographic_point: Vector2
		if point_value is Vector2:
			geographic_point = point_value
		elif point_value is Array and point_value.size() >= 2:
			geographic_point = Vector2(float(point_value[0]), float(point_value[1]))
		else:
			continue
		var local_point := Vector2(
			(geographic_point.x - origin.x) * longitude_scale,
			(origin.y - geographic_point.y) * METRES_PER_LATITUDE_DEGREE
		)
		if result.is_empty() or result[result.size() - 1].distance_to(local_point) > 0.02:
			result.append(local_point)
	if result.size() > 2 and result[0].distance_to(result[result.size() - 1]) <= 0.02:
		result.remove_at(result.size() - 1)
	return result


func _is_usable_polygon(polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3 or absf(_signed_area(polygon)) < MINIMUM_BUILDING_AREA_SQUARE_METRES:
		return false
	for first in polygon.size():
		var first_next := (first + 1) % polygon.size()
		for second in range(first + 1, polygon.size()):
			var second_next := (second + 1) % polygon.size()
			if first_next == second or second_next == first:
				continue
			var intersection = Geometry2D.segment_intersects_segment(polygon[first], polygon[first_next], polygon[second], polygon[second_next])
			if intersection != null:
				var intersection_point: Vector2 = intersection
				var touches_known_corner := intersection_point.distance_to(polygon[first]) <= 0.02 or intersection_point.distance_to(polygon[first_next]) <= 0.02 or intersection_point.distance_to(polygon[second]) <= 0.02 or intersection_point.distance_to(polygon[second_next]) <= 0.02
				if not touches_known_corner:
					return false
	return true


func _signed_area(polygon: PackedVector2Array) -> float:
	var doubled_area := 0.0
	for index in polygon.size():
		var next := (index + 1) % polygon.size()
		doubled_area += polygon[index].x * polygon[next].y - polygon[next].x * polygon[index].y
	return doubled_area * 0.5


func _usable_area(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> float:
	var area := absf(_signed_area(outer))
	for hole in holes:
		area -= absf(_signed_area(hole))
	return maxf(0.0, area)


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var west := INF
	var north := INF
	var east := -INF
	var south := -INF
	for point in polygon:
		west = minf(west, point.x)
		east = maxf(east, point.x)
		north = minf(north, point.y)
		south = maxf(south, point.y)
	return Rect2(Vector2(west, north), Vector2(east - west, south - north))


func _serialise_polygon(polygon: PackedVector2Array) -> Array:
	var result: Array[Array] = []
	for point in polygon:
		result.append([point.x, point.y])
	return result
