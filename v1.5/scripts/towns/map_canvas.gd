class_name TownMapCanvas
extends Control

## Lightweight map editor used by the import wizard.
## Longitude is stored in Vector2.x and latitude in Vector2.y.

signal cbd_changed(bounds: Dictionary)
signal start_changed(location: Dictionary)
signal start_rejected(message: String)
signal vehicle_start_rejected(message: String)
signal placement_rotation_requested(change_degrees: float)
signal building_selected(building: Dictionary)
signal building_hovered(building: Dictionary, screen_position: Vector2)
signal building_door_requested(location: Dictionary)
signal override_zone_drawn(zone: Dictionary)
signal coordinates_picked(location: Dictionary)
signal view_changed(zoom: float)

enum EditMode { INSPECT, DRAW_CBD, SET_START, HIDE_BUILDING, DRAW_BLOCKED_WATER, DRAW_ALLOWED_GROUND, PLACE_BUILDING_DOOR, COPY_COORDINATES, SET_VEHICLE_START }

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
const HIDDEN_COLOUR := Color("#ef7d72")
const ALLOWED_GROUND_COLOUR := Color("#8bd39b")
const COORDINATE_PICK_COLOUR := Color("#ed77d9")
const HOVER_INDEX_DIMENSION := 64
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const LandCoverScript = preload("res://scripts/land_cover/land_cover.gd")
const LandCoverLayerScript = preload("res://scripts/land_cover/land_cover_layer.gd")
const BuildingInformationScript = preload("res://scripts/places/osm_building_information.gd")
var land_cover = LandCoverLayerScript.new()
var land_cover_origin := Vector2.ZERO

var features: Array[Dictionary] = []
var geographic_bounds: Dictionary = {}
var cbd_bounds: Dictionary = {}
var start_location: Dictionary = {}
var copied_coordinate_location: Dictionary = {}
var edit_mode := EditMode.INSPECT
var selected_building_id := ""
var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var dragging := false
var panning := false
var left_pointer_down := false
var left_dragged := false
var left_press_position := Vector2.ZERO
var rotation_pointer_down := false
var rotation_dragged := false
var view_zoom := 1.0
var view_center_ratio := Vector2(0.5, 0.5)
var coordinate_label: Label
var override_data: Dictionary = {"hidden_feature_ids": [], "zones": []}
var building_exterior_data: Dictionary = {"buildings": {}}
var building_exterior_textures: Dictionary = {}
var building_hover_cells: Dictionary = {}
var hovered_building_id := ""
var osm_hover_card: PanelContainer
var osm_hover_label: Label


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
	mouse_exited.connect(_clear_building_hover)
	_build_osm_hover_card()
	_update_coordinates()


func _build_osm_hover_card() -> void:
	osm_hover_card = PanelContainer.new()
	osm_hover_card.name = "OsmBuildingHoverCard"
	osm_hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	osm_hover_card.z_index = 100
	osm_hover_card.visible = false
	osm_hover_card.clip_contents = true
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("#101815f2")
	hover_style.border_color = CBD_COLOUR
	hover_style.set_border_width_all(2)
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	hover_style.content_margin_left = 12
	hover_style.content_margin_right = 12
	hover_style.content_margin_top = 10
	hover_style.content_margin_bottom = 10
	osm_hover_card.add_theme_stylebox_override("panel", hover_style)
	osm_hover_label = Label.new()
	osm_hover_label.name = "OsmBuildingHoverText"
	osm_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	osm_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	osm_hover_label.max_lines_visible = 18
	osm_hover_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	osm_hover_label.add_theme_font_size_override("font_size", 12)
	osm_hover_label.add_theme_color_override("font_color", Color("#edf6f1"))
	osm_hover_card.add_child(osm_hover_label)
	add_child(osm_hover_card)


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
	_clear_building_hover()
	features = import_result.features
	geographic_bounds = import_result.bounds
	land_cover_origin = Vector2(geographic_bounds.west, geographic_bounds.south)
	var land_bounds := Rect2(Vector2.ZERO, (Vector2(geographic_bounds.east, geographic_bounds.north) - land_cover_origin) * 100000.0)
	land_cover.setup(features, _land_cover_point, land_bounds)
	cbd_bounds = {}
	start_location = {}
	selected_building_id = ""
	hovered_building_id = ""
	_build_building_hover_index()
	reset_view()
	queue_redraw()


