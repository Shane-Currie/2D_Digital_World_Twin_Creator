extends RefCounted

## A tiny visibility graph around the actual rotated wagon, not a sideways
## steering guess. It can find the other side when a wall blocks one side.
static func plan(start: Vector2, goal: Vector2, centre: Vector2, angle: float, half: Vector2, segment_clear: Callable) -> Array:
	var points: Array[Vector2] = [start, goal]
	var corner_half := half + Vector2.ONE * 1.5
	for corner in [-corner_half, Vector2(corner_half.x, -corner_half.y), corner_half, Vector2(-corner_half.x, corner_half.y)]:
		points.append(centre + corner.rotated(angle))
	var costs := [0.0, INF, INF, INF, INF, INF]
	var previous := [-1, -1, -1, -1, -1, -1]
	var visited: Array[int] = []
	for iteration in 6:
		var current := -1
		for index in 6:
			if index not in visited and (current < 0 or costs[index] < costs[current]):
				current = index
		if current < 0 or costs[current] == INF:
			break
		if current == 1:
			var route: Array = []
			while current != 0:
				route.push_front(points[current])
				current = previous[current]
			return route
		visited.append(current)
		for next in 6:
			if next in visited or blocked(points[current], points[next], centre, angle, half) or not bool(segment_clear.call(points[current], points[next])):
				continue
			var cost: float = costs[current] + points[current].distance_to(points[next])
			if cost < costs[next]:
				costs[next] = cost
				previous[next] = current
	return []


static func blocked(start: Vector2, finish: Vector2, centre: Vector2, angle: float, half: Vector2) -> bool:
	var a := (start - centre).rotated(-angle)
	var b := (finish - centre).rotated(-angle)
	var bounds := Rect2(-half, half * 2.0)
	if bounds.has_point(a):
		return b.length_squared() <= a.length_squared()
	if bounds.has_point(b):
		return true
	var corners := [-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
	for index in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false


static func advance(agent: Dictionary, delta: float, population: Node2D) -> bool:
	if str(agent.kind) not in ["person", "robot"] or str(agent.get("space", "outdoors")) == "interior":
		return false
	var wagon = population.owned_wagon
	if not is_instance_valid(wagon) or not wagon.visible or wagon.shape == null:
		agent.erase("parked_detour")
		return false
	var crossing: Dictionary = wagon.crossing_travel.active
	var same_level := int(agent.get("route_layer", 0)) == int(crossing.get("layer", 0)) and bool(agent.get("route_bridge", false)) == (str(crossing.get("kind", "")) == "bridge") and bool(agent.get("route_tunnel", false)) == (str(crossing.get("kind", "")) == "tunnel")
	if not same_level or absf(float(wagon.speed)) > 0.2 * population.pixels_per_metre:
		agent.erase("parked_detour")
		return false
	# Do not detour off the side of a bridge or through a tunnel wall.
	if bool(agent.get("route_bridge", false)) or bool(agent.get("route_tunnel", false)):
		return false
	var route: Dictionary = agent.get("parked_detour", {})
	if not route.is_empty() and (Vector2(route.car_position).distance_to(wagon.position) > 1.0 or absf(float(route.car_angle) - wagon.rotation) > 0.02):
		agent.erase("parked_detour")
		route = {}
	if route.is_empty():
		if Vector2(agent.position).distance_to(wagon.position) > 100.0:
			return false
		var half: Vector2 = wagon.shape.size * 0.5 + Vector2.ONE * 5.5
		if not blocked(agent.position, agent.target, wagon.position, wagon.rotation, half):
			return false
		agent.parked_detour_retry = maxf(0.0, float(agent.get("parked_detour_retry", 0.0)) - delta)
		if float(agent.parked_detour_retry) > 0.0:
			return true
		agent.parked_detour_retry = 0.5
		var was_crossing: bool = bool(agent.get("route_crossing", false)) or population._walk_edge_crosses_vehicle_road(agent.position, agent.target)
		var clear := func(a: Vector2, b: Vector2) -> bool:
			return population._walk_segment_is_clear(a, b) and (was_crossing or not population._walk_edge_crosses_vehicle_road(a, b))
		var points := plan(agent.position, agent.target, wagon.position, wagon.rotation, half, clear)
		if points.is_empty():
			# No safe route exists: wait, rather than walk through the car/water.
			return true
		route = {"points": points, "car_position": wagon.position, "car_angle": wagon.rotation, "crossing": was_crossing}
		agent.parked_detour = route
	var points: Array = route.points
	var waypoint: Vector2 = points[0]
	if bool(route.crossing) and not bool(agent.get("crossing_committed", false)):
		if bool(agent.get("route_signal_control", false)) and population.traffic_flow.signal_state(Vector2(agent.target) - Vector2(agent.position), population.elapsed) != "green":
			return true
		# Reserve the bent path, not the blocked straight line through the car.
		var before: Vector2 = agent.position
		for point in points:
			if not population.crossing_safety.can_begin(before, point, float(agent.speed), population._outdoor_agents(), wagon):
				return true
			before = point
		var saved_position: Vector2 = agent.position
		var saved_target: Vector2 = agent.target
		before = saved_position
		for point in points:
			agent.position = before
			agent.target = point
			population.crossing_safety.reserve(agent)
			before = point
		agent.position = saved_position
		agent.target = saved_target
	var from: Vector2 = agent.position
	var next := from.move_toward(waypoint, float(agent.speed) * delta)
	if not population._walker_step_clear(agent, next) and (not bool(route.crossing) or bool(agent.get("crossing_committed", false))):
		# A detour is still a pedestrian path: two walkers must be able to pass
		# one another instead of becoming a new blockage beside the parked car.
		for opposite_side in [false, true]:
			var direction: Vector2 = population._walker_avoidance_direction(agent, from.direction_to(waypoint), opposite_side)
			var candidate := from + direction * minf(float(agent.speed) * delta, from.distance_to(waypoint))
			if population._walker_step_clear(agent, candidate) and population._walk_segment_is_clear(from, candidate):
				next = candidate
				break
		if not population._walker_step_clear(agent, next):
			# Beside a car, a brief pure sideways step can be necessary to
			# pass a head-on walker. The car/world checks still bound the step.
			var sideways := from.direction_to(waypoint).orthogonal()
			for direction in [sideways, -sideways]:
				var candidate: Vector2 = from + direction * float(agent.speed) * delta
				if population._walker_step_clear(agent, candidate) and population._walk_segment_is_clear(from, candidate):
					next = candidate
					break
	if not population._walk_segment_is_clear(from, next) or not population._walker_step_clear(agent, next):
		return true
	agent.position = next
	if from != next:
		agent.angle = from.direction_to(next).angle()
	if next.is_equal_approx(waypoint):
		points.pop_front()
		if points.is_empty():
			agent.erase("parked_detour")
			if not population._point_on_vehicle_road(next):
				population.crossing_safety.release(agent, true)
	return true
