extends SceneTree

const InteriorLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")
const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")
const TownRuntimeScript = preload("res://scripts/runtime/town_runtime.gd")


class RendererStub extends Node2D:
	func is_ground_traversable(_position: Vector2, _clearance := 0.0) -> bool:
		return true


class BubbleStub extends Node:
	var message := ""
	func show_object(_player: Node2D, text_value: String, _duration := 2.6) -> void:
		message = text_value
	func hide_bubble() -> void:
		message = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor := {
		"id": "ground_floor", "name": "Ground floor", "level": 0,
		"width_metres": 20.0, "height_metres": 12.0,
		"boundary_metres": [[0, 0], [20, 0], [20, 12], [0, 12]],
		"holes_metres": [[[15, 4], [18, 4], [18, 8], [15, 8]]],
		"walls": [{
			"id": "wall_1", "start_x_metres": 7.0, "start_y_metres": 0.1,
			"end_x_metres": 7.0, "end_y_metres": 11.9, "thickness_metres": 0.18,
			"doors": [{"id": "door_1", "offset_metres": 5.9, "width_metres": 1.2}]
		}],
		"rooms": [{"id": "room_1", "name": "Hidden room", "label_x_metres": 12.0, "label_y_metres": 6.0}],
		"furniture": [{"id": "hidden_sofa", "catalog_id": "sofa", "object_type": "sofa", "x_metres": 12.0, "y_metres": 3.0, "width_metres": 2.0, "depth_metres": 0.9, "collision": true}],
		"entry_links": []
	}
	var link := {"exterior_entrance_id": "entrance_1", "spawn_x_metres": 2.0, "spawn_y_metres": 2.0}
	var layer = InteriorLayerScript.new()
	root.add_child(layer)
	var opened: Dictionary = layer.open_floor({"name": "Test Building"}, floor, link, 2.0)
	assert(opened.ok, str(opened.get("message", "")))
	assert(layer.is_traversable(Vector2(opened.position), 4.0), "The arrival point is not safely inside the footprint-shaped floor.")
	assert(not layer.is_traversable(Vector2(32, 12), 0.0), "The courtyard hole became walkable.")
	assert(not layer.is_traversable(Vector2(-1, 5), 0.0), "The player can walk outside the interior footprint.")

	var runtime = TownRuntimeScript.new()
	runtime.collision_data = {"runtime_scale": {"pixels_per_metre": 2.0}}
	runtime.interior_layer = layer
	runtime.player = PlayerScript.new()
	root.add_child(runtime.player)
	runtime.renderer = RendererStub.new()
	runtime.population = Node2D.new()
	runtime.tracks = Node2D.new()
	runtime.wagon = Node2D.new()
	runtime.object_identification_bubble = BubbleStub.new()
	root.add_child(runtime.renderer)
	root.add_child(runtime.population)
	root.add_child(runtime.tracks)
	root.add_child(runtime.wagon)
	root.add_child(runtime.object_identification_bubble)
	var entrance := {
		"feature_id": "way/test", "building_name": "Test Building",
		"world_position": Vector2(500, 600), "record": {"name": "Test Building"},
		"floor": floor, "link": link
	}
	runtime._enter_interior(entrance)
	assert(runtime.inside_building_id == "way/test" and runtime.player.interior_mode, "E interaction did not enter the building.")
	assert(runtime.player.position == layer.exit_position, "The player did not arrive at the saved interior entry point.")
	assert(layer.discovered_components.size() == 1, "An internal room was visible before the player entered it.")
	assert(layer.furniture_at_world(Vector2(24.0, 6.0)).is_empty(), "Furniture in an undiscovered room remained visible or clickable.")
	var hidden_population = PopulationScript.new()
	hidden_population.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(hidden_population)
	hidden_population.agents.assign([{"kind": "person", "space": "interior", "building_id": "way/test", "floor_id": "ground_floor", "position": Vector2(24.0, 12.0), "phase": 0.0, "angle": 0.0, "moving": false, "npc_asset": "npc_medium_man_adult"}])
	hidden_population.set_active_interior("way/test", "ground_floor")
	hidden_population.set_interior_visibility_check(layer.is_position_discovered)
	assert(hidden_population.nearest_conversation_target(Vector2(20.0, 12.0), 20.0).is_empty(), "An NPC concealed by room fog could still be selected.")
	runtime.player.position = Vector2(11.0, 12.0)
	var use_door := InputEventKey.new()
	use_door.keycode = KEY_E
	use_door.pressed = true
	runtime._unhandled_input(use_door)
	assert(runtime.inside_building_id == "way/test" and runtime.player.position.x > 14.0, "Pressing E near the internal doorway did not enter the room: position=%s notice=%s" % [runtime.player.position, runtime.notice_text])
	assert(layer.discovered_components.size() == 2, "The room did not become visible after the player entered through its doorway.")
	assert(str(layer.furniture_at_world(Vector2(24.0, 6.0)).get("object_type", "")) == "sofa", "Discovered furniture did not become visible and clickable.")
	assert(not hidden_population.nearest_conversation_target(runtime.player.position, 20.0).is_empty(), "The discovered room NPC did not become selectable.")
	assert(layer.current_room_name(runtime.player.position) == "Hidden room", "The entered room name was not available for the top building heading.")
	layer.floor_data.walls[0].doors[0]["locked"] = true
	runtime.player.position = Vector2(11.0, 12.0)
	runtime._try_internal_door()
	assert(runtime.player.position == Vector2(11.0, 12.0), "The player crossed a locked internal door.")
	assert(runtime.object_identification_bubble.message == "The door is locked.", "Trying a locked door did not show a player speech bubble.")
	layer.floor_data.walls[0].doors[0]["locked"] = false
	runtime.player.position = layer.exit_position
	runtime._try_exit_interior()
	assert(runtime.inside_building_id.is_empty() and not runtime.player.interior_mode, "E interaction did not exit the building.")
	assert(runtime.player.position == Vector2(500, 600), "Exiting did not return the player to the exterior arrow.")
	print("RUNTIME INTERIORS PASSED: fog-hidden furniture/NPCs, reveal and targeting, footprint confinement, E-only and locked doors, saved entry and exterior return.")
	runtime.player.queue_free()
	layer.queue_free()
	runtime.renderer.queue_free()
	runtime.population.queue_free()
	runtime.tracks.queue_free()
	runtime.wagon.queue_free()
	runtime.object_identification_bubble.queue_free()
	hidden_population.queue_free()
	await process_frame
	quit(0)