func set_edit_mode(mode: EditMode) -> void:
	edit_mode = mode
	dragging = false
	left_pointer_down = false
	rotation_pointer_down = false
	_clear_building_hover()
	queue_redraw()


func set_override_data(data: Dictionary) -> void:
	override_data = data.duplicate(true)
	queue_redraw()


func set_building_exterior_data(data: Dictionary, town_directory: String) -> void:
	building_exterior_data = data.duplicate(true)
	building_exterior_textures.clear()
	for feature_id in building_exterior_data.get("buildings", {}):
		var record: Dictionary = building_exterior_data.buildings[feature_id]
		var relative_path := str(record.get("exterior", {}).get("relative_path", ""))
		if relative_path.is_empty():
			continue
		var image := Image.load_from_file(town_directory.path_join(relative_path))
		if image != null and not image.is_empty():
			building_exterior_textures[str(feature_id)] = ImageTexture.create_from_image(image)
	queue_redraw()


func clear_markers() -> void:
	cbd_bounds = {}
	start_location = {}
	copied_coordinate_location = {}
	selected_building_id = ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if features.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if edit_mode == EditMode.SET_VEHICLE_START or not selected_building_id.is_empty():
			if event.pressed:
				rotation_pointer_down = true
				rotation_dragged = false
			else:
				if rotation_pointer_down and not rotation_dragged: _rotate_selected_placement(15.0)
				rotation_pointer_down = false
			accept_event()
			return
	if event is InputEventMouseMotion and rotation_pointer_down:
		if absf(event.relative.x) > 0.0:
			rotation_dragged = true
			_rotate_selected_placement(event.relative.x * 0.5)
		accept_event()
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
		if panning: _clear_building_hover()
		mouse_default_cursor_shape = Control.CURSOR_DRAG if panning else Control.CURSOR_CROSS
		accept_event()
		return
	if event is InputEventMouseMotion and panning:
		_pan_by(event.relative)
		accept_event()
		return
	# Drawing tools own left-drag. Other modes distinguish a click from a pan.
	if edit_mode not in [EditMode.DRAW_CBD, EditMode.DRAW_BLOCKED_WATER, EditMode.DRAW_ALLOWED_GROUND]:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				left_pointer_down = true
				left_dragged = false
				left_press_position = event.position
			else:
				if left_pointer_down and not left_dragged: _apply_map_click(event.position)
				left_pointer_down = false
				left_dragged = false
			accept_event()
			return
		if event is InputEventMouseMotion and left_pointer_down:
			if not left_dragged and event.position.distance_to(left_press_position) >= 5.0:
				left_dragged = true
				_clear_building_hover()
				_pan_by(event.position - left_press_position)
			elif left_dragged: _pan_by(event.relative)
			accept_event()
			return
	if event is InputEventMouseMotion and not dragging:
		_update_building_hover(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if edit_mode in [EditMode.DRAW_CBD, EditMode.DRAW_BLOCKED_WATER, EditMode.DRAW_ALLOWED_GROUND]:
				_clear_building_hover()
				drag_start = event.position
				drag_current = event.position
				dragging = true
			elif edit_mode == EditMode.SET_START:
				_set_start_from_screen(event.position)
			elif edit_mode == EditMode.PLACE_BUILDING_DOOR:
				building_door_requested.emit(_screen_to_location(event.position))
			elif edit_mode == EditMode.COPY_COORDINATES:
				copied_coordinate_location = _screen_to_location(event.position)
				coordinates_picked.emit(copied_coordinate_location)
				queue_redraw()
			else:
				_select_building_at(event.position)
		elif edit_mode in [EditMode.DRAW_CBD, EditMode.DRAW_BLOCKED_WATER, EditMode.DRAW_ALLOWED_GROUND] and dragging:
			drag_current = event.position
			dragging = false
			if edit_mode == EditMode.DRAW_CBD:
				_set_cbd_from_drag()
			else:
				_emit_override_zone_from_drag()
	elif event is InputEventMouseMotion and dragging:
		drag_current = event.position
		queue_redraw()


func _apply_map_click(position_value: Vector2) -> void:
	match edit_mode:
		EditMode.SET_START: _set_start_from_screen(position_value)
		EditMode.SET_VEHICLE_START:
			var result := SpawnSafetyScript.set_vehicle_start(start_location, _screen_to_location(position_value), features, geographic_bounds, float(start_location.get("vehicle", {}).get("rotation_degrees", 0.0)))
			if not result.ok: vehicle_start_rejected.emit(result.message)
			else:
				start_location = result.starting_location
				start_changed.emit(start_location)
				queue_redraw()
		EditMode.PLACE_BUILDING_DOOR: building_door_requested.emit(_screen_to_location(position_value))
		EditMode.COPY_COORDINATES:
			copied_coordinate_location = _screen_to_location(position_value)
			coordinates_picked.emit(copied_coordinate_location)
			queue_redraw()
		_: _select_building_at(position_value)


func _rotate_selected_placement(change_degrees: float) -> void:
	if edit_mode == EditMode.SET_VEHICLE_START and not start_location.is_empty():
		set_vehicle_rotation(float(start_location.get("vehicle", {}).get("rotation_degrees", 0.0)) + change_degrees)
	else: placement_rotation_requested.emit(change_degrees)


func set_vehicle_rotation(degrees: float) -> void:
	if not start_location.has("vehicle"): return
	start_location = start_location.duplicate(true)
	start_location.vehicle["rotation_degrees"] = fposmod(degrees, 360.0)
	start_changed.emit(start_location)
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
		var hidden: bool = str(feature.id) in override_data.get("hidden_feature_ids", [])
		if not hidden and building_exterior_textures.has(str(feature.id)):
			var exterior: Dictionary = building_exterior_data.get("buildings", {}).get(str(feature.id), {}).get("exterior", {})
			_draw_textured_polygon(polygon, building_exterior_textures[str(feature.id)], exterior)
		else:
			_draw_valid_fill(polygon, Color(BUILDING_COLOUR, 0.22) if hidden else BUILDING_COLOUR)
		for hole_value in feature.get("holes", []):
			var hole_polygon := _screen_polygon(hole_value)
			if hole_polygon.size() >= 3:
				_draw_valid_fill(hole_polygon, MAP_BACKGROUND)
				draw_polyline(_closed_polygon(hole_polygon), BUILDING_OUTLINE, 1.0, true)
		var outline := HIDDEN_COLOUR if hidden else BUILDING_OUTLINE
		var width := 1.0
		if str(feature.id) == selected_building_id:
			outline = SELECTED_COLOUR
			width = 3.0
		draw_polyline(_closed_polygon(polygon), outline, width, true)
		if hidden:
			var bounds := _polygon_bounds(polygon)
			draw_line(bounds.position, bounds.end, HIDDEN_COLOUR, 1.5, true)
			draw_line(Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.position.x, bounds.end.y), HIDDEN_COLOUR, 1.5, true)

	for feature in features:
		if feature.kind != "overhead_structure":
			continue
		var roof_polygon := _screen_polygon(feature.points)
		if roof_polygon.size() >= 3:
			_draw_valid_fill(roof_polygon, Color("#788582"))
			draw_polyline(_closed_polygon(roof_polygon), Color("#c8c4aa"), 1.0, true)

	for zone_value in override_data.get("zones", []):
		var zone: Dictionary = zone_value
		var zone_polygon := _screen_polygon(zone.get("points", []))
		if zone_polygon.size() < 3:
			continue
		var colour := WATER_COLOUR if str(zone.get("mode", "")) == "blocked_water" else ALLOWED_GROUND_COLOUR
		_draw_valid_fill(zone_polygon, Color(colour, 0.36))
		draw_polyline(_closed_polygon(zone_polygon), colour, 2.5, true)

	for feature_id in building_exterior_data.get("buildings", {}):
		var record: Dictionary = building_exterior_data.buildings[feature_id]
		var doors: Array = record.get("doors", [record.door] if record.has("door") else [])
		for door_value in doors:
			var door: Dictionary = door_value
			var door_point := _geographic_to_screen(Vector2(float(door.longitude), float(door.latitude)))
			var outside_point := _geographic_to_screen(Vector2(float(door.outside_longitude), float(door.outside_latitude)))
			var direction := outside_point.direction_to(door_point)
			var normal := Vector2(-direction.y, direction.x)
			draw_line(door_point - normal * 5.0, door_point + normal * 5.0, Color("#6b3f27"), 3.0, true)
			var arrow := PackedVector2Array([door_point, outside_point + normal * 5.0, outside_point - normal * 5.0])
			draw_colored_polygon(arrow, Color("#55d681"))
			draw_polyline(_closed_polygon(arrow), Color("#173b29"), 1.2, true)

	if not cbd_bounds.is_empty():
		var top_left := _geographic_to_screen(Vector2(cbd_bounds.west, cbd_bounds.north))
		var bottom_right := _geographic_to_screen(Vector2(cbd_bounds.east, cbd_bounds.south))
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(CBD_COLOUR, 0.15), true)
		draw_rect(Rect2(top_left, bottom_right - top_left), CBD_COLOUR, false, 3.0)
	if dragging:
		var drag_rectangle := Rect2(drag_start, drag_current - drag_start).abs()
		var drag_colour := CBD_COLOUR
		if edit_mode == EditMode.DRAW_BLOCKED_WATER:
			drag_colour = WATER_OUTLINE
		elif edit_mode == EditMode.DRAW_ALLOWED_GROUND:
			drag_colour = ALLOWED_GROUND_COLOUR
		draw_rect(drag_rectangle, Color(drag_colour, 0.18), true)
		draw_rect(drag_rectangle, drag_colour, false, 2.0)
	if not start_location.is_empty():
		var marker := _geographic_to_screen(Vector2(start_location.longitude, start_location.latitude))
		draw_circle(marker, 8.0, START_COLOUR)
		draw_circle(marker, 13.0, START_COLOUR, false, 3.0)
		if start_location.has("vehicle"):
			var vehicle_marker := _geographic_to_screen(Vector2(start_location.vehicle.longitude, start_location.vehicle.latitude))
			var angle := deg_to_rad(float(start_location.vehicle.get("rotation_degrees", 0.0)))
			var car_outline := PackedVector2Array()
			for corner in [Vector2(-6, -10), Vector2(6, -10), Vector2(6, 10), Vector2(-6, 10)]: car_outline.append(vehicle_marker + corner.rotated(angle))
			draw_colored_polygon(car_outline, START_COLOUR)
			var tip := vehicle_marker + Vector2.UP.rotated(angle) * 24.0
			draw_line(vehicle_marker, tip, Color("#ffffff"), 3.0, true)
			draw_line(tip, tip + Vector2(-5, 7).rotated(angle), Color("#ffffff"), 2.0, true)
			draw_line(tip, tip + Vector2(5, 7).rotated(angle), Color("#ffffff"), 2.0, true)
			draw_line(marker, vehicle_marker, Color(START_COLOUR, 0.55), 2.0, true)
	_draw_custom_names()
	if not copied_coordinate_location.is_empty():
		var coordinate_marker := _geographic_to_screen(Vector2(float(copied_coordinate_location.longitude), float(copied_coordinate_location.latitude)))
		draw_circle(coordinate_marker, 10.0, Color(COORDINATE_PICK_COLOUR, 0.25), true)
		draw_circle(coordinate_marker, 10.0, COORDINATE_PICK_COLOUR, false, 2.0)
		draw_line(coordinate_marker - Vector2(15, 0), coordinate_marker + Vector2(15, 0), COORDINATE_PICK_COLOUR, 2.0, true)
		draw_line(coordinate_marker - Vector2(0, 15), coordinate_marker + Vector2(0, 15), COORDINATE_PICK_COLOUR, 2.0, true)


