extends SceneTree

const ProjectLoaderScript = preload("res://scripts/content/project_loader.gd")
const MapOverrideStoreScript = preload("res://scripts/editor/map_override_store.gd")
const PersonaStoreScript = preload("res://scripts/npcs/persona_store.gd")
const InteriorStoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const StorylineStoreScript = preload("res://scripts/npcs/storyline_npc_store.gd")
const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var town_index := arguments.find("--town")
	assert(town_index >= 0 and town_index + 1 < arguments.size(), "Pass --town followed by the Albury town directory.")
	var town_directory: String = arguments[town_index + 1]
	var project := ProjectLoaderScript.new().load_project(town_directory)
	assert(project.ok, str(project.get("message", "Could not load the town.")))
	var persona_result := PersonaStoreScript.new().load_from_town(town_directory)
	var interior_result := InteriorStoreScript.new().load_from_town(town_directory)
	assert(persona_result.ok and interior_result.ok, "Could not load personas or interiors.")
	var override_load := MapOverrideStoreScript.new().load_from_town(town_directory, project.import_result.features, project.import_result.bounds)
	assert(override_load.ok, str(override_load.get("message", "Could not load map corrections.")))
	var effective := MapOverrideStoreScript.new().apply(project.import_result.features, override_load.data)
	assert(effective.ok, str(effective.get("message", "Could not apply map corrections.")))
	var storyline_result := StorylineStoreScript.new().load_from_town(town_directory, project.town.map_bounds, effective.features, persona_result.data, interior_result.data)
	assert(storyline_result.ok, str(storyline_result.get("message", "Could not load storyline NPCs.")))
	var saved_npc: Dictionary = {}
	for value in storyline_result.data.get("npcs", []):
		if value is Dictionary and str(value.get("display_name", "")).to_lower() == "kekie":
			saved_npc = value
			break
	assert(not saved_npc.is_empty(), "Kekie was not saved in Albury's storyline data.")
	assert(str(saved_npc.location.space) == "interior" and str(saved_npc.location.floor_id) == "ground_floor", "Kekie is not assigned to the ground floor.")

	var collision_data := _read_json(town_directory.path_join("data/building_collisions.json"))
	var navigation := _read_json(town_directory.path_join("data/navigation_graphs.json"))
	var settings := _read_json(town_directory.path_join("game_settings.json"))
	# This is a placement/visibility check; omit ordinary populations for speed.
	settings["population"] = {"traffic_car_count": 0, "pedestrian_count": 0, "robot_count": 0, "drone_count": 0, "cbd_car_percent": 0, "cbd_pedestrian_percent": 0, "cbd_robot_percent": 0, "cbd_drone_percent": 0}
	var population = PopulationScript.new()
	root.add_child(population)
	population.set_persona_library(persona_result.data)
	population.set_storyline_npcs(storyline_result.data)
	population.set_ground_check(func(_position: Vector2, _clearance := 0.0): return true)
	population.setup(navigation, settings, collision_data.projection, float(collision_data.runtime_scale.pixels_per_metre), project.town.cbd.bounds, str(project.town.id), project.town.map_bounds, effective.features)
	var kekie_agent: Dictionary = {}
	for agent in population.agents:
		if str(agent.get("display_name", "")).to_lower() == "kekie":
			kekie_agent = agent
			break
	assert(not kekie_agent.is_empty(), "Kekie was filtered out while creating the playable population.")
	population.set_active_interior(str(saved_npc.location.building_id), "ground_floor")
	population.set_draw_view(Vector2(kekie_agent.position), 2.7, false)
	assert(population._agent_in_active_space(kekie_agent) and population._draws_position(Vector2(kekie_agent.position)), "Kekie was still hidden by outdoor camera culling on the ground floor.")
	var building: Dictionary = interior_result.data.buildings[str(saved_npc.location.building_id)]
	var floor: Dictionary = InteriorStoreScript.floor_by_id(building, "ground_floor")
	var entry: Dictionary = floor.get("entry_links", [])[0]
	var entry_metres := Vector2(float(entry.spawn_x_metres), float(entry.spawn_y_metres))
	var npc_metres := Vector2(float(saved_npc.location.x_metres), float(saved_npc.location.y_metres))
	print("SAVED INTERIOR NPC PASSED: Kekie is visible on ground_floor at X %.2f Y %.2f, %.1f metres from the entrance." % [npc_metres.x, npc_metres.y, npc_metres.distance_to(entry_metres)])
	population.queue_free()
	await process_frame
	quit(0)


func _read_json(path_value: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	assert(parsed is Dictionary, "%s is not readable JSON." % path_value.get_file())
	return parsed
