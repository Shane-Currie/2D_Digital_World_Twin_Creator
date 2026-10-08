extends Node2D

## Map limits are information, not physical obstacles or traffic signals.
## Complete OSM ways often extend beyond the export, so intersect segments
## with the playable rectangle rather than looking only at their last node.
var exits: Array[Dictionary] = []
var map_bounds := Rect2()
var camera_zoom := 1.0
var visible_bounds := Rect2()
var show_overview := false
var show_tunnels := false
var edge_tolerance := 0.25


func setup(road_paths: Array, bounds: Rect2, pixels_per_metre: float) -> void:
	exits.clear()
	map_bounds = bounds
	edge_tolerance = maxf(0.01, pixels_per_metre * 0.25)
	var seen: Dictionary = {}
	if not bounds.has_area(): return
	for road in road_paths:
		if road.get("walkway", false): continue
		var points: PackedVector2Array = road.points
		for index in range(points.size() - 1):
			var start := points[index]
			var finish := points[index + 1]
			var interval := _clip_segment(start, finish)
			if interval.is_empty(): continue
			var entry := start.lerp(finish, interval[0])
			var exit := start.lerp(finish, interval[1])
			# Ignore tangential contact and roads running along the boundary.
			if entry.distance_to(exit) <= 0.01 or not bounds.grow(-0.01).has_point((entry + exit) * 0.5): continue
			if interval[0] > 0.000001 or (index == 0 or not _inside(points[index - 1])) and _on_edge(entry):
				_add_exit(entry, finish.direction_to(start), road, seen)
			if interval[1] < 0.999999 or (index == points.size() - 2 or not _inside(points[index + 2])) and _on_edge(exit):
				_add_exit(exit, start.direction_to(finish), road, seen)
	z_index = 12
	queue_redraw()


func _clip_segment(start: Vector2, finish: Vector2) -> PackedFloat64Array:
	var direction := finish - start
	var entry := 0.0
	var exit := 1.0
	for axis in 2:
		var lower := map_bounds.position[axis]
		var upper := map_bounds.end[axis]
		if absf(direction[axis]) < 0.000001:
			if start[axis] < lower or start[axis] > upper: return PackedFloat64Array()
			continue
		var first := (lower - start[axis]) / direction[axis]
		var second := (upper - start[axis]) / direction[axis]
		entry = maxf(entry, minf(first, second))
		exit = minf(exit, maxf(first, second))
		if exit < entry: return PackedFloat64Array()
	return PackedFloat64Array([entry, exit])


func _inside(point: Vector2) -> bool:
	return point.x >= map_bounds.position.x and point.x <= map_bounds.end.x and point.y >= map_bounds.position.y and point.y <= map_bounds.end.y


func _on_edge(point: Vector2) -> bool:
	return minf(minf(absf(point.x - map_bounds.position.x), absf(point.x - map_bounds.end.x)), minf(absf(point.y - map_bounds.position.y), absf(point.y - map_bounds.end.y))) <= edge_tolerance


func _add_exit(point: Vector2, outward: Vector2, road: Dictionary, seen: Dictionary) -> void:
	# Snap small coordinate-rounding differences to the actual export edge.
	var edges := [absf(point.x - map_bounds.position.x), absf(point.x - map_bounds.end.x), absf(point.y - map_bounds.position.y), absf(point.y - map_bounds.end.y)]
	var closest := edges.find(edges.min())
	if closest < 2: point.x = map_bounds.position.x if closest == 0 else map_bounds.end.x
	else: point.y = map_bounds.position.y if closest == 2 else map_bounds.end.y
	var key := "%d:%d:%d:%s:%s" % [roundi(point.x / edge_tolerance), roundi(point.y / edge_tolerance), int(road.get("layer", 0)), str(road.get("bridge", false)), str(road.get("tunnel", false))]
	if seen.has(key): return
	seen[key] = true
	exits.append({"position": point, "outward": outward, "road_id": str(road.get("path_id", "")), "tunnel": bool(road.get("tunnel", false)), "layer": int(road.get("layer", 0))})


func update_presentation(zoom: float, view_bounds: Rect2, overview: bool, tunnels: bool) -> void:
	var safe_zoom := maxf(zoom, 0.000001)
	if is_equal_approx(camera_zoom, safe_zoom) and visible_bounds == view_bounds and show_overview == overview and show_tunnels == tunnels: return
	camera_zoom = safe_zoom
	visible_bounds = view_bounds
	show_overview = overview
	show_tunnels = tunnels
	queue_redraw()


func marker_position(exit: Dictionary) -> Vector2:
	# Keep the complete X inside the map; maintain readable screen size at
	# walking, driving and map zooms without scaling the road or collision.
	var inset := minf(10.0 / camera_zoom, minf(map_bounds.size.x, map_bounds.size.y) * 0.05)
	var centre: Vector2 = exit.position - exit.outward * inset
	return centre.clamp(map_bounds.position + Vector2.ONE * inset, map_bounds.end - Vector2.ONE * inset)


func _draw() -> void:
	var drawn_cells: Dictionary = {}
	var radius := 7.0 / camera_zoom
	for exit in exits:
		if not show_overview and bool(exit.tunnel) != show_tunnels: continue
		var centre := marker_position(exit)
		if not show_overview and visible_bounds.has_area() and not visible_bounds.grow(radius).has_point(centre): continue
		# Dense city overviews may combine visually overlapping Xs; every road
		# retains its exit record and separates again as the map is zoomed in.
		var cell := Vector2i(roundi(centre.x * camera_zoom / 15.0), roundi(centre.y * camera_zoom / 15.0))
		if drawn_cells.has(cell): continue
		drawn_cells[cell] = true
		draw_circle(centre, radius + 2.0 / camera_zoom, Color("#172e29"))
		draw_arc(centre, radius + 2.0 / camera_zoom, 0.0, TAU, 24, Color("#fff1d0"), 1.0 / camera_zoom, true)
		for slope in [-1.0, 1.0]:
			var diagonal := Vector2(radius * 0.65, radius * 0.65 * slope)
			draw_line(centre - diagonal, centre + diagonal, Color("#ff625d"), 3.0 / camera_zoom, true)
