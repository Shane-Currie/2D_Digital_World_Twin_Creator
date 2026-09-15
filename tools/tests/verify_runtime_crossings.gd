extends SceneTree

const NavigationBuilder = preload("res://scripts/navigation/osm_navigation_builder.gd")
const CrossingSafety = preload("res://scripts/runtime/pedestrians/runtime_crossing_safety.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
const TrafficFlow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
const PlayerVehicle = preload("res://scripts/runtime/runtime_player_vehicle.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var builder = NavigationBuilder.new()
	var mapped_crossing: Dictionary = builder._edge(0, 1, 2, 10.0, {"id": "way:crossing", "tags": {"highway": "footway", "footway": "crossing"}}, "footway", false)
	var ordinary_walk: Dictionary = builder._edge(1, 1, 2, 10.0, {"id": "way:path", "tags": {"highway": "footway"}}, "footway", false)
	assert(mapped_crossing.crossing and not ordinary_walk.crossing, "Only OSM-marked road-spanning ways may activate crossing safety.")
	var safety = CrossingSafety.new()
	var walker := {"kind": "robot", "walker_id": 7, "node": 1, "target_node": 2, "position": Vector2(0, -40), "target": Vector2(0, 40), "speed": 30.0, "route_crossing": true, "crossing_committed": false}
	var car := {"kind": "traffic", "traffic_id": 2, "node": 10, "target_node": 11, "position": Vector2(-50, 0), "target": Vector2(50, 0), "speed": 55.0, "route_bridge": false, "route_tunnel": false}
	var road_users: Array[Dictionary] = [car, walker]
	assert(not safety.can_begin(walker.position, walker.target, walker.speed, road_users, null), "An NPR walked into an approaching car.")
	assert(safety.denied_crossings == 1)
	car.position = Vector2(-250, 0)
	car.target = Vector2(-150, 0)
	assert(safety.can_begin(walker.position, walker.target, walker.speed, road_users, null), "A car far from the crossing blocked it.")
	var wagon = PlayerVehicle.new()
	root.add_child(wagon)
	wagon.position = Vector2(-30, 0)
	wagon.rotation = -PI / 2.0
	wagon.speed = 40.0
	wagon.occupied = true
	assert(not safety.can_begin(walker.position, walker.target, walker.speed, road_users, wagon), "The owned car's approach was ignored before a crossing.")
	wagon.occupied = false
	assert(safety.can_begin(walker.position, walker.target, walker.speed, road_users, wagon), "An empty owned car blocked a walking link as if it were moving.")
	wagon.queue_free()
	safety.reserve(walker)
	assert(walker.crossing_committed)
	var flow = TrafficFlow.new()
	car.position = Vector2(-18, 0)
	car.target = Vector2(50, 0)
	var empty_graph := {"degree": {11: 2}}
	var no_obstacles: Array[Node2D] = []
	assert(not flow.can_move(car, road_users, Vector2(0, 0), empty_graph, no_obstacles, 0.0, 0.1, safety), "A car did not yield after a walker committed.")
	assert(str(car.blocked_reason) == "Pedestrian crossing")
	car.waiting_seconds = 30.0
	var recovery_rng := RandomNumberGenerator.new()
	var recovery_graph := {"nodes": {11: Vector2(900, 0)}, "adjacency": {11: [10]}, "all_ids": [11]}
	assert(not flow.update_wait_and_recover(car, 0.1, 31.0, recovery_graph, road_users, no_obstacles, recovery_rng), "A car legally yielding to a committed walker was treated as jammed.")
	safety.release(walker, true)
	assert(safety.completed_crossings == 1 and safety.reservations.is_empty())
	assert(flow.can_move(car, road_users, Vector2(0, 0), empty_graph, no_obstacles, 0.0, 0.1, safety), "A finished crossing did not release traffic.")
	car.route_bridge = true
	safety.reserve(walker)
	assert(flow.can_move(car, road_users, Vector2(0, 0), empty_graph, no_obstacles, 0.0, 0.1, safety), "A different-level bridge car yielded to a surface crossing.")
	safety.release(walker)
	car.route_bridge = false
	var population = Population.new()
	root.add_child(population)
	population.set_process(false)
	population.visible = false
	population.graphs = {"person": {"nodes": {1: walker.position, 2: walker.target}, "adjacency": {1: [2]}, "edge_by_pair": {"1>2": mapped_crossing}, "all_ids": [1]}}
	var npr := {"kind": "robot", "walker_id": 9, "graph_key": "person", "node": 1, "target_node": 1, "position": walker.position, "target": walker.position, "speed": 30.0, "phase": 0.0, "crossing_committed": false}
	population.agents.clear()
	population.agents.append(npr)
	population._choose_next(npr)
	assert(npr.route_crossing, "NPR did not inherit the mapped pedestrian crossing rule.")
	population.agents.append(car)
	car.position = Vector2(-20, 0)
	car.target = Vector2(60, 0)
	population._advance_agent(npr, 0.25)
	assert(npr.position == walker.position and not npr.crossing_committed, "An NPR entered a crossing while traffic approached.")
	car.position = Vector2(-250, 0)
	car.target = Vector2(-150, 0)
	population._advance_agent(npr, 0.25)
	assert(npr.crossing_committed, "A clear NPR crossing was not reserved before movement.")
	car.position = Vector2(-5, 0)
	car.target = Vector2.ZERO
	car.angle = 0.0
	car.waiting_seconds = 0.0
	car.target_node = 11
	car.graph_key = "traffic"
	population.graphs.traffic = {"nodes": {11: Vector2.ZERO}, "adjacency": {11: []}, "all_ids": [11], "degree": {11: 2}}
	population._advance_traffic(car, 0.25)
	assert(car.position == Vector2(-5, 0) and str(car.blocked_reason) == "Pedestrian crossing", "A short final car hop skipped the committed walker reservation.")
	population.crossing_safety.release(npr)
	population.graphs.person.nodes[3] = Vector2(-30, -40)
	population.graphs.person.adjacency[1] = [2, 3]
	population.graphs.person.edge_by_pair["1>3"] = ordinary_walk
	population._choose_next(npr, true)
	assert(npr.target_node == 3 and not npr.route_crossing, "A long-waiting walker failed to try a non-crossing link.")
	population.queue_free()
	print("RUNTIME CROSSINGS PASSED: OSM-tagged links, car/wagon gap, NPR commitment, NPC yield/release, short endpoint hop and bridge separation")
	quit(0)
