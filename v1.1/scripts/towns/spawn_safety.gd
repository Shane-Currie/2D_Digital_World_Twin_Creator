class_name SpawnSafety
extends RefCounted

# Clearance includes the collision body plus a small safety margin.
const PLAYER_CLEARANCE_METRES := 1.0
const VEHICLE_CLEARANCE_METRES := 4.0
const PLAYER_VEHICLE_GAP_METRES := 8.0
const MAX_VEHICLE_DISTANCE_METRES := 250.0
const METRES_PER_LATITUDE_DEGREE := 110540.0
const METRES_PER_LONGITUDE_DEGREE := 111320.0


static func create_starting_location(player_location: Dictionary, features: Array) -> Dictionary:
	var player_point := Vector2(float(player_location.longitude), float(player_location.latitude))
	var nearby_footprints := _collect_nearby_fixed_footprints(features, player_point)
	if _overlaps_fixed_footprint(player_point, nearby_footprints, PLAYER_CLEARANCE_METRES):
		return {"ok": false, "message": "That starting point is inside or too close to a fixed building. Choose an open space."}
	if _is_unsafe_water(player_point, features, PLAYER_CLEARANCE_METRES):
		return {"ok": false, "message": "That starting point is in mapped water. Choose dry land or a mapped bridge."}
	var vehicle_result := _find_clear_vehicle_location(player_point, features, nearby_footprints)
	if not vehicle_result.ok:
		return vehicle_result
	var vehicle_point: Vector2 = vehicle_result.location
	return {
		"ok": true,
		"message": "The player and vehicle both have clear starting space.",
		"starting_location": {
			"longitude": float(player_location.longitude),
			"latitude": float(player_location.latitude),
			"vehicle": {"longitude": vehicle_point.x, "latitude": vehicle_point.y},
			"clearance": {
				"checked_against": "fixed_building_footprints_and_osm_water",
				"player_metres": PLAYER_CLEARANCE_METRES,
				"vehicle_metres": VEHICLE_CLEARANCE_METRES
			}
		}
	}


static func validate_starting_location(starting_location: Dictionary, features: Array) -> Dictionary:
	if not starting_location.has("longitude") or not starting_location.has("latitude"):
		return {"ok": false, "message": "The player's starting location is missing."}
	if not starting_location.has("vehicle") or not starting_location.vehicle is Dictionary:
		return {"ok": false, "message": "The player's vehicle does not have a starting location."}
	var vehicle: Dictionary = starting_location.vehicle
	if not vehicle.has("longitude") or not vehicle.has("latitude"):
		return {"ok": false, "message": "The player's vehicle starting location is incomplete."}
	var player_point := Vector2(float(starting_location.longitude), float(starting_location.latitude))
	var vehicle_point := Vector2(float(vehicle.longitude), float(vehicle.latitude))
	var nearby_footprints := _collect_nearby_fixed_footprints(features, player_point)
	if _overlaps_fixed_footprint(player_point, nearby_footprints, PLAYER_CLEARANCE_METRES):
		return {"ok": false, "message": "The player would start inside or too close to a fixed building footprint."}
	if _overlaps_fixed_footprint(vehicle_point, nearby_footprints, VEHICLE_CLEARANCE_METRES):
		return {"ok": false, "message": "The player's vehicle would start inside or too close to a fixed building footprint."}
	if _is_unsafe_water(player_point, features, PLAYER_CLEARANCE_METRES):
		return {"ok": false, "message": "The player would start in mapped water."}
	if _is_unsafe_water(vehicle_point, features, VEHICLE_CLEARANCE_METRES):
		return {"ok": false, "message": "The player's vehicle would start in mapped water."}
	var separation := _to_local_metres(vehicle_point, player_point).length()
	if separation < PLAYER_VEHICLE_GAP_METRES:
		return {"ok": false, "message": "The player and vehicle starting positions overlap."}
	if separation > MAX_VEHICLE_DISTANCE_METRES:
		return {"ok": false, "message": "The player's vehicle is too far from the player starting point."}
	return {"ok": true, "message": "The player and vehicle starting locations are clear."}


