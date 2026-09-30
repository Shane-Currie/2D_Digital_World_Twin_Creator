extends RefCounted

const TrafficFlow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")

static func vehicle_may_move(agents: Array, start: Vector2, finish: Vector2, angle: float, half_size: Vector2, crossing: Dictionary) -> bool:
	var candidates: Array = []
	var swept_bounds := Rect2(start, finish - start).abs().grow(half_size.length() + 32.0)
	for agent in agents:
		var kind := str(agent.get("kind", ""))
		if kind not in ["traffic", "person", "robot"]:
			continue
		if bool(agent.get("route_bridge", false)) != (str(crossing.get("kind", "")) == "bridge") or bool(agent.get("route_tunnel", false)) != (str(crossing.get("kind", "")) == "tunnel"):
			continue
		if int(agent.get("route_layer", 0)) != int(crossing.get("layer", 0)):
			continue
		var centre := Vector2(agent.position)
		if kind == "traffic":
			centre = TrafficFlow.visible_vehicle_position(agent, centre)
		if swept_bounds.has_point(centre):
			candidates.append({"agent": agent, "centre": centre})
	if candidates.is_empty():
		return true
	var steps := maxi(1, ceili(start.distance_to(finish) / 3.0))
	for candidate in candidates:
		var agent: Dictionary = candidate.agent
		var centre: Vector2 = candidate.centre
		var initially_overlapping := _overlaps(start, angle, half_size, agent, centre)
		for step in range(1, steps + 1):
			var position := start.lerp(finish, float(step) / steps)
			if not _overlaps(position, angle, half_size, agent, centre):
				continue
			# Permit reversing out of an old/spawn overlap, but never deeper in.
			if initially_overlapping and position.distance_squared_to(centre) > start.distance_squared_to(centre) + 0.01:
				continue
			return false
	return true


static func _overlaps(position: Vector2, angle: float, half_size: Vector2, agent: Dictionary, centre: Vector2) -> bool:
	if str(agent.kind) != "traffic":
		var local := (centre - position).rotated(-angle)
		var closest := local.clamp(-half_size, half_size)
		return local.distance_to(closest) < (4.5 if str(agent.kind) == "robot" else 3.5)
	var own_polygon := _rectangle(position, angle, half_size)
	var other_half := Vector2(8.5, 19.0)
	var other_angle := float(agent.get("angle", 0.0)) + PI * 0.5
	return not Geometry2D.intersect_polygons(own_polygon, _rectangle(centre, other_angle, other_half)).is_empty()


static func _rectangle(position: Vector2, angle: float, half_size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in [Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), half_size, Vector2(-half_size.x, half_size.y)]:
		points.append(position + corner.rotated(angle))
	return points