func _draw_grid() -> void:
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), MAP_GRID, 1.0)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), MAP_GRID, 1.0)


func _draw_custom_names() -> void:
	var occupied_labels: Array[Rect2] = []
	for feature in features:
		var name_value := str(building_exterior_data.get("buildings", {}).get(str(feature.get("id", "")), {}).get("custom_name", ""))
		if name_value.is_empty() or str(feature.id) in override_data.get("hidden_feature_ids", []): continue
		var polygon := _screen_polygon(feature.get("points", []))
		if polygon.size() < 3: continue
		var centre := _polygon_bounds(polygon).get_center()
		var text_size := ThemeDB.fallback_font.get_string_size(name_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var box := Rect2(centre - text_size * 0.5, text_size).grow(4.0)
		if not Rect2(Vector2.ZERO, size).encloses(box) or occupied_labels.any(func(other): return other.intersects(box)): continue
		occupied_labels.append(box)
		draw_rect(box, Color("#10251fee"))
		draw_string(ThemeDB.fallback_font, centre + Vector2(-text_size.x * 0.5, 4.0), name_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#fff4cb"))


func _draw_valid_fill(polygon: PackedVector2Array, colour: Color) -> void:
	# Tiny/collapsed or invalid preview rings still get their outline. Do not
	# submit a ring Godot cannot fill, or modify the source/collision geometry.
	if not Geometry2D.triangulate_polygon(polygon).is_empty():
		draw_colored_polygon(polygon, colour)


func _draw_textured_polygon(polygon: PackedVector2Array, texture: Texture2D, exterior: Dictionary = {}) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return
	var bounds := _polygon_bounds(polygon)
	var safe_size := bounds.size.max(Vector2.ONE)
	for index in range(0, indices.size(), 3):
		var triangle := PackedVector2Array()
		var uvs := PackedVector2Array()
		for offset in 3:
			var point := polygon[indices[index + offset]]
			triangle.append(point)
			uvs.append(_aligned_exterior_uv((point - bounds.position) / safe_size, exterior))
		draw_primitive(triangle, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]), uvs, texture)


