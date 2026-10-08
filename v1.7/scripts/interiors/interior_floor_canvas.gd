class_name InteriorFloorCanvas
extends Control

signal entry_spawn_requested(position_metres: Vector2)
signal storyline_location_requested(position_metres: Vector2)
signal furniture_position_requested(position_metres: Vector2)
signal furniture_rotation_requested(furniture_id: String, change_degrees: float)
signal furniture_selected(furniture_id: String)
signal furniture_move_requested(furniture_id: String, position_metres: Vector2, duplicate: bool)
signal furniture_resize_requested(furniture_id: String, position_metres: Vector2, dimensions_metres: Vector2)
signal npc_move_requested(npc_id: String, position_metres: Vector2)
signal npc_selected(npc_id: String)
signal wall_door_selected(wall_id: String, door_id: String)
signal wall_door_move_requested(wall_id: String, door_id: String, position_metres: Vector2)
signal wall_requested(start_metres: Vector2, end_metres: Vector2)
signal wall_move_requested(wall_id: String, start_metres: Vector2, end_metres: Vector2)
signal wall_selected(wall_id: String)
signal wall_door_requested(wall_id: String, position_metres: Vector2)
signal room_label_requested(position_metres: Vector2)
signal floor_paint_requested(points_metres: Array, fill_room: bool)
signal view_changed(zoom: float)
signal stair_point_requested(position_metres: Vector2)
signal stair_move_requested(stair_id: String, side: String, position_metres: Vector2)
signal stair_selected(stair_id: String)
signal stair_cancelled
signal stair_rotation_requested(stair_id: String, side: String, change_degrees: float)
signal connection_point_requested(position_metres: Vector2)
signal connection_move_requested(connection_id: String, position_metres: Vector2)
signal connection_selected(connection_id: String)
signal seat_direction_requested(item_id: String, degrees: float)
const SeatOrientation = preload("res://scripts/npcs/creation/seat_orientation.gd")
var seat_direction_edit_enabled := false
var seat_direction_gesture: Dictionary = {}

const BACKGROUND := Color("#101815")
const InteriorFurnitureCatalogScript = preload("res://scripts/interiors/interior_furniture_catalog.gd")
const NpcPoseArt = preload("res://scripts/npcs/creation/npc_pose_art.gd")
var npc_creation_data: Dictionary = {"creations":[]}
var npc_artwork_directory := ""
const GRID := Color("#263a32")
const FLOOR := Color("#d8d1bf")
const WALL := Color("#35463f")
const ENTRY := Color("#55d681")
const LOCKED_DOOR := Color("#e45b55")
const STORYLINE_LOCATION := Color("#72a7ff")
const WallStoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const SNAP_PIXELS := 18.0
const WALL_PICK_PIXELS := 12.0
const DRAG_THRESHOLD_PIXELS := 5.0

var floor_data: Dictionary = {}
var placing_entry := false
## Optional focused entry editor used by Building Creator. Other tools retain
## their existing controls, so furniture/wall drags cannot move arrival points.
var entry_drag_enabled := false
var entry_drag_id := ""
var entry_pointer_down := false
var entry_preview := Vector2.INF
var placing_storyline_location := false
var placing_furniture := false
var placing_wall := false
var wall_start := Vector2.INF
var placing_wall_door := false
var selected_wall_id := ""
var placing_room_label := false
var painting_floor := false
var floor_paint_dragging := false
var floor_paint_preview: Array[Vector2] = []
var storyline_location := Vector2.INF
var view_zoom := 1.0
var view_center_ratio := Vector2(0.5, 0.5)
var panning := false
var left_pan_down := false
var left_pan_dragged := false
var left_pan_start := Vector2.ZERO
var right_rotation_down := false
var right_rotation_dragged := false
var selected_furniture_id := ""
var furniture_preview: Dictionary = {}
var asset_root := ""
var custom_textures: Dictionary = {}
var floor_material_definitions: Dictionary = {}
var floor_material_textures: Dictionary = {}
var current_view_key := ""
var wall_store = WallStoreScript.new()
var pointer_position := Vector2.ZERO
var wall_pointer_down := false
var wall_press_position := Vector2.ZERO
var drawing_drag := false
var dragged_wall_id := ""
var dragged_endpoint := -1
var drag_original_start := Vector2.ZERO
var drag_original_finish := Vector2.ZERO
var preview_start := Vector2.INF
var preview_finish := Vector2.INF
var snap_hint: Dictionary = {}
var preview_validation: Callable
var preview_valid := true
var last_edit_ok := true
var invalid_position := Vector2.INF
var selected_door_id := ""
var repeat_furniture_id := ""
var object_drag_kind := ""
var object_drag_id := ""
var object_drag_wall := ""
var object_drag_original: Dictionary = {}
var object_drag_offset := Vector2.ZERO
var object_resize_corner := -1
var object_resize_offset := Vector2.ZERO
const RESIZE_SIGNS := [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
const RESIZE_PICK_PIXELS := 10.0
var object_press := Vector2.ZERO
var object_moving := false
var object_preview: Dictionary = {}
var interior_npcs: Array = []
var selected_npc_id := ""
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const Stairs = preload("res://scripts/interiors/stairs/interior_stairs.gd")
var stair_endpoints: Array = []
var stair_edit_enabled := false
var placing_stair := false
var stair_drag: Dictionary = {}
var stair_preview := Vector2.INF
var stair_selected_id := ""
var stair_validation: Callable
var stair_rotation_degrees := 0.0
## Keep held rotation as a preview so one release creates one undoable edit.
var stair_rotation_gesture: Dictionary = {}
const Connections = preload("res://scripts/interiors/connections/building_connections.gd")
var connection_endpoints: Array = []
var connection_edit_enabled := false
var placing_connection := false
var connection_drag: Dictionary = {}
var connection_preview := Vector2.INF
var connection_selected_id := ""
var connection_validation: Callable


func set_connections(data: Dictionary, building_id: String, floor_id: String, enabled: bool) -> void:
	connection_endpoints = Connections.endpoints(data, building_id, floor_id)
	if not floor_data.is_empty(): floor_data["_connection_arrivals"] = connection_endpoints.duplicate(true)
	connection_edit_enabled = enabled
	placing_connection = false
	connection_drag.clear()
	connection_preview = Vector2.INF
	queue_redraw()


func _handle_connection_input(event: InputEvent) -> bool:
	if not connection_edit_enabled or floor_data.is_empty(): return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		placing_connection = false; connection_drag.clear(); connection_preview = Vector2.INF
		queue_redraw()
		return true
	if event is InputEventMouseMotion and (placing_connection or not connection_drag.is_empty()):
		connection_preview = _object_metres(event.position)
		preview_valid = bool(connection_validation.call(connection_preview, str(connection_drag.get("id", "")))) if connection_validation.is_valid() else true
		queue_redraw()
		return true
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return false
	if event.pressed:
		if placing_connection:
			connection_point_requested.emit(_object_metres(event.position))
			return true
		for endpoint in connection_endpoints:
			if minf(event.position.distance_to(_metres_to_screen(Connections.position(endpoint))), event.position.distance_to(_metres_to_screen(Connections.wall_position(endpoint)))) > 18: continue
			connection_drag = endpoint.duplicate(true)
			connection_selected_id = str(endpoint.id)
			connection_selected.emit(connection_selected_id)
			connection_preview = Connections.wall_position(endpoint)
			queue_redraw()
			return true
	elif not connection_drag.is_empty():
		var id := str(connection_drag.id)
		connection_drag.clear(); connection_preview = Vector2.INF
		connection_move_requested.emit(id, _object_metres(event.position))
		return true
	return false


func set_stairs(record: Dictionary, floor_id: String, enabled: bool) -> void:
	stair_endpoints = Stairs.endpoints(record, floor_id)
	if not floor_data.is_empty(): floor_data["_stair_endpoints"] = stair_endpoints.duplicate(true)
	stair_edit_enabled = enabled
	placing_stair = false
	stair_drag.clear()
	stair_rotation_gesture.clear()
	stair_preview = Vector2.INF
	queue_redraw()


func _handle_stair_input(event: InputEvent) -> bool:
	if not stair_edit_enabled or floor_data.is_empty(): return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_begin_stair_rotation(event.position)
		elif not stair_rotation_gesture.is_empty():
			var gesture := stair_rotation_gesture.duplicate(true)
			stair_rotation_gesture.clear()
			if not placing_stair: stair_preview = Vector2.INF
			var change: float = float(gesture.rotation_degrees) - float(gesture.start_angle) if gesture.dragged else 90.0
			stair_rotation_requested.emit(str(gesture.id), str(gesture.side), change)
			queue_redraw()
		return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		placing_stair = false
		stair_drag.clear()
		stair_rotation_gesture.clear()
		stair_preview = Vector2.INF
		stair_cancelled.emit()
		queue_redraw()
		return true
	if not stair_rotation_gesture.is_empty():
		if event is InputEventMouseMotion:
			if not is_zero_approx(event.relative.x):
				stair_rotation_gesture.dragged = true
				stair_rotation_gesture.rotation_degrees = wrapf(float(stair_rotation_gesture.rotation_degrees) + event.relative.x, 0, 360)
			preview_valid = bool(stair_validation.call(stair_preview, str(stair_rotation_gesture.id), float(stair_rotation_gesture.rotation_degrees))) if stair_validation.is_valid() else true
			queue_redraw()
		# Do not mix movement, placement or zoom with an unfinished rotation.
		return true
	if event is InputEventMouseMotion and (placing_stair or not stair_drag.is_empty()):
		stair_preview = _object_metres(event.position)
		preview_valid = bool(stair_validation.call(stair_preview, str(stair_drag.get("id", "")), float(stair_drag.get("rotation_degrees", stair_rotation_degrees)))) if stair_validation.is_valid() else true
		queue_redraw()
		return true
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return false
	if event.pressed:
		if placing_stair:
			stair_point_requested.emit(_object_metres(event.position))
			return true
		for endpoint in stair_endpoints:
			var point := Stairs.position(endpoint)
			if Geometry2D.is_point_in_polygon(_object_metres(event.position), Stairs.rectangle(point, Stairs.ART_SIZE, Stairs.rotation(endpoint))):
				stair_drag = endpoint.duplicate(true)
				stair_selected_id = str(endpoint.id)
				stair_rotation_degrees = Stairs.rotation(endpoint)
				stair_selected.emit(stair_selected_id)
				stair_preview = point
				preview_valid = true
				queue_redraw()
				return true
	elif not stair_drag.is_empty():
		var dragged := stair_drag.duplicate(true)
		stair_drag.clear()
		stair_preview = Vector2.INF
		stair_move_requested.emit(str(dragged.id), str(dragged.side), _object_metres(event.position))
		return true
	return false


func _begin_stair_rotation(screen_position: Vector2) -> void:
	if not stair_drag.is_empty(): return
	var endpoint: Dictionary = {}
	if not placing_stair:
		for candidate in stair_endpoints:
			if str(candidate.id) == stair_selected_id: endpoint = candidate
		for candidate in stair_endpoints:
			if Geometry2D.is_point_in_polygon(_object_metres(screen_position), Stairs.rectangle(Stairs.position(candidate), Stairs.ART_SIZE, Stairs.rotation(candidate))):
				endpoint = candidate
				break
		if endpoint.is_empty(): return
		stair_selected_id = str(endpoint.id)
		stair_rotation_degrees = Stairs.rotation(endpoint)
		stair_preview = Stairs.position(endpoint)
		stair_selected.emit(stair_selected_id)
	elif stair_preview == Vector2.INF:
		stair_preview = _object_metres(screen_position)
	stair_rotation_gesture = {"id":str(endpoint.get("id", "")), "side":str(endpoint.get("side", "")), "start_angle":stair_rotation_degrees, "rotation_degrees":stair_rotation_degrees, "up":bool(endpoint.get("up", true)), "dragged":false}
	preview_valid = bool(stair_validation.call(stair_preview, str(stair_rotation_gesture.id), stair_rotation_degrees)) if stair_validation.is_valid() else true
	grab_focus()
	queue_redraw()


func cancel_selection() -> void:
	seat_direction_gesture.clear()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_handle_object_input(escape)
	placing_stair = false
	placing_connection = false
	stair_drag.clear()
	stair_rotation_gesture.clear()
	connection_drag.clear()
	stair_preview = Vector2.INF
	connection_preview = Vector2.INF
	stair_selected_id = ""
	connection_selected_id = ""
	selected_furniture_id = ""
	selected_npc_id = ""
	selected_door_id = ""
	selected_wall_id = ""
	repeat_furniture_id = ""
	object_drag_kind = ""
	object_preview.clear()
	left_pan_down = false
	panning = false
	invalid_position = Vector2.INF
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(280, 180)
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)


