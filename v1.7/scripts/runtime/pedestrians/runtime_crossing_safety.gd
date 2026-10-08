class_name RuntimeCrossingSafety
extends RefCounted

## A small, map-independent version of v1.3's pedestrian crossing contract.
## Walking and flying routes are not treated as traffic crossings unless OSM
## explicitly marks the walk segment as a crossing.
const CROSSING_CAR_CLEARANCE_PIXELS := 28.0
const FORECAST_CLEARANCE_PIXELS := 27.0
const TrafficFlow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")

var reservations: Dictionary = {}
var denied_crossings := 0
var completed_crossings := 0


func reset() -> void:
	reservations.clear()
	denied_crossings = 0
	completed_crossings = 0


func can_begin(start: Vector2, finish: Vector2, walk_speed: float, road_users: Array[Dictionary], owned_wagon: Node2D) -> bool:
	# Opposite walkers must not meet on a single narrow crossing line, where
	# sideways avoidance is intentionally disabled. Admit one direction first.
	for held in reservations.values():
		for segment in held.get("segments", [held]):
			if start.direction_to(finish).dot(Vector2(segment.start).direction_to(segment.finish)) < 0.5 and _segments_near(start, finish, segment.start, segment.finish, 5.0):
				return false
	var crossing_seconds := start.distance_to(finish) / maxf(1.0, walk_speed) + 1.5
	var crossing_centre := start.lerp(finish, 0.5)
	var crossing_radius := start.distance_to(finish) * 0.5 + 65.0
	if is_instance_valid(owned_wagon) and _wagon_conflicts(start, finish, crossing_seconds, owned_wagon):
		denied_crossings += 1
		return false
	for road_user in road_users:
		if str(road_user.get("kind", "")) != "traffic" or bool(road_user.get("route_bridge", false)) or bool(road_user.get("route_tunnel", false)):
			continue
		var maximum_reach := crossing_radius + float(road_user.get("speed", 0.0)) * crossing_seconds
		if Vector2(road_user.position).distance_squared_to(crossing_centre) > maximum_reach * maximum_reach:
			continue
		var position := TrafficFlow.visible_vehicle_position(road_user, road_user.position)
		var target := TrafficFlow.visible_vehicle_position(road_user, road_user.target)
		var direction := position.direction_to(target)
		var remaining := position.distance_to(target)
		var stopped := (road_user.has("moving") and not bool(road_user.moving) and not str(road_user.get("blocked_reason", "")).is_empty()) or float(road_user.get("waiting_seconds", 0.0)) > 1.0
		# A stopped queue keeps its actual body, not a maximum-speed exclusion
		# circle across an entire district. Once walkers reserve a crossing, NPC
		# traffic yields at that segment.
		var travel := 0.0 if stopped else minf(remaining, float(road_user.get("speed", 0.0)) * crossing_seconds)
		if _segments_near(start, finish, position - direction * 20.0, position + direction * (travel + 20.0), FORECAST_CLEARANCE_PIXELS):
			denied_crossings += 1
			return false
		# An OSM vertex is not a place where the car stops. Forecast the already
		# chosen outgoing segment too, including a turn toward this crossing.
		var budget := float(road_user.get("speed", 0.0)) * crossing_seconds - remaining
		if budget > 0.0 and not stopped and road_user.has("planned_exit_position"):
			var exit: Vector2 = road_user.planned_exit_position
			var continuation := target.move_toward(exit, budget)
			if _segments_near(start, finish, target, continuation, FORECAST_CLEARANCE_PIXELS + 20.0):
				denied_crossings += 1
				return false
	return true


func reserve(agent: Dictionary) -> void:
	var id := int(agent.get("walker_id", -1))
	var segments: Array = reservations.get(id, {}).get("segments", []).duplicate()
	var segment := {"start": agent.position, "finish": agent.target}
	if segment not in segments and Vector2(agent.position).distance_squared_to(agent.target) > 0.01:
		segments.append(segment)
	reservations[id] = {"start": agent.position, "finish": agent.target, "segments": segments}
	agent["crossing_committed"] = true


func release(agent: Dictionary, completed: bool = false) -> void:
	reservations.erase(int(agent.get("walker_id", -1)))
	agent["crossing_committed"] = false
	if completed:
		completed_crossings += 1


func car_may_move(current: Vector2, next_position: Vector2) -> bool:
	# Check only committed crossings. Scanning every person/robot for every car
	# would multiply the two creator-configurable population counts each frame.
	for reserved in reservations.values():
		for segment in reserved.get("segments", [reserved]):
			if _segments_near(current, next_position, segment.start, segment.finish, CROSSING_CAR_CLEARANCE_PIXELS):
				return false
	return true


func _wagon_conflicts(start: Vector2, finish: Vector2, crossing_seconds: float, wagon: Node2D) -> bool:
	if not wagon.visible:
		return false
	if not wagon.get("crossing_travel").active.is_empty():
		return false
	var speed := float(wagon.get("speed"))
	if not bool(wagon.get("occupied")) or absf(speed) < 0.1:
		return _segments_near(start, finish, wagon.position - Vector2.UP.rotated(wagon.rotation) * 23.0, wagon.position + Vector2.UP.rotated(wagon.rotation) * 23.0, 14.0)
	var direction := Vector2.UP.rotated(wagon.rotation) * (-1.0 if speed < 0.0 else 1.0)
	var travel := minf(absf(speed) * crossing_seconds + 0.5 * float(wagon.get("acceleration")) * crossing_seconds * crossing_seconds, float(wagon.get("forward_speed")) * crossing_seconds)
	return _segments_near(start, finish, wagon.position - direction * 23.0, wagon.position + direction * (travel + 23.0), FORECAST_CLEARANCE_PIXELS)


func _segments_near(first_start: Vector2, first_end: Vector2, second_start: Vector2, second_end: Vector2, clearance: float) -> bool:
	var first_bounds := Rect2(first_start, first_end - first_start).abs().grow(clearance)
	if not first_bounds.intersects(Rect2(second_start, second_end - second_start).abs().grow(clearance), true):
		return false
	if Geometry2D.segment_intersects_segment(first_start, first_end, second_start, second_end) != null:
		return true
	for point in [first_start, first_end]:
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, second_start, second_end)) <= clearance:
			return true
	for point in [second_start, second_end]:
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, first_start, first_end)) <= clearance:
			return true
	return false