func _aligned_exterior_uv(uv: Vector2, exterior: Dictionary) -> Vector2:
	var scale := maxf(0.5, float(exterior.get("scale_percent", 100.0)) / 100.0)
	var offset := Vector2(float(exterior.get("offset_x_percent", 0.0)), float(exterior.get("offset_y_percent", 0.0))) / 100.0
	var centred := uv - Vector2(0.5, 0.5) - offset
	centred = centred.rotated(-deg_to_rad(float(exterior.get("rotation_degrees", 0.0)))) / scale
	return centred + Vector2(0.5, 0.5)


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
		var point: Vector2 = point_value if point_value is Vector2 else Vector2(float(point_value[0]), float(point_value[1]))
		result.append(_geographic_to_screen(point))
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
	_clear_building_hover()
	_update_coordinates()
	view_changed.emit(view_zoom)
	queue_redraw()


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	if geographic_bounds.is_empty():
		return
	_clear_building_hover()
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
	_clear_building_hover()
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


func _emit_override_zone_from_drag() -> void:
	if drag_start.distance_to(drag_current) < 12.0:
		return
	var first := _screen_to_location(drag_start)
	var second := _screen_to_location(drag_current)
	var west: float = minf(first.longitude, second.longitude)
	var east: float = maxf(first.longitude, second.longitude)
	var south: float = minf(first.latitude, second.latitude)
	var north: float = maxf(first.latitude, second.latitude)
	if west >= east or south >= north:
		return
	override_zone_drawn.emit({
		"mode": "blocked_water" if edit_mode == EditMode.DRAW_BLOCKED_WATER else "allowed_ground",
		"points": [[west, south], [east, south], [east, north], [west, north], [west, south]],
		"applies_to": ["player", "vehicle", "npc", "npr"],
		"source": "creator_authored"
	})


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
	var feature := _building_at_screen(screen_position)
	if not feature.is_empty():
		selected_building_id = str(feature.id)
		building_selected.emit(feature)
		queue_redraw()
		return
	selected_building_id = ""
	queue_redraw()


