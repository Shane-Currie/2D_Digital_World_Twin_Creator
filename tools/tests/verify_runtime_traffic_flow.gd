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

	var junction_graph := {"degree": {10: 4}}
	var first := _car(10, 2, 10, Vector2(-20, 0), Vector2(0, 0))
	var second := _car(11, 3, 10, Vector2(0, -20), Vector2(0, 0))
	var junction_agents: Array[Dictionary] = [first, second]
	assert(flow.can_move(first, junction_agents, Vector2(-18, 0), junction_graph, no_obstacles), "The first car could not reserve an open intersection.")
	assert(not flow.can_move(second, junction_agents, Vector2(0, -18), junction_graph, no_obstacles), "Conflicting cars entered the same generated-map intersection.")
	flow.complete_segment(first)
	assert(flow.can_move(second, junction_agents, Vector2(0, -18), junction_graph, no_obstacles), "The intersection did not release for the next car.")

	var signal_car := _car(12, 4, 12, Vector2(-20, 0), Vector2.ZERO)
	var signal_agents: Array[Dictionary] = [signal_car]
	var signal_graph := {"degree": {12: 4}, "control_by_node": {12: "traffic_signals"}}
	assert(not flow.can_move(signal_car, signal_agents, Vector2(-18, 0), signal_graph, no_obstacles, 20.0, 0.1), "A car entered on an amber traffic signal.")
	assert(str(signal_car.blocked_reason) == "Traffic signal")
	assert(flow.can_move(signal_car, signal_agents, Vector2(-18, 0), signal_graph, no_obstacles, 10.0, 0.1), "A car did not enter on its green traffic signal.")

	var stop_car := _car(13, 5, 13, Vector2(-20, 0), Vector2.ZERO)
	var stop_agents: Array[Dictionary] = [stop_car]
	var stop_graph := {"degree": {13: 2}, "control_by_node": {13: "stop"}}
	assert(not flow.can_move(stop_car, stop_agents, Vector2(-18, 0), stop_graph, no_obstacles, 0.0, 0.5), "A car did not stop at an imported stop sign.")
	assert(flow.can_move(stop_car, stop_agents, Vector2(-18, 0), stop_graph, no_obstacles, 0.5, 0.5), "A car remained blocked after a full stop.")

	var jammed := _car(20, 0, 0, Vector2.ZERO, Vector2.ZERO)
	jammed.waiting_seconds = 5.0
	var recovery_agents: Array[Dictionary] = [jammed]
	var recovery_graph := {"nodes": {0: Vector2.ZERO, 1: Vector2(900, 0)}, "adjacency": {0: [1], 1: [0]}, "all_ids": [1]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert(flow.update_wait_and_recover(jammed, 0.1, 10.0, recovery_graph, recovery_agents, no_obstacles, rng), "A timed-out jammed car was not relocated.")
	assert(jammed.position == Vector2(900, 0) and int(jammed.jam_recoveries) == 1, "Jam recovery did not use a clear distant road node.")

	print("RUNTIME TRAFFIC FLOW PASSED: queue gap, OSM signals/stops, exclusive generated junction and distant jam recovery.")
	quit(0)


func _car(id: int, from_node: int, to_node: int, position: Vector2, target: Vector2) -> Dictionary:
	return {
		"kind": "traffic",
		"traffic_id": id,
		"node": from_node,
		"target_node": to_node,
		"position": position,
		"target": target,
		"reserved_node": -1,
		"waiting_seconds": 0.0,
		"stop_wait_seconds": 0.0,
		"completed_stop_node": -1,
		"jam_recoveries": 0
	}
