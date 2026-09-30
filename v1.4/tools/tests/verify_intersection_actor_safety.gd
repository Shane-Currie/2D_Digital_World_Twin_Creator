extends SceneTree

const Collision = preload("res://scripts/runtime/traffic/runtime_actor_collision.gd")
const Flow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
const Safety = preload("res://scripts/runtime/pedestrians/runtime_crossing_safety.gd")
const Vehicle = preload("res://scripts/runtime/runtime_player_vehicle.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var car := {"kind": "traffic", "traffic_id": 1, "position": Vector2(0, -65), "target": Vector2(0, -150), "angle": -PI/2, "speed": 40.0, "node": 1, "target_node": 2, "reserved_node": -1}
	var walker := {"kind": "person", "walker_id": 2, "position": Vector2(0, -55), "target": Vector2(100, -55)}
	var robot := walker.duplicate()
	robot.kind = "robot"
	for actor in [car, walker, robot]:
		assert(not Collision.vehicle_may_move([actor], Vector2.ZERO, Vector2(0, -100), 0.0, Vector2(8.5,20), {}), "The player wagon passed through a traffic car or walker on a long step.")
		assert(Collision.vehicle_may_move([actor], Vector2.ZERO, Vector2(0, 10), 0.0, Vector2(8.5,20), {}), "Reversing away from an actor was blocked.")
	car.route_bridge = true
	car.route_layer = 1
	assert(Collision.vehicle_may_move([car], Vector2.ZERO, Vector2(0,-100), 0.0, Vector2(8.5,20), {}), "Bridge traffic incorrectly blocked a ground wagon.")
	car.route_bridge = false
	car.route_layer = 0
	var population = Population.new()
	root.add_child(population)
	population.set_process(false)
	population.visible = false
	population.agents.append(walker)
	var wagon = Vehicle.new()
	root.add_child(wagon)
	wagon.set_physics_process(false)
	wagon.actor_check = population.player_vehicle_may_move
	population.owned_wagon = wagon
	wagon.occupied = true
	wagon.speed = 100.0
	wagon.set_cruise_target(200.0)
	wagon._physics_process(0.5)
	assert(wagon.position == Vector2.ZERO and wagon.speed == 0.0, "The real wagon movement did not enforce actor collision.")
	walker.position = Vector2(19, 0)
	assert(not wagon._can_rotate_to(PI/2), "Steering rotated the wagon through a walker.")
	walker.position = Vector2(-40,0)
	assert(not population._walker_step_clear(walker, Vector2(40,0)), "An NPC walked through the player's stopped wagon.")
	var flow = Flow.new()
	var crossing_car := car.duplicate()
	crossing_car.traffic_id = 3
	crossing_car.position = Vector2(-60, 0)
	crossing_car.target = Vector2(100, 0)
	crossing_car.angle = 0.0
	car.position = Vector2(0, -20)
	car.target = Vector2(0, 100)
	car.angle = PI/2
	assert(not flow.can_move(crossing_car, [car, crossing_car], Vector2(20, 0), {}, []), "Cars on different OSM routes passed through each other.")
	var safety = Safety.new()
	car.position = Vector2(-80,0)
	car.target = Vector2(-60,0)
	car.angle = 0.0
	car.planned_exit_position = Vector2(60,0)
	assert(not safety.can_begin(Vector2(0,-40), Vector2(0,40), 30, [car], null), "A walker ignored a car continuing past a short OSM edge.")
	car.moving = false
	car.blocked_reason = "Traffic signal"
	assert(safety.can_begin(Vector2(0,-40), Vector2(0,40), 30, [car], null), "A stopped red-light queue was forecast as moving and stranded the walker.")
	var held := {"walker_id": 10, "position": Vector2(0,-40), "target": Vector2(0,40)}
	safety.reserve(held)
	assert(not safety.can_begin(Vector2(0,40), Vector2(0,-40), 30, [], null), "Opposing walkers were admitted onto the same narrow crossing.")
	safety.release(held)
	assert(safety.can_begin(Vector2(0,40), Vector2(0,-40), 30, [], null), "Releasing a crossing failed to let the opposite queue proceed.")
	_check_split_junction_queue()
	wagon.queue_free()
	population.queue_free()
	await process_frame
	print("INTERSECTION ACTOR SAFETY PASSED: wagon movement/steering, cars across routes, layers, short-edge forecasts and opposing walker release.")
	quit()


func _check_split_junction_queue() -> void:
	var population = Population.new()
	population.graphs.traffic = {
		"nodes": {0: Vector2(-300,0), 1: Vector2.ZERO, 2: Vector2(15,0), 3: Vector2(30,0), 4: Vector2(300,0), 5: Vector2(5000,0)},
		"adjacency": {0: [1], 1: [2], 2: [3], 3: [4], 4: [5], 5: []},
		"degree": {1: 2, 2: 2, 3: 2}, "control_by_node": {1: "traffic_signals", 3: "traffic_signals"}, "all_ids": [0]
	}
	population.graphs.traffic.junction_zone_by_node = {1:1, 2:1, 3:1}
	population.graphs.traffic.junction_clearance = 25.0
	for index in 3:
		var agent := {"kind": "traffic", "graph_key": "traffic", "traffic_id": index, "node": 0, "target_node": 1, "position": Vector2(-50 - index * 80,0), "target": Vector2.ZERO, "angle": 0.0, "speed": 55.0, "reserved_node": -1, "planned_exit_node": 2, "moving": true}
		population.agents.append(agent)
		population._choose_next(agent)
	var min_gap := INF
	var reasons: Dictionary = {}
	for frame in 3600:
		population.elapsed = 17.5 + frame / 60.0
		population.traffic_flow.begin_frame(population.agents)
		for agent in population.agents:
			var previous: Vector2 = agent.position
			population._advance_traffic(agent, 1.0/60.0)
			agent.moving = Vector2(agent.position).distance_to(previous) > 0.001
			population.traffic_flow.sync_agent_route(agent)
			if not str(agent.get("blocked_reason", "")).is_empty():
				var reason: String = agent.blocked_reason
				reasons[reason] = int(reasons.get(reason,0)) + 1
		for index in range(1,3):
			min_gap = minf(min_gap, Vector2(population.agents[index-1].position).distance_to(population.agents[index].position))
	for agent in population.agents:
		assert(Vector2(agent.position).x > 300, "A queue car remained stranded inside a junction split across several OSM vertices.")
	assert(min_gap >= 38, "The moving queue overlapped car bodies at an edge transition.")
	assert(reasons.has("Traffic signal") and reasons.has("Traffic ahead"), "The queue test did not exercise red-light waiting and following.")
	print("SPLIT JUNCTION QUEUE: three cars cleared; minimum gap=", min_gap, "; waits=", reasons)
	population.free()
