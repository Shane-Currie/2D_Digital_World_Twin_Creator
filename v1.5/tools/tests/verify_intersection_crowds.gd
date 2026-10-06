extends SceneTree

const Population = preload("res://scripts/runtime/runtime_population.gd")
const Motion = preload("res://scripts/runtime/crashes/impact_motion.gd")
const Actors = preload("res://scripts/runtime/traffic/runtime_actor_collision.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAILED: ", message)


func _walker(id: int, position: Vector2, target: Vector2, crossing := false) -> Dictionary:
	return {"kind": "robot" if id % 2 else "person", "walker_id": id, "position": position,
		"target": target, "speed": 20.0, "angle": 0.0, "phase": 0.0, "graph_key": "person",
		"node": 0, "target_node": 1, "route_phase": "edge", "route_crossing": crossing,
		"route_layer": 0, "route_bridge": false, "route_tunnel": false}


func _run() -> void:
	# Two touching walkers used to turn one another into an immovable wall.
	var p := Population.new()
	var first := _walker(0, Vector2(0,-45), Vector2(0,-100))
	var second := _walker(1, Vector2(0,-50), Vector2(0,-100))
	p.agents.assign([first, second])
	var hit := Actors.first_contact(p.agents, Vector2.ZERO, Vector2(0,-100), 0.0, Vector2(8.5,20), {})
	Motion.apply(hit, Vector2(0,-40), p)
	for frame in 90:
		for agent in p.agents:
			Motion.advance(agent, 1.0 / 30.0, p)
	_expect(first.position.y < -46.0 and second.position.y < -53.0, "Clustered NPC/NPR did not respond to a car impact.")
	print("CROWD IMPACT POSITIONS: ", first.position, " ", second.position)
	var embedded := _walker(2, Vector2(1,-10), Vector2(0,-100))
	p.agents.assign([embedded])
	var embedded_hit := Actors.first_contact(p.agents, Vector2.ZERO, Vector2(0,-2), 0.0, Vector2(8.5,20), {})
	var embedded_response := Motion.apply(embedded_hit, Vector2(0,-30), p)
	_expect(float(embedded_response.impulse_ns) > 0.0 and Vector2(embedded_response.actor_velocity).y < 0.0, "A character inside an old wagon overlap received a sideways zero-force normal.")
	p.free()

	# Shared waypoints must not cause orbiting around a stationary character.
	p = Population.new()
	p.graphs.person = {"nodes": {0: Vector2(-80,0), 1: Vector2.ZERO, 2: Vector2(100,0)}, "adjacency": {0:[1],1:[2],2:[1]}, "edge_by_pair": {}, "all_ids": [0,1,2]}
	var centre := _walker(50, Vector2.ZERO, Vector2.ZERO)
	centre.storyline_stationary = true
	p.agents.append(centre)
	for id in 6:
		var walker := _walker(id, Vector2(-30 - id * 9, (id % 2) * 8 - 4), Vector2.ZERO)
		p.agents.append(walker)
	var advanced: Dictionary = {}
	for frame in 420:
		p._process(1.0 / 30.0)
		for walker in p.agents:
			if not bool(walker.get("storyline_stationary", false)) and walker.position.x > 20.0:
				advanced[int(walker.walker_id)] = true
	_expect(advanced.size() == 6, "Walkers circled or froze at an occupied graph waypoint (%d/6 advanced)." % advanced.size())
	print("CROWD WAYPOINT PROGRESS: ", advanced.size(), "/6")
	p.free()
	_check_committed_crossing()
	if "--play-town" in OS.get_cmdline_user_args():
		await _check_real_town()
	if failures == 0:
		print("INTERSECTION CROWDS PASSED: clustered impact and occupied waypoint progress.")
	quit(1 if failures else 0)


