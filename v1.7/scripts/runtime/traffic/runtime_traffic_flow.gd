class_name RuntimeTrafficFlow
extends RefCounted
const SignalJunctions = preload("res://scripts/runtime/traffic/runtime_signal_junctions.gd")

## Map-independent traffic spacing, compatible junction reservations and jam
## recovery for the generated OSM graph. This keeps the rules separate from
## drawing the cars and uses only the imported town's generated topology.

const FOLLOWING_GAP_PIXELS := 56.0
const JUNCTION_APPROACH_PIXELS := 42.0
const JUNCTION_RELEASE_PIXELS := 48.0
const JUNCTION_EXIT_CLEARANCE_PIXELS := 66.0
const PRIORITY_APPROACH_PIXELS := 90.0
const PLAYER_CLEARANCE_PIXELS := 24.0

var reservations: Dictionary = {}
var recovery_enabled := true
var jam_timeout_seconds := 30.0
var recovery_spacing_seconds := 2.0
var respawn_distance_pixels := 800.0
var respawn_attempts := 24
var last_recovery_time := -INF
var recovered_car_count := 0
var route_agents: Dictionary = {}
var target_agents: Dictionary = {}
var indexed_routes: Dictionary = {}
var index_ready := false
var traffic_cells: Dictionary = {}
var indexed_cells: Dictionary = {}


func configure(settings: Dictionary) -> void:
	var recovery: Dictionary = settings.get("traffic_recovery", {})
	recovery_enabled = bool(recovery.get("enabled", true))
	jam_timeout_seconds = float(recovery.get("jam_timeout_seconds", 30.0))
	recovery_spacing_seconds = float(recovery.get("recovery_spacing_seconds", 2.0))
	respawn_distance_pixels = float(recovery.get("respawn_distance_pixels", 800.0))
	respawn_attempts = int(recovery.get("respawn_attempts", 24))
	index_ready = false


func begin_frame(agents: Array[Dictionary]) -> void:
	# Route and junction neighbours are queried for every traffic car. Indexing
	# once per frame avoids repeatedly scanning the whole editable population.
	route_agents.clear()
	target_agents.clear()
	indexed_routes.clear()
	traffic_cells.clear()
	indexed_cells.clear()
	for agent in agents:
		if str(agent.get("kind", "")) != "traffic":
			if str(agent.get("kind", "")) in ["person", "robot"]:
				traffic_cells.get_or_add(Vector2i(Vector2(agent.position).floor() / 128.0), []).append(agent)
			continue
		_add_indexed_route(agent)
		_sync_spatial_cell(agent)
	index_ready = true


func sync_agent_route(agent: Dictionary) -> void:
	if not index_ready:
		return
	_sync_spatial_cell(agent)
	var traffic_id := int(agent.get("traffic_id", -1))
	var old: Dictionary = indexed_routes.get(traffic_id, {})
	var from_node := int(agent.get("node", -1))
	var to_node := int(agent.get("target_node", -1))
	if not old.is_empty() and int(old.from) == from_node and int(old.to) == to_node:
		return
	if not old.is_empty():
		_remove_indexed_route(agent, int(old.from), int(old.to))
	_add_indexed_route(agent)


func _route_key(from_node: int, to_node: int) -> String:
	return "%d>%d" % [from_node, to_node]


func _add_indexed_route(agent: Dictionary) -> void:
	var from_node := int(agent.get("node", -1))
	var to_node := int(agent.get("target_node", -1))
	route_agents.get_or_add(_route_key(from_node, to_node), []).append(agent)
	target_agents.get_or_add(to_node, []).append(agent)
	indexed_routes[int(agent.get("traffic_id", -1))] = {"from": from_node, "to": to_node}


func _remove_indexed_route(agent: Dictionary, from_node: int, to_node: int) -> void:
	var key := _route_key(from_node, to_node)
	var on_route: Array = route_agents.get(key, [])
	on_route.erase(agent)
	if on_route.is_empty():
		route_agents.erase(key)
	var approaching: Array = target_agents.get(to_node, [])
	approaching.erase(agent)
	if approaching.is_empty():
		target_agents.erase(to_node)


