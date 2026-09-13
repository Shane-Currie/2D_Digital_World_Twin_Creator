class_name TownMapCanvas
extends Control

## Lightweight map editor used by the import wizard.
## Longitude is stored in Vector2.x and latitude in Vector2.y.

signal cbd_changed(bounds: Dictionary)
signal start_changed(location: Dictionary)
signal start_rejected(message: String)
signal building_selected(building: Dictionary)
signal view_changed(zoom: float)

enum EditMode { INSPECT, DRAW_CBD, SET_START }

const MAP_BACKGROUND := Color("#17231f")
const MAP_GRID := Color("#263b34")
const ROAD_COLOUR := Color("#89938f")
const FOOTPATH_COLOUR := Color("#bcbcaf")
const PARKING_COLOUR := Color("#6d7778")
const PARKING_OUTLINE := Color("#c9c8ae")
const BRIDGE_COLOUR := Color("#d7d1ba")
const TUNNEL_COLOUR := Color("#46524f")
const WATER_COLOUR := Color("#397f9b")
const WATER_OUTLINE := Color("#79b7c5")
const BUILDING_COLOUR := Color("#c59462")
const BUILDING_OUTLINE := Color("#e0bd89")
const SELECTED_COLOUR := Color("#ffd166")
const CBD_COLOUR := Color("#4bc7a1")
const START_COLOUR := Color("#72a7ff")
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const LandCoverScript = preload("res://scripts/land_cover/land_cover.gd")
const LandCoverLayerScript = preload("res://scripts/land_cover/land_cover_layer.gd")
var land_cover = LandCoverLayerScript.new()
var land_cover_origin := Vector2.ZERO

