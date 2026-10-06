extends RefCounted

const Settings = preload("res://scripts/runtime/crashes/crash_settings.gd")
const TrafficFlow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
const CrossingTravel = preload("res://scripts/crossings/crossing_travel.gd")


static func impulse_response(player_velocity: Vector2, actor_velocity: Vector2, normal: Vector2, actor_mass: float, scale: float, lever_metres: Vector2 = Vector2.ZERO, inertia: float = 0.0, angular_velocity: float = 0.0, moving_mass: float = Settings.PLAYER_MASS_KG) -> Dictionary:
	var contact_velocity := actor_velocity + Vector2(-lever_metres.y, lever_metres.x) * angular_velocity * scale
	var closing_mps := maxf(0.0, (player_velocity - contact_velocity).dot(normal) / scale)
	var rotational_inverse_mass := pow(lever_metres.cross(normal), 2.0) / inertia if inertia > 0.0 else 0.0
	var impulse := (1.0 + Settings.RESTITUTION) * closing_mps / (1.0 / moving_mass + 1.0 / actor_mass + rotational_inverse_mass)
	if closing_mps < Settings.MIN_CLOSING_SPEED_MPS:
		impulse = 0.0
	return {"player_velocity": player_velocity - normal * impulse / moving_mass * scale,
		"actor_velocity": actor_velocity + normal * impulse / actor_mass * scale,
		"actor_angular_velocity": angular_velocity + lever_metres.cross(normal * impulse) / inertia if inertia > 0.0 else 0.0,
		"impulse_ns": impulse, "closing_speed_kmh": closing_mps * 3.6}


static func apply(contact: Dictionary, player_velocity: Vector2, population: Node2D) -> Dictionary:
	var agent: Dictionary = contact.agent
	var actor_velocity := velocity_for(agent)
	var mass := Settings.mass_for(agent)
	var scale: float = population.pixels_per_metre
	var lever := Vector2.ZERO
	var inertia := 0.0
	if str(agent.kind) == "traffic":
		var centre := TrafficFlow.visible_vehicle_position(agent, agent.position)
		lever = (Vector2(contact.get("point", centre)) - centre) / scale
		# Box moment of inertia matches the same envelope used for collision.
		inertia = mass * (pow(17.0 / scale, 2.0) + pow(38.0 / scale, 2.0)) / 12.0
	var response := impulse_response(player_velocity, actor_velocity, contact.normal, mass, scale, lever, inertia, float(agent.get("impact_angular_velocity", 0.0)))
	if float(response.impulse_ns) <= 0.0:
		return response
	begin_impact(agent, response, population)
	return response


static func velocity_for(agent: Dictionary) -> Vector2:
	if agent.has("impact_velocity"):
		return agent.impact_velocity
	if bool(agent.get("moving", false)):
		return Vector2.RIGHT.rotated(float(agent.get("angle", 0.0))) * float(agent.get("speed", 0.0))
	return Vector2.ZERO


static func begin_impact(agent: Dictionary, response: Dictionary, population: Node2D) -> void:
	if str(agent.kind) == "traffic":
		population.traffic_flow.complete_segment(agent, true)
	else:
		population.crossing_safety.release(agent)
		agent.erase("parked_detour")
	agent["impact_velocity"] = response.actor_velocity
	agent["impact_angular_velocity"] = clampf(float(response.actor_angular_velocity), -Settings.MAX_SPIN_RADIANS_PER_SECOND, Settings.MAX_SPIN_RADIANS_PER_SECOND)
	agent["impact_recovery_seconds"] = Settings.RECOVERY_DELAY_SECONDS
	agent["impact_rejoining"] = true
	agent["waiting_seconds"] = 0.0
	# Passing decisions made before a crash are no longer valid afterwards.
	agent.erase("walker_passing")


