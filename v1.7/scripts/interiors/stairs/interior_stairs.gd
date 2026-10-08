class_name InteriorStairs
extends RefCounted

## A paired, passable stair platform. Coordinates use each floor's local metres.
## Stairs are passable. Reserve their whole artwork plus a small wall gap;
## the centre still has room for the player, without an empty 65 cm border.
const ART_SIZE := Vector2(1.4, 2.4)
const CLEAR_SIZE := ART_SIZE + Vector2.ONE * 0.2
const MAX_PAIRS := 40

static func position(endpoint: Dictionary) -> Vector2:
	return Vector2(float(endpoint.get("x_metres", -INF)), float(endpoint.get("y_metres", -INF)))

static func endpoints(record: Dictionary, floor_id: String) -> Array:
	var result: Array = []
	for pair in record.get("stairs", []):
		if not pair is Dictionary: continue
		for side in ["from", "to"]:
			if not pair.get(side, {}) is Dictionary or not pair.get("to" if side == "from" else "from", {}) is Dictionary: continue
			var endpoint: Dictionary = pair.get(side, {})
			var point := position(endpoint)
			if not is_finite(point.x) or not is_finite(point.y): continue
			if str(endpoint.get("floor_id", "")) == floor_id:
				var opposite: Dictionary = pair.get("to" if side == "from" else "from", {})
				var value: Dictionary = endpoint.duplicate(true)
				value["id"] = str(pair.get("id", ""))
				value["side"] = side
				value["destination"] = opposite.duplicate(true)
				for floor in record.get("floors", []):
					if str(floor.get("id", "")) == str(opposite.get("floor_id", "")):
						value["destination_name"] = str(floor.get("name", "Floor"))
						value["up"] = int(floor.get("level", 0)) > _level(record, floor_id)
				result.append(value)
	return result

static func _level(record: Dictionary, floor_id: String) -> int:
	for floor in record.get("floors", []):
		if str(floor.get("id", "")) == floor_id: return int(floor.get("level", 0))
	return 0

static func rectangle(point: Vector2, size: Vector2 = CLEAR_SIZE, degrees := 0.0) -> PackedVector2Array:
	var half := size * 0.5
	var result := PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	for i in result.size(): result[i] = result[i].rotated(deg_to_rad(degrees)) + point
	return result

static func rotation(endpoint: Dictionary) -> float:
	return float(endpoint.get("rotation_degrees", 0.0))

static func clear_polygon(endpoint: Dictionary) -> PackedVector2Array:
	return rectangle(position(endpoint), CLEAR_SIZE, rotation(endpoint))

