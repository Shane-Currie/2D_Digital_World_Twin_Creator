class_name RuntimeWorldRenderer
extends Node2D

const MapGeometryValidatorScript = preload("res://scripts/validation/map_geometry_validator.gd")

const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const LandCoverScript = preload("res://scripts/land_cover/land_cover.gd")
const LandCoverLayerScript = preload("res://scripts/land_cover/land_cover_layer.gd")
var land_cover = LandCoverLayerScript.new()
const GRASS := Color("#8fb56d")
const GRASS_DARK := Color("#6f9858")
const WATER := Color("#397f9b")
const WATER_LIGHT := Color("#68aec1")
const WATER_EDGE := Color("#b5d7d5")
const TUNNEL_ROAD := Color("#414b4c")
const BRIDGE_EDGE := Color("#ece2c3")
const ROAD := Color("#747e7e")
const ROAD_EDGE := Color("#d0cfb2")
const ROAD_LINE := Color("#e8e1bd")
const FOOTPATH := Color("#bcbcaf")
const FOOTPATH_EDGE := Color("#e0dcc2")
const BUILDING_EDGE := Color("#394f50")
const WINDOW := Color("#315b78")
const WINDOW_LIGHT := Color("#a9d8e6")
const TRIM := Color("#f5dba1")
const BUILDING_SHADOW := Color(0.12, 0.20, 0.17, 0.28)

const BUILDING_PALETTES := {
	"brick": {"roof": Color("#ad4f35"), "light": Color("#e38b57"), "dark": Color("#9b5845"), "facade": Color("#bf7651")},
	"weatherboard": {"roof": Color("#667e69"), "light": Color("#9fb498"), "dark": Color("#506652"), "facade": Color("#d8d1b5")},
	"rendered": {"roof": Color("#7189a2"), "light": Color("#93abc2"), "dark": Color("#536d88"), "facade": Color("#eedbb7")},
	"commercial": {"roof": Color("#718084"), "light": Color("#9eaaab"), "dark": Color("#53666b"), "facade": Color("#d5b778")},
	"civic": {"roof": Color("#a56149"), "light": Color("#cd8a62"), "dark": Color("#7f493f"), "facade": Color("#dbc38f")},
	"health": {"roof": Color("#73949c"), "light": Color("#a9c1bf"), "dark": Color("#56747c"), "facade": Color("#d9e1d2")},
	"industrial": {"roof": Color("#858987"), "light": Color("#acafaa"), "dark": Color("#666b6a"), "facade": Color("#b7b49c")},
	"tall": {"roof": Color("#61798a"), "light": Color("#91a8b2"), "dark": Color("#455e70"), "facade": Color("#a9bcc0")}
}

var visual_style_version := "v1.3-generic-1"
var tunnel_view_only := false
var underpass_path_index := -1
var active_land_bridge_id := ""
var map_overview := false

var features: Array = []
var projection: Dictionary = {}
var pixels_per_metre := 8.0
var world_bounds := Rect2()
var road_segments: Array[Dictionary] = []
var road_paths: Array[Dictionary] = []
var water_areas: Array[Dictionary] = []
var water_cells: Dictionary = {}
var water_crossing_segments: Array[Dictionary] = []
var crossing_corridors: Array[Dictionary] = []
var named_road_cells: Dictionary = {}
var street_label_count := 0
var last_label_camera_zoom := -1.0
var last_label_detail := -1.0
var last_label_map_open := false


func setup(feature_values: Array, collision_data: Dictionary, map_bounds: Dictionary) -> void:
	features = feature_values
	projection = collision_data.projection
	pixels_per_metre = float(collision_data.runtime_scale.pixels_per_metre)
	var north_west := _world(Vector2(float(map_bounds.west), float(map_bounds.north)))
	var south_east := _world(Vector2(float(map_bounds.east), float(map_bounds.south)))
	world_bounds = Rect2(north_west, south_east - north_west).abs()
	_build_environment(collision_data)
	_build_roads()
	land_cover.setup(features, func(value: Variant) -> Vector2: return _world(ProjectionScript.value_to_location(value)), world_bounds)
	queue_redraw()


func is_grass(world_position: Vector2) -> bool:
	if not world_bounds.has_point(world_position):
		return false
	if is_open_water(world_position):
		return false
	var category: String = land_cover.category_at(world_position)
	if category not in ["", "grass"]:
		return false
	for segment in road_segments:
		var closest := Geometry2D.get_closest_point_to_segment(world_position, segment.a, segment.b)
		if closest.distance_to(world_position) <= float(segment.half_width) + 3.0:
			return false
	return true


func is_ground_traversable(world_position: Vector2, clearance_pixels: float = 0.0) -> bool:
	if not world_bounds.grow(-clearance_pixels).has_point(world_position):
		return false
	# Bridge and tunnel centre-lines are explicit legal corridors through water.
	if _is_on_water_crossing(world_position, clearance_pixels):
		return true
	var samples := [world_position]
	if clearance_pixels > 0.0:
		samples.append_array([
			world_position + Vector2(clearance_pixels, 0.0),
			world_position + Vector2(-clearance_pixels, 0.0),
			world_position + Vector2(0.0, clearance_pixels),
			world_position + Vector2(0.0, -clearance_pixels)
		])
	for sample in samples:
		if is_open_water(sample):
			return false
	return true