func _update_building_hover(screen_position: Vector2) -> void:
	var feature := _building_at_screen(screen_position)
	hovered_building_id = str(feature.get("id", ""))
	_show_osm_building_hover(feature, screen_position)
	building_hovered.emit(feature, screen_position)


func _clear_building_hover() -> void:
	var had_hover := not hovered_building_id.is_empty() or (is_instance_valid(osm_hover_card) and osm_hover_card.visible)
	hovered_building_id = ""
	if is_instance_valid(osm_hover_card): osm_hover_card.visible = false
	if had_hover: building_hovered.emit({}, Vector2.ZERO)


func _show_osm_building_hover(building: Dictionary, screen_position: Vector2) -> void:
	if not is_instance_valid(osm_hover_card) or not is_instance_valid(osm_hover_label): return
	if building.is_empty():
		osm_hover_card.visible = false
		return
	var record := BuildingInformationScript.describe_feature(building)
	var lines := BuildingInformationScript.editor_hover_lines(record)
	var custom_name := str(building_exterior_data.get("buildings", {}).get(str(building.get("id", "")), {}).get("custom_name", ""))
	if not custom_name.is_empty(): lines.push_front("Creator name: %s" % custom_name)
	var available_width := maxf(180.0, size.x - 16.0)
	var card_width := minf(390.0, available_width)
	var available_height := maxf(100.0, size.y - 16.0)
	osm_hover_card.custom_minimum_size = Vector2.ZERO
	osm_hover_label.custom_minimum_size.x = maxf(150.0, card_width - 28.0)
	osm_hover_label.max_lines_visible = maxi(3, floori((available_height - 20.0) / 21.0))
	osm_hover_label.text = "\n".join(PackedStringArray(lines))
	var wrapped_text_height := osm_hover_label.get_minimum_size().y + 20.0
	var card_height := minf(maxf(120.0, wrapped_text_height), available_height)
	var card_size := Vector2(card_width, card_height)
	osm_hover_card.custom_minimum_size = card_size
	var desired := screen_position + Vector2(18.0, 18.0)
	if desired.x + card_size.x > size.x - 8.0: desired.x = screen_position.x - card_size.x - 18.0
	if desired.y + card_size.y > size.y - 8.0: desired.y = screen_position.y - card_size.y - 18.0
	desired.x = clampf(desired.x, 8.0, maxf(8.0, size.x - card_size.x - 8.0))
	desired.y = clampf(desired.y, 8.0, maxf(8.0, size.y - card_size.y - 8.0))
	osm_hover_card.position = desired
	osm_hover_card.size = card_size
	osm_hover_card.visible = true


