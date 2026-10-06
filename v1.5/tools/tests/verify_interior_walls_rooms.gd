extends SceneTree

const StoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const RuntimeLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const CanvasScript = preload("res://scripts/interiors/interior_floor_canvas.gd")
var drag_result: Dictionary = {}
var draw_result: Dictionary = {}


func _initialize() -> void:
	var store = StoreScript.new()
	var data := store.empty_data()
	data.buildings["test_building"] = {
		"feature_id": "test_building", "name": "Wall and room test",
		"floors": [{
			"id": "ground_floor", "name": "Ground floor", "level": 0,
			"layout_source": "creator_blank_from_osm_footprint", "survey_status": "not_surveyed",
			"width_metres": 20.0, "height_metres": 15.0, "grid_metres": 1.0, "footprint_scale": 1.0,
			"boundary_metres": [[0.0, 0.0], [20.0, 0.0], [20.0, 15.0], [0.0, 15.0]],
			"holes_metres": [], "walls": [], "rooms": [], "furniture": [],
			"entry_links": [{
				"id": "entry_front", "exterior_entrance_id": "front", "floor_id": "ground_floor",
				"spawn_x_metres": 2.0, "spawn_y_metres": 2.0, "placement_source": "creator_selected"
			}]
		}]
	}
	var base_data := data.duplicate(true)
	var wall_result: Dictionary = store.add_wall(data, "test_building", "ground_floor", Vector2(10.0, 0.1), Vector2(10.0, 14.9))
	assert(wall_result.ok, str(wall_result.get("message", "Wall placement failed.")))
	data = wall_result.data
	var wall_id := str(wall_result.wall_id)
	var snapped_wall: Dictionary = data.buildings.test_building.floors[0].walls[0]
	assert(float(snapped_wall.start_y_metres) < 0.1 and float(snapped_wall.end_y_metres) > 14.9, "Wall ends did not snap to the footprint walls.")
	var blocked_furniture: Dictionary = store.place_furniture(data, "test_building", "ground_floor", "dining_chair", Vector2(10.0, 4.0), 0.0)
	assert(not blocked_furniture.ok, "Furniture was allowed to overlap an internal wall.")
	var blocked_location := store.validate_location(data, {"space": "interior", "building_id": "test_building", "floor_id": "ground_floor", "x_metres": 10.0, "y_metres": 4.0})
	assert(not blocked_location.ok, "A storyline NPC location was allowed inside an internal wall.")
	var door_result: Dictionary = store.add_wall_door(data, "test_building", "ground_floor", wall_id, Vector2(10.0, 7.0), 1.2)
	assert(door_result.ok, str(door_result.get("message", "Doorway placement failed.")))
	data = door_result.data
	assert(not bool(data.buildings.test_building.floors[0].walls[0].doors[0].get("locked", true)), "A new doorway did not default to unlocked.")
	var room_result: Dictionary = store.add_room_label(data, "test_building", "ground_floor", "Bedroom", Vector2(5.0, 6.0))
	assert(room_result.ok, str(room_result.get("message", "Room naming failed.")))
	data = room_result.data
	assert(store.validate(data).ok, "Walls, doorway and room names failed canonical validation.")
	assert(store.validate_location(data, {"space": "interior", "building_id": "test_building", "floor_id": "ground_floor", "x_metres": 10.0, "y_metres": 7.0}).ok, "The doorway did not create a clear NPC placement opening.")

	var runtime = RuntimeLayerScript.new()
	get_root().add_child(runtime)
	var floor: Dictionary = data.buildings.test_building.floors[0]
	var opened: Dictionary = runtime.open_floor(data.buildings.test_building, floor, floor.entry_links[0], 10.0)
	assert(opened.ok, str(opened.get("message", "Runtime interior did not open.")))
	assert(not runtime.is_traversable(Vector2(100.0, 40.0), 2.0), "The playable character passed through a solid internal wall.")
	assert(not runtime.is_traversable(Vector2(100.0, 70.0), 2.0), "The player walked through an internal doorway without pressing E.")
	assert(runtime.discovered_components.size() == 1, "Only the starting room should be visible when the interior opens.")
	assert(runtime.current_room_name(Vector2(20.0, 20.0)) == "Bedroom", "The starting room name was not available for the top gameplay heading.")
	var crossed: Dictionary = runtime.cross_internal_door(Vector2(94.0, 70.0), 2.0)
	assert(crossed.ok and runtime.is_traversable(Vector2(crossed.position), 2.0), str(crossed.get("message", "Pressing E did not move the player through the doorway.")))
	runtime.update_player_position(Vector2(crossed.position))
	assert(runtime.discovered_components.size() == 2, "Entering through the doorway did not reveal the room on the other side.")
	assert(runtime.current_room_name(Vector2(crossed.position)).is_empty(), "A room name from the previous visibility region remained in the top gameplay heading.")
	var lock_result: Dictionary = store.set_wall_door_locked(data, "test_building", "ground_floor", wall_id, str(door_result.door_id), true)
	assert(lock_result.ok and bool(lock_result.data.buildings.test_building.floors[0].walls[0].doors[0].locked), "Creator Studio could not lock a saved doorway.")
	var locked_runtime = RuntimeLayerScript.new()
	get_root().add_child(locked_runtime)
	var locked_floor: Dictionary = lock_result.data.buildings.test_building.floors[0]
	assert(locked_runtime.open_floor(lock_result.data.buildings.test_building, locked_floor, locked_floor.entry_links[0], 10.0).ok, "Locked-door runtime fixture did not open.")
	var locked_cross: Dictionary = locked_runtime.cross_internal_door(Vector2(94.0, 70.0), 2.0)
	assert(not locked_cross.ok and bool(locked_cross.get("locked", false)) and str(locked_cross.message) == "The door is locked.", "A locked door did not refuse E-entry with the expected message.")

	var automatic_data := base_data.duplicate(true)
	var first_wall := store.add_wall(automatic_data, "test_building", "ground_floor", Vector2(5.0, 0.2), Vector2(5.0, 14.8))
	assert(first_wall.ok, "Automatic-wall doorway fixture could not add its first wall.")
	automatic_data = first_wall.data
	var second_wall := store.add_wall(automatic_data, "test_building", "ground_floor", Vector2(15.0, 0.2), Vector2(15.0, 14.8))
	assert(second_wall.ok, "Automatic-wall doorway fixture could not add its second wall.")
	automatic_data = second_wall.data
	var automatic_door := store.add_wall_door(automatic_data, "test_building", "ground_floor", str(first_wall.wall_id), Vector2(15.0, 7.0), 0.9)
	assert(automatic_door.ok and str(automatic_door.wall_id) == str(second_wall.wall_id), "Door placement followed the list selection instead of the visible wall that was clicked.")

	var canvas = CanvasScript.new()
	canvas.size = Vector2(520, 420)
	get_root().add_child(canvas)
	canvas.set_floor(floor, "test_building/ground_floor")
	assert(canvas.floor_data.get("walls", []).size() == 1 and canvas.floor_data.get("rooms", []).size() == 1, "Interior preview did not receive the saved wall and room name.")
	canvas.begin_wall_placement()
	assert(canvas.placing_wall, "Interior preview did not enter two-click wall drawing mode.")
	canvas.begin_wall_door_placement(wall_id)
	assert(canvas.placing_wall_door and canvas.selected_wall_id == wall_id, "Interior preview did not enter doorway placement mode.")
	canvas.begin_room_label_placement()
	assert(canvas.placing_room_label, "Interior preview did not enter room-name placement mode.")
	var resized: Dictionary = store.resize_floor(data, "test_building", "ground_floor", 1.5)
	assert(resized.ok, str(resized.get("message", "The wall layout did not survive floor resizing.")))
	var resized_floor: Dictionary = resized.data.buildings.test_building.floors[0]
	assert(is_equal_approx(float(resized_floor.walls[0].start_x_metres), float(floor.walls[0].start_x_metres) * 1.5) and is_equal_approx(float(resized_floor.walls[0].doors[0].offset_metres), float(floor.walls[0].doors[0].offset_metres) * 1.5), "Floor resizing did not preserve the wall and doorway proportions.")
	assert(is_equal_approx(float(resized_floor.rooms[0].label_x_metres), 7.5), "Floor resizing did not preserve the room-name position.")
	var remove_room: Dictionary = store.remove_room_label(data, "test_building", "ground_floor", str(room_result.room_id))
	assert(remove_room.ok and remove_room.data.buildings.test_building.floors[0].rooms.is_empty(), "The saved room name could not be removed independently.")
	var remove_door: Dictionary = store.remove_wall_door(remove_room.data, "test_building", "ground_floor", wall_id, str(door_result.door_id))
	assert(remove_door.ok and remove_door.data.buildings.test_building.floors[0].walls[0].doors.is_empty(), "Removing a doorway did not make that wall section solid again.")
	var remove_wall: Dictionary = store.remove_wall(remove_door.data, "test_building", "ground_floor", wall_id)
	assert(remove_wall.ok and remove_wall.data.buildings.test_building.floors[0].walls.is_empty(), "The selected internal wall could not be removed.")
	_verify_wall_dragging(store, base_data)
	print("INTERIOR WALLS/ROOMS PASSED: snapped walls, click-targeted and lockable doors, heading room names, room reveal and runtime collision.")
	quit(0)