static func _find_clear_vehicle_location(player_point: Vector2, features: Array, nearby_footprints: Array[Dictionary]) -> Dictionary:
	# Collect and sort nearby road candidates first. The previous implementation
	# checked every road candidate against every town building, which became
	# prohibitively expensive on real maps.
	var candidates: Array[Dictionary] = []
	for feature in features:
		if str(feature.get("kind", "")) != "road":
			continue
		var points: Array = feature.get("points", [])
		for index in range(points.size() - 1):
			var first: Vector2 = points[index]
			var second: Vector2 = points[index + 1]
			var local_first := _to_local_metres(first, player_point)
			var local_second := _to_local_metres(second, player_point)
			var segment := local_second - local_first
			var length_squared := segment.length_squared()
			if length_squared < 0.01:
				continue
			var nearest_t := clampf(-local_first.dot(segment) / length_squared, 0.0, 1.0)
			var nearest_distance := (local_first + segment * nearest_t).length()
			if nearest_distance > MAX_VEHICLE_DISTANCE_METRES + 12.0:
				continue
			var offset_t := 12.0 / sqrt(length_squared)
			for candidate_t in [nearest_t - offset_t, nearest_t + offset_t, nearest_t]:
				var clamped_t := clampf(float(candidate_t), 0.0, 1.0)
				var candidate := first.lerp(second, clamped_t)
				var distance := _to_local_metres(candidate, player_point).length()
				if distance < PLAYER_VEHICLE_GAP_METRES or distance > MAX_VEHICLE_DISTANCE_METRES:
					continue
				candidates.append({"location": candidate, "distance": distance})
	candidates.sort_custom(func(first: Dictionary, second: Dictionary): return first.distance < second.distance)
	var candidates_to_check := mini(candidates.size(), 64)
	for index in candidates_to_check:
		var candidate: Vector2 = candidates[index].location
		if not _overlaps_fixed_footprint(candidate, nearby_footprints, VEHICLE_CLEARANCE_METRES) and not _is_unsafe_water(candidate, features, VEHICLE_CLEARANCE_METRES):
			return {"ok": true, "location": candidate}
	if candidates.is_empty() or candidates_to_check > 0:
		return {"ok": false, "message": "No clear road position was found for the player's vehicle nearby. Choose another open starting area."}
	return {"ok": false, "message": "No usable roads were found near the selected starting area."}


static func _collect_nearby_fixed_footprints(features: Array, origin: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var latitude_margin := (MAX_VEHICLE_DISTANCE_METRES + VEHICLE_CLEARANCE_METRES) / METRES_PER_LATITUDE_DEGREE
	var longitude_scale := maxf(1.0, METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y)))
	var longitude_margin := (MAX_VEHICLE_DISTANCE_METRES + VEHICLE_CLEARANCE_METRES) / longitude_scale
	for feature in features:
		if str(feature.get("kind", "")) not in ["building", "fixed_footprint"]:
			continue
		var points: Array = feature.get("points", [])
		if points.size() < 3:
			continue
		var west := INF
		var south := INF
		var east := -INF
		var north := -INF
		for geographic_point in points:
			west = minf(west, geographic_point.x)
			east = maxf(east, geographic_point.x)
			south = minf(south, geographic_point.y)
			north = maxf(north, geographic_point.y)
		if east < origin.x - longitude_margin or west > origin.x + longitude_margin:
			continue
		if north < origin.y - latitude_margin or south > origin.y + latitude_margin:
			continue
		result.append({"points": points, "holes": feature.get("holes", []), "west": west, "south": south, "east": east, "north": north})
	return result


