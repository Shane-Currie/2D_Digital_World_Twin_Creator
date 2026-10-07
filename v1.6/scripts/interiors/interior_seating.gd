extends RefCounted

const Orientation = preload("res://scripts/npcs/creation/seat_orientation.gd")

## Reach and stand checks use the same floor geometry as normal walking.
## A seat is an explicit exception, not a general collision-disable mode.
static func clear_route(layer, from: Vector2, to: Vector2, seat_id: String, radius := 0.0) -> bool:
	var seat: Dictionary={}
	for item in layer.floor_data.get("furniture",[]):
		if str(item.get("id",""))==seat_id: seat=item; break
	var seat_point: Vector2=Orientation.position(seat)*layer.pixels_per_metre if not seat.is_empty() else to
	# Furniture-only clearance tapers beside a bar counter; walls, floor edges
	# and cubicle partitions retain the full walking radius along the route.
	var taper:=not seat.is_empty() and str(seat.get("catalog_id",""))=="bar_stool"
	var steps := maxi(1, ceili(from.distance_to(to) / maxf(.1, layer.pixels_per_metre * .04)))
	for step in range(steps + 1):
		var point:=from.lerp(to,float(step)/steps)
		var furniture_radius:=radius
		if taper:
			var fraction:=clampf(point.distance_to(seat_point)/(layer.pixels_per_metre*.5),0,1)
			furniture_radius=lerpf(minf(radius,layer.pixels_per_metre*.18),radius,fraction)
		if not layer.is_traversable(point, radius, seat_id, furniture_radius): return false
	return true

static func nearest(layer, player_position: Vector2, radius := 4.0) -> Dictionary:
	var nearest_item: Dictionary = {}
	var nearest_distance: float = layer.pixels_per_metre * 1.4
	for item in layer.floor_data.get("furniture", []):
		if not Orientation.supported(item): continue
		var point: Vector2 = Orientation.position(item) * layer.pixels_per_metre
		var distance := player_position.distance_to(point)
		if distance > nearest_distance or not layer.is_position_discovered(point): continue
		if not clear_route(layer, player_position, point, str(item.id), radius): continue
		nearest_item = item
		nearest_distance = distance
	return nearest_item

static func stand_position(layer, item: Dictionary, original: Vector2, radius: float, actor_clear: Callable) -> Vector2:
	var centre: Vector2 = Orientation.position(item) * layer.pixels_per_metre
	var candidates: Array[Vector2] = [original]
	var direction := Orientation.facing(item)
	for distance in [0.8, 1.0, 1.25, 1.5]:
		for step in 16:
			candidates.append(centre + direction.rotated(TAU * step / 16.0) * float(distance) * layer.pixels_per_metre)
	for candidate in candidates:
		if centre.distance_to(candidate) > layer.pixels_per_metre * 2.0: continue
		if not layer.is_traversable(candidate, radius) or not clear_route(layer, centre, candidate, str(item.id), radius): continue
		if actor_clear.is_valid() and not bool(actor_clear.call(candidate, radius)): continue
		return candidate
	return Vector2.INF