func set_floor(data: Dictionary, view_key := "") -> void:
	var should_reset_view := current_view_key != view_key or floor_data.is_empty()
	floor_data = data.duplicate(true)
	seat_direction_gesture.clear()
	stair_rotation_gesture.clear()
	current_view_key = view_key
	left_pan_down = false
	right_rotation_down = false
	if should_reset_view:
		selected_npc_id = ""
		selected_furniture_id = ""
		selected_door_id = ""
		repeat_furniture_id = ""
		object_drag_kind = ""
		object_preview.clear()
		invalid_position = Vector2.INF
	placing_entry = false
	placing_storyline_location = false
	placing_furniture = false
	placing_wall = false
	wall_start = Vector2.INF
	placing_wall_door = false
	placing_room_label = false
	painting_floor = false
	floor_paint_dragging = false
	floor_paint_preview.clear()
	storyline_location = Vector2.INF
	_cancel_wall_drag()
	if should_reset_view:
		reset_view()
	queue_redraw()


func set_asset_root(path_value: String) -> void:
	asset_root = path_value
	custom_textures.clear()
	queue_redraw()


func set_floor_materials(definitions: Array) -> void:
	floor_material_definitions.clear()
	floor_material_textures.clear()
	for definition_value in definitions:
		if not definition_value is Dictionary: continue
		var definition: Dictionary = definition_value
		var material_id := str(definition.get("id", ""))
		floor_material_definitions[material_id] = definition.duplicate(true)
		var path_value := str(definition.get("image_path", "")).replace("\\", "/")
		var texture: Texture2D
		if path_value.begins_with("res://"):
			if ResourceLoader.exists(path_value):
				var loaded = load(path_value)
				if loaded is Texture2D: texture = loaded
			if texture == null:
				var built_in_image := Image.new()
				if built_in_image.load(ProjectSettings.globalize_path(path_value)) == OK and not built_in_image.is_empty(): texture = ImageTexture.create_from_image(built_in_image)
		elif not path_value.is_empty() and not path_value.contains("..") and not path_value.is_absolute_path() and not asset_root.is_empty():
			var image := Image.new()
			if image.load(asset_root.path_join(path_value)) == OK and not image.is_empty(): texture = ImageTexture.create_from_image(image)
		if texture != null: floor_material_textures[material_id] = texture
	queue_redraw()


func update_floor_data(data: Dictionary) -> void:
	# Painting updates only the floor data. Preserve zoom, pan and the active
	# paint tool so creators can lay several strokes without reopening it.
	floor_data = data.duplicate(true)
	queue_redraw()


func zoom_in() -> void:
	_zoom_at(size * 0.5, 1.25)


func zoom_out() -> void:
	_zoom_at(size * 0.5, 0.8)


func reset_view() -> void:
	view_zoom = 1.0
	view_center_ratio = Vector2(0.5, 0.5)
	view_changed.emit(view_zoom)
	queue_redraw()


func begin_entry_placement() -> void:
	_clear_object_preview()
	if floor_data.is_empty():
		return
	placing_entry = true
	placing_storyline_location = false
	placing_furniture = false
	placing_wall = false
	placing_wall_door = false
	placing_room_label = false
	painting_floor = false
	queue_redraw()


func begin_storyline_location_placement() -> void:
	_clear_object_preview()
	if floor_data.is_empty():
		return
	placing_entry = false
	placing_storyline_location = true
	placing_furniture = false
	placing_wall = false
	placing_wall_door = false
	placing_room_label = false
	painting_floor = false
	queue_redraw()


func begin_furniture_placement() -> void:
	_clear_object_preview()
	if floor_data.is_empty():
		return
	placing_entry = false
	placing_storyline_location = false
	placing_furniture = true
	repeat_furniture_id = ""
	placing_wall = false
	placing_wall_door = false
	placing_room_label = false
	painting_floor = false
	queue_redraw()


func begin_wall_placement() -> void:
	_clear_object_preview()
	if floor_data.is_empty(): return
	placing_entry = false
	placing_storyline_location = false
	placing_furniture = false
	placing_wall = true
	wall_start = Vector2.INF
	placing_wall_door = false
	placing_room_label = false
	painting_floor = false
	_cancel_wall_drag()
	queue_redraw()


func begin_wall_editing() -> void:
	_clear_object_preview()
	placing_entry = false
	placing_storyline_location = false
	placing_furniture = false
	placing_wall = false
	wall_start = Vector2.INF
	placing_wall_door = false
	placing_room_label = false
	painting_floor = false
	_cancel_wall_drag()
	queue_redraw()


func select_wall(wall_id: String) -> void:
	selected_wall_id = wall_id
	queue_redraw()


func wall_snap_distance() -> float:
	var pixels_in_metres := SNAP_PIXELS * float(floor_data.get("width_metres", 1.0)) / maxf(_content_rect().size.x * view_zoom, 0.001)
	return clampf(pixels_in_metres, 0.12, 2.0)


func _snap_pointer(screen_position: Vector2, ignored_wall := "") -> Dictionary:
	var point := _screen_to_metres(screen_position)
	# Slight hand jitter should still produce a straight horizontal/vertical
	# wall. A real wall connection always has priority over this alignment.
	var snapped := wall_store.snap_wall_endpoint(point, floor_data, ignored_wall, wall_snap_distance())
	var anchor := wall_start if placing_wall else drag_original_finish if dragged_endpoint == 0 else drag_original_start
	if not bool(snapped.snapped) and anchor != Vector2.INF:
		var anchor_screen := _metres_to_screen(anchor)
		if absf(screen_position.x - anchor_screen.x) <= 9.0: point.x = anchor.x
		elif absf(screen_position.y - anchor_screen.y) <= 9.0: point.y = anchor.y
		snapped = wall_store.snap_wall_endpoint(point, floor_data, ignored_wall, wall_snap_distance())
	return snapped