func crossing_kind_at(world_position: Vector2, clearance_pixels: float = 0.0) -> String:
	# Prefer the underground classification if unusual OSM data overlaps two
	# grade-separated routes at the same map position.
	var found := ""
	for segment_value in water_crossing_segments:
		var segment: Dictionary = segment_value
		var usable_half_width := maxf(1.0, float(segment.half_width) - clearance_pixels)
		var closest := Geometry2D.get_closest_point_to_segment(world_position, segment.a, segment.b)
		if closest.distance_to(world_position) <= usable_half_width:
			if str(segment.kind) == "tunnel":
				return "tunnel"
			found = str(segment.kind)
	return found


func is_mapped_water(world_position: Vector2) -> bool:
	var cell := Vector2i(floori(world_position.x / 512.0), floori(world_position.y / 512.0))
	for area_value in water_cells.get(cell, []):
		if _point_in_water_area(world_position, area_value):
			return true
	return false


func set_map_overview(enabled: bool) -> void:
	if map_overview == enabled:
		return
	map_overview = enabled
	queue_redraw()


func set_active_land_bridge(bridge_id: String) -> void:
	if active_land_bridge_id == bridge_id:
		return
	active_land_bridge_id = bridge_id
	queue_redraw()


func bridge_portal_at(world_position: Vector2, travel_direction: Vector2 = Vector2.ZERO, radius: float = 18.0) -> Dictionary:
	if travel_direction.length_squared() < 0.01:
		return {}
	var travel := travel_direction.normalized()
	for corridor_value in crossing_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.kind) != "bridge" or bool(corridor.get("over_water", false)):
			continue
		var points: PackedVector2Array = corridor.points
		if points.size() < 2:
			continue
		var first_inward := points[0].direction_to(points[1])
		var last_inward := points[points.size() - 1].direction_to(points[points.size() - 2])
		if world_position.distance_to(points[0]) <= radius and absf(travel.dot(first_inward)) >= 0.65:
			return {"id": str(corridor.id), "entry_index": 0, "entry": points[0], "exit": points[points.size() - 1]}
		if world_position.distance_to(points[points.size() - 1]) <= radius and absf(travel.dot(last_inward)) >= 0.65:
			return {"id": str(corridor.id), "entry_index": 1, "entry": points[points.size() - 1], "exit": points[0]}
	return {}


func bridge_corridor(bridge_id: String) -> Dictionary:
	for corridor_value in crossing_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.id) == bridge_id and str(corridor.kind) == "bridge":
			return corridor
	return {}


func is_open_water(world_position: Vector2) -> bool:
	var cell := Vector2i(floori(world_position.x / 512.0), floori(world_position.y / 512.0))
	for area_value in water_cells.get(cell, []):
		var area: Dictionary = area_value
		var area_bounds: Rect2 = area.bounds
		if not area_bounds.has_point(world_position):
			continue
		if not Geometry2D.is_point_in_polygon(world_position, area.outer):
			continue
		var in_hole := false
		for hole_value in area.holes:
			if Geometry2D.is_point_in_polygon(world_position, hole_value):
				in_hole = true
				break
		if not in_hole and not _is_on_water_crossing(world_position, 0.0):
			return true
	return false


func update_street_label_presentation(camera_zoom: float, map_detail: float, map_open: bool) -> void:
	if is_equal_approx(camera_zoom, last_label_camera_zoom) and is_equal_approx(map_detail, last_label_detail) and map_open == last_label_map_open:
		return
	last_label_camera_zoom = camera_zoom
	last_label_detail = map_detail
	last_label_map_open = map_open
	var occupied_screen_rects: Array[Rect2] = []
	var shown_names: Dictionary = {}
	var broad_view := camera_zoom < 0.025
	for child in get_children():
		if not child.is_in_group("generated_street_labels"):
			continue
		if not map_open:
			child.scale = Vector2.ONE
			child.visible = false
			continue
		# Keep lettering a stable screen size, then remove overlaps in screen space.
		# World-space spacing is misleading when a large city is fitted on screen.
		child.scale = Vector2.ONE / maxf(camera_zoom, 0.001)
		var importance := int(child.get_meta("road_importance", 1))
		# Use absolute screen scale rather than a town-relative zoom number. A New
		# York-sized map therefore does not reveal every local label while still
		# showing the whole city, but can zoom far enough to reveal them later.
		var passes_detail := importance >= 3 if broad_view else (importance >= 2 if camera_zoom < 0.08 else true)
		var label_name := str(child.text)
		if not passes_detail or (broad_view and shown_names.has(label_name)):
			child.visible = false
			continue
		var screen_centre: Vector2 = (child.position + child.size * 0.5) * camera_zoom
		var cosine := absf(cos(child.rotation))
		var sine := absf(sin(child.rotation))
		var screen_size := Vector2(child.size.x * cosine + child.size.y * sine, child.size.x * sine + child.size.y * cosine) + Vector2(12.0, 8.0)
		var screen_rect := Rect2(screen_centre - screen_size * 0.5, screen_size)
		var overlaps := false
		for occupied in occupied_screen_rects:
			if occupied.intersects(screen_rect):
				overlaps = true
				break
		child.visible = not overlaps
		if not overlaps:
			occupied_screen_rects.append(screen_rect)
			shown_names[label_name] = true


