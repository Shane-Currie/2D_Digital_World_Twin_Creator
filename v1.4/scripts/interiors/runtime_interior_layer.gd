class_name RuntimeInteriorLayer
extends Node2D

## Draws and confines the currently occupied creator-authored interior floor.
## Interior coordinates are stored in real metres and converted with the same
## town pixels-per-metre scale used by roads and building footprints.

const BACKGROUND := Color("#101815")
const FLOOR := Color("#d8d1bf")
const WALL := Color("#35463f")
const EXIT := Color("#55d681")

var floor_data: Dictionary = {}
var building_name := "Building"
var pixels_per_metre := 1.0
var exit_position := Vector2.ZERO


func _ready() -> void:
	z_index = 1
	visible = false


func open_floor(record: Dictionary, floor: Dictionary, entry_link: Dictionary, scale: float) -> Dictionary:
	if floor.is_empty() or entry_link.is_empty():
		return {"ok": false, "message": "This entrance does not have a saved interior arrival point."}
	floor_data = floor.duplicate(true)
	building_name = str(record.get("name", "Building"))
	pixels_per_metre = maxf(scale, 0.1)
	exit_position = metres_to_world(Vector2(float(entry_link.get("spawn_x_metres", 0.0)), float(entry_link.get("spawn_y_metres", 0.0))))
	var safe_position := nearest_safe_position(exit_position, 4.0)
	if safe_position == Vector2.INF:
		floor_data = {}
		return {"ok": false, "message": "The saved interior entry point is too close to a wall. Move it farther inside in Interior Designer."}
	exit_position = safe_position
	visible = true
	queue_redraw()
	return {"ok": true, "position": safe_position}


func close_floor() -> void:
	visible = false
	floor_data = {}
	queue_redraw()


func metres_to_world(position_metres: Vector2) -> Vector2:
	return position_metres * pixels_per_metre


func floor_bounds_world() -> Rect2:
	var boundary := _world_ring(floor_data.get("boundary_metres", []))
	if boundary.is_empty():
		return Rect2(Vector2.ZERO, Vector2(
			float(floor_data.get("width_metres", 1.0)),
			float(floor_data.get("height_metres", 1.0))
		) * pixels_per_metre)
	var bounds := Rect2(boundary[0], Vector2.ZERO)
	for point in boundary:
		bounds = bounds.expand(point)
	return bounds


func is_traversable(position: Vector2, clearance := 0.0) -> bool:
	if floor_data.is_empty():
		return false
	var offsets := [Vector2.ZERO]
	if clearance > 0.0:
		offsets.append_array([Vector2(clearance, 0), Vector2(-clearance, 0), Vector2(0, clearance), Vector2(0, -clearance)])
	for offset in offsets:
		if not _inside_floor(position + offset):
			return false
	return true


func nearest_safe_position(preferred: Vector2, clearance: float) -> Vector2:
	if is_traversable(preferred, clearance):
		return preferred
	for radius in range(2, 42, 2):
		for step in 16:
			var candidate := preferred + Vector2.RIGHT.rotated(TAU * float(step) / 16.0) * float(radius)
			if is_traversable(candidate, clearance):
				return candidate
	return Vector2.INF


func _inside_floor(position: Vector2) -> bool:
	var outer := _world_ring(floor_data.get("boundary_metres", []))
	if outer.size() < 3 or not Geometry2D.is_point_in_polygon(position, outer):
		return false
	for hole_value in floor_data.get("holes_metres", []):
		var hole := _world_ring(hole_value)
		if hole.size() >= 3 and Geometry2D.is_point_in_polygon(position, hole):
			return false
	return true


func _draw() -> void:
	if floor_data.is_empty():
		return
	var floor_extent := Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0))) * pixels_per_metre
	draw_rect(Rect2(Vector2(-2000, -2000), floor_extent + Vector2(4000, 4000)), BACKGROUND)
	var outer := _world_ring(floor_data.get("boundary_metres", []))
	if outer.size() >= 3:
		draw_colored_polygon(outer, FLOOR)
		draw_polyline(_closed(outer), WALL, 3.0, true)
	for hole_value in floor_data.get("holes_metres", []):
		var hole := _world_ring(hole_value)
		if hole.size() >= 3:
			draw_colored_polygon(hole, BACKGROUND)
			draw_polyline(_closed(hole), WALL, 3.0, true)
	draw_circle(exit_position, 6.0, Color("#173b29"))
	draw_circle(exit_position, 3.5, EXIT)
	draw_line(exit_position, exit_position + Vector2(0, -11), EXIT, 2.0, true)


func _world_ring(values: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		if value is Array and value.size() >= 2:
			result.append(metres_to_world(Vector2(float(value[0]), float(value[1]))))
	return result


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
