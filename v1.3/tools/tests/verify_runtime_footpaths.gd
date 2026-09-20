extends SceneTree

const RuntimeScene = preload("res://scenes/runtime/town_runtime.tscn")
const RoadDimensionsScript = preload("res://scripts/roads/road_dimensions.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime = RuntimeScene.instantiate()
	root.add_child(runtime)
	await process_frame
	assert(runtime.population != null, "The imported town did not create its population.")
	var walking_routes := 0
	var blocked_routes := 0
	var missing_source_roads := 0
	for agent_value in runtime.population.agents:
		var agent: Dictionary = agent_value
		if str(agent.get("kind", "")) not in ["person", "robot"]:
			continue
		if str(agent.get("route_phase", "")) == "blocked":
			blocked_routes += 1
			continue
		var graph: Dictionary = runtime.population.graphs.person
		var edge: Dictionary = graph.edge_by_pair.get("%d>%d" % [int(agent.node), int(agent.target_node)], {})
		var tags: Dictionary = runtime.population.road_tags_by_id.get(str(edge.get("source_way_id", "")), {})
		if tags.is_empty() and str(edge.get("highway", "")) not in RoadDimensionsScript.WALKING_HIGHWAYS:
			missing_source_roads += 1
		if tags.is_empty() or RoadDimensionsScript.is_walkway(tags) or bool(edge.get("bridge", false)) or bool(edge.get("tunnel", false)):
			continue
		var centre_start: Vector2 = graph.nodes[int(agent.node)]
		var centre_end: Vector2 = graph.nodes[int(agent.target_node)]
		var distance := Vector2(agent.target).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(agent.target), centre_start, centre_end))
		assert(distance >= 3.0, "A ground NPC/NPR still targeted the middle of a vehicle road.")
		walking_routes += 1
	assert(walking_routes > 0, "The imported town did not exercise a road-edge walking route.")
	assert(missing_source_roads == 0, "A generated walking road lost the OSM geometry needed for its roadside offset.")
	print("FOOTPATH RUNTIME PASSED: %d NPC/NPR road-edge routes; %d blocked routes held safely." % [walking_routes, blocked_routes])
	quit(0)