func nearest_named_road(world_position: Vector2, maximum_distance: float) -> Dictionary:
	var cell_radius := ceili(maximum_distance / 256.0)
	var centre_cell := Vector2i(floori(world_position.x / 256.0), floori(world_position.y / 256.0))
	var best_distance := maximum_distance
	var best_segment: Dictionary = {}
	var checked_segments: Dictionary = {}
	for cell_y in range(centre_cell.y - cell_radius, centre_cell.y + cell_radius + 1):
		for cell_x in range(centre_cell.x - cell_radius, centre_cell.x + cell_radius + 1):
			for segment_value in named_road_cells.get(Vector2i(cell_x, cell_y), []):
				var segment: Dictionary = segment_value
				var segment_id := int(segment.segment_id)
				if checked_segments.has(segment_id):
					continue
				checked_segments[segment_id] = true
				var closest := Geometry2D.get_closest_point_to_segment(world_position, segment.a, segment.b)
				var distance := world_position.distance_to(closest)
				if distance < best_distance:
					best_distance = distance
					best_segment = segment
	if best_segment.is_empty():
		return {}
	return {
		"name": str(best_segment.name),
		"distance": best_distance,
		"on_road": best_distance <= float(best_segment.half_width) + 12.0
	}


func set_tunnel_view(enabled: bool) -> void:
	if tunnel_view_only == enabled:
		return
	tunnel_view_only = enabled
	queue_redraw()


func _draw() -> void:
	if tunnel_view_only:
		_draw_tunnel_view()
		return
	if underpass_path_index >= 0 and underpass_path_index < road_paths.size():
		var path: Dictionary = road_paths[underpass_path_index]
		var width := float(path.half_width) * 2.0
		draw_polyline(path.points, ROAD_EDGE, width + 6.0, true)
		draw_polyline(path.points, FOOTPATH if path.walkway else ROAD, width, true)
		if path.markings: _draw_road_markings(path.points, path.oneway)
		return
	draw_rect(world_bounds.grow(80.0), GRASS, true)
	for area in land_cover.areas:
		for piece in area.pieces:
			_draw_polygon_safely(piece, LandCoverScript.colour(area.category))
	_draw_grass_stalks()
	# Underground decks belong only to tunnel view; drawing them on top of grass
	# produces a dark cut through the visible town and apparent gaps in bridges.
	_draw_water()
	# Ground roads are painted first. Explicit bridge decks are painted in a
	# second pass so a valid elevated road remains visible over a lower road.
	for path in road_paths:
		if bool(path.tunnel) or bool(path.bridge):
			continue
		var points: PackedVector2Array = path.points
		var width := float(path.half_width) * 2.0
		var walkway: bool = bool(path.walkway)
		var path_color := FOOTPATH if walkway else ROAD
		var edge_color := FOOTPATH_EDGE if walkway else ROAD_EDGE
		draw_polyline(points, edge_color, width + (3.0 if walkway else 6.0), true)
		draw_polyline(points, path_color, width, true)
		if bool(path.markings):
			_draw_road_markings(points, bool(path.oneway))
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) != "building":
			continue
		if not MapGeometryValidatorScript.building_blocks_ground(feature):
			continue
		var outer: PackedVector2Array = _polygon(feature.get("points", []))
		if outer.size() < 3:
			continue
		var tags: Dictionary = feature.get("tags", {})
		var style_name := _building_style(tags, str(feature.get("id", "")))
		var palette: Dictionary = BUILDING_PALETTES[style_name]
		_draw_polygon_safely(_offset_polygon(outer, Vector2(3.0, 5.0)), BUILDING_SHADOW)
		_draw_styled_building(outer, palette, str(feature.get("id", "")))
		for hole_value in feature.get("holes", []):
			var hole: PackedVector2Array = _polygon(hole_value)
			if hole.size() >= 3:
				_draw_polygon_safely(hole, GRASS)
				draw_polyline(_closed(hole), BUILDING_EDGE, 1.0, true)
	for feature_value in features:
		var feature: Dictionary = feature_value
		var feature_kind := str(feature.get("kind", ""))
		var vertical_context := MapGeometryValidatorScript.building_vertical_context(feature)
		if feature_kind != "overhead_structure" and vertical_context != "overhead":
			continue
		var roof := _polygon(feature.get("points", []))
		if roof.size() >= 3:
			_draw_polygon_safely(roof, Color("#889495"))
			draw_polyline(_closed(roof), Color("#d4d0b8"), 1.2, true)
	# Draw elevated decks last. The lower town and intersecting road remain visible
	# around the bridge, while the deck itself is never hidden underneath them.
	for corridor_value in crossing_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.kind) != "bridge":
			continue
		# The overview shows the complete mapped network, independent of the
		# player's current crossing. Gameplay still uses the active bridge layer.
		if not map_overview and not bool(corridor.get("over_water", false)) and str(corridor.id) != active_land_bridge_id:
			continue
		var bridge_points: PackedVector2Array = corridor.points
		var bridge_width := float(corridor.half_width) * 2.0
		draw_polyline(bridge_points, BRIDGE_EDGE, bridge_width + 7.0, true)
		draw_polyline(bridge_points, ROAD, bridge_width, true)
		_draw_road_markings(bridge_points, false)
	_draw_crossing_portals()