func can_move(agent: Dictionary, agents: Array[Dictionary], next_position: Vector2, graph: Dictionary, obstacles: Array[Node2D], elapsed: float = 0.0, delta: float = 0.0, crossing_safety: Variant = null) -> bool:
	# Release from the actual position, never a proposed step that may be denied.
	_release_if_clear_of_junction(agent, Vector2(agent.position), graph)
	SignalJunctions.refresh_permission(agent, graph)
	var target_node := int(agent.get("target_node", -1))
	var committed_to_target := int(agent.get("reserved_node", -1)) == target_node
	var clearing_previous_junction := int(agent.get("reserved_node", -1)) >= 0 and bool(agent.get("passed_reserved_node", false)) and not committed_to_target
	if _same_lane_leader_is_close(agent, agents):
		agent.blocked_reason = "Traffic ahead"
		return false
	if _vehicle_body_ahead(agent, agents, next_position):
		agent.blocked_reason = "Vehicle crossing ahead"
		return false
	for obstacle in obstacles:
		if is_instance_valid(obstacle) and obstacle.visible and next_position.distance_to(obstacle.position) < PLAYER_CLEARANCE_PIXELS:
			agent.blocked_reason = "Player or owned vehicle ahead"
			return false
	if crossing_safety != null and not bool(agent.get("route_bridge", false)) and not bool(agent.get("route_tunnel", false)) and not crossing_safety.car_may_move(agent.position, next_position):
		agent.blocked_reason = "Pedestrian crossing"
		return false
	var target: Vector2 = agent.get("target", next_position)
	if graph.has("junction_zone_by_node") and (graph.junction_zone_by_node.has(target_node) or int(agent.get("signal_zone", -1)) >= 0):
		if not SignalJunctions.permitted(agent, agents, next_position, graph, self, elapsed):
			return false
		if graph.junction_zone_by_node.has(target_node) or int(agent.get("signal_zone", -1)) >= 0:
			agent.blocked_reason = ""
			return true
	var approaching_control := next_position.distance_to(target) <= JUNCTION_APPROACH_PIXELS
	var control := str(graph.get("control_by_node", {}).get(target_node, ""))
	if control != "stop" and int(agent.get("completed_stop_node", -1)) >= 0:
		agent.completed_stop_node = -1
	if approaching_control and control == "traffic_signals" and not committed_to_target and not clearing_previous_junction:
		var approach_direction: Vector2 = target - Vector2(agent.position)
		if signal_state(approach_direction, elapsed) != "green":
			agent.blocked_reason = "Traffic signal"
			return false
	if approaching_control and control == "stop" and not committed_to_target and int(agent.get("completed_stop_node", -1)) != target_node:
		agent.stop_wait_seconds = float(agent.get("stop_wait_seconds", 0.0)) + delta
		if float(agent.stop_wait_seconds) < 1.0:
			agent.blocked_reason = "Stop sign"
			return false
		agent.completed_stop_node = target_node
	if (int(graph.get("degree", {}).get(target_node, 0)) >= 3 or control == "traffic_signals") and approaching_control:
		if committed_to_target:
			agent.blocked_reason = ""
			return true
		var movement := _movement_for(agent, graph)
		if _exit_is_blocked(agent, agents, movement):
			agent.blocked_reason = "Intersection exit occupied"
			return false
		for reservation_value in reservations.get(target_node, []):
			var reservation: Dictionary = reservation_value
			if int(reservation.get("traffic_id", -1)) == int(agent.get("traffic_id", -1)):
				continue
			if _movements_may_share(movement, reservation, agent, reservation.get("agent", {}), graph):
				continue
			agent.blocked_reason = "Conflicting intersection movement"
			return false
		if not clearing_previous_junction and _must_yield_to_approach(agent, agents, movement, graph, control, elapsed):
			agent.blocked_reason = "Give way"
			return false
		# Do not waive the next node's conflict or exit tests just because the
		# car has permission to finish crossing after a signal change.
		if int(agent.get("reserved_node", -1)) >= 0:
			release_reservation(agent)
		_reserve_movement(agent, movement)
	agent.blocked_reason = ""
	return true


static func visible_vehicle_position(agent: Dictionary, position: Vector2) -> Vector2:
	var heading := float(agent.get("angle", Vector2(agent.get("target", position) - position).angle()))
	return position + Vector2.UP.rotated(heading) * (9.5 if str(agent.get("driving_side", "left")) == "left" else -9.5)