func _building_at_screen(screen_position: Vector2) -> Dictionary:
	if geographic_bounds.is_empty(): return {}
	var location := _screen_to_location(screen_position)
	var cell := _hover_cell_for_location(Vector2(float(location.longitude), float(location.latitude)))
	var candidates: Array = building_hover_cells.get("%d:%d" % [cell.x, cell.y], [])
	for candidate_position in range(candidates.size() - 1, -1, -1):
		var feature_index := int(candidates[candidate_position])
		if feature_index < 0 or feature_index >= features.size(): continue
		var feature: Dictionary = features[feature_index]
		var polygon := _screen_polygon(feature.get("points", []))
		var inside_building := polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen_position, polygon)
		if inside_building:
			for hole_value in feature.get("holes", []):
				var hole_polygon := _screen_polygon(hole_value)
				if hole_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen_position, hole_polygon):
					inside_building = false
					break
		if inside_building: return feature
	return {}


func _build_building_hover_index() -> void:
	building_hover_cells.clear()
	if geographic_bounds.is_empty(): return
	for feature_index in features.size():
		var feature: Dictionary = features[feature_index]
		if str(feature.get("kind", "")) != "building": continue
		var points: Array = feature.get("points", [])
		if points.size() < 3: continue
		var first_point: Vector2 = points[0] if points[0] is Vector2 else Vector2(float(points[0][0]), float(points[0][1]))
		var minimum := first_point
		var maximum := first_point
		for point_value in points:
			var point: Vector2 = point_value if point_value is Vector2 else Vector2(float(point_value[0]), float(point_value[1]))
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		var first_cell := _hover_cell_for_location(minimum)
		var last_cell := _hover_cell_for_location(maximum)
		for cell_y in range(mini(first_cell.y, last_cell.y), maxi(first_cell.y, last_cell.y) + 1):
			for cell_x in range(mini(first_cell.x, last_cell.x), maxi(first_cell.x, last_cell.x) + 1):
				var key := "%d:%d" % [cell_x, cell_y]
				if not building_hover_cells.has(key): building_hover_cells[key] = []
				building_hover_cells[key].append(feature_index)


func _hover_cell_for_location(location: Vector2) -> Vector2i:
	var longitude_range := maxf(0.000001, float(geographic_bounds.east) - float(geographic_bounds.west))
	var latitude_range := maxf(0.000001, float(geographic_bounds.north) - float(geographic_bounds.south))
	return Vector2i(
		clampi(floori((location.x - float(geographic_bounds.west)) / longitude_range * HOVER_INDEX_DIMENSION), 0, HOVER_INDEX_DIMENSION - 1),
		clampi(floori((location.y - float(geographic_bounds.south)) / latitude_range * HOVER_INDEX_DIMENSION), 0, HOVER_INDEX_DIMENSION - 1)
	)


func _road_width(tags: Dictionary) -> float:
	var road_type: String = str(tags.get("highway", ""))
	if road_type in ["motorway", "trunk", "primary"]:
		return 4.0
	if road_type in ["secondary", "tertiary"]:
		return 3.0
	return 2.0


func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds
