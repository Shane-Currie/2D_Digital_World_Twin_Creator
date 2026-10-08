extends RefCounted

const TrafficFlow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")

static func vehicle_may_move(agents: Array, start: Vector2, finish: Vector2, angle: float, half_size: Vector2, crossing: Dictionary) -> bool:
	return first_contact(agents, start, finish, angle, half_size, crossing).is_empty()


static func first_contact(agents: Array, start: Vector2, finish: Vector2, angle: float, half_size: Vector2, crossing: Dictionary) -> Dictionary:
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
		return {}
	var steps := maxi(1, ceili(start.distance_to(finish) / 1.5))
	var earliest: Dictionary = {}
	var first_fraction := INF
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
			var low := float(step - 1) / steps
			var high := float(step) / steps
			for refinement in 9:
				var middle := (low + high) * 0.5
				if _overlaps(start.lerp(finish, middle), angle, half_size, agent, centre):
					high = middle
				else:
					low = middle
			if high < first_fraction:
				first_fraction = high
				var hit_position := start.lerp(finish, high)
				var normal := _contact_normal(hit_position, angle, half_size, agent, centre)
				if initially_overlapping and (centre - start).length_squared() > 0.001:
					# Inside an old overlap, the nearest box face may be sideways
					# even while moving directly into the actor. Use the separating
					# centre axis so the closing motion still transfers momentum.
					normal = start.direction_to(centre)
				earliest = {"agent": agent, "fraction": low, "normal": normal, "point": _contact_point(hit_position, angle, half_size, agent, centre)}
			break
	return earliest


static func _contact_normal(position: Vector2, angle: float, half_size: Vector2, agent: Dictionary, centre: Vector2) -> Vector2:
	var offset := centre - position
	if str(agent.kind) != "traffic":
		var local := offset.rotated(-angle)
		var nearest := local.clamp(-half_size, half_size)
		var normal := local - nearest
		if normal.length_squared() < 0.001:
			normal = Vector2(signf(local.x) if local.x != 0.0 else 1.0, 0.0) if half_size.x - absf(local.x) < half_size.y - absf(local.y) else Vector2(0.0, signf(local.y) if local.y != 0.0 else 1.0)
		return normal.normalized().rotated(angle)
	var other_angle := float(agent.get("angle", 0.0)) + PI * 0.5
	var axes := [Vector2.RIGHT.rotated(angle), Vector2.DOWN.rotated(angle), Vector2.RIGHT.rotated(other_angle), Vector2.DOWN.rotated(other_angle)]
	var least_overlap := INF
	var normal := offset.normalized()
	for axis in axes:
		var extent := half_size.x * absf(axis.dot(axes[0])) + half_size.y * absf(axis.dot(axes[1])) + 8.5 * absf(axis.dot(axes[2])) + 19.0 * absf(axis.dot(axes[3]))
		var overlap := extent - absf(offset.dot(axis))
		if overlap < least_overlap:
			least_overlap = overlap
			normal = axis * (-1.0 if offset.dot(axis) < 0.0 else 1.0)
	return normal


static func _contact_point(position: Vector2, angle: float, half_size: Vector2, agent: Dictionary, centre: Vector2) -> Vector2:
	if str(agent.kind) == "traffic":
		var overlaps := Geometry2D.intersect_polygons(_rectangle(position, angle, half_size), _rectangle(centre, float(agent.get("angle", 0.0)) + PI * 0.5, Vector2(8.5,19)))
		if not overlaps.is_empty():
			var total := Vector2.ZERO
			for vertex in overlaps[0]:
				total += vertex
			return total / overlaps[0].size()
	return position + (centre - position).rotated(-angle).clamp(-half_size, half_size).rotated(angle)


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