func _sync_spatial_cell(agent: Dictionary) -> void:
	var id := int(agent.get("traffic_id", -1))
	var cell := Vector2i(Vector2(agent.position).floor() / 128.0)
	if indexed_cells.has(id) and indexed_cells[id] == cell:
		return
	if indexed_cells.has(id):
		var previous: Array = traffic_cells.get(indexed_cells[id], [])
		previous.erase(agent)
	traffic_cells.get_or_add(cell, []).append(agent)
	indexed_cells[id] = cell


func _vehicle_body_ahead(agent: Dictionary, agents: Array[Dictionary], next_position: Vector2) -> bool:
	var candidates: Array = agents
	if index_ready:
		candidates = []
		var centre := Vector2i(Vector2(agent.position).floor() / 128.0)
		var radius := maxi(1, ceili((Vector2(agent.position).distance_to(next_position) + 50.0) / 128.0))
		for y in range(centre.y - radius, centre.y + radius + 1):
			for x in range(centre.x - radius, centre.x + radius + 1):
				candidates.append_array(traffic_cells.get(Vector2i(x, y), []))
	var current := visible_vehicle_position(agent, agent.position)
	var next := visible_vehicle_position(agent, next_position)
	var heading := float(agent.get("angle", Vector2(agent.target - agent.position).angle()))
	var direction := Vector2.RIGHT.rotated(heading)
	var next_heading := float(agent.get("next_angle", heading))
	var next_direction := Vector2.RIGHT.rotated(next_heading)
	next = next_position + Vector2.UP.rotated(next_heading) * (9.5 if str(agent.get("driving_side", "left")) == "left" else -9.5)
	for other in candidates:
		if other == agent or str(other.get("kind", "")) not in ["traffic", "person", "robot"]:
			continue
		if int(other.get("route_layer", 0)) != int(agent.get("route_layer", 0)) or bool(other.get("route_bridge", false)) != bool(agent.get("route_bridge", false)) or bool(other.get("route_tunnel", false)) != bool(agent.get("route_tunnel", false)):
			continue
		if str(other.kind) != "traffic":
			var before_walker := Vector2(other.position).distance_to(Geometry2D.get_closest_point_to_segment(other.position, current - direction * 10.5, current + direction * 10.5))
			var after_walker := Vector2(other.position).distance_to(Geometry2D.get_closest_point_to_segment(other.position, next - direction * 10.5, next + direction * 10.5))
			if after_walker < 13.0 and after_walker < before_walker:
				return true
			continue
		var other_centre := visible_vehicle_position(other, other.position)
		if current.distance_to(other_centre) > 85.0 + current.distance_to(next):
			continue
		var other_heading := float(other.get("angle", Vector2(other.target - other.position).angle()))
		var other_direction := Vector2.RIGHT.rotated(other_heading)
		# Capsules enclose the artwork (38 x 17 at its largest). The same
		# lane offset is used for drawing, including after an OSM node split.
		var other_start := other_centre - other_direction * 10.5
		var other_end := other_centre + other_direction * 10.5
		var before := _segment_distance(current - direction * 10.5, current + direction * 10.5, other_start, other_end)
		var swept := _segment_distance(current - direction * 10.5, next + next_direction * 10.5, other_start, other_end)
		var after := _segment_distance(next - next_direction * 10.5, next + next_direction * 10.5, other_start, other_end)
		swept = minf(swept, after)
		# Allow existing overlap to separate; otherwise a bad spawn is a lock.
		if swept < 17.5 and (before >= 17.5 or after < before - 0.001 or next.distance_squared_to(other_centre) <= current.distance_squared_to(other_centre) + 0.001):
			return true
	return false


func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)), b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d))), minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)), d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b))))


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


func complete_segment(agent: Dictionary, force_release: bool = false) -> void:
	# Keep the movement reserved after the car reaches the intersection centre.
	# It is released after the rear of the car has cleared the outgoing arm.
	if force_release:
		release_reservation(agent)
		agent.erase("signal_zone")
		agent.erase("signal_path")
		agent.erase("junction_route")
	elif int(agent.get("reserved_node", -1)) >= 0 and int(agent.get("node", -1)) == int(agent.reserved_node):
		agent.passed_reserved_node = true
	agent.waiting_seconds = 0.0
	agent.stop_wait_seconds = 0.0