static func advance(agent: Dictionary, delta: float, population: Node2D) -> bool:
	if not agent.has("impact_velocity"):
		return false
	var velocity: Vector2 = agent.impact_velocity
	var scale: float = population.pixels_per_metre
	var next_velocity := velocity.move_toward(Vector2.ZERO, Settings.sliding_deceleration(agent) * scale * delta)
	var angular_velocity := float(agent.get("impact_angular_velocity", 0.0))
	var next_spin := move_toward(angular_velocity, 0.0, Settings.ANGULAR_DECELERATION * delta)
	var turn := (angular_velocity + next_spin) * 0.5 * delta
	var displacement := (velocity + next_velocity) * 0.5 * delta
	var steps := maxi(1, ceili(displacement.length() / Settings.MAX_MOVEMENT_STEP_PIXELS))
	steps = maxi(steps, ceili(absf(turn) / 0.06))
	var traffic := str(agent.kind) == "traffic"
	var before: Vector2 = agent.position
	for step in steps:
		var offset := TrafficFlow.visible_vehicle_position(agent, agent.position) - Vector2(agent.position) if traffic else Vector2.ZERO
		var centre := Vector2(agent.position) + offset
		var next := centre + displacement / steps
		var next_angle := float(agent.get("angle", 0.0)) + turn / steps
		if not world_pose_clear(agent, centre, next, population, next_angle + PI * 0.5 if traffic else 0.0):
			next_velocity = Vector2.ZERO
			next_spin = 0.0
			break
		var contact := actor_contact(agent, centre, next, population, next_angle + PI * 0.5 if traffic else 0.0)
		if not contact.is_empty():
			var other: Dictionary = contact.agent
			if str(other.kind) in ["person", "robot", "traffic"]:
				# A person behind another person is not a fixed wall. Transfer a
				# bounded pairwise impulse; subsequent updates move the front actor.
				var other_velocity := velocity_for(other)
				var lever := Vector2.ZERO
				var inertia := 0.0
				if str(other.kind) == "traffic":
					var other_centre := TrafficFlow.visible_vehicle_position(other, other.position)
					lever = (Vector2(contact.get("point", other_centre)) - other_centre) / scale
					inertia = Settings.mass_for(other) * (pow(17.0 / scale, 2.0) + pow(38.0 / scale, 2.0)) / 12.0
				var response := impulse_response(next_velocity, other_velocity, contact.normal, Settings.mass_for(other), scale, lever, inertia, float(other.get("impact_angular_velocity", 0.0)), Settings.mass_for(agent))
				if float(response.impulse_ns) > 0.0:
					begin_impact(other, response, population)
					next_velocity = response.player_velocity
				# Keep remaining momentum while the front actor moves away. Do
				# not erase it simply because their initial bodies were touching.
			else:
				next_velocity = Vector2.ZERO
				next_spin = 0.0
			next = centre.lerp(next, float(contact.fraction))
			displacement = Vector2.ZERO
		if traffic:
			agent.angle = next_angle
			offset = Vector2.UP.rotated(next_angle) * (9.5 if str(agent.get("driving_side", "left")) == "left" else -9.5)
		agent.position = next - offset
		if not contact.is_empty():
			break
	agent.impact_velocity = next_velocity
	agent.impact_angular_velocity = next_spin
	agent.moving = Vector2(agent.position).distance_squared_to(before) > 0.001 or absf(next_spin) > 0.01
	if next_velocity.length() <= 0.05 * scale and absf(next_spin) <= 0.01:
		agent.impact_velocity = Vector2.ZERO
		agent.impact_recovery_seconds = maxf(0.0, float(agent.impact_recovery_seconds) - delta)
		if float(agent.impact_recovery_seconds) <= 0.0:
			agent.erase("impact_velocity")
			agent.erase("impact_angular_velocity")
			# Continue from the displaced position, never snap back to the route.
			if str(agent.kind) in ["person", "robot"]:
				agent.crossing_retry_seconds = 0.0
	return true


static func pose_clear(agent: Dictionary, from: Vector2, to: Vector2, population: Node2D, angle_override: float = NAN) -> bool:
	return world_pose_clear(agent, from, to, population, angle_override) and actor_contact(agent, from, to, population, angle_override).is_empty()


static func world_pose_clear(agent: Dictionary, from: Vector2, to: Vector2, population: Node2D, angle_override: float = NAN) -> bool:
	var traffic := str(agent.kind) == "traffic"
	var half := Vector2(8.5, 19.0) if traffic else Vector2.ONE * (4.5 if str(agent.kind) == "robot" else 3.5)
	var angle := float(agent.get("angle", 0.0)) + PI * 0.5 if traffic else 0.0
	if not is_nan(angle_override):
		angle = angle_override
	if bool(agent.get("route_bridge", false)) or bool(agent.get("route_tunnel", false)):
		var found := false
		for corridor in population.bridge_corridors:
			if str(agent.get("route_source_way_id", "")) not in corridor.get("source_ids", [str(corridor.get("id", ""))]):
				continue
			if not CrossingTravel.contains_pose(corridor, to, angle, half):
				return false
			found = true
		if not found:
			return false
	else:
		if population.ground_check.is_valid() and not bool(population.ground_check.call(to, half.length())):
			return false
		if population.building_segment_check.is_valid():
			# Probe centre and perimeter, including the swept leading corners.
			for corner in [Vector2.ZERO, -half, half, Vector2(-half.x, half.y), Vector2(half.x, -half.y)]:
				var offset: Vector2 = corner.rotated(angle)
				if not bool(population.building_segment_check.call(from + offset, to + offset)):
					return false
	if population.is_inside_tree():
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := RectangleShape2D.new()
		shape.size = half * 2.0
		query.shape = shape
		query.transform = Transform2D(angle, to)
		query.collision_mask = 2 if bool(agent.get("route_bridge", false)) or bool(agent.get("route_tunnel", false)) else 1 | 2
		if not population.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	return true


static func actor_contact(agent: Dictionary, from: Vector2, to: Vector2, population: Node2D, angle_override: float = NAN) -> Dictionary:
	var traffic := str(agent.kind) == "traffic"
	var half := Vector2(8.5,19.0) if traffic else Vector2.ONE * (4.5 if str(agent.kind) == "robot" else 3.5)
	var angle := float(agent.get("angle", 0.0)) + PI * 0.5 if traffic else 0.0
	if not is_nan(angle_override):
		angle = angle_override
	var crossing := {"layer": int(agent.get("route_layer", 0)), "kind": "bridge" if bool(agent.get("route_bridge", false)) else ("tunnel" if bool(agent.get("route_tunnel", false)) else "")}
	var others: Array = []
	for other in population._outdoor_agents():
		if other != agent:
			others.append(other)
	return population.ActorCollisionScript.first_contact(others, from, to, angle, half, crossing)