func set_underpass_view(path_index: int) -> void:
	if underpass_path_index == path_index: return
	underpass_path_index = path_index
	queue_redraw()


func underpass_at(position: Vector2, driving: bool = false) -> int:
	# Only a lower mapped road inside an upper bridge deck selects this view.
	# Being near a bridge, or standing on grass next to its approach, is not enough.
	for corridor in crossing_corridors:
		if corridor.kind != "bridge": continue
		var points: PackedVector2Array = corridor.points
		if position.distance_to(points[0]) <= float(corridor.half_width) or position.distance_to(points[points.size()-1]) <= float(corridor.half_width): continue
		var beneath := false
		for index in range(points.size()-1):
			if Geometry2D.get_closest_point_to_segment(position,points[index],points[index+1]).distance_to(position) <= float(corridor.half_width):
				beneath = true
				break
		if not beneath: continue
		var closest_path := -1
		var closest_distance := INF
		for segment in road_segments:
			if segment.bridge or segment.tunnel or int(segment.layer) >= maxi(1,int(corridor.layer)): continue
			if driving and road_paths[int(segment.path_index)].walkway: continue
			var distance := Geometry2D.get_closest_point_to_segment(position,segment.a,segment.b).distance_to(position)
			if distance <= float(segment.half_width) and distance < closest_distance:
				closest_distance = distance
				closest_path = int(segment.path_index)
		if closest_path >= 0: return closest_path
	return -1


func _draw_tunnel_view() -> void:
	# Keep the mapped tunnel deck and its portals visible over the black tunnel
	# background while surface roads and buildings remain hidden.
	for corridor_value in crossing_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.kind) != "tunnel":
			continue
		var points: PackedVector2Array = corridor.points
		var width := float(corridor.half_width) * 2.0
		draw_polyline(points, ROAD_EDGE, width + 4.0, true)
		draw_polyline(points, TUNNEL_ROAD, width, true)
		_draw_road_markings(points, false)
	_draw_crossing_portals("tunnel")


func _draw_crossing_portals(kind_filter: String = "") -> void:
	for corridor_value in crossing_corridors:
		var corridor: Dictionary = corridor_value
		var kind := str(corridor.kind)
		if not kind_filter.is_empty() and kind != kind_filter:
			continue
		var points: PackedVector2Array = corridor.points
		if points.size() < 2:
			continue
		_draw_crossing_portal(points[0], points[0].direction_to(points[1]), kind, true)
		_draw_crossing_portal(points[points.size() - 1], points[points.size() - 1].direction_to(points[points.size() - 2]), kind, false)


func _draw_crossing_portal(position: Vector2, inward: Vector2, kind: String, entry: bool) -> void:
	var colour := Color("#69d4df") if kind == "bridge" else Color("#e2a65d")
	var edge := Color("#17343c") if kind == "bridge" else Color("#332a28")
	var direction := inward if entry else -inward
	var normal := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([
		position + direction * 8.0,
		position - direction * 5.0 + normal * 5.0,
		position - direction * 5.0 - normal * 5.0
	])
	draw_circle(position, 8.0, edge)
	draw_circle(position, 6.0, colour)
	draw_colored_polygon(arrow, Color("#f4f1dd"))
	var caption := "%s %s" % [kind.to_upper(), "ENTRY" if entry else "EXIT"]
	var label_offset := normal * 13.0 + Vector2(-float(caption.length()) * 2.2, 3.0)
	draw_string(ThemeDB.fallback_font, position + label_offset, caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#f4f1dd"))


func longest_crossing_corridor(kind: String) -> Dictionary:
	var result: Dictionary = {}
	var longest := -1.0
	for corridor_value in crossing_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.kind) != kind:
			continue
		var length := 0.0
		var points: PackedVector2Array = corridor.points
		for index in range(points.size() - 1):
			length += points[index].distance_to(points[index + 1])
		if length > longest:
			longest = length
			result = corridor
	return result


func bridge_road_overlap() -> Dictionary:
	# Used by validation/tests: a crossing is a true grade-separated overlap when
	# the bridge and lower road intersect geometrically without sharing an OSM
	# junction. This does not connect their navigation graphs.
	var best: Dictionary = {}
	var best_score := INF
	for corridor_value in crossing_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.kind) != "bridge" or bool(corridor.get("over_water", false)):
			continue
		var points: PackedVector2Array = corridor.points
		var corridor_length := 0.0
		for length_index in range(points.size() - 1):
			corridor_length += points[length_index].distance_to(points[length_index + 1])
		var clean_endpoints := crossing_kind_at(points[0]) != "tunnel" and crossing_kind_at(points[points.size() - 1]) != "tunnel"
		for index in range(points.size() - 1):
			for road_value in road_segments:
				var road: Dictionary = road_value
				if bool(road.get("bridge", false)) or bool(road.get("tunnel", false)):
					continue
				if road_paths[int(road.path_index)].walkway:
					continue
				var intersection = Geometry2D.segment_intersects_segment(points[index], points[index + 1], road.a, road.b)
				if intersection == null:
					continue
				var location: Vector2 = intersection
				if location.distance_to(points[index]) < 0.5 or location.distance_to(points[index + 1]) < 0.5:
					continue
				if is_mapped_water(location):
					continue
				# Prefer an ordinary, compact overpass with clean portals for review images;
				# all matching crossings still follow the same runtime rules.
				var score := absf(corridor_length - 480.0) + (0.0 if clean_endpoints else 1000000.0)
				if score < best_score:
					best_score = score
					best = {"position": location, "bridge": corridor, "road": road}
	return best


