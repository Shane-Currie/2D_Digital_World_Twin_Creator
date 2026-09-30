extends SceneTree

const InteriorLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")
const TownRuntimeScript = preload("res://scripts/runtime/town_runtime.gd")


class RendererStub extends Node2D:
	func is_ground_traversable(_position: Vector2, _clearance := 0.0) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor := {
		"id": "ground_floor", "name": "Ground floor", "level": 0,
		"width_metres": 20.0, "height_metres": 12.0,
		"boundary_metres": [[0, 0], [20, 0], [20, 12], [0, 12]],
		"holes_metres": [[[8, 4], [12, 4], [12, 8], [8, 8]]],
		"entry_links": []
	}
	var link := {"exterior_entrance_id": "entrance_1", "spawn_x_metres": 2.0, "spawn_y_metres": 6.0}
	var layer = InteriorLayerScript.new()
	root.add_child(layer)
	var opened: Dictionary = layer.open_floor({"name": "Test Building"}, floor, link, 2.0)
	assert(opened.ok, str(opened.get("message", "")))
	assert(layer.is_traversable(Vector2(opened.position), 4.0), "The arrival point is not safely inside the footprint-shaped floor.")
	assert(not layer.is_traversable(Vector2(20, 12), 0.0), "The courtyard hole became walkable.")
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
	root.add_child(runtime.renderer)
	root.add_child(runtime.population)
	root.add_child(runtime.tracks)
	root.add_child(runtime.wagon)
	var entrance := {
		"feature_id": "way/test", "building_name": "Test Building",
		"world_position": Vector2(500, 600), "record": {"name": "Test Building"},
		"floor": floor, "link": link
	}
	runtime._enter_interior(entrance)
	assert(runtime.inside_building_id == "way/test" and runtime.player.interior_mode, "E interaction did not enter the building.")
	assert(runtime.player.position == layer.exit_position, "The player did not arrive at the saved interior entry point.")
	runtime._try_exit_interior()
	assert(runtime.inside_building_id.is_empty() and not runtime.player.interior_mode, "E interaction did not exit the building.")
	assert(runtime.player.position == Vector2(500, 600), "Exiting did not return the player to the exterior arrow.")
	print("RUNTIME INTERIORS PASSED: footprint confinement, courtyard blocking, saved entry transfer and exterior return.")
	runtime.player.queue_free()
	layer.queue_free()
	runtime.renderer.queue_free()
	runtime.population.queue_free()
	runtime.tracks.queue_free()
	runtime.wagon.queue_free()
	await process_frame
	quit(0)
