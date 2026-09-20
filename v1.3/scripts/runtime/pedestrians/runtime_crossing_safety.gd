class_name RuntimeCrossingSafety
extends RefCounted

## A small, map-independent version of v1.3's pedestrian crossing contract.
## Walking and flying routes are not treated as traffic crossings unless OSM
## explicitly marks the walk segment as a crossing.
const CROSSING_CAR_CLEARANCE_PIXELS := 28.0
const FORECAST_CLEARANCE_PIXELS := 27.0

var reservations: Dictionary = {}
var denied_crossings := 0
var completed_crossings := 0


func reset() -> void:
	reservations.clear()
	denied_crossings = 0
	completed_crossings = 0


func can_begin(start: Vector2, finish: Vector2, walk_speed: float, road_users: Array[Dictionary], owned_wagon: Node2D) -> bool:
	var crossing_seconds := start.distance_to(finish) / maxf(1.0, walk_speed) + 1.5
	if is_instance_valid(owned_wagon) and _wagon_conflicts(start, finish, crossing_seconds, owned_wagon):
		denied_crossings += 1
		return false
	for road_user in road_users:
		if str(road_user.get("kind", "")) != "traffic" or bool(road_user.get("route_bridge", false)) or bool(road_user.get("route_tunnel", false)):
			continue
		var position: Vector2 = road_user.position
		var target: Vector2 = road_user.target
		var direction := position.direction_to(target)
		var remaining := position.distance_to(target)
		# A stopped queue keeps its actual body, not a maximum-speed exclusion
		# circle across an entire district. Once walkers reserve a crossing, NPC
		# traffic yields at that segment.
		var travel := 0.0 if float(road_user.get("waiting_seconds", 0.0)) > 1.0 else minf(remaining, float(road_user.get("speed", 0.0)) * crossing_seconds)
		if _segments_near(start, finish, position - direction * 20.0, position + direction * (travel + 20.0), FORECAST_CLEARANCE_PIXELS):
			denied_crossings += 1
			return false
	return true


func reserve(agent: Dictionary) -> void:
	reservations[int(agent.get("walker_id", -1))] = {"start": agent.position, "finish": agent.target}
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
		if _segments_near(current, next_position, reserved.start, reserved.finish, CROSSING_CAR_CLEARANCE_PIXELS):
			return false
	return true


func _wagon_conflicts(start: Vector2, finish: Vector2, crossing_seconds: float, wagon: Node2D) -> bool:
	if not bool(wagon.get("occupied")) or not wagon.visible:
		return false
	if not wagon.get("crossing_travel").active.is_empty():
		return false
	var speed := float(wagon.get("speed"))
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