var features: Array[Dictionary] = []
var geographic_bounds: Dictionary = {}
var cbd_bounds: Dictionary = {}
var start_location: Dictionary = {}
var edit_mode := EditMode.INSPECT
var selected_building_id := ""
var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var dragging := false
var panning := false
var view_zoom := 1.0
var view_center_ratio := Vector2(0.5, 0.5)
var coordinate_label: Label


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	custom_minimum_size = Vector2(600, 420)
	resized.connect(queue_redraw)
	coordinate_label = Label.new()
	coordinate_label.name = "MapCoordinates"
	coordinate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coordinate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coordinate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coordinate_label.add_theme_font_size_override("font_size", 13)
	coordinate_label.add_theme_color_override("font_color", Color("#e3eee9"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#17231feb")
	background.content_margin_left = 10
	background.content_margin_right = 10
	coordinate_label.add_theme_stylebox_override("normal", background)
	add_child(coordinate_label)
	coordinate_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	coordinate_label.offset_left = -280
	coordinate_label.offset_top = -56
	coordinate_label.offset_right = -8
	coordinate_label.offset_bottom = -8
	resized.connect(_update_coordinates)
	_update_coordinates()


func _update_coordinates() -> void:
	if not is_instance_valid(coordinate_label):
		return
	if geographic_bounds.is_empty():
		coordinate_label.text = "Latitude: —\nLongitude: —"
		return
	# Coordinates describe the visible map centre, independent of the pointer.
	var location := _screen_to_location(size * 0.5)
	coordinate_label.text = "Latitude: %.6f°\nLongitude: %.6f°" % [location.latitude, location.longitude]


func set_map_data(import_result: Dictionary) -> void:
	features = import_result.features
	geographic_bounds = import_result.bounds
	land_cover_origin = Vector2(geographic_bounds.west, geographic_bounds.south)
	var land_bounds := Rect2(Vector2.ZERO, (Vector2(geographic_bounds.east, geographic_bounds.north) - land_cover_origin) * 100000.0)
	land_cover.setup(features, _land_cover_point, land_bounds)
	cbd_bounds = {}
	start_location = {}
	selected_building_id = ""
	reset_view()
	queue_redraw()


func set_edit_mode(mode: EditMode) -> void:
	edit_mode = mode
	dragging = false
	queue_redraw()


func clear_markers() -> void:
	cbd_bounds = {}
	start_location = {}
	selected_building_id = ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if features.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.25)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 0.8)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		panning = event.pressed
		mouse_default_cursor_shape = Control.CURSOR_DRAG if panning else Control.CURSOR_CROSS
		accept_event()
		return
	if event is InputEventMouseMotion and panning:
		_pan_by(event.relative)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if edit_mode == EditMode.DRAW_CBD:
				drag_start = event.position
				drag_current = event.position
				dragging = true
			elif edit_mode == EditMode.SET_START:
				_set_start_from_screen(event.position)
			else:
				_select_building_at(event.position)
		elif edit_mode == EditMode.DRAW_CBD and dragging:
			drag_current = event.position
			dragging = false
			_set_cbd_from_drag()
	elif event is InputEventMouseMotion and dragging:
		drag_current = event.position
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), MAP_BACKGROUND)
	_draw_grid()
	if features.is_empty() or geographic_bounds.is_empty():
		_draw_empty_message()
		return

	for area in land_cover.areas:
		for piece in area.pieces:
			var polygon := PackedVector2Array()
			for point in piece:
				polygon.append(_geographic_to_screen(point / 100000.0 + land_cover_origin))
			_draw_valid_fill(polygon, LandCoverScript.colour(area.category))

	for feature in features:
		if feature.kind != "water":
			continue
		var water_polygon := _screen_polygon(feature.points)
		if water_polygon.size() >= 3:
			_draw_valid_fill(water_polygon, WATER_COLOUR)
			draw_polyline(_closed_polygon(water_polygon), WATER_OUTLINE, 1.5, true)

	for feature in features:
		if feature.kind != "parking":
			continue
		var parking_polygon := _screen_polygon(feature.points)
		if parking_polygon.size() >= 3:
			_draw_valid_fill(parking_polygon, PARKING_COLOUR)
			draw_polyline(_closed_polygon(parking_polygon), PARKING_OUTLINE, 1.0, true)

	for feature in features:
		if feature.kind != "road":
			continue
		var road_points := _screen_polygon(feature.points)
		if road_points.size() >= 2:
			var road_kind := str(feature.tags.get("highway", "")).to_lower()
			var walkway := road_kind in ["footway", "path", "pedestrian", "cycleway", "steps", "bridleway"]
			var road_colour := TUNNEL_COLOUR if _tag_enabled(feature.tags.get("tunnel", "")) else (BRIDGE_COLOUR if _tag_enabled(feature.tags.get("bridge", "")) else (FOOTPATH_COLOUR if walkway else ROAD_COLOUR))
			draw_polyline(road_points, road_colour, _road_width(feature.tags), true)

	for feature in features:
		if feature.kind != "building":
			continue
		var polygon := _screen_polygon(feature.points)
		if polygon.size() < 3:
			continue
		_draw_valid_fill(polygon, BUILDING_COLOUR)
		for hole_value in feature.get("holes", []):
			var hole_polygon := _screen_polygon(hole_value)
			if hole_polygon.size() >= 3:
				_draw_valid_fill(hole_polygon, MAP_BACKGROUND)
				draw_polyline(_closed_polygon(hole_polygon), BUILDING_OUTLINE, 1.0, true)
		var outline := BUILDING_OUTLINE
		var width := 1.0
		if str(feature.id) == selected_building_id:
			outline = SELECTED_COLOUR
			width = 3.0
		draw_polyline(_closed_polygon(polygon), outline, width, true)

	for feature in features:
		if feature.kind != "overhead_structure":
			continue
		var roof_polygon := _screen_polygon(feature.points)
		if roof_polygon.size() >= 3:
			_draw_valid_fill(roof_polygon, Color("#788582"))
			draw_polyline(_closed_polygon(roof_polygon), Color("#c8c4aa"), 1.0, true)

	if not cbd_bounds.is_empty():
		var top_left := _geographic_to_screen(Vector2(cbd_bounds.west, cbd_bounds.north))
		var bottom_right := _geographic_to_screen(Vector2(cbd_bounds.east, cbd_bounds.south))
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(CBD_COLOUR, 0.15), true)
		draw_rect(Rect2(top_left, bottom_right - top_left), CBD_COLOUR, false, 3.0)
	if dragging:
		var drag_rectangle := Rect2(drag_start, drag_current - drag_start).abs()
		draw_rect(drag_rectangle, Color(CBD_COLOUR, 0.12), true)
		draw_rect(drag_rectangle, CBD_COLOUR, false, 2.0)
	if not start_location.is_empty():
		var marker := _geographic_to_screen(Vector2(start_location.longitude, start_location.latitude))
		draw_circle(marker, 8.0, START_COLOUR)
		draw_circle(marker, 13.0, START_COLOUR, false, 3.0)
		if start_location.has("vehicle"):
			var vehicle_marker := _geographic_to_screen(Vector2(start_location.vehicle.longitude, start_location.vehicle.latitude))
			draw_rect(Rect2(vehicle_marker - Vector2(6, 10), Vector2(12, 20)), START_COLOUR, true)
			draw_line(marker, vehicle_marker, Color(START_COLOUR, 0.55), 2.0, true)