func _draw_water() -> void:
	for area_value in water_areas:
		var area: Dictionary = area_value
		for piece in area.pieces:
			_draw_polygon_safely(piece, WATER)
		draw_polyline(_closed(area.outer), WATER_EDGE, 2.0, true)
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) not in ["waterway", "coastline"]:
			continue
		var points := _polygon(feature.get("points", []))
		if points.size() < 2:
			continue
		var width := 5.0 if str(feature.get("kind", "")) == "waterway" else 2.0
		draw_polyline(points, WATER_LIGHT, width, true)


func _draw_styled_building(polygon: PackedVector2Array, palette: Dictionary, feature_id: String) -> void:
	# Alternating already-triangulated faces create a readable top-down roof while
	# remaining strictly inside any convex or concave OSM footprint.
	var triangle_indices := Geometry2D.triangulate_polygon(polygon)
	if triangle_indices.is_empty():
		return
	var seed := absi(hash(feature_id))
	var roof_colors := [palette.roof, palette.light, palette.dark]
	for index in range(0, triangle_indices.size(), 3):
		var triangle := PackedVector2Array([
			polygon[triangle_indices[index]],
			polygon[triangle_indices[index + 1]],
			polygon[triangle_indices[index + 2]]
		])
		var face_color: Color = roof_colors[(index / 3 + seed) % roof_colors.size()]
		draw_primitive(triangle, PackedColorArray([face_color, face_color, face_color]), PackedVector2Array())
	_draw_roof_seams(polygon, palette.dark)
	_draw_facade_edge(polygon, palette.facade)
	draw_polyline(_closed(polygon), BUILDING_EDGE, 2.0, true)
	_draw_roof_detail(polygon, palette, seed)


func _draw_roof_seams(polygon: PackedVector2Array, color: Color) -> void:
	if polygon.size() > 18:
		return
	var centre := _polygon_centre(polygon)
	if not Geometry2D.is_point_in_polygon(centre, polygon):
		return
	for index in range(polygon.size()):
		if index % 2 == 0:
			draw_line(centre, polygon[index], color.darkened(0.08), 0.8, true)


func _draw_facade_edge(polygon: PackedVector2Array, facade_color: Color) -> void:
	var best_a := Vector2.ZERO
	var best_b := Vector2.ZERO
	var best_score := -INF
	for index in range(polygon.size()):
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var length := a.distance_to(b)
		if length < 10.0:
			continue
		var score := (a.y + b.y) * 0.5 + minf(length, 80.0) * 0.08
		if score > best_score:
			best_score = score
			best_a = a
			best_b = b
	if best_score == -INF:
		return
	var direction := best_a.direction_to(best_b)
	var length := best_a.distance_to(best_b)
	var start := best_a + direction * minf(4.0, length * 0.15)
	var finish := best_b - direction * minf(4.0, length * 0.15)
	draw_line(start, finish, BUILDING_EDGE, 5.0, true)
	draw_line(start, finish, facade_color, 3.0, true)
	if length < 22.0:
		return
	var window_count := clampi(floori(length / 22.0), 1, 5)
	for window_index in window_count:
		var ratio := float(window_index + 1) / float(window_count + 1)
		var window_centre := start.lerp(finish, ratio)
		draw_line(window_centre - direction * 2.2, window_centre + direction * 2.2, WINDOW, 2.2, true)
		draw_line(window_centre - direction * 1.3, window_centre + direction * 1.3, WINDOW_LIGHT, 0.8, true)


func _draw_roof_detail(polygon: PackedVector2Array, palette: Dictionary, seed: int) -> void:
	var bounds := _points_bounds(polygon)
	if bounds.get_area() < 600.0:
		return
	var centre := _polygon_centre(polygon)
	if not Geometry2D.is_point_in_polygon(centre, polygon):
		centre = bounds.get_center()
	if not Geometry2D.is_point_in_polygon(centre, polygon):
		return
	if seed % 3 == 0:
		draw_rect(Rect2(centre - Vector2(4.0, 2.5), Vector2(8.0, 5.0)), BUILDING_EDGE, true)
		draw_rect(Rect2(centre - Vector2(3.0, 1.5), Vector2(6.0, 3.0)), WINDOW, true)
		draw_line(centre + Vector2(-2.0, -0.5), centre + Vector2(2.0, -0.5), WINDOW_LIGHT, 0.8)
	else:
		draw_rect(Rect2(centre - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), BUILDING_EDGE, true)
		draw_rect(Rect2(centre - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), TRIM.darkened(0.12), true)


