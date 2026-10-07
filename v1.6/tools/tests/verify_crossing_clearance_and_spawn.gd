extends SceneTree

const Population = preload("res://scripts/runtime/runtime_population.gd")
const Flow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")

func _initialize() -> void:
	for kind in ["person", "robot"]:
		_check_split_crossing(kind)
	_check_landing()
	_check_startup()
	print("CROSSING CLEARANCE AND SPAWN PASSED: NPC/NPR multi-node red-phase clearance, landing yield, blocked pavement, startup exclusion and car spacing.")
	quit()

func _check_split_crossing(kind: String) -> void:
	var p = Population.new()
	p.set_vehicle_road_segments([{"a":Vector2(-100,0),"b":Vector2(100,0),"half_width":20.0}])
	p.graphs.person = {"nodes":{0:Vector2(0,-40),1:Vector2.ZERO,2:Vector2(0,40),3:Vector2(0,100)},"adjacency":{0:[1],1:[2],2:[3],3:[2]},"edge_by_pair":{"0>1":{"crossing":true},"1>2":{"crossing":true}},"control_by_node":{0:"traffic_signals",1:"traffic_signals"},"all_ids":[0,1,2,3]}
	var walker := {"kind":kind,"walker_id":0,"graph_key":"person","node":0,"target_node":0,"position":Vector2(0,-40),"speed":30.0,"angle":0.0,"first_route":true}
	p.agents.append(walker)
	p._choose_next(walker)
	p.elapsed = 0.0
	p._advance_agent(walker,0.1)
	assert(walker.position == Vector2(0,-40), "Pedestrian entered a red crossing.")
	p.elapsed = 41.8
	walker.crossing_retry_seconds = 0.0
	p._advance_agent(walker,0.1)
	assert(walker.crossing_committed)
	for step in 120:
		p.elapsed = 42.0 + step/30.0
		p._rebuild_walker_cells()
		p._advance_agent(walker,1.0/30.0)
		if walker.position.y >= 40.0:
			break
	assert(walker.position.y >= 40.0, "Walker stopped at the red signal vertex inside the road.")
	assert(not walker.crossing_committed and p.crossing_safety.reservations.is_empty(), "Completed pedestrian crossing failed to release traffic.")
	p.free()

func _check_landing() -> void:
	var p = Population.new()
	p.set_vehicle_road_segments([{"a":Vector2(-100,0),"b":Vector2(100,0),"half_width":20.0}])
	var arriving := {"kind":"person","walker_id":0,"position":Vector2(0,28),"target":Vector2(0,40),"crossing_committed":true}
	var waiting := {"kind":"robot","walker_id":1,"position":Vector2(0,40),"target":Vector2(0,-40),"speed":30.0,"route_crossing":true}
	p.agents.assign([arriving,waiting])
	for step in 20:
		p._rebuild_walker_cells()
		p._yield_crossing_landing(waiting,1.0/30.0)
	assert(Vector2(waiting.position).distance_to(arriving.target) >= 9.0, "Waiting walker blocked the landing.")
	assert(not p._point_on_vehicle_road(waiting.position), "Waiting walker yielded into the road.")
	waiting.position = Vector2(0,40)
	p.set_ground_check(func(_point:Vector2,_radius:float)->bool: return false)
	p._rebuild_walker_cells()
	assert(not p._yield_crossing_landing(waiting,0.1) and waiting.position == Vector2(0,40), "Landing yield ignored blocked ground.")
	p.free()

func _check_startup() -> void:
	var p = Population.new()
	p.rng.seed = 123
	p.graphs.traffic = {"nodes":{0:Vector2(-2000,0),1:Vector2(2000,0)},"adjacency":{0:[1],1:[0]},"edge_by_pair":{"0>1":{},"1>0":{}},"degree":{},"all_ids":[0,1]}
	var wagon := Node2D.new()
	var obstacles: Array[Node2D] = [wagon]
	p.set_gameplay_obstacles(obstacles)
	p._add_population("traffic",20,0,75.0)
	assert(p.agents.size() == 20)
	for car in p.agents:
		var centre := Flow.visible_vehicle_position(car,car.position)
		assert(centre.distance_to(wagon.position) >= 160.0, "Traffic boxed in the starting wagon.")
		for other in p.agents:
			if car != other:
				assert(centre.distance_to(Flow.visible_vehicle_position(other,other.position)) >= 70.0, "Traffic spawned overlapping another car.")
	p.free()
	wagon.free()