func _cancel_wall_drag() -> void:
	wall_pointer_down = false
	drawing_drag = false
	dragged_wall_id = ""
	preview_start = Vector2.INF
	preview_finish = Vector2.INF
	snap_hint = {}


func _wall_at_pointer(screen_position: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := WALL_PICK_PIXELS
	# Prefer a selected endpoint where joined walls have overlapping handles.
	var walls: Array = floor_data.get("walls", []).duplicate()
	walls.sort_custom(func(a, b): return str(a.get("id", "")) == selected_wall_id and str(b.get("id", "")) != selected_wall_id)
	for wall in walls:
		var start := Vector2(float(wall.start_x_metres), float(wall.start_y_metres))
		var finish := Vector2(float(wall.end_x_metres), float(wall.end_y_metres))
		for index in 2:
			var endpoint: Vector2 = start if index == 0 else finish
			var distance := screen_position.distance_to(_metres_to_screen(endpoint))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = {"id": str(wall.id), "endpoint": index, "start": start, "finish": finish}
	if not nearest.is_empty(): return nearest
	for wall in walls:
		var start := Vector2(float(wall.start_x_metres), float(wall.start_y_metres))
		var finish := Vector2(float(wall.end_x_metres), float(wall.end_y_metres))
		var projection := wall_store._projection_on_segment(screen_position, _metres_to_screen(start), _metres_to_screen(finish))
		if float(projection.distance) < nearest_distance:
			nearest_distance = float(projection.distance)
			nearest = {"id": str(wall.id), "endpoint": -1, "start": start, "finish": finish}
	return nearest


func _update_wall_preview(screen_position: Vector2) -> void:
	if not dragged_wall_id.is_empty():
		if dragged_endpoint >= 0:
			snap_hint = _snap_pointer(screen_position, dragged_wall_id)
			preview_start = Vector2(snap_hint.position) if dragged_endpoint == 0 else drag_original_start
			preview_finish = Vector2(snap_hint.position) if dragged_endpoint == 1 else drag_original_finish
		else:
			var movement := _screen_to_metres(screen_position) - _screen_to_metres(wall_press_position)
			var start_snap := wall_store.snap_wall_endpoint(drag_original_start + movement, floor_data, dragged_wall_id, wall_snap_distance())
			var finish_snap := wall_store.snap_wall_endpoint(drag_original_finish + movement, floor_data, dragged_wall_id, wall_snap_distance())
			# A whole-wall drag keeps its length and angle: use one endpoint's snap
			# correction for both ends instead of independently distorting the wall.
			snap_hint = start_snap if bool(start_snap.snapped) else finish_snap
			var anchor := drag_original_start if bool(start_snap.snapped) else drag_original_finish
			var correction := Vector2(snap_hint.position) - (anchor + movement)
			preview_start = drag_original_start + movement + correction
			preview_finish = drag_original_finish + movement + correction
	elif placing_wall:
		snap_hint = _snap_pointer(screen_position)
		preview_start = wall_start
		preview_finish = Vector2(snap_hint.position)
	queue_redraw()


func _handle_wall_input(event: InputEvent) -> bool:
	var other_tool := placing_entry or placing_storyline_location or placing_furniture or placing_wall_door or placing_room_label or painting_floor
	if other_tool or floor_data.is_empty(): return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		placing_wall = false
		wall_start = Vector2.INF
		_cancel_wall_drag()
		queue_redraw()
		return true
	if event is InputEventMouseMotion:
		pointer_position = event.position
		queue_redraw()
		if wall_pointer_down and event.position.distance_to(wall_press_position) >= DRAG_THRESHOLD_PIXELS:
			drawing_drag = true
		_update_wall_preview(event.position)
		return placing_wall or not dragged_wall_id.is_empty()
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return false
	pointer_position = event.position
	if event.pressed:
		wall_press_position = event.position
		wall_pointer_down = true
		drawing_drag = false
		if placing_wall:
			if wall_start == Vector2.INF:
				wall_start = Vector2(_snap_pointer(event.position).position)
			else:
				var finish := Vector2(_snap_pointer(event.position).position)
				var start := wall_start
				wall_start = Vector2.INF
				_cancel_wall_drag()
				wall_requested.emit(start, finish)
			_update_wall_preview(event.position)
			return true
		var hit := _wall_at_pointer(event.position)
		if hit.is_empty():
			wall_pointer_down = false
			return false
		dragged_wall_id = str(hit.id)
		dragged_endpoint = int(hit.endpoint)
		drag_original_start = Vector2(hit.start)
		drag_original_finish = Vector2(hit.finish)
		select_wall(dragged_wall_id)
		wall_selected.emit(dragged_wall_id)
		_update_wall_preview(event.position)
		return true
	if not wall_pointer_down: return false
	_update_wall_preview(event.position)
	var was_drag: bool = drawing_drag or event.position.distance_to(wall_press_position) >= DRAG_THRESHOLD_PIXELS
	if not dragged_wall_id.is_empty():
		var wall_id := dragged_wall_id
		var start := preview_start
		var finish := preview_finish
		_cancel_wall_drag()
		if was_drag: wall_move_requested.emit(wall_id, start, finish)
	elif placing_wall and was_drag:
		var start := wall_start
		var finish := preview_finish
		wall_start = Vector2.INF
		_cancel_wall_drag()
		wall_requested.emit(start, finish)
	else:
		wall_pointer_down = false
	queue_redraw()
	return true


func begin_wall_door_placement(wall_id: String) -> void:
	_clear_object_preview()
	if floor_data.is_empty() or wall_id.is_empty(): return
	placing_entry = false
	placing_storyline_location = false
	placing_furniture = false
	placing_wall = false
	placing_wall_door = true
	selected_wall_id = wall_id
	placing_room_label = false
	painting_floor = false
	queue_redraw()


func begin_room_label_placement() -> void:
	_clear_object_preview()
	if floor_data.is_empty(): return
	placing_entry = false
	placing_storyline_location = false
	placing_furniture = false
	placing_wall = false
	placing_wall_door = false
	placing_room_label = true
	painting_floor = false
	queue_redraw()


func begin_floor_painting() -> void:
	_clear_object_preview()
	if floor_data.is_empty(): return
	placing_entry = false
	placing_storyline_location = false
	placing_furniture = false
	placing_wall = false
	placing_wall_door = false
	placing_room_label = false
	painting_floor = true
	floor_paint_dragging = false
	floor_paint_preview.clear()
	_cancel_wall_drag()
	queue_redraw()


func _handle_floor_paint_input(event: InputEvent) -> bool:
	if not painting_floor: return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		painting_floor = false
		floor_paint_dragging = false
		floor_paint_preview.clear()
		queue_redraw()
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var point := _screen_to_metres(event.position)
			if event.shift_pressed:
				floor_paint_requested.emit([point], true)
				return true
			floor_paint_dragging = true
			floor_paint_preview = [point]
			queue_redraw()
			return true
		if floor_paint_dragging:
			floor_paint_dragging = false
			if not floor_paint_preview.is_empty(): floor_paint_requested.emit(floor_paint_preview.duplicate(), false)
			floor_paint_preview.clear()
			queue_redraw()
			return true
	if event is InputEventMouseMotion and floor_paint_dragging:
		var point := _screen_to_metres(event.position)
		if floor_paint_preview.is_empty() or point.distance_to(floor_paint_preview[-1]) >= 0.18:
			floor_paint_preview.append(point)
			queue_redraw()
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if _handle_seat_input(event): accept_event(); return
	if _handle_connection_input(event): accept_event(); return
	if _handle_stair_input(event): accept_event(); return
	if _handle_entry_drag(event): accept_event(); return
	if event is InputEventMouseMotion:
		pointer_position = event.position
		if placing_furniture or placing_wall_door:
			_update_object_preview()
			queue_redraw()
	if not entry_drag_enabled and _handle_object_input(event):
		accept_event()
		return
	# Finish or cancel the corner gesture before changing rotation/zoom/tools.
	if object_drag_kind=="furniture_resize": accept_event(); return
	var rotate_tool := placing_furniture or (not selected_furniture_id.is_empty() and not (placing_wall or painting_floor or placing_wall_door or placing_room_label or placing_entry or placing_storyline_location))
	if rotate_tool and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			right_rotation_down = true
			right_rotation_dragged = false
		else:
			if right_rotation_down and not right_rotation_dragged: _request_furniture_rotation(45.0)
			right_rotation_down = false
		accept_event()
		return
	if event is InputEventMouseMotion and right_rotation_down:
		if absf(event.relative.x) > 0.0:
			right_rotation_dragged = true
			_request_furniture_rotation(event.relative.x)
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
		mouse_default_cursor_shape = Control.CURSOR_DRAG if panning else Control.CURSOR_CROSS
		accept_event()
		return
	if event is InputEventMouseMotion and panning:
		_pan_by(event.relative)
		accept_event()
		return
	if _handle_floor_paint_input(event):
		accept_event()
		return
	if _handle_wall_input(event):
		accept_event()
		return
	var active_tool := placing_entry or placing_storyline_location or placing_furniture or placing_wall or placing_wall_door or placing_room_label or painting_floor
	if not active_tool:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				left_pan_down = true
				left_pan_dragged = false
				left_pan_start = event.position
			else:
				if left_pan_down and not left_pan_dragged:
					selected_furniture_id = _furniture_at_pointer(event.position)
					furniture_selected.emit(selected_furniture_id)
				left_pan_down = false
			accept_event()
			queue_redraw()
			return
		if event is InputEventMouseMotion and left_pan_down:
			if not left_pan_dragged and event.position.distance_to(left_pan_start) >= 5.0:
				left_pan_dragged = true
				_pan_by(event.position - left_pan_start)
			elif left_pan_dragged: _pan_by(event.relative)
			accept_event()
			return
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
	elif placing_furniture and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer_position = event.position
		_update_object_preview()
		last_edit_ok = true
		var keep_placing: bool = event.shift_pressed
		var source_id := repeat_furniture_id
		if not source_id.is_empty(): furniture_move_requested.emit(source_id, _object_metres(event.position), true)
		else: furniture_position_requested.emit(_object_metres(event.position))
		placing_furniture = keep_placing or not last_edit_ok
		repeat_furniture_id = source_id if placing_furniture else ""
		if placing_furniture: _update_object_preview()
		accept_event()
		queue_redraw()
	elif placing_wall_door and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer_position = event.position
		_update_object_preview()
		last_edit_ok = true
		wall_door_requested.emit(selected_wall_id, _object_metres(event.position))
		placing_wall_door = not last_edit_ok
		accept_event()
		queue_redraw()
	elif placing_room_label and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		placing_room_label = false
		room_label_requested.emit(_screen_to_metres(event.position))
		accept_event()
		queue_redraw()


func _handle_entry_drag(event: InputEvent) -> bool:
	if not entry_drag_enabled or floor_data.is_empty(): return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			var selected := false
			for link in floor_data.get("entry_links",[]):
				if str(link.exterior_entrance_id)!=entry_drag_id: continue
				var point := _metres_to_screen(Vector2(link.spawn_x_metres,link.spawn_y_metres))
				selected=point.distance_to(event.position)<22
			entry_pointer_down=selected or placing_entry
			if not entry_pointer_down: return false
			entry_preview=_object_metres(event.position)
		elif entry_pointer_down:
			entry_pointer_down=false
			entry_preview=Vector2.INF
			placing_entry=false
			entry_spawn_requested.emit(_object_metres(event.position))
		else: return false
		queue_redraw()
		return true
	if event is InputEventMouseMotion and entry_pointer_down:
		entry_preview=_object_metres(event.position)
		queue_redraw()
		return true
	return false


func _request_furniture_rotation(change: float) -> void:
	if placing_furniture and not repeat_furniture_id.is_empty():
		furniture_preview.rotation_degrees = fposmod(float(furniture_preview.get("rotation_degrees", 0.0)) + change, 360.0)
		_update_object_preview()
		queue_redraw()
		return
	furniture_rotation_requested.emit("" if placing_furniture else selected_furniture_id, change)
	if placing_furniture: _update_object_preview()
	queue_redraw()


func set_edit_feedback(ok: bool, position_metres: Vector2) -> void:
	last_edit_ok = ok
	preview_valid = ok
	invalid_position = Vector2.INF if ok else position_metres
	queue_redraw()


func _clear_object_preview() -> void:
	object_drag_kind = ""
	object_preview.clear()
	invalid_position = Vector2.INF
	preview_valid = true
	repeat_furniture_id = ""


func _object_metres(screen_position: Vector2) -> Vector2:
	# Do not clamp object positions: a pointer outside the floor must show X,
	# not silently relocate the creator's item to a different position.
	var rect := _content_rect()
	return (view_center_ratio + (screen_position - rect.get_center()) / (rect.size * view_zoom)) * Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0)))