static func _overlaps_fixed_footprint(point: Vector2, footprints: Array[Dictionary], clearance_metres: float) -> bool:
	var latitude_margin := clearance_metres / METRES_PER_LATITUDE_DEGREE
	var longitude_scale := maxf(1.0, METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(point.y)))
	var longitude_margin := clearance_metres / longitude_scale
	for footprint in footprints:
		if footprint.east < point.x - longitude_margin or footprint.west > point.x + longitude_margin:
			continue
		if footprint.north < point.y - latitude_margin or footprint.south > point.y + latitude_margin:
			continue
		var polygon := PackedVector2Array()
		for geographic_point in footprint.points:
			polygon.append(_to_local_metres(geographic_point, point))
		var inside_outer := Geometry2D.is_point_in_polygon(Vector2.ZERO, polygon)
		var inside_hole := false
		if inside_outer:
			for hole_value in footprint.get("holes", []):
				var hole := PackedVector2Array()
				for geographic_point in hole_value:
					hole.append(_to_local_metres(geographic_point, point))
				if hole.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2.ZERO, hole):
					inside_hole = true
					for hole_index in hole.size():
						var hole_closest := _closest_point_on_segment(Vector2.ZERO, hole[hole_index], hole[(hole_index + 1) % hole.size()])
						if hole_closest.length() < clearance_metres:
							return true
					break
			if not inside_hole:
				return true
		if inside_hole:
			continue
		for index in range(polygon.size()):
			var closest := _closest_point_on_segment(Vector2.ZERO, polygon[index], polygon[(index + 1) % polygon.size()])
			if closest.length() < clearance_metres:
				return true
	return false


static func _closest_point_on_segment(point: Vector2, first: Vector2, second: Vector2) -> Vector2:
	var segment := second - first
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return first
	var amount := clampf((point - first).dot(segment) / length_squared, 0.0, 1.0)
	return first + segment * amount


static func _is_unsafe_water(point: Vector2, features: Array, clearance_metres: float) -> bool:
	if _point_on_water_crossing(point, features, clearance_metres):
		return false
	var sample_offsets := [Vector2.ZERO]
	if clearance_metres > 0.0:
		sample_offsets.append_array([
			Vector2(clearance_metres, 0.0), Vector2(-clearance_metres, 0.0),
			Vector2(0.0, clearance_metres), Vector2(0.0, -clearance_metres)
		])
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) != "water":
			continue
		var outer := PackedVector2Array()
		for geographic_point in feature.get("points", []):
			outer.append(_to_local_metres(geographic_point, point))
		if outer.size() < 3:
			continue
		var holes: Array[PackedVector2Array] = []
		for hole_value in feature.get("holes", []):
			var hole := PackedVector2Array()
			for geographic_point in hole_value:
				hole.append(_to_local_metres(geographic_point, point))
			if hole.size() >= 3:
				holes.append(hole)
		for sample in sample_offsets:
			if not Geometry2D.is_point_in_polygon(sample, outer):
				continue
			var in_hole := false
			for hole in holes:
				if Geometry2D.is_point_in_polygon(sample, hole):
					in_hole = true
					break
			if not in_hole:
				return true
	return false


static func _point_on_water_crossing(point: Vector2, features: Array, clearance_metres: float) -> bool:
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) != "road":
			continue
		var tags: Dictionary = feature.get("tags", {})
		if not _tag_enabled(tags.get("bridge", "")) and not _tag_enabled(tags.get("tunnel", "")):
			continue
		var usable_half_width := maxf(0.5, _road_half_width_metres(tags) - clearance_metres)
		var points: Array = feature.get("points", [])
		for index in range(points.size() - 1):
			var first := _to_local_metres(points[index], point)
			var second := _to_local_metres(points[index + 1], point)
			if _closest_point_on_segment(Vector2.ZERO, first, second).length() <= usable_half_width:
				return true
	return false


static func _tag_enabled(value: Variant) -> bool:
	var text := str(value).to_lower()
	return not text.is_empty() and text not in ["no", "false", "0"]


static func _road_half_width_metres(tags: Dictionary) -> float:
	var width := str(tags.get("width", ""))
	if width.is_valid_float() and width.to_float() > 0.5:
		return clampf(width.to_float() * 0.5, 1.5, 20.0)
	var highway := str(tags.get("highway", "")).to_lower()
	if highway in ["motorway", "trunk", "primary"]:
		return 4.5
	if highway in ["secondary", "tertiary"]:
		return 3.75
	if highway in ["footway", "path", "pedestrian", "cycleway", "steps"]:
		return 1.5
	return 3.25


static func _to_local_metres(point: Vector2, origin: Vector2) -> Vector2:
	var longitude_scale := METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y))
	return Vector2(
		(point.x - origin.x) * longitude_scale,
		(point.y - origin.y) * METRES_PER_LATITUDE_DEGREE
	)