func _draw_polygon_safely(polygon: PackedVector2Array, color: Color) -> void:
	# OSM can contain valid building outlines that are too complex or imperfect for
	# Godot's direct polygon draw call. Drawing verified triangles prevents one
	# unusual building from breaking the entire town preview.
	var triangle_indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if triangle_indices.is_empty():
		return
	for index in range(0, triangle_indices.size(), 3):
		var triangle := PackedVector2Array([
			polygon[triangle_indices[index]],
			polygon[triangle_indices[index + 1]],
			polygon[triangle_indices[index + 2]]
		])
		# draw_primitive accepts the triangles we already validated and does not ask
		# the renderer to triangulate the same geometry a second time.
		draw_primitive(triangle, PackedColorArray([color, color, color]), PackedVector2Array())


func _draw_grass_stalks() -> void:
	# The spacing adapts to map size so a large city cannot create an unbounded
	# number of decorative marks. Roads and buildings draw over these ground marks.
	var target_stalks := 8000.0
	var spacing := maxf(120.0, sqrt(world_bounds.get_area() / target_stalks))
	var start_x := floorf(world_bounds.position.x / spacing) * spacing
	var start_y := floorf(world_bounds.position.y / spacing) * spacing
	var x := start_x
	while x <= world_bounds.end.x:
		var y := start_y
		while y <= world_bounds.end.y:
			var cell_seed := int(x / spacing) * 73856093 ^ int(y / spacing) * 19349663
			var jitter := Vector2(float(posmod(cell_seed, 37)) - 18.0, float(posmod(cell_seed / 37, 31)) - 15.0)
			var base := Vector2(x, y) + jitter
			if land_cover.category_at(base) in ["", "grass"]:
				draw_line(base, base + Vector2(-2.0, -7.0), GRASS_DARK, 1.2)
				draw_line(base, base + Vector2(3.0, -6.0), Color("#789f5b"), 1.2)
			y += spacing
		x += spacing


func _build_roads() -> void:
	road_segments.clear()
	road_paths.clear()
	named_road_cells.clear()
	var label_candidates: Array = []
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) != "road":
			continue
		var points: PackedVector2Array = _polygon(feature.get("points", []))
		if points.size() < 2:
			continue
		var tags: Dictionary = feature.get("tags", {})
		var half_width := _road_half_width(tags)
		var road_kind := str(tags.get("highway", ""))
		var walkway := road_kind in ["footway", "path", "pedestrian", "cycleway", "steps"]
		var oneway_value := str(tags.get("oneway", "")).to_lower()
		var bridge := _tag_enabled(tags.get("bridge", ""))
		var tunnel := _tag_enabled(tags.get("tunnel", ""))
		road_paths.append({
			"path_id": str(feature.get("id", "")),
			"points": points,
			"half_width": half_width,
			"walkway": walkway,
			"markings": not walkway and road_kind in ["motorway", "trunk", "primary", "secondary", "tertiary"],
			"oneway": oneway_value in ["yes", "true", "1", "-1"],
			"bridge": bridge,
			"tunnel": tunnel,
			"layer": int(str(tags.get("layer", "0"))) if str(tags.get("layer", "0")).is_valid_int() else 0
		})
		var street_name := str(tags.get("name", "")).strip_edges()
		if not walkway and not street_name.is_empty():
			# OSM frequently divides one street into several ways. Keeping spatially
			# separated candidates lets its name remain visible in each neighbourhood;
			# the placement grid below removes labels that would overlap locally.
			label_candidates.append(_road_label_candidate(points, street_name, road_kind))
		for index in range(points.size() - 1):
			var segment := {
				"segment_id": road_segments.size(),
				"path_index": road_paths.size() - 1,
				"path_id": str(feature.get("id", "")),
				"a": points[index],
				"b": points[index + 1],
				"half_width": half_width,
				"name": street_name.to_upper(),
				"bridge": bridge,
				"tunnel": tunnel,
				"layer": int(str(tags.get("layer", "0"))) if str(tags.get("layer", "0")).is_valid_int() else 0
			}
			road_segments.append(segment)
			if not street_name.is_empty():
				_index_named_road_segment(segment)
	road_paths.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.half_width) < float(b.half_width))
	var sorted_path_indices: Dictionary = {}
	for index in road_paths.size(): sorted_path_indices[road_paths[index].path_id] = index
	for segment in road_segments: segment.path_index = sorted_path_indices[segment.path_id]
	_build_street_labels(label_candidates)


