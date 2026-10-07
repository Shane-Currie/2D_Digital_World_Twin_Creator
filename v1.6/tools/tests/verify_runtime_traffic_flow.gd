extends SceneTree

const TrafficFlowScript = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")


func _initialize() -> void:
	var flow = TrafficFlowScript.new()
	flow.configure({"traffic_recovery": {"enabled": true, "jam_timeout_seconds": 5.0, "recovery_spacing_seconds": 2.0, "respawn_distance_pixels": 800.0, "respawn_attempts": 4}})
	var no_obstacles: Array[Node2D] = []
	var lane_graph := {"degree": {1: 2}}
	var leader := _car(1, 0, 1, Vector2(50, 0), Vector2(100, 0))
	var follower := _car(2, 0, 1, Vector2(0, 0), Vector2(100, 0))
	var lane_agents: Array[Dictionary] = [leader, follower]
	assert(not flow.can_move(follower, lane_agents, Vector2(2, 0), lane_graph, no_obstacles), "A following car ignored the safe queue gap.")
	leader.position = Vector2(85, 0)
	assert(flow.can_move(follower, lane_agents, Vector2(2, 0), lane_graph, no_obstacles), "A safely spaced following car was blocked.")
	leader.position = Vector2(50, 0)
	flow.begin_frame(lane_agents)
	assert(not flow.can_move(follower, lane_agents, Vector2(2, 0), lane_graph, no_obstacles), "Indexed traffic ignored a leader on the same route.")
	leader.node = 1
	leader.target_node = 2
	flow.sync_agent_route(leader)
	assert(flow.can_move(follower, lane_agents, Vector2(2, 0), lane_graph, no_obstacles), "Indexed traffic kept a car on its old route after an OSM node transition.")
	flow.configure({"traffic_recovery": {"enabled": true, "jam_timeout_seconds": 5.0, "recovery_spacing_seconds": 2.0, "respawn_distance_pixels": 800.0, "respawn_attempts": 4}})

	var junction_graph := {
		"nodes": {0: Vector2(-100, 0), 1: Vector2.ZERO, 2: Vector2(100, 0), 3: Vector2(0, -100), 4: Vector2(0, 100)},
		"degree": {0: 1, 1: 4, 2: 1, 3: 1, 4: 1},
		"control_by_node": {}
	}
	var leader_car := _car(10, 0, 1, Vector2(-20, 0), Vector2.ZERO, 2)
	leader_car.moving = true
	var queue_car := _car(11, 0, 1, Vector2(-90, 0), Vector2.ZERO, 2)
	var opposing_car := _car(12, 2, 1, Vector2(20, 0), Vector2.ZERO, 0)
	var turning_car := _car(13, 3, 1, Vector2(0, -44), Vector2.ZERO, 2)
	var junction_agents: Array[Dictionary] = [leader_car, queue_car, opposing_car, turning_car]
	assert(flow.can_move(leader_car, junction_agents, Vector2(-18, 0), junction_graph, no_obstacles), "The first car could not reserve an open intersection.")
	assert(flow.can_move(queue_car, junction_agents, Vector2(-88, 0), junction_graph, no_obstacles), "A safely spaced moving queue could not share its exact intersection movement.")
	assert(flow.can_move(opposing_car, junction_agents, Vector2(18, 0), junction_graph, no_obstacles), "Compatible opposing straight traffic did not share the intersection.")
	assert(not flow.can_move(turning_car, junction_agents, Vector2(0, -40), junction_graph, no_obstacles), "A conflicting turn entered the reserved intersection.")
	leader_car.node = 1
	leader_car.target_node = 2
	leader_car.position = Vector2(70, 0)
	leader_car.target = Vector2(100, 0)
	leader_car.moving = false
	var stopped_follower := _car(15, 0, 1, Vector2(-20, 0), Vector2.ZERO, 2)
	var stopped_queue: Array[Dictionary] = [leader_car, stopped_follower]
	assert(not flow.can_move(stopped_follower, stopped_queue, Vector2(-18, 0), junction_graph, no_obstacles), "A follower entered behind a stationary leader's reservation.")
	leader_car.moving = true

	leader_car.node = 1
	leader_car.target_node = 2
	leader_car.position = Vector2.ZERO
	leader_car.target = Vector2(100, 0)
	flow.complete_segment(leader_car)
	assert(int(leader_car.reserved_node) == 1, "The reservation was released at the intersection centre instead of behind the car.")
	assert(flow.can_move(leader_car, junction_agents, Vector2(50, 0), junction_graph, no_obstacles), "The lead car could not clear its reserved intersection.")
	assert(int(leader_car.reserved_node) == 1, "A proposed move released a reservation before actual clearance.")
	leader_car.position = Vector2(50, 0)
	flow.can_move(leader_car, junction_agents, Vector2(52, 0), junction_graph, no_obstacles)
	assert(int(leader_car.reserved_node) == -1, "The reservation remained after the vehicle cleared the junction.")

	flow.reservations.clear()
	for car in junction_agents:
		car.reserved_node = -1
	var stopped_exit := _car(14, 1, 2, Vector2(24, 0), Vector2(100, 0), -1)
	stopped_exit.moving = false
	stopped_exit.blocked_reason = "Traffic ahead"
	var exit_test_agents: Array[Dictionary] = [leader_car, stopped_exit]
	leader_car.node = 0
	leader_car.target_node = 1
	leader_car.position = Vector2(-20, 0)
	leader_car.target = Vector2.ZERO
	leader_car.planned_exit_node = 2
	assert(not flow.can_move(leader_car, exit_test_agents, Vector2(-18, 0), junction_graph, no_obstacles), "A car entered an intersection whose outbound arm was blocked.")
	assert(str(leader_car.blocked_reason) == "Intersection exit occupied")

	flow.reservations.clear()
	var signal_car := _car(20, 0, 1, Vector2(-20, 0), Vector2.ZERO, 2)
	var signal_agents: Array[Dictionary] = [signal_car]
	var signal_graph := junction_graph.duplicate(true)
	signal_graph.control_by_node = {1: "traffic_signals"}
	assert(not flow.can_move(signal_car, signal_agents, Vector2(-18, 0), signal_graph, no_obstacles, 20.0, 0.1), "A car entered on an amber traffic signal.")
	assert(str(signal_car.blocked_reason) == "Traffic signal")
	var signal_exit_blocker := _car(23, 1, 2, Vector2(24, 0), Vector2(100, 0), -1)
	signal_exit_blocker.moving = false
	signal_exit_blocker.blocked_reason = "Traffic ahead"
	assert(not flow.can_move(signal_car, [signal_car, signal_exit_blocker], Vector2(-18, 0), signal_graph, no_obstacles, 10.0, 0.1), "A green signal bypassed the occupied-exit safety check.")
	assert(int(signal_car.reserved_node) == -1, "A car reserved a signalised junction before its exit/conflict checks passed.")
	assert(flow.can_move(signal_car, signal_agents, Vector2(-18, 0), signal_graph, no_obstacles, 10.0, 0.1), "A car did not enter on its green traffic signal.")
	assert(flow.can_move(signal_car, signal_agents, Vector2(-16, 0), signal_graph, no_obstacles, 30.0, 0.1), "A committed car stopped inside the intersection when its signal changed.")

	# Real OSM junctions often contain several nearby signal nodes: one at the
	# entry stop line and another across the box. Exercise the actual node
	# transition so a far-side red cannot strand the car mid-intersection.
	flow.reservations.clear()
	var multi_signal_graph := {
		"nodes": {0: Vector2(-100, 0), 1: Vector2.ZERO, 2: Vector2(20, 0), 3: Vector2(200, 0)},
		"degree": {0: 1, 1: 2, 2: 2, 3: 1},
		"control_by_node": {1: "traffic_signals", 2: "traffic_signals", 3: "traffic_signals"}
	}
	var crossing_car := _car(22, 0, 1, Vector2(-20, 0), Vector2.ZERO, 2)
	var crossing_agents: Array[Dictionary] = [crossing_car]
	assert(flow.can_move(crossing_car, crossing_agents, Vector2(-18, 0), multi_signal_graph, no_obstacles, 10.0, 0.1), "A green degree-two OSM stop-line signal did not commit the car to clearing the junction.")
	assert(int(crossing_car.reserved_node) == 1, "The green stop-line signal did not retain a crossing commitment.")
	crossing_car.position = Vector2.ZERO
	crossing_car.node = 1
	flow.complete_segment(crossing_car)
	crossing_car.target_node = 2
	crossing_car.target = Vector2(20, 0)
	crossing_car.planned_exit_node = 3
	assert(flow.can_move(crossing_car, crossing_agents, Vector2(2, 0), multi_signal_graph, no_obstacles, 30.0, 0.1), "A far-side red signal stopped a committed car in the middle of the intersection.")
	assert(str(crossing_car.blocked_reason).is_empty(), "A clearing car retained a false traffic-light blocked reason.")
	crossing_car.position = Vector2(20, 0)
	crossing_car.node = 2
	flow.complete_segment(crossing_car)
	assert(int(crossing_car.reserved_node) >= 0, "A short intermediate OSM segment released the crossing before rear clearance.")
	crossing_car.position = Vector2(160, 0)
	crossing_car.target_node = 3
	crossing_car.target = Vector2(200, 0)
	assert(not flow.can_move(crossing_car, crossing_agents, Vector2(162, 0), multi_signal_graph, no_obstacles, 30.0, 0.1), "Clearing one junction allowed the car to ignore a later red signal.")

	var stop_car := _car(21, 5, 6, Vector2(-20, 0), Vector2.ZERO)
	var stop_agents: Array[Dictionary] = [stop_car]
	var stop_graph := {"degree": {6: 2}, "control_by_node": {6: "stop"}}
	assert(not flow.can_move(stop_car, stop_agents, Vector2(-18, 0), stop_graph, no_obstacles, 0.0, 0.5), "A car did not stop at an imported stop sign.")
	assert(flow.can_move(stop_car, stop_agents, Vector2(-18, 0), stop_graph, no_obstacles, 0.5, 0.5), "A car remained blocked after a full stop.")

	var jammed := _car(30, 0, 0, Vector2.ZERO, Vector2.ZERO)
	jammed.waiting_seconds = 5.0
	var recovery_agents: Array[Dictionary] = [jammed]
	var recovery_graph := {"nodes": {0: Vector2.ZERO, 1: Vector2(900, 0)}, "adjacency": {0: [1], 1: [0]}, "all_ids": [1]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert(flow.update_wait_and_recover(jammed, 0.1, 10.0, recovery_graph, recovery_agents, no_obstacles, rng), "A timed-out jammed car was not relocated.")
	assert(jammed.position == Vector2(900, 0) and int(jammed.jam_recoveries) == 1, "Jam recovery did not use a clear distant road node.")

	print("RUNTIME TRAFFIC FLOW PASSED: progressive queue, compatible/opposing movements, conflicting turn, blocked exit, held clearance, OSM signals/stops and distant jam recovery.")
	quit(0)


func _car(id: int, from_node: int, to_node: int, position: Vector2, target: Vector2, planned_exit: int = -1) -> Dictionary:
	return {
		"kind": "traffic",
		"traffic_id": id,
		"node": from_node,
		"target_node": to_node,
		"position": position,
		"target": target,
		"planned_exit_node": planned_exit,
		"reserved_node": -1,
		"waiting_seconds": 0.0,
		"stop_wait_seconds": 0.0,
		"completed_stop_node": -1,
		"jam_recoveries": 0,
		"moving": true,
		"blocked_reason": ""
	}
