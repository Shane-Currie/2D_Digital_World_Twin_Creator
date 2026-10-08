extends RefCounted

## Artwork only: the saved doorway and E-interaction anchor never move.
const HeightGeometry = preload("res://scripts/buildings/building_height_geometry.gd")
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const DOOR_TO_CHARACTER_HEIGHT := 1.15

static func build(door_point: Vector2, outside_point: Vector2, pixels_per_metre: float, ground: Array[PackedVector2Array], facades: Array[PackedVector2Array], rise_direction: Vector2 = Vector2.ZERO) -> Dictionary:
	var outward := door_point.direction_to(outside_point)
	var tangent := Vector2(-outward.y, outward.x)
	var bounds := Rect2()
	for piece in ground:
		var piece_bounds := HeightGeometry.polygon_bounds(piece)
		bounds = bounds.merge(piece_bounds) if bounds.has_area() else piece_bounds
	# A fixed metre-sized marker can dominate a tiny imported building. Limit
	# BOTH dimensions proportionally, preserving the saved interaction anchor.
	var shortest_span := minf(bounds.size.x, bounds.size.y)
	var door_height := minf(ActorArt.GROUND_CHARACTER_DRAW_SIZE.y * DOOR_TO_CHARACTER_HEIGHT, shortest_span * 0.20)
	var half_width := door_height * 0.25
	# Door base is at the ground entrance; its top rises INTO the joined facade,
	# not outward into the street or over the separately projected roof.
	var direction := -outward if rise_direction.is_zero_approx() else rise_direction.normalized()
	# Keep screen-visible door height proportional to the walking sprite even
	# when a consistent oblique prism rise adds sideways depth to the picture.
	var depth := direction * door_height / (maxf(0.65,absf(direction.y)) if not rise_direction.is_zero_approx() else 1.0)
	var corners := PackedVector2Array([door_point - tangent * half_width, door_point + tangent * half_width, door_point + tangent * half_width + depth, door_point - tangent * half_width + depth])
	var uvs := PackedVector2Array([Vector2(0,1),Vector2.ONE,Vector2(1,0),Vector2.ZERO])
	# Fit the COMPLETE picture into a short facade instead of cropping away
	# its handle/threshold. This scales art only, never the usable entrance.
	var visible := HeightGeometry.clipped_surfaces(corners, uvs, facades)
	if _surface_area(visible) < HeightGeometry.polygon_area(corners) * 0.98:
		var lower := 0.0
		var upper := 1.0
		for attempt in 10:
			var candidate := (lower+upper)*0.5
			var smaller := PackedVector2Array()
			for point in corners: smaller.append(door_point+(point-door_point)*candidate)
			if _surface_area(HeightGeometry.clipped_surfaces(smaller,uvs,facades)) >= HeightGeometry.polygon_area(smaller)*0.98: lower = candidate
			else: upper = candidate
		var fit := maxf(0.0,lower-0.002)
		for index in corners.size(): corners[index] = door_point+(corners[index]-door_point)*fit
		half_width *= fit
		visible = HeightGeometry.clipped_surfaces(corners,uvs,facades) if fit > 0.01 else []
	# ONLY visible exterior wall surfaces are eligible. No facade means no door
	# artwork from this camera direction; the entry arrow and E still work.
	var arrow_distance := door_point.distance_to(outside_point)
	for facade in facades:
		for index in facade.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(door_point, door_point+outward*pixels_per_metre*8.0, facade[index], facade[(index+1)%facade.size()])
			if hit != null: arrow_distance = maxf(arrow_distance, door_point.distance_to(hit)+pixels_per_metre*0.3)
	return {"anchor": door_point, "arrow_anchor": door_point+outward*arrow_distance, "visual_width": half_width * 2.0, "surfaces": visible}

static func _surface_area(surfaces: Array) -> float:
	var area := 0.0
	for surface in surfaces: area += HeightGeometry.polygon_area(surface.points)
	return area
