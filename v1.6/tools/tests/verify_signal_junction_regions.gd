extends SceneTree

const Zones = preload("res://scripts/runtime/traffic/runtime_signal_junctions.gd")
const Flow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")

func _initialize() -> void:
	var graph := {
		"nodes": {0: Vector2(-800,0), 1: Vector2.ZERO, 2: Vector2(60,0), 3: Vector2(120,30), 4: Vector2(120,100), 5: Vector2(120,800), 6: Vector2(120,1600), 7: Vector2(60,-800)},
		"adjacency": {0:[1], 1:[2], 2:[3], 3:[4], 4:[5], 5:[6], 6:[], 7:[2]},
		"degree": {1:2, 2:3, 3:2, 4:2, 5:2},
		"control_by_node": {1:"traffic_signals", 4:"traffic_signals", 5:"traffic_signals"},
		"edge_by_pair": {}, "all_ids":[0]
	}
	for from in graph.adjacency:
		for to in graph.adjacency[from]:
			graph.edge_by_pair["%d>%d" % [from,to]] = {}
	Zones.prepare(graph, 8.0)
	assert(graph.junction_zone_by_node[1] == graph.junction_zone_by_node[4], "Signals on a split turning junction were separated.")
	assert(graph.junction_zone_by_node[1] != graph.junction_zone_by_node[5], "Separate traffic lights were merged across a long street.")
	var population = Population.new()
	population.graphs.traffic = graph
	var car := {"kind":"traffic", "graph_key":"traffic", "traffic_id":1, "node":0, "target_node":1, "position":Vector2(-42,0), "target":Vector2.ZERO, "speed":40.0, "angle":0.0, "moving":true, "reserved_node":-1}
	population.agents.append(car)
	population._choose_next(car)
	assert(car.junction_route == [1,2,3,4,5], "The selected route did not span the full junction.")
	var flow = population.traffic_flow
	var obstacles: Array[Node2D] = []
	assert(not flow.can_move(car, population.agents, Vector2(-41,0), graph, obstacles, 23), "A red entry was allowed.")
	var blocker := {"kind":"traffic", "traffic_id":2, "node":4, "target_node":5, "position":Vector2(120,140), "target":Vector2(120,800), "angle":PI/2, "moving":false}
	var blocked_agents: Array[Dictionary] = [car,blocker]
	assert(not flow.can_move(car, blocked_agents, Vector2(-41,0), graph, obstacles, 17), "An occupied exit immediately beyond a long exit edge was missed.")
	assert(car.blocked_reason == "Intersection exit occupied")
	assert(flow.can_move(car, population.agents, Vector2(-41,0), graph, obstacles, 17), "A clear green entry was denied.")
	assert(int(car.signal_zone) >= 0)
	# Competing route through the same box must wait even if it is green.
	var rival := {"kind":"traffic", "traffic_id":3, "node":7, "target_node":2, "position":Vector2(60,-42), "target":Vector2(60,0), "angle":PI/2, "planned_exit_node":3}
	Zones.plan(rival, graph, population.rng)
	assert(not Zones.permitted(rival, [car,rival], Vector2(60,-41), graph, flow, 25), "A conflicting green route entered an occupied junction.")
	assert(rival.blocked_reason == "Conflicting intersection movement")
	for frame in 720:
		population.elapsed = 17.0 + frame/60.0
		flow.begin_frame(population.agents)
		population._advance_traffic(car, 1.0/60.0)
		assert(str(car.get("blocked_reason","")) != "Traffic signal", "A phase change or far-side light stopped the admitted car inside the turning junction.")
	assert(Vector2(car.position).y > 150, "The turning car failed to clear the entire junction.")
	assert(int(car.get("signal_zone",-1)) < 0, "Rear clearance did not release the junction.")
	car.position = Vector2(120,758)
	assert(not flow.can_move(car, population.agents, Vector2(120,759), graph, obstacles, 0), "A later independent red light was ignored.")
	flow.complete_segment(car, true)
	assert(not car.has("junction_route") and not car.has("signal_zone"), "Jam relocation retained stale permission.")
	population.free()
	print("SIGNAL JUNCTION REGIONS PASSED: automatic split-node grouping, turning through phase change, occupied exits, conflicting green, rear release, later red and recovery cleanup.")
	quit()