func _door_at_pointer(screen_position: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 13.0
	for wall in floor_data.get("walls", []):
		var start := Vector2(float(wall.start_x_metres), float(wall.start_y_metres))
		var finish := Vector2(float(wall.end_x_metres), float(wall.end_y_metres))
		for door in wall.get("doors", []):
			var centre := start + start.direction_to(finish) * float(door.offset_metres)
			var gap := screen_position.distance_to(_metres_to_screen(centre))
			if gap < distance:
				distance = gap
				nearest = {"id": str(door.id), "wall_id": str(wall.id), "position": centre, "door": door.duplicate(true)}
	return nearest


func _handle_object_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		placing_furniture = false
		placing_wall_door = false
		placing_wall = false
		placing_entry = false
		placing_storyline_location = false
		placing_room_label = false
		painting_floor = false
		floor_paint_dragging = false
		floor_paint_preview.clear()
		wall_start = Vector2.INF
		_cancel_wall_drag()
		_clear_object_preview()
		queue_redraw()
		return true
	var other_tool := placing_wall or painting_floor or placing_entry or placing_storyline_location or placing_room_label
	if floor_data.is_empty() or other_tool: return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT and not selected_furniture_id.is_empty() and object_drag_kind.is_empty():
		for item in floor_data.get("furniture", []):
			if str(item.id) == selected_furniture_id:
				furniture_preview = item.duplicate(true)
				repeat_furniture_id = selected_furniture_id
				placing_furniture = true
				placing_wall_door = false
				_update_object_preview()
				queue_redraw()
		return true
	if placing_furniture or placing_wall_door: return false
	if event is InputEventMouseMotion and object_drag_kind.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if not _resize_handle_at(event.position).is_empty() else Control.CURSOR_CROSS
	if event is InputEventMouseMotion and not object_drag_kind.is_empty():
		object_moving = object_moving or event.position.distance_to(object_press) >= DRAG_THRESHOLD_PIXELS
		if object_moving: _update_object_preview()
		queue_redraw()
		return true
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return false
	if event.pressed:
		invalid_position = Vector2.INF
		object_preview.clear()
		var handle := _resize_handle_at(event.position)
		if not handle.is_empty():
			grab_focus()
			object_press=event.position
			object_moving=false
			object_drag_kind="furniture_resize"
			object_drag_original=handle.item.duplicate(true)
			object_drag_id=str(handle.item.id)
			object_resize_corner=int(handle.corner)
			object_resize_offset=Vector2(handle.position)-_object_metres(event.position)
			_update_object_preview(); queue_redraw()
			return true
		var door := _door_at_pointer(event.position)
		var furniture_id := _furniture_at_pointer(event.position)
		var npc := _npc_at_pointer(event.position)
		if door.is_empty() and furniture_id.is_empty() and npc.is_empty(): return false
		grab_focus()
		object_press = event.position
		object_moving = false
		object_drag_offset = Vector2.ZERO
		selected_npc_id = ""
		if not npc.is_empty():
			object_drag_kind = "npc"
			object_drag_id = str(npc.id)
			selected_npc_id = object_drag_id
			selected_furniture_id = ""
			selected_door_id = ""
			object_drag_original = npc.duplicate(true)
			object_drag_offset = Vector2(float(npc.location.x_metres), float(npc.location.y_metres)) - _object_metres(event.position)
			npc_selected.emit(object_drag_id)
		elif not door.is_empty():
			object_drag_kind = "door"
			object_drag_wall = str(door.wall_id)
			object_drag_id = str(door.id)
			selected_door_id = object_drag_id
			selected_wall_id = object_drag_wall
			selected_furniture_id = ""
			object_drag_original = door.door
			wall_door_selected.emit(object_drag_wall, object_drag_id)
		else:
			object_drag_kind = "furniture"
			object_drag_id = furniture_id
			selected_furniture_id = furniture_id
			selected_door_id = ""
			for item in floor_data.get("furniture", []):
				if str(item.id) == furniture_id: object_drag_original = item.duplicate(true)
			object_drag_offset = Vector2(float(object_drag_original.x_metres), float(object_drag_original.y_metres)) - _object_metres(event.position)
			furniture_selected.emit(furniture_id)
		queue_redraw()
		return true
	if object_drag_kind.is_empty(): return false
	pointer_position = event.position
	var kind := object_drag_kind
	var id := object_drag_id
	var wall_id := object_drag_wall
	var moved: bool = object_moving or event.position.distance_to(object_press) >= DRAG_THRESHOLD_PIXELS
	var position_metres := _object_metres(event.position) + object_drag_offset
	if moved:
		_update_object_preview()
		last_edit_ok = true
		if kind == "furniture_resize":
			furniture_resize_requested.emit(id,Vector2(object_preview.x_metres,object_preview.y_metres),Vector2(object_preview.width_metres,object_preview.depth_metres))
		elif kind == "furniture": furniture_move_requested.emit(id, position_metres, event.shift_pressed)
		elif kind == "npc": npc_move_requested.emit(id, position_metres)
		else: wall_door_move_requested.emit(wall_id, id, position_metres)
	object_drag_kind = ""
	object_moving = false
	if last_edit_ok: object_preview.clear()
	queue_redraw()
	return true


func _update_object_preview() -> void:
	var point := _object_metres(pointer_position) + (object_drag_offset if object_drag_kind in ["furniture", "npc"] else Vector2.ZERO)
	var kind := object_drag_kind if not object_drag_kind.is_empty() else "furniture" if placing_furniture else "door"
	var candidate := object_drag_original.duplicate(true) if not object_drag_kind.is_empty() else furniture_preview.duplicate(true) if placing_furniture else {}
	if kind == "furniture_resize":
		candidate = _resize_candidate(pointer_position)
		point = Vector2(candidate.x_metres,candidate.y_metres)
		kind = "furniture"
	if kind == "furniture":
		candidate.x_metres = snappedf(point.x, 0.01)
		candidate.y_metres = snappedf(point.y, 0.01)
	elif kind == "npc":
		candidate.location.x_metres = snappedf(point.x, 0.01)
		candidate.location.y_metres = snappedf(point.y, 0.01)
	var ignored_id := object_drag_id if object_drag_kind in ["furniture","furniture_resize"] else ""
	var result: Dictionary = preview_validation.call(kind, point, candidate, object_drag_wall if not object_drag_kind.is_empty() else selected_wall_id, object_drag_id if not object_drag_kind.is_empty() else "", ignored_id) if preview_validation.is_valid() else {"ok": true}
	preview_valid = bool(result.ok)
	invalid_position = Vector2.INF if preview_valid else point
	object_preview = candidate if kind in ["furniture", "npc"] else result.get("preview", {"position": point})
	object_preview["preview_kind"] = kind


func _furniture_at_pointer(position_value: Vector2) -> String:
	var point := _screen_to_metres(position_value)
	for item in floor_data.get("furniture", []):
		var centre := Vector2(float(item.x_metres), float(item.y_metres))
		var local := (point - centre).rotated(-deg_to_rad(float(item.get("rotation_degrees", 0.0))))
		if absf(local.x) <= float(item.width_metres) * 0.5 and absf(local.y) <= float(item.depth_metres) * 0.5: return str(item.id)
	return ""


func _furniture_corners(item: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var centre := Vector2(float(item.x_metres),float(item.y_metres))
	var half := Vector2(float(item.width_metres),float(item.depth_metres))*0.5
	var angle := deg_to_rad(float(item.get("rotation_degrees",0)))
	for sign_value in RESIZE_SIGNS: points.append(centre+(half*sign_value).rotated(angle))
	return points


func _resize_handle_at(screen_position: Vector2) -> Dictionary:
	if selected_furniture_id.is_empty() or entry_drag_enabled or placing_stair or placing_connection: return {}
	var nearest: Dictionary = {}
	var distance := RESIZE_PICK_PIXELS
	for item in floor_data.get("furniture", []):
		if str(item.id)!=selected_furniture_id: continue
		var corners := _furniture_corners(item)
		for i in corners.size():
			var gap := screen_position.distance_to(_metres_to_screen(corners[i]))
			if gap <= distance: nearest={"item":item,"corner":i,"position":corners[i]}; distance=gap
	return nearest


func _resize_candidate(screen_position: Vector2) -> Dictionary:
	var item := object_drag_original.duplicate(true)
	var angle := deg_to_rad(float(item.get("rotation_degrees",0)))
	var sign_value: Vector2 = RESIZE_SIGNS[object_resize_corner]
	var anchor := _furniture_corners(item)[(object_resize_corner+2)%4]
	var delta := (_object_metres(screen_position)+object_resize_offset-anchor).rotated(-angle)
	# Do not flip the object when a dragged corner crosses its opposite.
	# A red preview is retained until the creator returns to a valid size.
	var dimensions := (delta*sign_value).max(Vector2.ONE*0.01)
	var centre := anchor+(dimensions*sign_value*0.5).rotated(angle)
	item.x_metres=centre.x; item.y_metres=centre.y
	item.width_metres=dimensions.x; item.depth_metres=dimensions.y
	return item


func _draw_resize_handles() -> void:
	if entry_drag_enabled or placing_furniture or placing_wall or painting_floor or placing_wall_door or placing_room_label or placing_entry or placing_storyline_location or placing_stair or placing_connection: return
	for value in floor_data.get("furniture", []):
		if str(value.id)!=selected_furniture_id: continue
		var item: Dictionary = object_preview if object_drag_kind=="furniture_resize" and not object_preview.is_empty() else value
		var outline := PackedVector2Array()
		for corner in _furniture_corners(item): outline.append(_metres_to_screen(corner))
		var colour := ENTRY if object_drag_kind!="furniture_resize" or preview_valid else LOCKED_DOOR
		draw_polyline(_closed(outline),colour,2.0,true)
		for point in outline:
			draw_rect(Rect2(point-Vector2.ONE*6,Vector2.ONE*12),Color("#11251f"))
			draw_rect(Rect2(point-Vector2.ONE*4,Vector2.ONE*8),colour)
		var dimensions := "%.2f × %.2f m" % [item.width_metres,item.depth_metres]
		var label_position := outline[0]+Vector2(8,-10)
		var label_width := ThemeDB.fallback_font.get_string_size(dimensions,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		label_position.x=clampf(label_position.x,8,maxf(8,size.x-label_width-8))
		label_position.y=clampf(label_position.y,18,maxf(18,size.y-8))
		draw_string(ThemeDB.fallback_font,label_position,dimensions,HORIZONTAL_ALIGNMENT_LEFT,-1,13,colour)
		return


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if floor_data.is_empty():
		var message := "Create a blank ground floor to begin."
		draw_string(ThemeDB.fallback_font, Vector2(28, 48), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a8bbb2"))
		return
	_draw_metre_grid()
	var outer := _screen_points(floor_data.get("boundary_metres", []))
	if outer.size() >= 3 and not Geometry2D.triangulate_polygon(outer).is_empty():
		draw_colored_polygon(outer, FLOOR)
		draw_polyline(_closed(outer), WALL, 5.0, true)
	_draw_flooring()
	for hole_value in floor_data.get("holes_metres", []):
		var hole := _screen_points(hole_value)
		if hole.size() >= 3:
			draw_colored_polygon(hole, BACKGROUND)
			draw_polyline(_closed(hole), WALL, 4.0, true)
	for room_value in floor_data.get("rooms", []):
		_draw_room_label(room_value)
	for wall_value in floor_data.get("walls", []):
		_draw_internal_wall(wall_value)
	for furniture_value in floor_data.get("furniture", []):
		_draw_furniture(furniture_value)
		if str(furniture_value.get("id", "")) == selected_furniture_id:
			draw_circle(_metres_to_screen(Vector2(float(furniture_value.x_metres), float(furniture_value.y_metres))), 12.0, ENTRY, false, 2.0, true)
	_draw_interior_npcs()
	if not object_preview.is_empty():
		if str(object_preview.get("preview_kind", "")) == "furniture": _draw_furniture(object_preview)
		elif str(object_preview.get("preview_kind", "")) == "npc": _draw_interior_npc(object_preview)
		else:
			var door_centre := _metres_to_screen(Vector2(object_preview.get("position", Vector2.ZERO)))
			var direction: Vector2 = object_preview.get("direction", Vector2.RIGHT)
			var half_width := float(object_preview.get("width_metres", 0.9)) * 0.5
			draw_line(_metres_to_screen(Vector2(object_preview.get("position", Vector2.ZERO)) - direction * half_width), _metres_to_screen(Vector2(object_preview.get("position", Vector2.ZERO)) + direction * half_width), ENTRY if preview_valid else LOCKED_DOOR, 6.0, true)
			draw_circle(door_centre, 10.0, ENTRY if preview_valid else LOCKED_DOOR, false, 2.0, true)
	if invalid_position != Vector2.INF:
		var cross := _metres_to_screen(invalid_position)
		draw_circle(cross, 13.0, Color("#251915"))
		for slope in [-1.0, 1.0]:
			var diagonal := Vector2(8, 8 * slope)
			draw_line(cross - diagonal, cross + diagonal, LOCKED_DOOR, 4.0, true)
	_draw_resize_handles()
	_draw_seat_arrows()
	for wall in floor_data.get("walls", []):
		if str(wall.id) != selected_wall_id: continue
		var start := Vector2(float(wall.start_x_metres), float(wall.start_y_metres))
		var finish := Vector2(float(wall.end_x_metres), float(wall.end_y_metres))
		for door in wall.get("doors", []):
			if str(door.id) == selected_door_id: draw_circle(_metres_to_screen(start + start.direction_to(finish) * float(door.offset_metres)), 12.0, Color("#72a7ff"), false, 2.0, true)
	for link_value in floor_data.get("entry_links", []):
		var link: Dictionary = link_value
		var marker := _metres_to_screen(Vector2(float(link.spawn_x_metres), float(link.spawn_y_metres)))
		draw_circle(marker, 10.0, Color("#173b29"))
		draw_circle(marker, 6.0, ENTRY)
		draw_line(marker, marker + Vector2(0, -18), ENTRY, 3.0, true)
		if entry_drag_enabled and str(link.exterior_entrance_id)==entry_drag_id:
			draw_circle(marker,16,Color("#72a7ff"),false,2,true)
	if entry_preview!=Vector2.INF:
		draw_circle(_metres_to_screen(entry_preview),13,ENTRY,false,3,true)
	_draw_wall_edit_overlay()
	var stair_scale := _metres_to_screen(Vector2.ONE).x - _metres_to_screen(Vector2.ZERO).x
	for endpoint in connection_endpoints:
		Connections.draw_door(self, endpoint, _metres_to_screen(Connections.wall_position(endpoint)), _metres_to_screen(Connections.position(endpoint)), stair_scale, str(endpoint.id) == connection_selected_id)
		if connection_edit_enabled:
			var label_point := _metres_to_screen(Connections.position(endpoint)) + Vector2(-160, -16)
			label_point.x = clampf(label_point.x, 10, maxf(10, size.x - 240))
			draw_string(ThemeDB.fallback_font, label_point, "To: " + str(endpoint.destination_name), HORIZONTAL_ALIGNMENT_LEFT, 240, 14, Color("#263a32"))
	if connection_edit_enabled and connection_preview != Vector2.INF:
		var marker := _metres_to_screen(connection_preview)
		draw_circle(marker, 12, ENTRY if preview_valid else LOCKED_DOOR, false, 3, true)
		if not preview_valid:
			draw_line(marker - Vector2(10,10), marker + Vector2(10,10), LOCKED_DOOR, 4)
			draw_line(marker + Vector2(-10,10), marker + Vector2(10,-10), LOCKED_DOOR, 4)
	for endpoint in stair_endpoints:
		if not stair_rotation_gesture.is_empty() and str(endpoint.id) == str(stair_rotation_gesture.id) and str(endpoint.side) == str(stair_rotation_gesture.side): continue
		Stairs.draw_platform(self, _metres_to_screen(Stairs.position(endpoint)), stair_scale, bool(endpoint.get("up", true)), str(endpoint.id) == stair_selected_id, Stairs.rotation(endpoint))
		if stair_edit_enabled and stair_scale >= 14.0:
			draw_string(ThemeDB.fallback_font, _metres_to_screen(Stairs.position(endpoint)) + Vector2(Stairs.ART_SIZE.x * stair_scale * 0.5 + 8, -5), "%s → %s" % ["Up" if bool(endpoint.get("up", true)) else "Down", str(endpoint.get("destination_name", "Floor"))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#33443e"))
	if stair_edit_enabled and stair_preview != Vector2.INF:
		var preview_centre := _metres_to_screen(stair_preview)
		var preview_endpoint: Dictionary = stair_rotation_gesture if not stair_rotation_gesture.is_empty() else stair_drag
		Stairs.draw_platform(self, preview_centre, stair_scale, bool(preview_endpoint.get("up", true)), true, float(preview_endpoint.get("rotation_degrees", stair_rotation_degrees)))
		if not stair_rotation_gesture.is_empty():
			draw_string(ThemeDB.fallback_font, preview_centre + Vector2(20, -20), "%.0f°" % float(stair_rotation_gesture.rotation_degrees), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ENTRY if preview_valid else LOCKED_DOOR)

		if not preview_valid:
			draw_line(preview_centre - Vector2(12, 12), preview_centre + Vector2(12, 12), LOCKED_DOOR, 4.0)
			draw_line(preview_centre + Vector2(-12, 12), preview_centre + Vector2(12, -12), LOCKED_DOOR, 4.0)
	if storyline_location != Vector2.INF:
		var storyline_marker := _metres_to_screen(storyline_location)
		draw_circle(storyline_marker, 9.0, Color("#17304f"))
		draw_circle(storyline_marker, 5.0, STORYLINE_LOCATION)
		draw_line(storyline_marker + Vector2(-7, 0), storyline_marker + Vector2(7, 0), STORYLINE_LOCATION, 2.0)
		draw_line(storyline_marker + Vector2(0, -7), storyline_marker + Vector2(0, 7), STORYLINE_LOCATION, 2.0)
	if placing_entry:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Click / drag to place arrival · green ring = selected doorway." if entry_drag_enabled else "Click inside the floor to place the selected entrance spawn.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ENTRY)
	elif placing_storyline_location:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Click inside the floor to copy a storyline NPC location.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, STORYLINE_LOCATION)
	elif placing_furniture:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Click to place · hold Shift for more copies · red X = blocked · Esc cancels.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#efc56c"))
	elif placing_wall:
		var message := "Drag to finish, or click the end. Right-click cancels." if wall_start != Vector2.INF else "Drag to draw a wall, or click both ends. Green ring = snapped joint."
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0b86a"))
	elif placing_wall_door:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Click any visible internal wall where its doorway should open.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ENTRY)
	elif placing_room_label:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Click inside the room to place its name.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#91bfe8"))
	elif painting_floor:
		for point in floor_paint_preview:
			draw_circle(_metres_to_screen(point), 9.0, Color(0.30, 0.86, 0.65, 0.34))
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Hold left mouse and drag to paint · Shift-click fills this room · right-click finishes.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ENTRY)
	elif stair_edit_enabled:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Hold right mouse + drag to rotate · right-click turns 90° · left-drag moves · Esc cancels.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a8bbb2"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 22), "Select item → drag corners to resize · body to move · Shift copies · empty floor pans.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a8bbb2"))


func set_interior_npcs(npcs: Array, building_id: String, floor_id: String) -> void:
	interior_npcs.clear()
	for npc in npcs:
		var location: Dictionary = npc.get("location", {})
		if str(location.get("space", "")) == "interior" and str(location.get("building_id", "")) == building_id and str(location.get("floor_id", "")) == floor_id:
			interior_npcs.append(npc.duplicate(true))
	queue_redraw()


func _draw_interior_npcs() -> void:
	for npc in interior_npcs:
		if object_moving and object_drag_kind == "npc" and str(npc.id) == object_drag_id: continue
		_draw_interior_npc(npc)


func _npc_draw_size(npc: Dictionary = {}) -> Vector2:
	var pixels_per_metre := _content_rect().size.x * view_zoom / maxf(float(floor_data.get("width_metres", 1.0)), 0.001)
	# Match the existing runtime robot's 18x25 drawing box and 0.625 scale.
	if str(npc.get("npc_role", "")) == "npr": return Vector2(18,25) * 0.625 / 8.0 * pixels_per_metre
	return ActorArt.GROUND_CHARACTER_DRAW_SIZE / 8.0 * pixels_per_metre


func _npc_at_pointer(point: Vector2) -> Dictionary:
	for index in range(interior_npcs.size() - 1, -1, -1):
		var npc: Dictionary = interior_npcs[index]
		var draw_size := _npc_draw_size(npc)
		var feet := _metres_to_screen(Vector2(float(npc.location.x_metres), float(npc.location.y_metres)))
		if Rect2(feet - Vector2(draw_size.x * 0.5, draw_size.y), draw_size).grow(5.0).has_point(point): return npc
	return {}


func _draw_interior_npc(npc: Dictionary) -> void:
	var location: Dictionary = npc.location
	var feet := _metres_to_screen(Vector2(float(location.x_metres), float(location.y_metres)))
	var draw_size := _npc_draw_size(npc)
	draw_circle(feet, maxf(4.0, draw_size.x * 0.5), Color("#efc56c") if str(npc.id) == selected_npc_id else STORYLINE_LOCATION, false, 2.0, true)
	if str(npc.get("npc_role",""))=="npr":
		var sprite: Dictionary = ActorArt.directional_sprite("npr",Vector2.DOWN)
		if not sprite.is_empty(): draw_texture_rect_region(sprite.texture,Rect2(feet-Vector2(draw_size.x*.5,draw_size.y),draw_size),sprite.region)
	else:
		NpcPoseArt.draw_actor(self,npc.get("appearance",{}),npc_creation_data,npc_artwork_directory,feet,Vector2.DOWN,"idle",0,draw_size.y/ActorArt.GROUND_CHARACTER_DRAW_SIZE.y)
	if str(npc.id) != selected_npc_id and _npc_at_pointer(get_local_mouse_position()).get("id", "") != npc.id: return
	var name := str(npc.get("display_name", "NPC")).replace("\n", " ").left(48)
	var width := ThemeDB.fallback_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_rect(Rect2(feet + Vector2(-width * 0.5 - 4, 5), Vector2(width + 8, 18)), Color("#172e29"))
	draw_string(ThemeDB.fallback_font, feet + Vector2(-width * 0.5, 18), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f5f0e6"))


func _seat_arrow_tip(item: Dictionary, degrees: float) -> Vector2:
	return _metres_to_screen(SeatOrientation.position(item))+Vector2.DOWN.rotated(deg_to_rad(degrees))*48

func _handle_seat_input(event: InputEvent) -> bool:
	if not seat_direction_edit_enabled: return false
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		seat_direction_gesture.clear(); queue_redraw(); return true
	if event is InputEventMouseMotion and not seat_direction_gesture.is_empty():
		var centre := _metres_to_screen(SeatOrientation.position(seat_direction_gesture.item))
		if centre.distance_to(event.position)>6: seat_direction_gesture.degrees=fposmod(rad_to_deg(Vector2.DOWN.angle_to(event.position-centre)),360)
		queue_redraw(); return true
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return false
	if not event.pressed and not seat_direction_gesture.is_empty():
		var gesture := seat_direction_gesture.duplicate(true); seat_direction_gesture.clear()
		seat_direction_requested.emit(str(gesture.item.id),float(gesture.degrees)); queue_redraw(); return true
	if not event.pressed: return false
	for item in floor_data.get("furniture",[]):
		if not SeatOrientation.supported(item): continue
		if event.position.distance_to(_seat_arrow_tip(item,SeatOrientation.angle(item)))<14:
			selected_furniture_id=str(item.id); furniture_selected.emit(selected_furniture_id)
			seat_direction_gesture={"item":item.duplicate(true),"degrees":SeatOrientation.angle(item)}; grab_focus(); return true
	var id := _furniture_at_pointer(event.position)
	for item in floor_data.get("furniture",[]):
		if str(item.id)==id and SeatOrientation.supported(item):
			selected_furniture_id=id; furniture_selected.emit(id); queue_redraw(); return true
	return false

func _draw_seat_arrows() -> void:
	if not seat_direction_edit_enabled: return
	for item in floor_data.get("furniture",[]):
		if not SeatOrientation.supported(item): continue
		var degrees := float(seat_direction_gesture.degrees) if not seat_direction_gesture.is_empty() and str(seat_direction_gesture.item.id)==str(item.id) else SeatOrientation.angle(item)
		var centre := _metres_to_screen(SeatOrientation.position(item))
		var tip := _seat_arrow_tip(item,degrees)
		var direction := centre.direction_to(tip)
		var colour := Color("#72a7ff") if str(item.id)==selected_furniture_id else Color("#80978e")
		draw_line(centre,tip,colour,3,true)
		draw_colored_polygon(PackedVector2Array([tip,tip-direction.rotated(.55)*12,tip-direction.rotated(-.55)*12]),colour)
		draw_circle(tip,8,colour,false,2,true)
		if str(item.id)==selected_furniture_id: draw_string(ThemeDB.fallback_font,tip+Vector2(10,-10),"Sit %.0f°" % degrees,HORIZONTAL_ALIGNMENT_LEFT,-1,13,colour)

func _draw_wall_edit_overlay() -> void:
	var editing := not (placing_entry or placing_storyline_location or placing_furniture or placing_wall_door or placing_room_label or painting_floor)
	if not editing: return
	for wall in floor_data.get("walls", []):
		var start := _metres_to_screen(Vector2(float(wall.start_x_metres), float(wall.start_y_metres)))
		var finish := _metres_to_screen(Vector2(float(wall.end_x_metres), float(wall.end_y_metres)))
		var selected := str(wall.id) == selected_wall_id
		for endpoint in [start, finish]:
			draw_circle(endpoint, 6.0 if selected else 4.0, Color("#edb85a") if selected else Color("#91a89c"))
			draw_circle(endpoint, 2.0, WALL)
	if preview_start != Vector2.INF and preview_finish != Vector2.INF:
		var start := _metres_to_screen(preview_start)
		var finish := _metres_to_screen(preview_finish)
		draw_line(start, finish, Color("#edb85a"), 4.0, true)
		draw_circle(start, 5.0, Color("#edb85a"))
		draw_circle(finish, 5.0, Color("#edb85a"))
	if not snap_hint.is_empty() and bool(snap_hint.get("snapped", false)):
		var position := _metres_to_screen(Vector2(snap_hint.position))
		draw_circle(position, 9.0, ENTRY, false, 2.0, true)
		draw_line(position + Vector2(-12, 0), position + Vector2(12, 0), ENTRY, 1.0)
		draw_line(position + Vector2(0, -12), position + Vector2(0, 12), ENTRY, 1.0)


func _draw_flooring() -> void:
	var flooring: Dictionary = floor_data.get("flooring", {})
	var cell_size := float(flooring.get("cell_size_metres", 0.5))
	if cell_size <= 0.0: return
	for cell_key in flooring.get("cells", {}):
		var parts := str(cell_key).split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var material_id := str(flooring.get("cells", {}).get(cell_key, ""))
		if material_id == "default_floor": continue
		var top_left := _metres_to_screen(Vector2(cell.x, cell.y) * cell_size)
		var bottom_right := _metres_to_screen(Vector2(cell.x + 1, cell.y + 1) * cell_size)
		var destination := Rect2(top_left, bottom_right - top_left).abs().grow(0.35)
		var texture: Texture2D = floor_material_textures.get(material_id)
		if texture != null:
			var source_cell := 64
			var source_columns := maxi(1, texture.get_width() / source_cell)
			var source_rows := maxi(1, texture.get_height() / source_cell)
			var source := Rect2(posmod(cell.x, source_columns) * source_cell, posmod(cell.y, source_rows) * source_cell, source_cell, source_cell)
			draw_texture_rect_region(texture, destination, source)
		else:
			var definition: Dictionary = floor_material_definitions.get(material_id, {})
			draw_rect(destination, Color(str(definition.get("fill", "#8a735d"))))


func _draw_internal_wall(wall: Dictionary) -> void:
	var start := Vector2(float(wall.get("start_x_metres", 0.0)), float(wall.get("start_y_metres", 0.0)))
	var finish := Vector2(float(wall.get("end_x_metres", 0.0)), float(wall.get("end_y_metres", 0.0)))
	var delta := finish - start
	var length := delta.length()
	if length <= 0.001: return
	var direction := delta / length
	var openings: Array = []
	for door_value in wall.get("doors", []):
		var door: Dictionary = door_value
		var half_width := float(door.get("width_metres", 0.9)) * 0.5
		openings.append({"start": maxf(0.0, float(door.get("offset_metres", 0.0)) - half_width), "finish": minf(length, float(door.get("offset_metres", 0.0)) + half_width), "locked": bool(door.get("locked", false))})
	openings.sort_custom(func(a, b): return float(a.start) < float(b.start))
	var cursor := 0.0
	var line_width := maxf(2.0, float(wall.get("thickness_metres", 0.18)) / maxf(float(floor_data.get("width_metres", 1.0)), 1.0) * _content_rect().size.x * view_zoom)
	for opening in openings:
		if float(opening.start) > cursor:
			draw_line(_metres_to_screen(start + direction * cursor), _metres_to_screen(start + direction * float(opening.start)), WALL, line_width, true)
		var door_centre := _metres_to_screen(start + direction * ((float(opening.start) + float(opening.finish)) * 0.5))
		draw_circle(door_centre, 4.0, LOCKED_DOOR if bool(opening.locked) else ENTRY)
		cursor = maxf(cursor, float(opening.finish))
	if cursor < length:
		draw_line(_metres_to_screen(start + direction * cursor), _metres_to_screen(finish), WALL, line_width, true)


func _draw_room_label(room: Dictionary) -> void:
	var position := _metres_to_screen(Vector2(float(room.get("label_x_metres", 0.0)), float(room.get("label_y_metres", 0.0))))
	var name := str(room.get("name", "Room"))
	var width := ThemeDB.fallback_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_rect(Rect2(position + Vector2(-width * 0.5 - 5, -17), Vector2(width + 10, 22)), Color("#dce9e1aa"))
	draw_string(ThemeDB.fallback_font, position + Vector2(-width * 0.5, 0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#263a32"))


func _draw_furniture(item: Dictionary) -> void:
	var centre := Vector2(float(item.get("x_metres", 0.0)), float(item.get("y_metres", 0.0)))
	var half_size := Vector2(float(item.get("width_metres", 0.5)), float(item.get("depth_metres", 0.5))) * 0.5
	var rotation := deg_to_rad(float(item.get("rotation_degrees", 0.0)))
	var polygon := PackedVector2Array()
	for corner in [Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)]:
		polygon.append(_metres_to_screen(centre + corner.rotated(rotation)))
	if polygon.size() < 3:
		return
	var outline := Color(str(item.get("outline", "#41362d")))
	var custom_texture := _texture_for_item(item)
	if custom_texture == null:
		draw_colored_polygon(polygon, Color(str(item.get("fill", "#8a735d"))))
	draw_polyline(_closed(polygon), outline, 2.0, true)
	var screen_centre := _metres_to_screen(centre)
	var rect := _content_rect()
	var floor_size := Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0))).max(Vector2.ONE)
	var half_screen := half_size / floor_size * rect.size * view_zoom
	draw_set_transform(screen_centre, rotation, Vector2.ONE)
	if custom_texture != null:
		draw_texture_rect(custom_texture, Rect2(-half_screen, half_screen * 2.0), false)
	else:
		_draw_furniture_details(str(item.get("catalog_id", "")), half_screen, outline)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var label := str(item.get("name", "Furniture"))
	var label_position := screen_centre + Vector2(-ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, half_screen.y + 14)
	# Keep arrival editing clear of overlapping labels; Interior Designer retains them.
	if not entry_drag_enabled and (str(item.get("id", "")) == selected_furniture_id or _furniture_at_pointer(get_local_mouse_position()) == str(item.get("id", ""))):
		draw_string(ThemeDB.fallback_font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f5f0e6"))


func _draw_furniture_details(catalog_id: String, half_size: Vector2, outline: Color) -> void:
	var light := outline.lightened(0.55)
	var dark := outline.darkened(0.18)
	match catalog_id:
		"dining_table":
			draw_rect(Rect2(-half_size * 0.78, half_size * 1.56), light, false, 1.0)
			for corner in [Vector2(-0.65, -0.58), Vector2(0.65, -0.58), Vector2(0.65, 0.58), Vector2(-0.65, 0.58)]:
				draw_circle(corner * half_size, maxf(1.0, minf(half_size.x, half_size.y) * 0.12), dark)
		"dining_chair":
			draw_rect(Rect2(Vector2(-half_size.x * 0.7, -half_size.y * 0.45), Vector2(half_size.x * 1.4, half_size.y * 1.05)), light, false, 1.0)
			draw_line(Vector2(-half_size.x * 0.72, -half_size.y * 0.7), Vector2(half_size.x * 0.72, -half_size.y * 0.7), dark, 2.0)
		"sofa":
			draw_rect(Rect2(Vector2(-half_size.x * 0.82, -half_size.y * 0.5), Vector2(half_size.x * 1.64, half_size.y * 1.05)), light, false, 1.0)
			draw_rect(Rect2(Vector2(-half_size.x * 0.92, -half_size.y * 0.85), Vector2(half_size.x * 1.84, half_size.y * 0.28)), dark)
			draw_rect(Rect2(Vector2(-half_size.x * 0.95, -half_size.y * 0.5), Vector2(half_size.x * 0.16, half_size.y * 1.15)), dark)
			draw_rect(Rect2(Vector2(half_size.x * 0.79, -half_size.y * 0.5), Vector2(half_size.x * 0.16, half_size.y * 1.15)), dark)
			draw_line(Vector2.ZERO, Vector2(0, half_size.y * 0.55), outline, 1.0)
		"single_bed":
			draw_rect(Rect2(Vector2(-half_size.x * 0.82, -half_size.y * 0.82), Vector2(half_size.x * 1.64, half_size.y * 0.42)), Color("#e7ded0"))
			draw_rect(Rect2(Vector2(-half_size.x * 0.78, -half_size.y * 0.3), Vector2(half_size.x * 1.56, half_size.y * 1.02)), light, false, 1.0)
			draw_line(Vector2(-half_size.x * 0.78, half_size.y * 0.25), Vector2(half_size.x * 0.78, half_size.y * 0.25), outline, 1.0)
		"wardrobe":
			draw_line(Vector2(0, -half_size.y * 0.88), Vector2(0, half_size.y * 0.88), light, 1.0)
			draw_circle(Vector2(-half_size.x * 0.12, 0), 1.2, light)
			draw_circle(Vector2(half_size.x * 0.12, 0), 1.2, light)
		"kitchen_counter":
			draw_rect(Rect2(Vector2(-half_size.x * 0.9, -half_size.y * 0.82), Vector2(half_size.x * 1.8, half_size.y * 0.22)), light)
			draw_circle(Vector2(-half_size.x * 0.42, 0), minf(half_size.y * 0.38, 4.0), Color("#b9d0d2"))
			draw_circle(Vector2(half_size.x * 0.45, 0), minf(half_size.y * 0.3, 3.5), dark, false, 1.0)
		"bathroom_sink":
			draw_circle(Vector2(0, half_size.y * 0.05), minf(half_size.x, half_size.y) * 0.58, Color("#f2f5f2"))
			draw_circle(Vector2(0, half_size.y * 0.05), minf(half_size.x, half_size.y) * 0.32, Color("#9eb8ba"), false, 1.0)
			draw_line(Vector2(0, -half_size.y * 0.65), Vector2(0, -half_size.y * 0.15), dark, 1.5)
		"toilet":
			draw_rect(Rect2(Vector2(-half_size.x * 0.62, -half_size.y * 0.83), Vector2(half_size.x * 1.24, half_size.y * 0.4)), Color("#f5f6f1"))
			draw_circle(Vector2(0, half_size.y * 0.2), minf(half_size.x * 0.62, half_size.y * 0.48), Color("#f5f6f1"))
			draw_circle(Vector2(0, half_size.y * 0.2), minf(half_size.x * 0.35, half_size.y * 0.28), Color("#9fb7b8"), false, 1.0)
		"office_desk":
			draw_rect(Rect2(Vector2(-half_size.x * 0.25, -half_size.y * 0.45), Vector2(half_size.x * 0.5, half_size.y * 0.38)), Color("#314f5e"))
			draw_line(Vector2(0, -half_size.y * 0.07), Vector2(0, half_size.y * 0.35), light, 1.0)
		"shop_shelf":
			for fraction in [-0.55, 0.0, 0.55]:
				draw_line(Vector2(-half_size.x * 0.85, half_size.y * fraction), Vector2(half_size.x * 0.85, half_size.y * fraction), light, 1.0)
		"bar_counter":
			draw_rect(Rect2(Vector2(-half_size.x * 0.9, -half_size.y * 0.78), Vector2(half_size.x * 1.8, half_size.y * 0.28)), light)
			for fraction in [-0.55, 0.0, 0.55]:
				draw_line(Vector2(half_size.x * fraction, -half_size.y * 0.3), Vector2(half_size.x * fraction, half_size.y * 0.72), dark, 1.0)
		"bar_stool":
			draw_circle(Vector2.ZERO, minf(half_size.x, half_size.y) * 0.65, light)
			draw_circle(Vector2.ZERO, minf(half_size.x, half_size.y) * 0.38, dark, false, 1.0)


func _content_rect() -> Rect2:
	var floor_size := Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0))).max(Vector2.ONE)
	var available := (size - Vector2(64, 64)).max(Vector2(64, 64))
	var scale := minf(available.x / floor_size.x, available.y / floor_size.y)
	var drawn_size := floor_size * scale
	return Rect2((size - drawn_size) * 0.5, drawn_size)


