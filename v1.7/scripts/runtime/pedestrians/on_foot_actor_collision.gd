extends RefCounted

## Ground-foot collision against drawn population actors (not physics nodes).
## Use their real feet/car positions, never walking routes or traffic signals.
const TrafficFlow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
const CONTACT_MARGIN := 0.02


static func same_level(agent: Dictionary, crossing: Dictionary) -> bool:
	return int(agent.get("route_layer", 0)) == int(crossing.get("layer", 0)) and bool(agent.get("route_bridge", false)) == (str(crossing.get("kind", "")) == "bridge") and bool(agent.get("route_tunnel", false)) == (str(crossing.get("kind", "")) == "tunnel")


static func resolve_motion(agents: Array, start: Vector2, finish: Vector2, radius: float, crossing: Dictionary) -> Vector2:
	var candidates: Array = []
	var bounds := Rect2(start, finish - start).abs().grow(radius + 32.0)
	for agent in agents:
		var kind := str(agent.get("kind", ""))
		if kind not in ["person", "robot", "traffic"] or not same_level(agent, crossing): continue
		var centre := Vector2(agent.position)
		if kind == "traffic": centre = TrafficFlow.visible_vehicle_position(agent, centre)
		if bounds.has_point(centre): candidates.append({"agent": agent, "centre": centre})
	var position := start
	var remaining := finish - start
	# Bounded contact-and-slide handles corners/crowds without an unbounded
	# avoidance search. Sweeps also prevent passing through at low frame rates.
	for iteration in 3:
		if remaining.length_squared() < 0.000001: break
		var nearest: Dictionary = {}
		for candidate in candidates:
			var agent: Dictionary = candidate.agent
			var centre: Vector2 = candidate.centre
			var contact: Dictionary
			if str(agent.kind) == "traffic":
				contact = _car_contact(position, position + remaining, centre, float(agent.get("angle", 0.0)) + PI * 0.5, Vector2(8.5, 19.0), radius)
			else:
				contact = _circle_contact(position, position + remaining, centre, radius + (4.5 if str(agent.kind) == "robot" else 3.5))
			if not contact.is_empty() and (nearest.is_empty() or float(contact.fraction) < float(nearest.fraction)): nearest = contact
		if nearest.is_empty():
			position += remaining
			break
		var fraction := maxf(0.0, float(nearest.fraction) - CONTACT_MARGIN / remaining.length())
		position += remaining * fraction
		remaining *= 1.0 - fraction
		var normal: Vector2 = nearest.normal
		remaining -= normal * minf(0.0, remaining.dot(normal))
	return position


static func _circle_contact(start: Vector2, finish: Vector2, centre: Vector2, radius: float) -> Dictionary:
	var offset := start - centre
	var motion := finish - start
	var length_squared := motion.length_squared()
	if length_squared < 0.000001: return {}
	if offset.length_squared() < 0.000001: return {}
	var normal := offset.normalized() if offset.length_squared() > 0.000001 else -motion.normalized()
	if offset.length_squared() <= radius * radius:
		# Let an old/spawn overlap escape; never allow movement farther in.
		if motion.dot(normal) >= -0.000001: return {}
		return {"fraction": 0.0, "normal": normal}
	var projected := offset.dot(motion)
	var discriminant := projected * projected - length_squared * (offset.length_squared() - radius * radius)
	if discriminant < 0.0: return {}
	var fraction := (-projected - sqrt(discriminant)) / length_squared
	if fraction < 0.0 or fraction > 1.0: return {}
	normal = (start.lerp(finish, fraction) - centre).normalized()
	if motion.dot(normal) >= -0.000001: return {}
	return {"fraction": fraction, "normal": normal}


static func _car_contact(start: Vector2, finish: Vector2, centre: Vector2, angle: float, half: Vector2, radius: float) -> Dictionary:
	var local_start := (start - centre).rotated(-angle)
	var local_finish := (finish - centre).rotated(-angle)
	var motion := local_finish - local_start
	var closest := local_start.clamp(-half, half)
	var offset := local_start - closest
	if offset.length_squared() <= radius * radius:
		var normal := offset.normalized()
		if offset.length_squared() < 0.000001:
			normal = Vector2(signf(local_start.x) if local_start.x != 0.0 else 1.0, 0.0) if half.x - absf(local_start.x) < half.y - absf(local_start.y) else Vector2(0.0, signf(local_start.y) if local_start.y != 0.0 else 1.0)
		if motion.dot(normal) >= -0.000001: return {}
		return {"fraction": 0.0, "normal": normal.rotated(angle)}
	var contacts: Array = []
	for sign_value in [-1.0, 1.0]:
		if absf(motion.x) > 0.000001 and motion.x * sign_value < 0.0:
			var fraction: float = (float(sign_value) * (half.x + radius) - local_start.x) / motion.x
			if fraction >= 0.0 and fraction <= 1.0 and absf(local_start.y + motion.y * fraction) <= half.y:
				contacts.append({"fraction": fraction, "normal": Vector2(sign_value, 0)})
		if absf(motion.y) > 0.000001 and motion.y * sign_value < 0.0:
			var fraction: float = (float(sign_value) * (half.y + radius) - local_start.y) / motion.y
			if fraction >= 0.0 and fraction <= 1.0 and absf(local_start.x + motion.x * fraction) <= half.x:
				contacts.append({"fraction": fraction, "normal": Vector2(0, sign_value)})
	for corner in [-half, Vector2(-half.x, half.y), half, Vector2(half.x, -half.y)]:
		var contact := _circle_contact(local_start, local_finish, corner, radius)
		if not contact.is_empty(): contacts.append(contact)
	var nearest: Dictionary = {}
	for contact in contacts:
		if nearest.is_empty() or float(contact.fraction) < float(nearest.fraction): nearest = contact
	if not nearest.is_empty(): nearest.normal = Vector2(nearest.normal).rotated(angle)
	return nearest
