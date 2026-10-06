extends SceneTree

const ProjectLoaderScript = preload("res://scripts/content/project_loader.gd")
const MapOverrideStoreScript = preload("res://scripts/editor/map_override_store.gd")
const PersonaStoreScript = preload("res://scripts/npcs/persona_store.gd")
const StorylineNpcStoreScript = preload("res://scripts/npcs/storyline_npc_store.gd")
const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")
const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var town_index := arguments.find("--town")
	assert(town_index >= 0 and town_index + 1 < arguments.size(), "Pass --town followed by a Creator Studio town directory.")
	var town_directory: String = arguments[town_index + 1]
	var project_result := ProjectLoaderScript.new().load_project(town_directory)
	assert(project_result.ok, str(project_result.get("message", "Could not load project.")))
	var town: Dictionary = project_result.town
	var imported: Dictionary = project_result.import_result
	var persona_result := PersonaStoreScript.new().load_from_town(town_directory)
	assert(persona_result.ok, str(persona_result.get("message", "Could not load personas.")))
	var override_result := MapOverrideStoreScript.new().load_from_town(town_directory, imported.features, imported.bounds)
	assert(override_result.ok, str(override_result.get("message", "Could not load map corrections.")))
	var applied := MapOverrideStoreScript.new().apply(imported.features, override_result.data)
	assert(applied.ok, str(applied.get("message", "Could not apply map corrections.")))
	var start: Dictionary = town.starting_location
	var location := {"latitude": float(start.latitude), "longitude": float(start.longitude)}
	var parsed_coordinates := StorylineNpcStoreScript.parse_coordinate_text("Latitude: %.8f, Longitude: %.8f" % [location.latitude, location.longitude])
	assert(parsed_coordinates.ok and is_equal_approx(float(parsed_coordinates.location.latitude), float(location.latitude)), "Copied coordinate text could not be pasted back into the creator.")
	var add_result := StorylineNpcStoreScript.new().add_random_outdoor_npc(StorylineNpcStoreScript.empty_data(), location, str(town.id), persona_result.data)
	assert(add_result.ok, str(add_result.get("message", "Could not create the storyline NPC.")))
	var named_result := StorylineNpcStoreScript.new().add_outdoor_npc(StorylineNpcStoreScript.empty_data(), location, str(town.id), persona_result.data, "Morgan Vale", "friendly_local")
	assert(named_result.ok, str(named_result.get("message", "Could not create a named storyline NPC.")))
	assert(str(named_result.npc.display_name) == "Morgan Vale" and str(named_result.npc.persona_id) == "friendly_local", "The provided name or compatible persona was not retained.")
	var duplicate_name := StorylineNpcStoreScript.new().add_outdoor_npc(named_result.data, location, str(town.id), persona_result.data, "Morgan Vale", "friendly_local")
	assert(not duplicate_name.ok, "Two storyline NPCs were allowed to use the same custom name.")
	var incompatible_persona := StorylineNpcStoreScript.new().add_outdoor_npc(StorylineNpcStoreScript.empty_data(), location, str(town.id), persona_result.data, "Unit Test", "civic_robot")
	assert(not incompatible_persona.ok, "A human storyline NPC accepted an NPR robot persona.")
	var validation := StorylineNpcStoreScript.validate(add_result.data, imported.bounds, applied.features, persona_result.data)
	assert(validation.passed, str(validation.errors[0]) if not validation.errors.is_empty() else "Storyline NPC validation failed.")
	var navigation := _read_json(town_directory.path_join("data/navigation_graphs.json"))
	navigation["pedestrian"]["nodes"] = [{"id": 0, "longitude": location.longitude, "latitude": location.latitude, "control": ""}]
	assert(StorylineNpcStoreScript.validate_pedestrian_reachability(location, navigation).ok, "The selected point did not link to its nearby pedestrian route.")
	var distant_navigation := navigation.duplicate(true)
	distant_navigation["pedestrian"]["nodes"] = [{"id": 0, "longitude": float(location.longitude) + 1.0, "latitude": location.latitude, "control": ""}]
	assert(not StorylineNpcStoreScript.validate_pedestrian_reachability(location, distant_navigation).ok, "A storyline point far from every pedestrian route was accepted.")
	var collisions := _read_json(town_directory.path_join("data/building_collisions.json"))
	var settings := _read_json(town_directory.path_join("game_settings.json"))
	settings["population"] = {"traffic_car_count": 0, "pedestrian_count": 0, "robot_count": 0, "drone_count": 0, "cbd_car_percent": 0, "cbd_pedestrian_percent": 0, "cbd_robot_percent": 0, "cbd_drone_percent": 0}
	var population := PopulationScript.new()
	root.add_child(population)
	population.set_persona_library(persona_result.data)
	population.set_storyline_npcs(add_result.data)
	population.set_ground_check(func(_position: Vector2, _clearance := 0.0): return true)
	population.setup(navigation, settings, collisions.projection, float(collisions.runtime_scale.pixels_per_metre), town.cbd.bounds, str(town.id), town.map_bounds, applied.features)
	assert(population.agents.size() == 1, "The saved storyline NPC was not added to the playable population.")
	var agent: Dictionary = population.agents[0]
	assert(str(agent.storyline_npc_id) == str(add_result.npc.id) and bool(agent.storyline_stationary), "The persistent storyline identity or stationary placement was lost.")
	assert(not ActorArt.sprite(str(agent.npc_asset)).is_empty(), "The random storyline NPC artwork could not load.")
	var expected_position := ProjectionScript.geographic_to_world(Vector2(location.longitude, location.latitude), collisions.projection, float(collisions.runtime_scale.pixels_per_metre))
	assert(Vector2(agent.position).is_equal_approx(expected_position), "Latitude and longitude did not reproduce the saved outdoor position.")
	assert(population.begin_conversation(0, expected_position + Vector2(10, 0)), "The storyline NPC could not enter the existing local-LLM conversation flow.")
	population.end_conversation(0)
	population._process(1.0)
	assert(Vector2(population.agents[0].position).is_equal_approx(expected_position), "A stationary storyline NPC wandered away from its creator-selected location.")
	print("STORYLINE NPC PASSED: copied coordinates, optional named identity/persona, random fallback/art, persistence and playable conversation target.")
	quit(0)


func _read_json(path_value: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	assert(parsed is Dictionary, "%s was not readable JSON." % path_value.get_file())
	return parsed
