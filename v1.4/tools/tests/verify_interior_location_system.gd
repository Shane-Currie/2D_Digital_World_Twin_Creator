extends SceneTree

const InteriorStoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const InteriorCanvasScript = preload("res://scripts/interiors/interior_floor_canvas.gd")
const InteriorLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const PersonaStoreScript = preload("res://scripts/npcs/persona_store.gd")
const StorylineStoreScript = preload("res://scripts/npcs/storyline_npc_store.gd")
const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")
const TownRuntimeScript = preload("res://scripts/runtime/town_runtime.gd")
const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var interior_store = InteriorStoreScript.new()
	var interior_data := {
		"schema_version": 1, "kind": "creator_building_interiors",
		"buildings": {"way/inside-test": {
			"feature_id": "way/inside-test", "name": "Test Hall",
			"floors": [{
				"id": "ground_floor", "name": "Ground floor", "level": 0,
				"width_metres": 20.0, "height_metres": 12.0, "footprint_scale": 1.0,
				"boundary_metres": [[0, 0], [20, 0], [20, 12], [0, 12]],
				"holes_metres": [[[8, 4], [12, 4], [12, 8], [8, 8]]],
				"entry_links": []
			}]
		}}
	}
	var location := {"space": "interior", "building_id": "way/inside-test", "floor_id": "ground_floor", "x_metres": 4.25, "y_metres": 6.5}
	assert(interior_store.validate(interior_data).ok, "The synthetic interior was not valid.")
	assert(interior_store.validate_location(interior_data, location).ok, "A clear point inside the floor was rejected.")
	var courtyard_location := location.duplicate(true)
	courtyard_location.x_metres = 10.0
	assert(not interior_store.validate_location(interior_data, courtyard_location).ok, "A storyline location was allowed inside a courtyard hole.")

	var copied_text := StorylineStoreScript.format_interior_location("way/inside-test", "ground_floor", Vector2(4.25, 6.5))
	var parsed := StorylineStoreScript.parse_location_text(copied_text)
	assert(parsed.ok and parsed.location.building_id == "way/inside-test" and is_equal_approx(float(parsed.location.x_metres), 4.25), "The copied interior location did not paste back reliably.")
	var persona_data := PersonaStoreScript.recommended_data()
	var add_result := StorylineStoreScript.new().add_interior_npc(StorylineStoreScript.empty_data(), parsed.location, "test_town", persona_data, "Indigo Hall", "friendly_local")
	assert(add_result.ok, str(add_result.get("message", "Could not add the interior storyline NPC.")))
	var validation := StorylineStoreScript.validate(add_result.data, {}, [], persona_data, false, interior_data)
	assert(validation.passed, str(validation.errors[0]) if not validation.errors.is_empty() else "Interior storyline validation failed.")

	var canvas = InteriorCanvasScript.new()
	root.add_child(canvas)
	canvas.size = Vector2(520, 420)
	canvas.set_floor(interior_data.buildings["way/inside-test"].floors[0])
	var selected_position := [Vector2.INF]
	canvas.storyline_location_requested.connect(func(value: Vector2): selected_position[0] = value)
	canvas.begin_storyline_location_placement()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = canvas._metres_to_screen(Vector2(4.25, 6.5))
	canvas._gui_input(click)
	assert(Vector2(selected_position[0]).distance_to(Vector2(4.25, 6.5)) < 0.02, "Interior Designer did not return metre coordinates from the selected floor point.")

	var navigation := {
		"vehicle": {"nodes": [], "edges": []},
		"pedestrian": {"nodes": [], "edges": []},
		"aerial": {"nodes": [], "edges": []}
	}
	var settings := {
		"road_rules": {"driving_side": "left"},
		"skin_tone_distribution": {"light_percent": 34, "medium_percent": 33, "dark_percent": 33},
		"population": {"traffic_car_count": 0, "pedestrian_count": 0, "robot_count": 0, "drone_count": 0, "cbd_car_percent": 0, "cbd_pedestrian_percent": 0, "cbd_robot_percent": 0, "cbd_drone_percent": 0}
	}
	var projection := {"origin_longitude": 149.0, "origin_latitude": -35.0, "longitude_metres_per_degree": 91200.0, "latitude_metres_per_degree": 110540.0}
	var cbd := {"west": 149.0, "east": 149.1, "south": -35.1, "north": -35.0}
	var population = PopulationScript.new()
	root.add_child(population)
	population.set_persona_library(persona_data)
	population.set_storyline_npcs(add_result.data)
	population.setup(navigation, settings, projection, 2.0, cbd, "test_town")
	assert(population.agents.size() == 1 and str(population.agents[0].space) == "interior", "The saved interior storyline NPC was not loaded into gameplay.")
	assert(str(population.agents[0].floor_id) == "ground_floor", "The ground-floor storyline placement was not retained.")
	assert(population.nearest_conversation_target(Vector2(8.5, 13.0), 30.0).is_empty(), "An interior NPC leaked into the outdoor world.")
	population.set_active_interior("way/inside-test", "ground_floor")
	population.set_draw_view(Vector2(8000, 8000), 2.7, false)
	assert(not population._draws_position(Vector2(population.agents[0].position)), "The regression setup did not reproduce stale outdoor camera culling.")
	population.set_draw_view(Vector2(population.agents[0].position), 2.7, false)
	assert(population._draws_position(Vector2(population.agents[0].position)), "The ground-floor NPC remained culled after the interior camera view was applied.")
	var target := population.nearest_conversation_target(Vector2(8.5, 13.0), 30.0)
	assert(not target.is_empty(), "The interior storyline NPC was not available on its saved floor.")

	var layer = InteriorLayerScript.new()
	root.add_child(layer)
	layer.pixels_per_metre = 2.0
	var player = PlayerScript.new()
	root.add_child(player)
	player.position = Vector2(8.5, 13.0)
	var runtime = TownRuntimeScript.new()
	runtime.inside_building_id = "way/inside-test"
	runtime.inside_building_name = "Test Hall"
	runtime.inside_floor_id = "ground_floor"
	runtime.inside_floor_name = "Ground floor"
	runtime.interior_layer = layer
	runtime.player = player
	var interior_map_location := runtime._map_location_for_world(player.position)
	assert(str(interior_map_location.display).contains("Building: way/inside-test") and str(interior_map_location.display).contains("Floor: ground_floor") and str(interior_map_location.display).contains("Cursor X: 4.25 m") and str(interior_map_location.display).contains("Y: 6.50 m"), "The interior map cursor lost its stable IDs or metre coordinates.")
	var pasted_interior := StorylineStoreScript.parse_location_text(str(interior_map_location.copy))
	assert(pasted_interior.ok and str(pasted_interior.location.floor_id) == "ground_floor", "The interior map did not copy plain paste-ready ground-floor details.")
	runtime.inside_building_id = ""
	runtime.collision_data = {"projection": projection, "runtime_scale": {"pixels_per_metre": 2.0}}
	var outdoor_geographic := Vector2(149.012345, -35.023456)
	var outdoor_world := ProjectionScript.geographic_to_world(outdoor_geographic, projection, 2.0)
	var outdoor_map_location := runtime._map_location_for_world(outdoor_world)
	assert(Vector2(outdoor_map_location.geographic).distance_to(outdoor_geographic) < 0.000001, "The outdoor mouse position did not convert back to latitude/longitude.")
	var pasted_outdoor := StorylineStoreScript.parse_location_text(str(outdoor_map_location.copy))
	assert(pasted_outdoor.ok and absf(float(pasted_outdoor.location.latitude) - outdoor_geographic.y) < 0.000001, "The outdoor map did not copy plain Notepad/storyline-compatible latitude and longitude.")

	canvas.queue_free()
	population.queue_free()
	layer.queue_free()
	player.queue_free()
	await process_frame
	print("INTERIOR LOCATIONS PASSED: ground floor included; Creator selection/copy, runtime indoor/outdoor mouse-map locations, plain clipboard text, safe placement, interior-camera visibility and conversation targeting.")
	quit(0)
