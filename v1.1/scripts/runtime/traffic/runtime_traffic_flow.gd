class_name RuntimeTrafficFlow
extends RefCounted

## Map-independent traffic spacing, junction ownership and jam recovery for the
## generated OSM graph. This keeps the rules separate from drawing the cars.

const FOLLOWING_GAP_PIXELS := 56.0
const JUNCTION_APPROACH_PIXELS := 42.0
const PLAYER_CLEARANCE_PIXELS := 24.0

var reservations: Dictionary = {}
var recovery_enabled := true
var jam_timeout_seconds := 30.0
var recovery_spacing_seconds := 2.0
var respawn_distance_pixels := 800.0
var respawn_attempts := 24
var last_recovery_time := -INF
var recovered_car_count := 0


func configure(settings: Dictionary) -> void:
	var recovery: Dictionary = settings.get("traffic_recovery", {})
	recovery_enabled = bool(recovery.get("enabled", true))
	jam_timeout_seconds = float(recovery.get("jam_timeout_seconds", 30.0))
	recovery_spacing_seconds = float(recovery.get("recovery_spacing_seconds", 2.0))
	respawn_distance_pixels = float(recovery.get("respawn_distance_pixels", 800.0))
	respawn_attempts = int(recovery.get("respawn_attempts", 24))


func can_move(agent: Dictionary, agents: Array[Dictionary], next_position: Vector2, graph: Dictionary, obstacles: Array[Node2D], elapsed: float = 0.0, delta: float = 0.0) -> bool:
	if _same_lane_leader_is_close(agent, agents):
		agent.blocked_reason = "Traffic ahead"
		return false
	for obstacle in obstacles:
		if is_instance_valid(obstacle) and obstacle.visible and next_position.distance_to(obstacle.position) < PLAYER_CLEARANCE_PIXELS:
			agent.blocked_reason = "Player or owned vehicle ahead"
			return false
	var target_node := int(agent.get("target_node", -1))
	var target: Vector2 = agent.get("target", next_position)
	var approaching_control := next_position.distance_to(target) <= JUNCTION_APPROACH_PIXELS
	var control := str(graph.get("control_by_node", {}).get(target_node, ""))
	if approaching_control and control == "traffic_signals":
		var approach_direction: Vector2 = target - Vector2(agent.position)
		if signal_state(approach_direction, elapsed) != "green":
			agent.blocked_reason = "Traffic signal"
			return false
	if approaching_control and control == "stop" and int(agent.get("completed_stop_node", -1)) != target_node:
		agent.stop_wait_seconds = float(agent.get("stop_wait_seconds", 0.0)) + delta
		if float(agent.stop_wait_seconds) < 1.0:
			agent.blocked_reason = "Stop sign"
			return false
		agent.completed_stop_node = target_node
	if int(graph.get("degree", {}).get(target_node, 0)) >= 3 and approaching_control:
		var holder := int(reservations.get(target_node, -1))
		if holder >= 0 and holder != int(agent.get("traffic_id", -1)):
			agent.blocked_reason = "Intersection occupied"
			return false
		reservations[target_node] = int(agent.get("traffic_id", -1))
		agent.reserved_node = target_node
	agent.blocked_reason = ""
	return true


func signal_state(direction: Vector2, elapsed: float) -> String:
	var phase := fmod(elapsed, 48.0)
	var horizontal := absf(direction.x) > absf(direction.y)
	if horizontal:
		if phase < 18.0:
			return "green"
		if phase < 21.0:
			return "amber"
	else:
		if phase >= 24.0 and phase < 42.0:
			return "green"
		if phase >= 42.0 and phase < 45.0:
			return "amber"
	return "red"


func complete_segment(agent: Dictionary) -> void:
	var reserved_node := int(agent.get("reserved_node", -1))
	if reserved_node >= 0 and int(reservations.get(reserved_node, -1)) == int(agent.get("traffic_id", -1)):
		reservations.erase(reserved_node)
	agent.reserved_node = -1
	agent.waiting_seconds = 0.0
	agent.stop_wait_seconds = 0.0


func update_wait_and_recover(agent: Dictionary, delta: float, elapsed: float, graph: Dictionary, agents: Array[Dictionary], obstacles: Array[Node2D], rng: RandomNumberGenerator) -> bool:
	# Legal signal waits do not count as a traffic jam, matching the v1.3 rule.
	if str(agent.get("blocked_reason", "")) == "Traffic signal":
		return false
	agent.waiting_seconds = float(agent.get("waiting_seconds", 0.0)) + delta
	if not recovery_enabled or float(agent.waiting_seconds) < jam_timeout_seconds:
		return false
	if elapsed < last_recovery_time + recovery_spacing_seconds:
		return false
	var origin: Vector2 = agent.position
	var ids: Array = graph.get("all_ids", [])
	if ids.is_empty():
		return false
	for _attempt in respawn_attempts:
		var candidate_id := int(ids[rng.randi_range(0, ids.size() - 1)])
		if graph.get("adjacency", {}).get(candidate_id, []).is_empty():
			continue
		var candidate: Vector2 = graph.nodes[candidate_id]
		if candidate.distance_to(origin) < respawn_distance_pixels:
			continue
		if not _spawn_clear(candidate, agent, agents, obstacles):
			continue
		complete_segment(agent)
		agent.node = candidate_id
		agent.target_node = candidate_id
		agent.position = candidate
		agent.target = candidate
		agent.jam_recoveries = int(agent.get("jam_recoveries", 0)) + 1
		last_recovery_time = elapsed
		recovered_car_count += 1
		return true
	return false


func _same_lane_leader_is_close(agent: Dictionary, agents: Array[Dictionary]) -> bool:
	var from_node := int(agent.get("node", -1))
	var to_node := int(agent.get("target_node", -1))
	var agent_position: Vector2 = agent.position
	var agent_target: Vector2 = agent.target
	var remaining: float = agent_position.distance_to(agent_target)
	for other in agents:
		if other == agent or str(other.get("kind", "")) != "traffic":
			continue
		if int(other.get("node", -2)) != from_node or int(other.get("target_node", -2)) != to_node:
			continue
		var other_position: Vector2 = other.position
		var other_target: Vector2 = other.target
		var other_remaining: float = other_position.distance_to(other_target)
		if other_remaining < remaining and remaining - other_remaining < FOLLOWING_GAP_PIXELS:
			return true
	return false


func _spawn_clear(candidate: Vector2, agent: Dictionary, agents: Array[Dictionary], obstacles: Array[Node2D]) -> bool:
	for other in agents:
		var other_position: Vector2 = other.get("position", Vector2.INF)
		if other != agent and str(other.get("kind", "")) == "traffic" and candidate.distance_to(other_position) < FOLLOWING_GAP_PIXELS:
			return false
	for obstacle in obstacles:
		if is_instance_valid(obstacle) and obstacle.visible and candidate.distance_to(obstacle.position) < respawn_distance_pixels:
			return false
	return true