func _verify_wall_dragging(store, base_data: Dictionary) -> void:
	var data := base_data.duplicate(true)
	var first: Dictionary = store.add_wall(data, "test_building", "ground_floor", Vector2(5, 5), Vector2(12, 5))
	assert(first.ok, str(first.get("message", "")))
	var second: Dictionary = store.add_wall(first.data, "test_building", "ground_floor", Vector2(18, 2), Vector2(18, 13))
	assert(second.ok, str(second.get("message", "")))
	var door: Dictionary = store.add_wall_door(second.data, "test_building", "ground_floor", str(first.wall_id), Vector2(8, 5), 0.9)
	var locked: Dictionary = store.set_wall_door_locked(door.data, "test_building", "ground_floor", str(first.wall_id), str(door.door_id), true)
	data = locked.data
	var canvas = CanvasScript.new()
	canvas.size = Vector2(720, 540)
	root.add_child(canvas)
	canvas.set_floor(data.buildings.test_building.floors[0], "drag_test")
	canvas.wall_move_requested.connect(func(id, start, finish): drag_result = {"id": id, "start": start, "finish": finish})
	canvas.wall_requested.connect(func(start, finish): draw_result = {"start": start, "finish": finish})
	canvas.begin_wall_editing()
	var press_position: Vector2 = canvas._metres_to_screen(Vector2(12, 5))
	var target: Vector2 = canvas._metres_to_screen(Vector2(18, 5)) + Vector2(-7, 0)
	_mouse_button(canvas, press_position, true)
	_mouse_motion(canvas, target)
	assert(bool(canvas.snap_hint.get("snapped", false)), "Endpoint dragging did not show the live snap marker.")
	_mouse_button(canvas, target, false)
	assert(str(drag_result.get("id", "")) == str(first.wall_id) and is_equal_approx(Vector2(drag_result.finish).x, 18.0), "A real press/drag/release did not snap the existing wall endpoint to another wall.")
	var moved: Dictionary = store.move_wall(data, "test_building", "ground_floor", str(drag_result.id), Vector2(drag_result.start), Vector2(drag_result.finish), canvas.wall_snap_distance(), true)
	assert(moved.ok, str(moved.get("message", "")))
	var moved_wall: Dictionary = moved.data.buildings.test_building.floors[0].walls[0]
	assert(str(moved_wall.id) == str(first.wall_id) and str(moved_wall.doors[0].id) == str(door.door_id) and bool(moved_wall.doors[0].locked), "Dragging lost a stable wall/door ID or door lock state.")
	assert(store.validate(moved.data).ok, "The snapped T-junction was not valid canonical data.")
	var invalid: Dictionary = store.move_wall(data, "test_building", "ground_floor", str(first.wall_id), Vector2(1, 2), Vector2(4, 2), 0.1, true)
	assert(not invalid.ok and float(data.buildings.test_building.floors[0].walls[0].start_x_metres) == 5.0, "A move across an entry arrival changed the original layout.")
	canvas.set_floor(data.buildings.test_building.floors[0], "drag_test")
	canvas.begin_wall_editing()
	drag_result = {}
	press_position = canvas._metres_to_screen(Vector2(8.5, 5))
	target = canvas._metres_to_screen(Vector2(8.5, 7))
	_mouse_button(canvas, press_position, true)
	_mouse_motion(canvas, target)
	_mouse_button(canvas, target, false)
	assert(not drag_result.is_empty(), "Dragging the wall body did not emit an edit.")
	assert(Vector2(drag_result.start).distance_to(Vector2(drag_result.finish)) == 7.0, "Dragging a whole wall changed its length.")
	var translated: Dictionary = store.move_wall(data, "test_building", "ground_floor", str(first.wall_id), drag_result.start, drag_result.finish, canvas.wall_snap_distance(), true)
	assert(translated.ok, str(translated.get("message", "")))
	canvas.begin_wall_placement()
	canvas.view_zoom = 1.5
	canvas.view_center_ratio = Vector2(0.35, 0.5)
	press_position = canvas._metres_to_screen(Vector2(0.0, 9.0))
	target = canvas._metres_to_screen(Vector2(5.0, 9.0))
	_mouse_button(canvas, press_position, true)
	_mouse_motion(canvas, target)
	_mouse_button(canvas, target, false)
	assert(not draw_result.is_empty() and Vector2(draw_result.start).x < 0.1 and is_equal_approx(Vector2(draw_result.finish).x, 5.0), "Drag drawing failed to preserve snapped metre positions while zoomed and panned.")
	var drawn: Dictionary = store.add_wall(data, "test_building", "ground_floor", draw_result.start, draw_result.finish, canvas.wall_snap_distance(), true)
	assert(drawn.ok, str(drawn.get("message", "")))
	canvas.set_floor(data.buildings.test_building.floors[0], "drag_test")
	canvas.begin_wall_placement()
	canvas.reset_view()
	draw_result = {}
	_mouse_button(canvas, canvas._metres_to_screen(Vector2(5, 10)), true)
	_mouse_button(canvas, canvas._metres_to_screen(Vector2(5, 10)), false)
	assert(draw_result.is_empty(), "A stationary first click saved a zero-length wall.")
	_mouse_button(canvas, canvas._metres_to_screen(Vector2(12, 10)), true)
	_mouse_button(canvas, canvas._metres_to_screen(Vector2(12, 10)), false)
	assert(not draw_result.is_empty(), "The two-click wall drawing option stopped working.")
	print("WALL DRAGGING PASSED: input gestures, endpoint/T-junction snap, body movement, zoom/pan, door-lock preservation and invalid-move rollback.")
	canvas.free()


func _mouse_button(canvas, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	canvas._gui_input(event)


func _mouse_motion(canvas, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(event)