func release_reservation(agent: Dictionary) -> void:
	var reserved_node := int(agent.get("reserved_node", -1))
	if reserved_node >= 0 and reservations.has(reserved_node):
		var retained: Array[Dictionary] = []
		for reservation_value in reservations[reserved_node]:
			var reservation: Dictionary = reservation_value
			if int(reservation.get("traffic_id", -1)) != int(agent.get("traffic_id", -1)):
				retained.append(reservation)
		if retained.is_empty():
			reservations.erase(reserved_node)
		else:
			reservations[reserved_node] = retained
	agent.reserved_node = -1
	agent.erase("reserved_entry_node")
	agent.erase("reserved_exit_node")
	agent.erase("passed_reserved_node")


func update_wait_and_recover(agent: Dictionary, delta: float, elapsed: float, graph: Dictionary, agents: Array[Dictionary], obstacles: Array[Node2D], rng: RandomNumberGenerator) -> bool:
	# Legal signal and committed-walker waits do not count as a traffic jam.
	if str(agent.get("blocked_reason", "")) in ["Traffic signal", "Pedestrian crossing"]:
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
		complete_segment(agent, true)
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
	var candidates: Array = route_agents.get(_route_key(from_node, to_node), []) if index_ready else agents
	for other in candidates:
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


func _movement_for(agent: Dictionary, graph: Dictionary) -> Dictionary:
	var entry_node := int(agent.get("node", -1))
	var junction_node := int(agent.get("target_node", -1))
	var exit_node := int(agent.get("planned_exit_node", -1))
	var nodes: Dictionary = graph.get("nodes", {})
	var junction: Vector2 = nodes.get(junction_node, agent.get("target", Vector2.ZERO))
	var entry: Vector2 = nodes.get(entry_node, agent.get("position", junction))
	var exit: Vector2 = nodes.get(exit_node, junction)
	var incoming := (junction - entry).normalized()
	var outgoing := (exit - junction).normalized() if exit_node >= 0 and exit != junction else incoming
	var turn_cross := incoming.cross(outgoing)
	var turn := "straight"
	if incoming.dot(outgoing) < 0.65:
		turn = "right" if turn_cross > 0.0 else "left"
	return {
		"traffic_id": int(agent.get("traffic_id", -1)),
		"entry_node": entry_node,
		"junction_node": junction_node,
		"exit_node": exit_node,
		"entry_direction": incoming,
		"exit_direction": outgoing,
		"turn": turn,
		"agent": agent
	}


func _reserve_movement(agent: Dictionary, movement: Dictionary) -> void:
	var junction_node := int(movement.junction_node)
	if int(agent.get("reserved_node", -1)) == junction_node:
		return
	if not reservations.has(junction_node):
		reservations[junction_node] = []
	reservations[junction_node].append(movement)
	agent.reserved_node = junction_node
	agent.reserved_entry_node = int(movement.entry_node)
	agent.reserved_exit_node = int(movement.exit_node)
	agent.passed_reserved_node = false


func _movements_may_share(candidate: Dictionary, held: Dictionary, candidate_agent: Dictionary, held_agent: Dictionary, graph: Dictionary) -> bool:
	# Cars following the exact same movement may discharge as a moving queue,
	# provided the leader already has a full safe gap. A stopped leader retains
	# the reservation and therefore prevents the follower entering the box.
	if int(candidate.entry_node) == int(held.get("entry_node", -2)) and int(candidate.exit_node) == int(held.get("exit_node", -3)):
		if held_agent.is_empty() or not bool(held_agent.get("moving", true)):
			return false
		return _movement_progress(held_agent, held, graph) - _movement_progress(candidate_agent, candidate, graph) >= FOLLOWING_GAP_PIXELS
	# Opposing straight-through lanes are compatible. The runtime draws their
	# left/right lane offsets separately, so their centre-line node may be shared.
	if str(candidate.turn) == "straight" and str(held.get("turn", "")) == "straight":
		var entry_opposed := Vector2(candidate.entry_direction).dot(Vector2(held.get("entry_direction", Vector2.ZERO))) < -0.8
		var exits_opposed := Vector2(candidate.exit_direction).dot(Vector2(held.get("exit_direction", Vector2.ZERO))) < -0.8
		return entry_opposed and exits_opposed
	return false