func _metres_to_screen(point: Vector2) -> Vector2:
	var rect := _content_rect()
	var floor_size := Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0))).max(Vector2.ONE)
	var ratio := point / floor_size
	return rect.get_center() + (ratio - view_center_ratio) * rect.size * view_zoom


func _screen_to_metres(point: Vector2) -> Vector2:
	var rect := _content_rect()
	var ratio := (view_center_ratio + (point - rect.get_center()) / (rect.size * view_zoom)).clamp(Vector2.ZERO, Vector2.ONE)
	return ratio * Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0)))


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	if floor_data.is_empty(): return
	var rect := _content_rect()
	var ratio_before := view_center_ratio + (screen_position - rect.get_center()) / (rect.size * view_zoom)
	view_zoom = clampf(view_zoom * factor, 1.0, 12.0)
	view_center_ratio = ratio_before - (screen_position - rect.get_center()) / (rect.size * view_zoom)
	_clamp_view_center()
	view_changed.emit(view_zoom)
	queue_redraw()


func _pan_by(screen_delta: Vector2) -> void:
	var rect := _content_rect()
	view_center_ratio -= screen_delta / (rect.size * view_zoom)
	_clamp_view_center()
	queue_redraw()


func _clamp_view_center() -> void:
	var half_view := 0.5 / view_zoom
	view_center_ratio.x = clampf(view_center_ratio.x, half_view, 1.0 - half_view)
	view_center_ratio.y = clampf(view_center_ratio.y, half_view, 1.0 - half_view)


