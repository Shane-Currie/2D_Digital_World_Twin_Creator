class_name InteriorFloorCanvas
extends Control

signal entry_spawn_requested(position_metres: Vector2)
signal storyline_location_requested(position_metres: Vector2)

const BACKGROUND := Color("#101815")
const GRID := Color("#263a32")
const FLOOR := Color("#d8d1bf")
const WALL := Color("#35463f")
const ENTRY := Color("#55d681")
const STORYLINE_LOCATION := Color("#72a7ff")

var floor_data: Dictionary = {}
var placing_entry := false
var placing_storyline_location := false
var storyline_location := Vector2.INF


func _ready() -> void:
	custom_minimum_size = Vector2(520, 420)
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	resized.connect(queue_redraw)


func set_floor(data: Dictionary) -> void:
	floor_data = data.duplicate(true)
	placing_entry = false
	placing_storyline_location = false
	storyline_location = Vector2.INF
	queue_redraw()


func begin_entry_placement() -> void:
	if floor_data.is_empty():
		return
	placing_entry = true
	placing_storyline_location = false
	queue_redraw()


func begin_storyline_location_placement() -> void:
	if floor_data.is_empty():
		return
	placing_entry = false
	placing_storyline_location = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if placing_entry and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		placing_entry = false
		entry_spawn_requested.emit(_screen_to_metres(event.position))
		accept_event()
		queue_redraw()
	elif placing_storyline_location and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		placing_storyline_location = false
		storyline_location = _screen_to_metres(event.position)
		storyline_location_requested.emit(storyline_location)
		accept_event()
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	for x in range(0, int(size.x), 32):
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID, 1.0)
	for y in range(0, int(size.y), 32):
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 1.0)
	if floor_data.is_empty():
		var message := "Create a blank ground floor to begin."
		draw_string(ThemeDB.fallback_font, Vector2(28, 48), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a8bbb2"))
		return
	var outer := _screen_points(floor_data.get("boundary_metres", []))
	if outer.size() >= 3 and not Geometry2D.triangulate_polygon(outer).is_empty():
		draw_colored_polygon(outer, FLOOR)
		draw_polyline(_closed(outer), WALL, 5.0, true)
	for hole_value in floor_data.get("holes_metres", []):
		var hole := _screen_points(hole_value)
		if hole.size() >= 3:
			draw_colored_polygon(hole, BACKGROUND)
			draw_polyline(_closed(hole), WALL, 4.0, true)
	for link_value in floor_data.get("entry_links", []):
		var link: Dictionary = link_value
		var marker := _metres_to_screen(Vector2(float(link.spawn_x_metres), float(link.spawn_y_metres)))
		draw_circle(marker, 10.0, Color("#173b29"))
		draw_circle(marker, 6.0, ENTRY)
		draw_line(marker, marker + Vector2(0, -18), ENTRY, 3.0, true)
	if storyline_location != Vector2.INF:
		var storyline_marker := _metres_to_screen(storyline_location)
		draw_circle(storyline_marker, 9.0, Color("#17304f"))
		draw_circle(storyline_marker, 5.0, STORYLINE_LOCATION)
		draw_line(storyline_marker + Vector2(-7, 0), storyline_marker + Vector2(7, 0), STORYLINE_LOCATION, 2.0)
		draw_line(storyline_marker + Vector2(0, -7), storyline_marker + Vector2(0, 7), STORYLINE_LOCATION, 2.0)
	if placing_entry:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Click inside the floor to place the selected entrance spawn.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ENTRY)
	elif placing_storyline_location:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Click inside the floor to copy a storyline NPC location.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, STORYLINE_LOCATION)


func _content_rect() -> Rect2:
	var floor_size := Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0))).max(Vector2.ONE)
	var available := (size - Vector2(64, 64)).max(Vector2(64, 64))
	var scale := minf(available.x / floor_size.x, available.y / floor_size.y)
	var drawn_size := floor_size * scale
	return Rect2((size - drawn_size) * 0.5, drawn_size)


func _metres_to_screen(point: Vector2) -> Vector2:
	var rect := _content_rect()
	var floor_size := Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0))).max(Vector2.ONE)
	return rect.position + point / floor_size * rect.size


func _screen_to_metres(point: Vector2) -> Vector2:
	var rect := _content_rect()
	var ratio := ((point - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE)
	return ratio * Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0)))


func _screen_points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		result.append(_metres_to_screen(Vector2(float(value[0]), float(value[1]))))
	return result


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
