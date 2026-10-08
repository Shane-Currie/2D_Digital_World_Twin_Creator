extends RefCounted

## Startup-only spatial index. Facades must never paint over mapped obstacles.
const Geometry = preload("res://scripts/buildings/building_height_geometry.gd")
const CELL_SIZE := 512.0
var polygons: Array = []
var cells: Dictionary = {}

func add_polygon(points: PackedVector2Array, owner: String = "", floors: int = 0) -> void:
	if points.size() < 3: return
	var bounds := Geometry.polygon_bounds(points)
	var index := polygons.size()
	polygons.append({"points": points, "bounds": bounds, "owner": owner, "floors":floors})
	for cell in _cells_for(bounds): cells.get_or_add(cell, []).append(index)

func add_path(path: Dictionary, pixels_per_metre: float) -> void:
	if bool(path.get("tunnel", false)): return
	var points: PackedVector2Array = path.points
	var edge_margin := (0.125 if bool(path.walkway) else 0.30) * pixels_per_metre
	var width := float(path.half_width) + edge_margin + 0.1
	for index in range(points.size() - 1):
		if points[index].distance_to(points[index+1]) < 0.01: continue
		# Index individual segments, not a whole city's long road bounding box.
		for polygon in Geometry2D.offset_polyline(PackedVector2Array([points[index],points[index+1]]), width, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			add_polygon(polygon)

func query(bounds: Rect2, exclude_owner: String) -> Array:
	var found: Dictionary = {}
	for cell in _cells_for(bounds):
		for index in cells.get(cell, []): found[index] = true
	var result: Array = []
	for index in found:
		var polygon: Dictionary = polygons[index]
		if polygon.owner != exclude_owner and bounds.intersects(polygon.bounds, true): result.append(polygon)
	return result

func _cells_for(bounds: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var low := Vector2i(floori(bounds.position.x/CELL_SIZE),floori(bounds.position.y/CELL_SIZE))
	var high := Vector2i(floori(bounds.end.x/CELL_SIZE),floori(bounds.end.y/CELL_SIZE))
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1): result.append(Vector2i(x,y))
	return result