func _movement_progress(agent: Dictionary, movement: Dictionary, graph: Dictionary) -> float:
	var nodes: Dictionary = graph.get("nodes", {})
	var junction: Vector2 = nodes.get(int(movement.junction_node), Vector2.ZERO)
	if int(agent.get("node", -1)) == int(movement.junction_node) and int(agent.get("target_node", -1)) == int(movement.exit_node):
		return Vector2(agent.get("position", junction)).distance_to(junction)
	return -Vector2(agent.get("position", junction)).distance_to(junction)


func _exit_is_blocked(agent: Dictionary, agents: Array[Dictionary], movement: Dictionary) -> bool:
	var junction_node := int(movement.junction_node)
	var exit_node := int(movement.exit_node)
	if exit_node < 0:
		return false
	var candidates: Array = route_agents.get(_route_key(junction_node, exit_node), []) if index_ready else agents
	for other in candidates:
		if other == agent or str(other.get("kind", "")) != "traffic":
			continue
		if int(other.get("node", -1)) != junction_node or int(other.get("target_node", -1)) != exit_node:
			continue
		if Vector2(other.get("position", Vector2.INF)).distance_to(Vector2(agent.get("target", Vector2.ZERO))) >= JUNCTION_EXIT_CLEARANCE_PIXELS:
			continue
		if not bool(other.get("moving", true)) or str(other.get("blocked_reason", "")) != "":
			return true
	return false


func _must_yield_to_approach(agent: Dictionary, agents: Array[Dictionary], movement: Dictionary, graph: Dictionary, control: String, elapsed: float) -> bool:
	var junction_node := int(movement.junction_node)
	var candidates: Array = target_agents.get(junction_node, []) if index_ready else agents
	for other in candidates:
		if other == agent or str(other.get("kind", "")) != "traffic" or int(other.get("target_node", -1)) != junction_node:
			continue
		if Vector2(other.get("position", Vector2.INF)).distance_to(Vector2(agent.get("target", Vector2.ZERO))) > PRIORITY_APPROACH_PIXELS:
			continue
		var other_movement := _movement_for(other, graph)
		if _movements_may_share(movement, other_movement, agent, other, graph):
			continue
		var other_control := str(graph.get("control_by_node", {}).get(int(other.get("target_node", -1)), ""))
		if other_control == "traffic_signals":
			var other_direction: Vector2 = Vector2(other.get("target", Vector2.ZERO)) - Vector2(other.get("position", Vector2.ZERO))
			if signal_state(other_direction, elapsed) != "green":
				continue
		if control == "give_way" and other_control != "give_way":
			return true
		var agent_wait := float(agent.get("waiting_seconds", 0.0))
		var other_wait := float(other.get("waiting_seconds", 0.0))
		if other_wait > agent_wait + 0.25:
			return true
		if absf(other_wait - agent_wait) <= 0.25 and int(other.get("traffic_id", 0)) < int(agent.get("traffic_id", 0)):
			return true
	return false


func _release_if_clear_of_junction(agent: Dictionary, next_position: Vector2, graph: Dictionary) -> void:
	var reserved_node := int(agent.get("reserved_node", -1))
	if reserved_node < 0:
		return
	if int(agent.get("node", -1)) == reserved_node:
		agent.passed_reserved_node = true
	if not bool(agent.get("passed_reserved_node", false)):
		return
	var junction: Vector2 = graph.get("nodes", {}).get(reserved_node, Vector2.INF)
	if junction != Vector2.INF and next_position.distance_to(junction) >= JUNCTION_RELEASE_PIXELS:
		release_reservation(agent)


func _spawn_clear(candidate: Vector2, agent: Dictionary, agents: Array[Dictionary], obstacles: Array[Node2D]) -> bool:
	for other in agents:
		var other_position: Vector2 = other.get("position", Vector2.INF)
		if other != agent and str(other.get("kind", "")) == "traffic" and candidate.distance_to(other_position) < FOLLOWING_GAP_PIXELS:
			return false
	for obstacle in obstacles:
		if is_instance_valid(obstacle) and obstacle.visible and candidate.distance_to(obstacle.position) < respawn_distance_pixels:
			return false
	return true
