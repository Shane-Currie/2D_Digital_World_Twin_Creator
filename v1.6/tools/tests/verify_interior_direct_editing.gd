extends SceneTree

const StudioScript = preload("res://scripts/app/creator_studio.gd")
var studio
var canvas
var feature_id := ""
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAILED: ", message)


func _button(point: Vector2, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = canvas._metres_to_screen(point)
	event.pressed = pressed
	event.shift_pressed = shift
	canvas._gui_input(event)


func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = canvas._metres_to_screen(point)
	canvas._gui_input(event)


func _shift() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.pressed = true
	canvas._gui_input(event)


func _floor() -> Dictionary:
	return studio.interior_data.buildings[feature_id].floors[0]


func _run() -> void:
	studio = StudioScript.new()
	root.add_child(studio)
	await process_frame
	var args := OS.get_cmdline_user_args()
	var index := args.find("--town")
	if index < 0 or index + 1 >= args.size():
		printerr("Supply --town <saved project>; the check reads it without saving changes.")
		quit(1)
		return
	var town_path := args[index + 1]
	var town: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(town_path.path_join("town.json")))
	var features: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(town_path.path_join("data/map_features.json")))
	studio.loaded_project_directory = town_path
	studio.imported_town = {"ok": true, "bounds": town.map_bounds, "features": features.features}
	studio._show_interior_designer_page()
	await process_frame
	canvas = studio.interior_floor_canvas
	_expect(canvas != null and not studio.interior_selected_feature.is_empty(), "Read-only saved town did not open Interior Designer.")
	if canvas == null:
		quit(1)
		return
	feature_id = str(studio.interior_selected_feature.id)
	# Exercise a roomy editor fixture in memory only. No saved town changes.
	var floor := {"id": "ground_floor", "name": "Ground floor", "level": 0, "width_metres": 20.0, "height_metres": 15.0, "footprint_scale": 1.0, "boundary_metres": [[0,0],[20,0],[20,15],[0,15]], "holes_metres": [], "entry_links": [], "furniture": [], "walls": [], "rooms": []}
	studio.interior_data.buildings[feature_id] = {"feature_id": feature_id, "name": "Direct editing check", "floors": [floor]}
	var store = studio.building_interior_store
	var placed: Dictionary = store.place_furniture(studio.interior_data, feature_id, "ground_floor", "dining_chair", Vector2(3,4), 25.0)
	_expect(placed.ok, "Could not prepare furniture fixture.")
	studio.interior_data = placed.data
	var item_id := str(placed.furniture_id)
	var wall: Dictionary = store.add_wall(studio.interior_data, feature_id, "ground_floor", Vector2(10,0.1), Vector2(10,14.9))
	studio.interior_data = wall.data
	var first_wall_id := str(wall.wall_id)
	var second: Dictionary = store.add_wall(studio.interior_data, feature_id, "ground_floor", Vector2(15,0.1), Vector2(15,14.9))
	studio.interior_data = second.data
	var second_wall_id := str(second.wall_id)
	var door: Dictionary = store.add_wall_door(studio.interior_data, feature_id, "ground_floor", first_wall_id, Vector2(10,5), 1.2)
	studio.interior_data = store.set_wall_door_locked(door.data, feature_id, "ground_floor", first_wall_id, str(door.door_id), true).data
	var npc := {"id": "fixture_npc", "display_name": "Kekie", "appearance": {"npc_asset": "npc_medium_woman_adult"}, "location": {"space": "interior", "building_id": feature_id, "floor_id": "ground_floor", "x_metres": 6.0, "y_metres": 8.0}}
	var other_floor: Dictionary = npc.duplicate(true)
	other_floor.location.floor_id = "floor_1"
	studio.storyline_npc_data = {"npcs": [npc, other_floor]}
	studio._refresh_interior_designer_controls("ground_floor")
	await process_frame
	canvas.size = Vector2(800,600)
	studio.message_dialog.hide()
	_expect(canvas.interior_npcs.size() == 1 and canvas.interior_npcs[0].display_name == "Kekie", "Interior NPC visibility did not filter building/floor.")
	# Real input routing: body selection takes priority over empty-space pan.
	_button(Vector2(3,4), true)
	_motion(Vector2(4,5))
	_expect(canvas.object_drag_kind == "furniture" and canvas.preview_valid, "Furniture drag did not show a valid preview.")
	_button(Vector2(4,5), false)
	_expect(Vector2(_floor().furniture[0].x_metres, _floor().furniture[0].y_metres).is_equal_approx(Vector2(4,5)), "Dragging furniture did not save its new position.")
	_expect(str(_floor().furniture[0].id) == item_id and _floor().furniture[0].rotation_degrees == 25.0, "Moving changed the item's ID or rotation.")
	_button(Vector2(4,5), true)
	_motion(Vector2(6,8))
	_expect(not canvas.preview_valid and canvas.invalid_position != Vector2.INF, "NPC overlap did not show an invalid preview.")
	_button(Vector2(6,8), false)
	_expect(not canvas.last_edit_ok and _floor().furniture[0].x_metres == 4.0 and not studio.message_dialog.visible, "Invalid move changed saved data or opened a modal.")
	# Shift-selected copies work even if the library currently selects another
	# catalogue item; preserve the actual source artwork, dimensions and angle.
	_button(Vector2(4,5), true)
	_button(Vector2(4,5), false)
	_shift()
	_motion(Vector2(3,9))
	_button(Vector2(3,9), true, true)
	_button(Vector2(3,9), false, true)
	_motion(Vector2(4,11))
	_button(Vector2(4,11), true, true)
	_button(Vector2(4,11), false, true)
	_expect(_floor().furniture.size() == 3 and canvas.placing_furniture, "Shift did not paste multiple objects without reopening the menu.")
	_expect(_floor().furniture[1].rotation_degrees == 25.0 and _floor().furniture[1].catalog_id == "dining_chair" and _floor().furniture[1].id != item_id, "Copied item did not preserve source properties or get a new ID.")
	_motion(Vector2(-1,9))
	_expect(not canvas.preview_valid, "An outside placement was clamped silently instead of showing X.")
	_button(Vector2(-1,9), true, true)
	_button(Vector2(-1,9), false, true)
	_expect(_floor().furniture.size() == 3 and not studio.message_dialog.visible, "Blocked repeated placement added an item or displayed a modal.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	canvas._gui_input(escape)
	# Door picking must take priority over dragging its supporting wall.
	_button(Vector2(10,5), true)
	_expect(canvas.object_drag_kind == "door" and canvas.selected_door_id == str(door.door_id), "Clicking a door grabbed its wall instead.")
	_motion(Vector2(10,8))
	_button(Vector2(10,8), false)
	var moved_door: Dictionary = _floor().walls[0].doors[0]
	_expect(moved_door.offset_metres > 7.0 and moved_door.locked and moved_door.width_metres == 1.2, "Door drag lost width/lock state or did not move.")
	_button(Vector2(10,8), true)
	_motion(Vector2(15,8))
	_button(Vector2(15,8), false)
	_expect(_floor().walls[0].doors.is_empty() and _floor().walls[1].doors.size() == 1 and _floor().walls[1].doors[0].locked, "A door could not be dragged to another wall with its lock retained.")
	_button(Vector2(15,8), true)
	_motion(Vector2(18,12))
	_button(Vector2(18,12), false)
	_expect(not canvas.last_edit_ok and _floor().walls[1].doors.size() == 1 and not studio.message_dialog.visible, "Invalid door move lost the original or displayed a modal.")
	# Creating a doorway at an invalid point stays active for retry, no modal.
	canvas.begin_wall_door_placement(second_wall_id)
	_motion(Vector2(18,12))
	_button(Vector2(18,12), true)
	_button(Vector2(18,12), false)
	_expect(canvas.placing_wall_door and not canvas.last_edit_ok and not studio.message_dialog.visible, "Invalid doorway creation did not keep the tool ready.")
	_motion(Vector2(15,4))
	_button(Vector2(15,4), true)
	_button(Vector2(15,4), false)
	_expect(_floor().walls[1].doors.size() == 2 and canvas.last_edit_ok, "Doorway creation could not recover after an invalid click.")
	# Generic library-placement repeat mode, as well as copies of saved items.
	studio._populate_interior_furniture_options("dining_chair")
	studio._begin_interior_furniture_placement()
	_motion(Vector2(7,3))
	_button(Vector2(7,3), true, true)
	_button(Vector2(7,3), false, true)
	_motion(Vector2(7,5))
	_button(Vector2(7,5), true, true)
	_button(Vector2(7,5), false, true)
	_expect(_floor().furniture.size() == 5 and canvas.placing_furniture, "Shift did not keep catalogue placement active.")
	_motion(Vector2(10,10))
	_button(Vector2(10,10), true, true)
	_button(Vector2(10,10), false, true)
	_expect(_floor().furniture.size() == 5 and not canvas.last_edit_ok and not studio.message_dialog.visible, "A wall-overlap placement was accepted or opened a modal.")
	canvas._gui_input(escape)
	# NPC gestures use the visible sprite, preserving the grabbed offset to its
	# feet. The fixture is saved only to a unique temporary directory below.
	var personas := preload("res://scripts/npcs/persona_store.gd").recommended_data()
	var added: Dictionary = studio.storyline_npc_store.add_interior_npc(studio.storyline_npc_store.empty_data(), npc.location, str(town.id), personas, "Kekie")
	_expect(added.ok, "Could not prepare a complete storyline record.")
	studio.storyline_npc_data = added.data
	var original: Dictionary = added.npc.duplicate(true)
	canvas.set_interior_npcs(added.data.npcs, feature_id, "ground_floor")
	_button(Vector2(6,7.8), true)
	_motion(Vector2(7,8.8))
	_expect(canvas.object_drag_kind == "npc" and canvas.preview_valid, "Sprite click did not start NPC drag with a valid preview.")
	_button(Vector2(7,8.8), false)
	var moved_npc: Dictionary = studio.storyline_npc_data.npcs[0]
	_expect(Vector2(moved_npc.location.x_metres, moved_npc.location.y_metres).is_equal_approx(Vector2(7,9)), "NPC drag lost its feet offset.")
	_expect(moved_npc.id == original.id and moved_npc.persona_id == original.persona_id and moved_npc.appearance == original.appearance and moved_npc.display_name == "Kekie", "NPC movement changed identity/persona/artwork.")
	for blocked in [Vector2(10,10), Vector2(7,5), Vector2(-1,9)]:
		_button(Vector2(7,9), true)
		_motion(blocked)
		_expect(not canvas.preview_valid, "Blocked NPC drop did not show a red X.")
		_button(blocked, false)
		_expect(not canvas.last_edit_ok and studio.storyline_npc_data.npcs[0].location.x_metres == 7.0 and not studio.message_dialog.visible, "Invalid NPC move changed data or displayed a modal.")
	var another: Dictionary = studio.storyline_npc_data.npcs[0].duplicate(true)
	another.id = "another_npc"
	another.location.x_metres = 8.0
	_expect(not studio.storyline_npc_store.move_interior_npc({"npcs": [moved_npc, another]}, str(moved_npc.id), Vector2(8,9), studio.interior_data).ok, "NPCs could be dropped on top of one another.")
	var temporary_town := OS.get_environment("TEMP").path_join("twin_npc_edit_%s" % Time.get_ticks_usec())
	studio.loaded_project_directory = temporary_town
	DirAccess.make_dir_recursive_absolute(temporary_town.path_join("data"))
	var town_file := FileAccess.open(temporary_town.path_join("town.json"), FileAccess.WRITE)
	var temporary_metadata := town.duplicate(true)
	temporary_metadata["source"]={"files":[]}
	town_file.store_string(JSON.stringify(temporary_metadata)); town_file.close()
	studio.interior_custom_catalog_data = studio.interior_furniture_library.empty_data()
	studio.interior_floor_material_data = studio.interior_floor_material_library.empty_data()
	studio.interior_data.buildings = {feature_id: studio.interior_data.buildings[feature_id]}
	# Save the custom name through the real store. Interior Save deliberately
	# reloads the latest exterior, so an in-memory-only name is not a valid test.
	studio.interior_exterior_data = studio.building_exterior_store.set_custom_name(studio.building_exterior_store.empty_data(),feature_id,"The Pub").data
	_expect(studio.building_exterior_store.save_to_town(temporary_town,studio.interior_exterior_data).ok,"Could not save fixture building name.")
	studio._save_interior_layouts()
	var reopened: Dictionary = studio.storyline_npc_store.load_from_town(temporary_town, {}, [], personas, studio.interior_data)
	_expect(reopened.ok and reopened.data.npcs[0].location.x_metres == 7.0 and reopened.data.npcs[0].location.y_metres == 9.0, "Top Save did not persist the dragged NPC position.")
	studio.storyline_npc_option = OptionButton.new()
	studio.add_child(studio.storyline_npc_option)
	studio._refresh_storyline_npc_controls()
	_expect(studio.storyline_npc_option.get_item_text(0).contains("The Pub / Ground floor"), "NPC menu did not identify the building and floor.")
	print("Disposable fixture retained for inspection: ", temporary_town)
	if args.has("--render"):
		canvas.get_parent().queue_sort()
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://docs/screenshots/interior_direct_editing.png")
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		_expect(image.save_png(path) == OK, "Could not save actual editor preview.")
	if failures == 0: print("INTERIOR DIRECT EDITING PASSED: items/doors/NPC sprite dragging, blocked drops, identity/feet anchoring, top-Save/reload, named building/floor menu, locks, Shift copies and floor-specific visibility; saved town untouched.")
	studio.queue_free()
	await process_frame
	quit(1 if failures else 0)
