extends SceneTree

const DestinationScript = preload("res://scripts/population/osm_population_destinations.gd")
const BuildingInformationScript = preload("res://scripts/places/osm_building_information.gd")
const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")


func _initialize() -> void:
	var features := [
		_building("home", {"building": "house", "name": "Mapped Home"}, 146.9000, -36.0800),
		_building("school", {"building": "yes", "amenity": "school", "name": "Mapped School"}, 146.9010, -36.0800),
		_building("shop", {"building": "retail", "shop": "bakery", "name": "Mapped Bakery"}, 146.9020, -36.0800),
		_building("unknown", {"building": "yes"}, 146.9030, -36.0800),
		_building("far", {"building": "hospital", "amenity": "hospital"}, 147.5000, -36.5000)
	]
	var pedestrian_nodes := []
	for index in 4:
		pedestrian_nodes.append({"id": index, "longitude": 146.9000 + index * 0.0010, "latitude": -36.0800})
	var navigation := {"pedestrian": {"nodes": pedestrian_nodes}}
	var places: Dictionary = BuildingInformationScript.new().build(features).data
	var built: Dictionary = DestinationScript.new().build(features, navigation, places)
	assert(built.ok)
	assert(built.data.destinations.size() == 3, "Unknown and unlinked buildings must not become destinations.")
	assert(built.data.statistics.category_counts == {"residential": 1, "education": 1, "retail": 1})
	assert(built.data.statistics.tagged_footprints_without_nearby_pedestrian_route == 1)
	for destination in built.data.destinations:
		assert(destination.source_attribution == "© OpenStreetMap contributors")
		assert(destination.entrance_status == "not_mapped_or_not_selected")
		assert(float(destination.route_link_distance_metres) <= 250.0)

	var positions := {0: Vector2(0, 0), 1: Vector2(10, 0), 2: Vector2(20, 0), 3: Vector2(30, 0)}
	var adjacency := {0: [1], 1: [0, 2], 2: [1, 3], 3: [2]}
	var edge_by_pair := {}
	for from_node in adjacency:
		for to_node in adjacency[from_node]:
			edge_by_pair["%d>%d" % [from_node, to_node]] = {"crossing": false, "bridge": false, "tunnel": false}
	var graph := {
		"nodes": positions, "adjacency": adjacency, "edge_by_pair": edge_by_pair,
		"all_ids": [0, 1, 2, 3], "cbd_ids": [0, 1, 2, 3], "control_by_node": {},
		"component_by_node": {0: 0, 1: 0, 2: 0, 3: 0},
		"geographic_by_node": {0: Vector2.ZERO, 1: Vector2.ZERO, 2: Vector2.ZERO, 3: Vector2.ZERO}
	}
	graph.nodes[4] = Vector2(1000, 1000)
	graph.adjacency[4] = []
	graph.component_by_node[4] = 1
	var destination_fixture: Dictionary = built.data.duplicate(true)
	var isolated: Dictionary = destination_fixture.destinations[2].duplicate(true)
	isolated.id = "isolated-destination"
	isolated.pedestrian_node_id = 4
	destination_fixture.destinations.append(isolated)
	var population = PopulationScript.new()
	population.graphs = {"person": graph, "traffic": graph}
	population.rng.seed = 1409
	population.skin_tone_distribution = {"light_percent": 34, "medium_percent": 33, "dark_percent": 33}
	population._prepare_population_destinations(destination_fixture)
	assert(population._destinations_in_agent_component({"node": 0}, population.population_destinations).size() == 3, "Disconnected destinations were offered to the wrong walking section.")
	population._add_population("person", 4, 0, 30.0)
	population._add_population("robot", 2, 0, 27.0)
	for agent in population.agents:
		assert(bool(agent.destination_routing), "NPC/NPR did not use mapped destinations.")
		assert(int(agent.destination_node) >= 0)
		assert(not str(agent.destination_category).is_empty())
		assert(str(agent.destination_id) != "isolated-destination")
		assert(str(agent.destination_category) != "residential", "Initial trip should leave home for an activity when one exists.")
	var route := population._find_route(graph, 0, 3)
	assert(route == [0, 1, 2, 3], "Destination routing did not follow the imported pedestrian graph.")
	population.free()

	var town_path := _argument_value("--town")
	var actual_message := ""
	if not town_path.is_empty():
		var feature_data: Dictionary = _read_json(town_path.path_join("data/map_features.json"))
		var navigation_data: Dictionary = _read_json(town_path.path_join("data/navigation_graphs.json"))
		var place_data: Dictionary = _read_json(town_path.path_join("data/place_information.json"))
		var actual: Dictionary = DestinationScript.new().build(feature_data.get("features", []), navigation_data, place_data).data
		assert(int(actual.statistics.destination_count) > 0, "The real map produced no usable destinations.")
		assert(int(actual.statistics.category_counts.get("residential", 0)) > 0, "The real map produced no homes.")
		var town_data := _read_json(town_path.path_join("town.json"))
		var collision_data := _read_json(town_path.path_join("data/building_collisions.json"))
		var settings_data := _read_json(town_path.path_join("game_settings.json"))
		var actual_population = PopulationScript.new()
		actual_population.setup(
			navigation_data, settings_data, collision_data.projection,
			float(collision_data.runtime_scale.pixels_per_metre), town_data.cbd.bounds,
			str(town_data.id), town_data.map_bounds, feature_data.features, actual
		)
		var routed_walkers := 0
		var walkers := 0
		for actual_agent in actual_population.agents:
			if str(actual_agent.kind) in ["person", "robot"]:
				walkers += 1
				if bool(actual_agent.get("destination_routing", false)):
					routed_walkers += 1
		assert(routed_walkers > 0, "The real map destinations were not assigned to any NPC/NPR.")
		actual_population.free()
		actual_message = " Real map: %d destinations across %d categories; %d/%d walkers received reachable destination travel." % [int(actual.statistics.destination_count), actual.statistics.category_counts.size(), routed_walkers, walkers]
	print("POPULATION DESTINATIONS PASSED: direct OSM uses, route links, truthful unknowns, graph routes and NPC/NPR destination assignment.%s" % actual_message)
	quit(0)


func _building(id: String, tags: Dictionary, longitude: float, latitude: float) -> Dictionary:
	var half := 0.00005
	return {
		"id": id, "kind": "building", "tags": tags,
		"points": [
			[longitude - half, latitude - half], [longitude + half, latitude - half],
			[longitude + half, latitude + half], [longitude - half, latitude + half],
			[longitude - half, latitude - half]
		],
		"holes": []
	}


func _read_json(path_value: String) -> Dictionary:
	var file := FileAccess.open(path_value, FileAccess.READ)
	assert(file != null, "Could not read %s" % path_value)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "Invalid JSON in %s" % path_value)
	return parsed


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index] == name and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""