static func ring(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		if value is Array and value.size() >= 2: result.append(Vector2(float(value[0]), float(value[1])))
	return result

static func overlaps(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	return not Geometry2D.intersect_polygons(first, second).is_empty()

static func fits(floor: Dictionary, point: Vector2, existing: Array = [], ignored_id := "", degrees := 0.0) -> bool:
	if not is_finite(point.x) or not is_finite(point.y) or not is_finite(degrees) or floor.is_empty(): return false
	var polygon := rectangle(point, CLEAR_SIZE, degrees)
	var outer := ring(floor.get("boundary_metres", []))
	if outer.size() < 3: return false
	# Clipping also detects concave notches crossing between valid corners.
	if not Geometry2D.clip_polygons(polygon, outer).is_empty(): return false
	for hole in floor.get("holes_metres", []):
		if overlaps(polygon, ring(hole)): return false
	for wall in floor.get("walls", []):
		var start := Vector2(float(wall.get("start_x_metres", 0.0)), float(wall.get("start_y_metres", 0.0)))
		var finish := Vector2(float(wall.get("end_x_metres", 0.0)), float(wall.get("end_y_metres", 0.0)))
		var side := (finish - start).normalized().orthogonal() * (float(wall.get("thickness_metres", 0.2)) * 0.5 + 0.05)
		if overlaps(polygon, PackedVector2Array([start + side, finish + side, finish - side, start - side])): return false
	for item in floor.get("furniture", []):
		var centre := Vector2(float(item.get("x_metres", 0.0)), float(item.get("y_metres", 0.0)))
		var size := Vector2(float(item.get("width_metres", 0.0)), float(item.get("depth_metres", 0.0)))
		var item_polygon := rectangle(Vector2.ZERO, size)
		for i in item_polygon.size(): item_polygon[i] = item_polygon[i].rotated(deg_to_rad(float(item.get("rotation_degrees", 0.0)))) + centre
		if overlaps(polygon, item_polygon): return false
	for link in floor.get("entry_links", []):
		var arrival := Vector2(float(link.get("spawn_x_metres", 0.0)), float(link.get("spawn_y_metres", 0.0)))
		if overlaps(polygon, rectangle(arrival, Vector2.ONE * 1.6)): return false
	for other in existing:
		if str(other.get("id", "")) != ignored_id and overlaps(polygon, clear_polygon(other)): return false
	return true

static func validate(record: Dictionary) -> Dictionary:
	var pairs = record.get("stairs", [])
	if not pairs is Array or pairs.size() > MAX_PAIRS or not record.get("floors", []) is Array: return {"ok": false, "message": "Use at most 40 paired stairs per building."}
	var ids: Dictionary = {}
	for pair in pairs:
		if not pair is Dictionary: return {"ok": false, "message": "Invalid stair pair."}
		var id := str(pair.get("id", ""))
		if id.is_empty() or ids.has(id): return {"ok": false, "message": "Stairs need distinct stable IDs."}
		ids[id] = true
		if not pair.get("from") is Dictionary or not pair.get("to") is Dictionary: return {"ok": false, "message": "Place both ends of the stairs."}
		if str(pair.from.get("floor_id", "")) == str(pair.to.get("floor_id", "")): return {"ok": false, "message": "Stairs must connect two different floors."}
		for side in ["from", "to"]:
			var endpoint: Dictionary = pair[side]
			var floor: Dictionary = {}
			for candidate in record.get("floors", []):
				if str(candidate.get("id", "")) == str(endpoint.get("floor_id", "")): floor = candidate
			if not endpoint.get("x_metres") is float and not endpoint.get("x_metres") is int or not endpoint.get("y_metres") is float and not endpoint.get("y_metres") is int:
				return {"ok": false, "message": "Stair coordinates must be finite numbers."}
			var angle = endpoint.get("rotation_degrees", 0.0)
			if not angle is float and not angle is int or not is_finite(float(angle)) or float(angle) < 0 or float(angle) >= 360:
				return {"ok": false, "message": "Stair rotation must be from 0 to 359 degrees."}
			if not fits(floor, position(endpoint), endpoints(record, str(endpoint.get("floor_id", ""))), id, float(angle)):
				return {"ok": false, "message": "Keep stairs and their landing clear of edges, courtyards, walls, furniture, entrances and other stairs."}
	return {"ok": true}

static func draw_platform(canvas: CanvasItem, centre: Vector2, scale: float, up: bool, selected := false, degrees := 0.0) -> void:
	canvas.draw_set_transform(centre, deg_to_rad(degrees))
	centre = Vector2.ZERO
	var rect := Rect2(-ART_SIZE * scale * 0.5, ART_SIZE * scale)
	canvas.draw_rect(rect, Color("#33443e"))
	var inset := rect.grow(-0.12 * scale)
	canvas.draw_rect(inset, Color("#a69b83"))
	for step in range(1, 9):
		var y := inset.position.y + inset.size.y * step / 9.0
		canvas.draw_line(Vector2(inset.position.x, y), Vector2(inset.end.x, y), Color("#635e50"), maxf(1.0, scale * 0.05))
	var direction := Vector2(0, -1 if up else 1)
	var tip := centre + direction * scale * 0.75
	canvas.draw_line(centre - direction * scale * 0.65, tip, Color("#ffe6a4"), maxf(2.0, scale * 0.09))
	canvas.draw_line(tip, tip - direction.rotated(0.6) * scale * 0.45, Color("#ffe6a4"), maxf(2.0, scale * 0.09))
	canvas.draw_line(tip, tip - direction.rotated(-0.6) * scale * 0.45, Color("#ffe6a4"), maxf(2.0, scale * 0.09))
	canvas.draw_rect(rect, Color("#72a7ff") if selected else Color("#d2c6ad"), false, maxf(1.0, scale * 0.05))
	canvas.draw_set_transform(Vector2.ZERO)