func _draw_grid() -> void:
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), MAP_GRID, 1.0)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), MAP_GRID, 1.0)


func _draw_valid_fill(polygon: PackedVector2Array, colour: Color) -> void:
	# Tiny/collapsed or invalid preview rings still get their outline. Do not
	# submit a ring Godot cannot fill, or modify the source/collision geometry.
	if not Geometry2D.triangulate_polygon(polygon).is_empty():
		draw_colored_polygon(polygon, colour)


func _draw_empty_message() -> void:
	var font := ThemeDB.fallback_font
	var message := "Your town preview will appear here after you choose and read OSM files."
	var text_size := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(font, (size - text_size) * 0.5, message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#afc5bc"))


func _land_cover_point(value: Variant) -> Vector2:
	var location: Vector2 = value if value is Vector2 else Vector2(float(value[0]), float(value[1]))
	return (location - land_cover_origin) * 100000.0


func _tag_enabled(value: Variant) -> bool:
	var text := str(value).to_lower()
	return not text.is_empty() and text not in ["no", "false", "0"]


func _screen_polygon(geographic_points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point_value in geographic_points:
		result.append(_geographic_to_screen(point_value))
	# OSM commonly repeats the first node at the end of a closed way. Godot's
	# polygon triangulator expects that duplicate to be removed before filling.
	if result.size() > 2 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _geographic_to_screen(location: Vector2) -> Vector2:
	var padding := 24.0
	var usable_size := size - Vector2.ONE * padding * 2.0
	var longitude_range: float = maxf(0.000001, geographic_bounds.east - geographic_bounds.west)
	var latitude_range: float = maxf(0.000001, geographic_bounds.north - geographic_bounds.south)
	var location_ratio := Vector2(
		(location.x - geographic_bounds.west) / longitude_range,
		(geographic_bounds.north - location.y) / latitude_range
	)
	return Vector2.ONE * padding + usable_size * 0.5 + (location_ratio - view_center_ratio) * usable_size * view_zoom


func _screen_to_geographic(screen_position: Vector2) -> Vector2:
	# Vector2 is for drawing only: it rounds geographic coordinates to float32.
	var location := _screen_to_location(screen_position)
	return Vector2(location.longitude, location.latitude)


func _screen_to_location(screen_position: Vector2) -> Dictionary:
	# Persist full-precision scalars. A float32 map-edge latitude can round just
	# outside the exact OSM bounds and make a visibly valid CBD fail validation.
	var padding := 24.0
	var usable_size := (size - Vector2.ONE * padding * 2.0).max(Vector2.ONE)
	var ratio := view_center_ratio + (screen_position - Vector2.ONE * padding - usable_size * 0.5) / (usable_size * view_zoom)
	var x_ratio := clampf(ratio.x, 0.0, 1.0)
	var y_ratio := clampf(ratio.y, 0.0, 1.0)
	return {
		"longitude": clampf(lerpf(geographic_bounds.west, geographic_bounds.east, x_ratio), geographic_bounds.west, geographic_bounds.east),
		"latitude": clampf(lerpf(geographic_bounds.north, geographic_bounds.south, y_ratio), geographic_bounds.south, geographic_bounds.north)
	}


func zoom_in() -> void:
	_zoom_at(size * 0.5, 1.25)


func zoom_out() -> void:
	_zoom_at(size * 0.5, 0.8)


func reset_view() -> void:
	view_zoom = 1.0
	view_center_ratio = Vector2(0.5, 0.5)
	_update_coordinates()
	view_changed.emit(view_zoom)
	queue_redraw()


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	if geographic_bounds.is_empty():
		return
	var padding := 24.0
	var usable_size := size - Vector2.ONE * padding * 2.0
	var location_before := _screen_to_ratio(screen_position, usable_size, padding)
	view_zoom = clampf(view_zoom * factor, 1.0, 12.0)
	view_center_ratio = location_before - (screen_position - Vector2.ONE * padding - usable_size * 0.5) / (usable_size * view_zoom)
	_clamp_view_center()
	_update_coordinates()
	view_changed.emit(view_zoom)
	queue_redraw()


func _screen_to_ratio(screen_position: Vector2, usable_size: Vector2, padding: float) -> Vector2:
	return view_center_ratio + (screen_position - Vector2.ONE * padding - usable_size * 0.5) / (usable_size * view_zoom)


func _pan_by(screen_delta: Vector2) -> void:
	var usable_size := size - Vector2.ONE * 48.0
	view_center_ratio -= screen_delta / (usable_size * view_zoom)
	_clamp_view_center()
	_update_coordinates()
	queue_redraw()


func _clamp_view_center() -> void:
	var half_view := 0.5 / view_zoom
	view_center_ratio.x = clampf(view_center_ratio.x, half_view, 1.0 - half_view)
	view_center_ratio.y = clampf(view_center_ratio.y, half_view, 1.0 - half_view)


func _set_cbd_from_drag() -> void:
	if drag_start.distance_to(drag_current) < 12.0:
		return
	var first := _screen_to_location(drag_start)
	var second := _screen_to_location(drag_current)
	var selection := {
		"west": minf(first.longitude, second.longitude),
		"south": minf(first.latitude, second.latitude),
		"east": maxf(first.longitude, second.longitude),
		"north": maxf(first.latitude, second.latitude)
	}
	if selection.west >= selection.east or selection.south >= selection.north:
		return
	cbd_bounds = selection
	cbd_changed.emit(cbd_bounds)
	queue_redraw()


func _set_start_from_screen(screen_position: Vector2) -> void:
	var location := _screen_to_location(screen_position)
	var result: Dictionary = SpawnSafetyScript.create_starting_location(
		location,
		features
	)
	if not result.ok:
		start_location = {}
		start_rejected.emit(result.message)
		queue_redraw()
		return
	start_location = result.starting_location
	start_changed.emit(start_location)
	queue_redraw()


func _select_building_at(screen_position: Vector2) -> void:
	for index in range(features.size() - 1, -1, -1):
		var feature := features[index]
		if feature.kind != "building":
			continue
		var polygon := _screen_polygon(feature.points)
		var inside_building := polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen_position, polygon)
		if inside_building:
			for hole_value in feature.get("holes", []):
				var hole_polygon := _screen_polygon(hole_value)
				if hole_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen_position, hole_polygon):
					inside_building = false
					break
		if inside_building:
			selected_building_id = str(feature.id)
			building_selected.emit(feature)
			queue_redraw()
			return
	selected_building_id = ""
	queue_redraw()


func _road_width(tags: Dictionary) -> float:
	var road_type: String = str(tags.get("highway", ""))
	if road_type in ["motorway", "trunk", "primary"]:
		return 4.0
	if road_type in ["secondary", "tertiary"]:
		return 3.0
	return 2.0