func _build_environment(data: Dictionary) -> void:
	water_areas.clear()
	water_cells.clear()
	water_crossing_segments.clear()
	crossing_corridors.clear()
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) != "water":
			continue
		var outer := _polygon(feature.get("points", []))
		if outer.size() < 3:
			continue
		var holes: Array[PackedVector2Array] = []
		for hole_value in feature.get("holes", []):
			var hole := _polygon(hole_value)
			if hole.size() >= 3:
				holes.append(hole)
		var area := {"id": str(feature.get("id", "")), "outer": outer, "holes": holes, "bounds": _points_bounds(outer), "pieces": LandCoverScript.pieces(outer, holes)}
		water_areas.append(area)
		_index_water_area(area)
	var scale := float(data.get("runtime_scale", {}).get("pixels_per_metre", pixels_per_metre))
	for crossing_value in data.get("water_crossings", []):
		var crossing: Dictionary = crossing_value
		var points := PackedVector2Array()
		for point_value in crossing.get("points_metres", []):
			if point_value is Array and point_value.size() >= 2:
				points.append(Vector2(float(point_value[0]), float(point_value[1])) * scale)
		if points.size() < 2:
			continue
		var corridor := {
			"id": str(crossing.get("id", "")),
			"source_ids": [str(crossing.get("id", ""))],
			"kind": str(crossing.get("kind", "bridge")),
			"points": points,
			"half_width": float(crossing.get("half_width_metres", 3.25)) * scale,
			"layer": int(crossing.get("layer", 0)),
			"over_water": _path_over_mapped_water(points)
		}
		crossing_corridors.append(corridor)
		for index in range(points.size() - 1):
			water_crossing_segments.append({
				"id": corridor.id,
				"a": points[index],
				"b": points[index + 1],
				"half_width": corridor.half_width,
				"kind": corridor.kind
			})
	_merge_crossing_corridors()


