extends RefCounted

## Creator rectangles are data overlays, never edits to original OSM ways.
const Geometry = preload("res://scripts/interiors/connections/building_connections.gd")
const Roads = preload("res://scripts/roads/road_dimensions.gd")

static func valid(feature: Dictionary) -> bool:
	if str(feature.get("kind", "")) != "building" or not str(feature.get("id", "")).begins_with("creator_building_"): return false
	var suffix := str(feature.id).trim_prefix("creator_building_")
	if not suffix.is_valid_int() or suffix.to_int() < 1 or str(suffix.to_int()) != suffix: return false
	if not feature.get("tags", {}) is Dictionary or not Geometry.geometry_valid(feature): return false
	var points := Geometry.geometry_points(feature)
	if not feature.get("points", []) is Array or feature.points != points: return false
	if points.size() != 5 or points[0] != points[-1]: return false
	if points[0][1] != points[1][1] or points[1][0] != points[2][0] or points[2][1] != points[3][1] or points[3][0] != points[0][0]: return false
	var ring := PackedVector2Array()
	for point in points: ring.append(Geometry.project(point, points[0]))
	if ring[0].distance_to(ring[1]) < 2 or ring[1].distance_to(ring[2]) < 2: return false
	return Geometry2D.triangulate_polygon(ring.slice(0, 4)).size() == 6

static func propose(data: Dictionary, points: Array, name: String, features: Array, bounds: Dictionary, starts: Dictionary = {}) -> Dictionary:
	if data.get("custom_buildings", []).size() >= 1000: return {"ok": false, "message": "This town already has 1,000 custom footprints."}
	var next := 1
	var used: Dictionary = {}
	for feature in features: used[str(feature.get("id", ""))] = true
	for feature in data.get("custom_buildings", []): used[str(feature.get("id", ""))] = true
	while used.has("creator_building_%d" % next): next += 1
	var feature := {"id": "creator_building_%d" % next, "kind": "building", "points": points.duplicate(true), "precise_points": points.duplicate(true), "holes": [], "node_ids": [], "node_tags": {}, "tags": {"building": "yes", "source": "creator_authored", "name": name.strip_edges() if not name.strip_edges().is_empty() else "Custom building %d" % next}, "geometry_quality": "creator_authored"}
	if not valid(feature): return {"ok": false, "message": "Draw a building at least 2 m wide and 2 m long."}
	var polygon := PackedVector2Array()
	for point in points:
		if float(point[0]) < float(bounds.west) or float(point[0]) > float(bounds.east) or float(point[1]) < float(bounds.south) or float(point[1]) > float(bounds.north): return {"ok": false, "message": "Keep the footprint inside the map."}
		polygon.append(Geometry.project(point, points[0]))
	polygon.remove_at(polygon.size() - 1)
	for other in features:
		var kind := str(other.get("kind", ""))
		if kind not in ["building", "road", "footpath", "water", "parking"]: continue
		var values: Array = Geometry.geometry_points(other) if kind == "building" else other.get("points", [])
		var shape := PackedVector2Array()
		for point in values: shape.append(Geometry.project(point, points[0]))
		if kind in ["road", "footpath"]:
			if str(other.get("tags", {}).get("bridge", "no")) != "no" or str(other.get("tags", {}).get("tunnel", "no")) != "no": continue
			var tags: Dictionary = other.get("tags", {})
			var margin := Roads.half_width_metres(tags) + (Roads.sidewalk_width_metres(tags) if not Roads.sidewalk_sides(tags).is_empty() else 0.0) + 0.3
			for corridor in Geometry2D.offset_polyline(shape, margin):
				if not Geometry2D.intersect_polygons(polygon, corridor).is_empty(): return {"ok": false, "message": "Keep buildings clear of roads and footpaths."}
		elif shape.size() >= 3 and not Geometry2D.intersect_polygons(polygon, shape).is_empty():
			return {"ok": false, "message": "This footprint overlaps a building, water or parking area."}
	for start in [starts, starts.get("vehicle", {})]:
		if start.has("longitude") and start.has("latitude"):
			for envelope in Geometry2D.offset_polygon(polygon, 4.0 if start == starts.get("vehicle", {}) else 1.0):
				if Geometry2D.is_point_in_polygon(Geometry.project([start.longitude, start.latitude], points[0]), envelope): return {"ok": false, "message": "Keep clear space around the player and car start."}
	var updated := data.duplicate(true)
	var custom: Array = updated.get("custom_buildings", []).duplicate(true)
	custom.append(feature)
	updated["custom_buildings"] = custom
	return {"ok": true, "data": updated, "feature": feature, "message": "Footprint created. Save corrections and rebuild, then open Interior Designer to create its interior."}
