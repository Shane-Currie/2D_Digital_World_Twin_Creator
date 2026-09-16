extends RefCounted

## Per-actor crossing state. A map overlap is not an entrance. Side boundaries
## constrain the full moving footprint; only the two open ends release it.
var corridors: Array = []
var active: Dictionary = {}
var half_size := Vector2(4,4)

func candidate(from: Vector2, to: Vector2) -> Dictionary:
	if not active.is_empty(): return active
	if from.is_equal_approx(to): return {}
	var best: Dictionary = {}
	var first_fraction := INF
	for corridor in corridors:
		var points: PackedVector2Array = corridor.points
		for end in [0,points.size() - 1]:
			var neighbour := 1 if end == 0 else points.size() - 2
			var inward := points[end].direction_to(points[neighbour])
			var before := (from - points[end]).dot(inward)
			var after := (to - points[end]).dot(inward)
			if before > 0.01 or after < 0.0 or after <= before: continue
			# Reject sideways portal approaches and roads passing under a crossing.
			if from.direction_to(to).dot(inward) < 0.65: continue
			var fraction := clampf(-before / (after - before),0.0,1.0)
			var crossing_point := from.lerp(to,fraction)
			if absf((crossing_point - points[end]).cross(inward)) > float(corridor.half_width): continue
			if fraction < first_fraction:
				best = corridor
				first_fraction = fraction
	return best

func can_move(from: Vector2, to: Vector2, angle: float) -> bool:
	var corridor := candidate(from,to)
	if corridor.is_empty(): return true
	var steps := maxi(1,ceili(from.distance_to(to) / 4.0))
	for step in range(steps + 1):
		if not contains_pose(corridor,from.lerp(to,float(step)/steps),angle,half_size): return false
	return true

func commit_move(from: Vector2, to: Vector2) -> void:
	active = candidate(from,to)
	if active.is_empty(): return
	var points: PackedVector2Array = active.points
	for end in [0,points.size() - 1]:
		var neighbour := 1 if end == 0 else points.size() - 2
		var outward := points[neighbour].direction_to(points[end])
		# Wait until the whole actor clears an end, including when reversing out.
		if (to - points[end]).dot(outward) > half_size.length() and absf((to - points[end]).cross(outward)) <= float(active.half_width):
			var end_is_closest := true
			for index in range(points.size()-1):
				var sample := Geometry2D.get_closest_point_to_segment(to,points[index],points[index+1])
				if sample.distance_squared_to(to) + 0.01 < points[end].distance_squared_to(to):
					end_is_closest = false
					break
			if not end_is_closest: continue
			active = {}
			return

static func contains_pose(corridor: Dictionary, centre: Vector2, angle: float, extent: Vector2) -> bool:
	if not contains_point(corridor,centre): return false
	# Sample the perimeter, not only the centre, so a turning wagon cannot hang
	# its nose, rear or side beyond a railing on straight or curved crossings.
	var corners := [Vector2(-extent.x,-extent.y),Vector2(extent.x,-extent.y),Vector2(extent.x,extent.y),Vector2(-extent.x,extent.y)]
	for index in 4:
		var a: Vector2 = corners[index]
		var b: Vector2 = corners[(index+1)%4]
		var steps := maxi(1,ceili(a.distance_to(b)/4.0))
		for step in range(steps+1):
			if not contains_point(corridor,centre+a.lerp(b,float(step)/steps).rotated(angle)): return false
	return true

static func contains_point(corridor: Dictionary, point: Vector2) -> bool:
	var points: PackedVector2Array = corridor.points
	var width := float(corridor.half_width)
	var closest := Vector2.INF
	var distance := INF
	for index in range(points.size()-1):
		var sample := Geometry2D.get_closest_point_to_segment(point,points[index],points[index+1])
		var current := point.distance_squared_to(sample)
		if current < distance:
			distance = current
			closest = sample
	if distance <= width*width: return true
	for end in [0,points.size()-1]:
		if not closest.is_equal_approx(points[end]): continue
		var neighbour := 1 if end == 0 else points.size()-2
		var outward := points[neighbour].direction_to(points[end])
		if (point-points[end]).dot(outward) >= 0 and absf((point-points[end]).cross(outward)) <= width: return true
	return false