func _draw_metre_grid() -> void:
	var floor_size := Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0))).max(Vector2.ONE)
	var rect := _content_rect()
	var pixels_per_metre := minf(rect.size.x / floor_size.x, rect.size.y / floor_size.y) * view_zoom
	var grid_step := 1.0
	for candidate in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0]:
		grid_step = candidate
		if pixels_per_metre * grid_step >= 16.0: break
	var x := 0.0
	while x <= floor_size.x + 0.001:
		var start := _metres_to_screen(Vector2(x, 0.0))
		var finish := _metres_to_screen(Vector2(x, floor_size.y))
		draw_line(start, finish, GRID, 1.0)
		x += grid_step
	var y := 0.0
	while y <= floor_size.y + 0.001:
		var start := _metres_to_screen(Vector2(0.0, y))
		var finish := _metres_to_screen(Vector2(floor_size.x, y))
		draw_line(start, finish, GRID, 1.0)
		y += grid_step


func _texture_for_item(item: Dictionary) -> Texture2D:
	var built_in: Dictionary = InteriorFurnitureCatalogScript.definition(str(item.get("catalog_id", "")))
	var bundled := str(built_in.get("image_path", ""))
	if not bundled.is_empty():
		if custom_textures.has(bundled): return custom_textures[bundled]
		var resource = load(bundled) if ResourceLoader.exists(bundled) else null
		if resource is Texture2D:
			custom_textures[bundled] = resource
			return resource
		var bundled_image := Image.new()
		if bundled_image.load(ProjectSettings.globalize_path(bundled)) == OK:
			custom_textures[bundled] = ImageTexture.create_from_image(bundled_image)
			return custom_textures[bundled]
	var relative_path := str(item.get("image_path", "")).replace("\\", "/")
	if asset_root.is_empty() or relative_path.is_empty() or relative_path.contains("..") or relative_path.is_absolute_path(): return null
	if custom_textures.has(relative_path): return custom_textures[relative_path]
	var image := Image.new()
	if image.load(asset_root.path_join(relative_path)) != OK or image.is_empty():
		custom_textures[relative_path] = null
		return null
	var texture := ImageTexture.create_from_image(image)
	custom_textures[relative_path] = texture
	return texture


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