func _index_water_area(area: Dictionary) -> void:
	var bounds: Rect2 = area.bounds
	var low := Vector2i(floori(bounds.position.x / 512.0), floori(bounds.position.y / 512.0))
	var high := Vector2i(floori(bounds.end.x / 512.0), floori(bounds.end.y / 512.0))
	for cell_y in range(low.y, high.y + 1):
		for cell_x in range(low.x, high.x + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not water_cells.has(cell):
				water_cells[cell] = []
			water_cells[cell].append(area)


func _point_in_water_area(world_position: Vector2, area_value: Dictionary) -> bool:
	var area: Dictionary = area_value
	var area_bounds: Rect2 = area.bounds
	if not area_bounds.has_point(world_position):
		return false
	if not Geometry2D.is_point_in_polygon(world_position, area.outer):
		return false
	for hole_value in area.holes:
		if Geometry2D.is_point_in_polygon(world_position, hole_value):
			return false
	return true


func _path_over_mapped_water(points: PackedVector2Array) -> bool:
	for index in range(points.size() - 1):
		for sample_index in range(7):
			var sample := points[index].lerp(points[index + 1], float(sample_index) / 6.0)
			if is_mapped_water(sample):
				return true
	return false


func _merge_crossing_corridors() -> void:
	var pending: Array[Dictionary] = crossing_corridors.duplicate(true)
	var merged: Array[Dictionary] = []
	while not pending.is_empty():
		var current: Dictionary = pending.pop_back()
		var found_connection := true
		while found_connection:
			found_connection = false
			for candidate_index in pending.size():
				var candidate: Dictionary = pending[candidate_index]
				if str(candidate.kind) != str(current.kind) or int(candidate.layer) != int(current.layer):
					continue
				var joined: PackedVector2Array = _joined_corridor_points(current.points, candidate.points)
				if joined.is_empty():
					continue
				current.points = joined
				current.source_ids.append_array(candidate.get("source_ids", [str(candidate.id)]))
				pending.remove_at(candidate_index)
				found_connection = true
				break
		current.id = str(current.source_ids[0])
		current.over_water = _path_over_mapped_water(current.points)
		merged.append(current)
	crossing_corridors = merged


func _joined_corridor_points(first: PackedVector2Array, second: PackedVector2Array) -> PackedVector2Array:
	const JOIN_DISTANCE := 1.0
	if first[first.size() - 1].distance_to(second[0]) <= JOIN_DISTANCE:
		return _append_corridor(first, second)
	if first[first.size() - 1].distance_to(second[second.size() - 1]) <= JOIN_DISTANCE:
		var reversed_second := second.duplicate()
		reversed_second.reverse()
		return _append_corridor(first, reversed_second)
	if first[0].distance_to(second[second.size() - 1]) <= JOIN_DISTANCE:
		return _append_corridor(second, first)
	if first[0].distance_to(second[0]) <= JOIN_DISTANCE:
		var reversed_second := second.duplicate()
		reversed_second.reverse()
		return _append_corridor(reversed_second, first)
	return PackedVector2Array()


func _append_corridor(first: PackedVector2Array, second: PackedVector2Array) -> PackedVector2Array:
	var result := first.duplicate()
	for index in range(1, second.size()):
		result.append(second[index])
	return result


func _is_on_water_crossing(world_position: Vector2, clearance_pixels: float) -> bool:
	return not crossing_kind_at(world_position, clearance_pixels).is_empty()


func _tag_enabled(value: Variant) -> bool:
	var text := str(value).to_lower()
	return not text.is_empty() and text not in ["no", "false", "0"]


func _index_named_road_segment(segment: Dictionary) -> void:
	var margin := float(segment.half_width) + 12.0
	var low: Vector2 = segment.a.min(segment.b) - Vector2.ONE * margin
	var high: Vector2 = segment.a.max(segment.b) + Vector2.ONE * margin
	var low_cell := Vector2i(floori(low.x / 256.0), floori(low.y / 256.0))
	var high_cell := Vector2i(floori(high.x / 256.0), floori(high.y / 256.0))
	for cell_y in range(low_cell.y, high_cell.y + 1):
		for cell_x in range(low_cell.x, high_cell.x + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not named_road_cells.has(cell):
				named_road_cells[cell] = []
			named_road_cells[cell].append(segment)


func _road_label_candidate(points: PackedVector2Array, street_name: String, road_kind: String) -> Dictionary:
	var best_a := points[0]
	var best_b := points[1]
	var longest_segment := 0.0
	var total_length := 0.0
	for index in range(points.size() - 1):
		var segment_length := points[index].distance_to(points[index + 1])
		total_length += segment_length
		if segment_length > longest_segment:
			longest_segment = segment_length
			best_a = points[index]
			best_b = points[index + 1]
	var importance := 3 if road_kind in ["motorway", "trunk", "primary"] else (2 if road_kind in ["secondary", "tertiary"] else 1)
	return {"name": street_name, "a": best_a, "b": best_b, "score": total_length + importance * 10000.0, "importance": importance}


func _build_street_labels(candidates: Array) -> void:
	for child in get_children():
		if child.is_in_group("generated_street_labels"):
			child.queue_free()
	street_label_count = 0
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	var occupied_cells: Dictionary = {}
	for candidate_value in candidates:
		if street_label_count >= 4000:
			break
		var candidate: Dictionary = candidate_value
		var midpoint: Vector2 = candidate.a.lerp(candidate.b, 0.5)
		var cell := Vector2i(floori(midpoint.x / 96.0), floori(midpoint.y / 64.0))
		if occupied_cells.has(cell):
			continue
		occupied_cells[cell] = true
		var label := Label.new()
		label.add_to_group("generated_street_labels")
		label.set_meta("road_importance", int(candidate.importance))
		label.text = str(candidate.name).to_upper()
		var label_width := clampf(label.text.length() * 4.5 + 8.0, 36.0, 180.0)
		label.size = Vector2(label_width, 12.0)
		label.position = midpoint - label.size * 0.5
		label.pivot_offset = label.size * 0.5
		var label_angle: float = candidate.a.direction_to(candidate.b).angle()
		if label_angle > PI * 0.5 or label_angle < -PI * 0.5:
			label_angle += PI
		label.rotation = label_angle
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8 if int(candidate.importance) >= 2 else 7)
		label.add_theme_color_override("font_color", Color("#f3edcf"))
		label.add_theme_color_override("font_outline_color", Color("#263d31"))
		label.add_theme_constant_override("outline_size", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 1
		add_child(label)
		street_label_count += 1


func _draw_road_markings(points: PackedVector2Array, oneway: bool) -> void:
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var length := start.distance_to(finish)
		if length < 8.0:
			continue
		var direction := start.direction_to(finish)
		var offset := 4.0
		while offset < length:
			var dash_end := minf(offset + (6.0 if oneway else 5.0), length)
			draw_line(start + direction * offset, start + direction * dash_end, ROAD_LINE, 1.0, true)
			offset += 13.0 if oneway else 11.0


func _road_half_width(tags: Dictionary) -> float:
	var kind := str(tags.get("highway", ""))
	if kind in ["motorway", "trunk", "primary"]:
		return 30.0
	if kind in ["secondary", "tertiary"]:
		return 24.0
	if kind in ["footway", "path", "pedestrian", "cycleway"]:
		return 7.0
	return 18.0


func _building_style(tags: Dictionary, feature_id: String) -> String:
	var building := str(tags.get("building", "")).to_lower()
	var amenity := str(tags.get("amenity", "")).to_lower()
	var shop := str(tags.get("shop", "")).to_lower()
	var office := str(tags.get("office", "")).to_lower()
	var levels := int(tags.get("building:levels", 0))
	if levels >= 5 or building in ["apartments", "office", "hotel"]:
		return "tall"
	if amenity in ["hospital", "clinic", "doctors", "dentist", "pharmacy"] or building in ["hospital", "clinic"]:
		return "health"
	if amenity in ["school", "college", "university", "library", "townhall", "community_centre", "police", "fire_station"]:
		return "civic"
	if building in ["industrial", "warehouse", "manufacture", "hangar", "service"] or not str(tags.get("industrial", "")).is_empty():
		return "industrial"
	if building in ["commercial", "retail", "supermarket", "kiosk", "train_station"] or not shop.is_empty() or not office.is_empty():
		return "commercial"
	var residential_styles := ["brick", "weatherboard", "rendered"]
	return residential_styles[absi(hash(feature_id)) % residential_styles.size()]


func _polygon_centre(polygon: PackedVector2Array) -> Vector2:
	var centre := Vector2.ZERO
	for point in polygon:
		centre += point
	return centre / float(polygon.size())


func _points_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	return bounds


func _offset_polygon(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in polygon:
		shifted.append(point + offset)
	return shifted


func _polygon(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		result.append(_world(ProjectionScript.value_to_location(value)))
	if result.size() > 2 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


func _world(location: Vector2) -> Vector2:
	return ProjectionScript.geographic_to_world(location, projection, pixels_per_metre)


func _closed(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := polygon.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