func _check_committed_crossing() -> void:
	var p := Population.new()
	p.set_vehicle_road_segments([{"a": Vector2(-100,0), "b": Vector2(100,0), "half_width": 20.0}])
	p.graphs.person = {"nodes": {0: Vector2(0,-40), 1: Vector2.ZERO, 2: Vector2(0,40), 3: Vector2(0,100)}, "adjacency": {0:[1],1:[2],2:[3],3:[2]}, "edge_by_pair": {"0>1":{"crossing":true},"1>2":{"crossing":true}}, "control_by_node": {0:"traffic_signals",1:"traffic_signals"}, "all_ids": [0,1,2,3]}
	var walker := _walker(0, Vector2(0,-30), Vector2.ZERO, true)
	walker.route_signal_control = true
	var blocker := _walker(9, Vector2.ZERO, Vector2.ZERO)
	blocker.storyline_stationary = true
	p.agents.assign([walker, blocker])
	p.crossing_safety.reserve(walker)
	# Red after admission must not strand a person in the middle of the road.
	p.elapsed = 43.0
	for frame in 180:
		p._process(1.0/30.0)
		if walker.position.y >= 39.9:
			break
	_expect(walker.position.y >= 39.9 and not bool(walker.get("crossing_committed", false)), "An admitted walker could not pass an occupied intersection node and reach the pavement.")
	print("COMMITTED CROSSING EXIT: ", walker.position)
	# Crash recovery must clear the road instead of asking to start on red.
	var knocked := _walker(2, Vector2(35,-5), Vector2(35,40), true)
	knocked.node = 1
	knocked.target_node = 2
	knocked.route_signal_control = true
	knocked.impact_rejoining = true
	p.agents.assign([knocked])
	for frame in 120:
		p._process(1.0/30.0)
		if knocked.position.y >= 35.0:
			break
	_expect(knocked.position.y >= 35.0, "A knocked NPC stayed on a red-light crossing instead of clearing the road.")
	p.free()


func _check_real_town() -> void:
	var scene: PackedScene = load("res://scenes/runtime/town_runtime.tscn")
	var runtime = scene.instantiate()
	root.add_child(runtime)
	runtime.set_process(false)
	var p = runtime.population
	p.set_process(false)
	await physics_frame
	var candidates: Array = []
	for agent in p.agents:
		if str(agent.kind) not in ["person", "robot"] or bool(agent.get("route_bridge", false)) or bool(agent.get("route_tunnel", false)):
			continue
		if p._point_on_vehicle_road(agent.position):
			candidates.append(agent)
	var free_probes := 0
	var blocked_probes := 0
	var failed_shoves := 0
	for agent in candidates.slice(0,20):
		var original: Vector2 = agent.position
		var direction: Vector2 = original.direction_to(agent.target)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		if not Motion.world_pose_clear(agent, original, original + direction, p):
			blocked_probes += 1
			continue
		free_probes += 1
		var response := Motion.impulse_response(direction * 35.0, Vector2.ZERO, direction, 140.0 if str(agent.kind) == "robot" else 75.0, p.pixels_per_metre)
		Motion.begin_impact(agent, response, p)
		for frame in 10:
			for other in p.agents:
				Motion.advance(other, 1.0/30.0, p)
		if Vector2(agent.position).distance_to(original) < 0.1:
			failed_shoves += 1
			var obstruction := Motion.actor_contact(agent, original, original + direction, p)
			print("BLOCKED REAL SHOVE: ", JSON.stringify({"id":agent.walker_id,"kind":agent.kind,"position":str(original),"direction":str(direction),"world_clear_two_pixels":Motion.world_pose_clear(agent, original, original + direction * 2.0, p),"other_kind":str(obstruction.get("agent", {}).get("kind", "")),"other_position":str(obstruction.get("agent", {}).get("position", Vector2.INF)),"normal":str(obstruction.get("normal",Vector2.ZERO))}))
	_expect(failed_shoves == 0 and free_probes > 0, "Real-town road walkers failed impact probes on clear ground.")
	var moved: Dictionary = {}
	var lingering: Dictionary = {}
	var peak_stall := 0.0
	for frame in 600:
		p._process(1.0/30.0)
		for agent in p.agents:
			if str(agent.kind) not in ["person","robot"]:
				continue
			var id := int(agent.walker_id)
			if bool(agent.get("moving",false)):
				moved[id] = true
			var stalled: bool = bool(agent.get("crossing_committed", false)) and p._point_on_vehicle_road(agent.position) and not bool(agent.get("moving",false)) and not agent.has("impact_velocity")
			lingering[id] = float(lingering.get(id, 0.0)) + 1.0/30.0 if stalled else 0.0
			peak_stall = maxf(peak_stall, float(lingering[id]))
	var longest_stall := 0.0
	for seconds in lingering.values():
		longest_stall = maxf(longest_stall, float(seconds))
	print("REAL TOWN CROWD CHECK: ", JSON.stringify({"town":runtime.town.display_name,"clear_impact_probes":free_probes,"world_blocked_probes":blocked_probes,"failed_shoves":failed_shoves,"walkers_moving":moved.size(),"longest_current_committed_road_stall_seconds":longest_stall,"peak_committed_road_stall_seconds":peak_stall,"simulated_seconds":20}))
	runtime.queue_free()
