extends RefCounted

const Cover = preload("res://scripts/land_cover/land_cover.gd")
var areas: Array[Dictionary] = []
var cells: Dictionary = {}
var cell_size := 512.0

func setup(features: Array, project_point: Callable, map_bounds: Rect2) -> void:
	areas.clear()
	cells.clear()
	for feature in features:
		if feature.get("kind", "") not in ["land_cover", "building"]:
			continue
		var outer := _polygon(feature.get("points", []), project_point)
		if outer.size() < 3:
			continue
		var bounds := Rect2(outer[0], Vector2.ZERO)
		for point in outer:
			bounds = bounds.expand(point)
		if not bounds.intersects(map_bounds):
			continue
		var holes: Array[PackedVector2Array] = []
		for values in feature.get("holes", []):
			var hole := _polygon(values, project_point)
			if hole.size() >= 3:
				holes.append(hole)
		var category := "building" if feature.kind == "building" else Cover.classify(feature.tags)
		if category.is_empty(): continue
		var area := {"id": str(feature.id), "category": category, "outer": outer, "holes": holes, "bounds": bounds, "pieces": []}
		if category != "building":
			area.pieces = Cover.pieces(outer, holes)
			if area.pieces.is_empty():
				continue
		areas.append(area)
	# Broad parks form the base; smaller explicit surfaces and buildings win.
	areas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a.category == "building") != (b.category == "building"): return b.category == "building"
		if (a.category == "park") != (b.category == "park"): return a.category == "park"
		if not is_equal_approx(a.bounds.get_area(), b.bounds.get_area()): return a.bounds.get_area() > b.bounds.get_area()
		return a.id < b.id)
	for area in areas:
		var bounds: Rect2 = area.bounds.intersection(map_bounds)
		var low := Vector2i((bounds.position / cell_size).floor())
		var high := Vector2i((bounds.end / cell_size).floor())
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var key := Vector2i(x, y)
				if not cells.has(key): cells[key] = []
				cells[key].append(area)

func category_at(point: Vector2) -> String:
	var candidates: Array = cells.get(Vector2i((point / cell_size).floor()), [])
	for index in range(candidates.size() - 1, -1, -1):
		var area: Dictionary = candidates[index]
		if not area.bounds.has_point(point) or not Geometry2D.is_point_in_polygon(point, area.outer): continue
		var in_hole := false
		for hole in area.holes:
			if Geometry2D.is_point_in_polygon(point, hole):
				in_hole = true
				break
		if not in_hole: return area.category
	return ""

func _polygon(values: Array, project_point: Callable) -> PackedVector2Array:
	var points := PackedVector2Array()
	for value in values:
		var point: Vector2 = project_point.call(value)
		if points.is_empty() or not points[points.size() - 1].is_equal_approx(point): points.append(point)
	if points.size() > 2 and points[0].is_equal_approx(points[points.size() - 1]): points.remove_at(points.size() - 1)
	return points
