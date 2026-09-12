class_name BuildingCollisionRuntime
extends Node2D

## Loads only nearby collision chunks. Each OSM footprint becomes one static body
## made from convex pieces, allowing concave L-shaped buildings to stay accurate.

@export var collision_layer := 1
@export var stream_radius_chunks := 1

var collision_data: Dictionary = {}
var pixels_per_metre := 8.0
var chunk_size_metres := 256.0
var buildings_by_chunk: Dictionary = {}
var loaded_chunks: Dictionary = {}


func setup(data: Dictionary) -> Dictionary:
	clear()
	if str(data.get("kind", "")) != "building_collision_index":
		return {"ok": false, "message": "The building collision file is missing or unsupported."}
	collision_data = data
	pixels_per_metre = float(data.get("runtime_scale", {}).get("pixels_per_metre", 8.0))
	chunk_size_metres = float(data.get("chunk_size_metres", 256.0))
	for building_value in data.get("buildings", []):
		var building: Dictionary = building_value
		var chunk: Array = building.get("chunk", [0, 0])
		var key := _chunk_key(Vector2i(int(chunk[0]), int(chunk[1])))
		if not buildings_by_chunk.has(key):
			buildings_by_chunk[key] = []
		buildings_by_chunk[key].append(building)
	return {"ok": true, "message": "Building collision data is ready.", "buildings": data.get("buildings", []).size()}


func update_streaming(world_position_pixels: Vector2) -> void:
	if collision_data.is_empty():
		return
	var position_metres := world_position_pixels / pixels_per_metre
	var centre := Vector2i(floori(position_metres.x / chunk_size_metres), floori(position_metres.y / chunk_size_metres))
	var required: Dictionary = {}
	for y in range(centre.y - stream_radius_chunks, centre.y + stream_radius_chunks + 1):
		for x in range(centre.x - stream_radius_chunks, centre.x + stream_radius_chunks + 1):
			var coordinate := Vector2i(x, y)
			var key := _chunk_key(coordinate)
			required[key] = true
			if buildings_by_chunk.has(key) and not loaded_chunks.has(key):
				_load_chunk(key)
	for loaded_key in loaded_chunks.keys().duplicate():
		if not required.has(loaded_key):
			loaded_chunks[loaded_key].queue_free()
			loaded_chunks.erase(loaded_key)


func activate_all_for_testing() -> void:
	for key in buildings_by_chunk:
		if not loaded_chunks.has(key):
			_load_chunk(key)


func clear() -> void:
	for chunk_node in loaded_chunks.values():
		chunk_node.queue_free()
	loaded_chunks.clear()
	buildings_by_chunk.clear()
	collision_data = {}


func _load_chunk(key: String) -> void:
	var chunk_node := Node2D.new()
	chunk_node.name = "CollisionChunk_%s" % key.replace(",", "_")
	add_child(chunk_node)
	loaded_chunks[key] = chunk_node
	for building_value in buildings_by_chunk[key]:
		_add_building_body(chunk_node, building_value)


func _add_building_body(parent: Node2D, building: Dictionary) -> void:
	var outer := _polygon_from_json(building.get("outer_metres", []))
	if outer.size() < 3:
		return
	var holes: Array[PackedVector2Array] = []
	for hole_value in building.get("holes_metres", []):
		var hole := _polygon_from_json(hole_value)
		if hole.size() >= 3:
			holes.append(hole)
	var body := StaticBody2D.new()
	body.name = "Building_%s" % str(building.get("id", "unknown"))
	body.collision_layer = collision_layer
	body.collision_mask = 0
	body.set_meta("building_id", str(building.get("id", "")))
	parent.add_child(body)
	for piece in _convex_pieces_with_holes(outer, holes):
		if piece.size() < 3:
			continue
		var scaled_piece := PackedVector2Array()
		for point in piece:
			scaled_piece.append(point * pixels_per_metre)
		var shape := ConvexPolygonShape2D.new()
		shape.points = scaled_piece
		var collision_shape := CollisionShape2D.new()
		collision_shape.shape = shape
		collision_shape.set_meta("building_id", str(building.get("id", "")))
		body.add_child(collision_shape)


func _convex_pieces_with_holes(outer_value: PackedVector2Array, holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if holes.is_empty() and outer_value.size() <= 48:
		var ordinary_pieces := Geometry2D.decompose_polygon_in_convex(outer_value)
		if not ordinary_pieces.is_empty():
			return ordinary_pieces
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.agent_radius = 0.0
	navigation_polygon.cell_size = 0.05
	var source_geometry := NavigationMeshSourceGeometryData2D.new()
	source_geometry.add_traversable_outline(outer_value)
	for hole_value in holes:
		source_geometry.add_obstruction_outline(hole_value)
	# The synchronous Godot 4.7 baker deterministically triangulates complex
	# outlines and preserves explicitly supplied inner obstructions.
	NavigationServer2D.bake_from_source_geometry_data(navigation_polygon, source_geometry)
	var vertices := navigation_polygon.get_vertices()
	var pieces: Array[PackedVector2Array] = []
	for polygon_index in navigation_polygon.get_polygon_count():
		var piece := PackedVector2Array()
		for vertex_index in navigation_polygon.get_polygon(polygon_index):
			piece.append(vertices[vertex_index])
		if piece.size() >= 3:
			pieces.append(piece)
	return pieces


func _polygon_from_json(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		if value is Array and value.size() >= 2:
			result.append(Vector2(float(value[0]), float(value[1])))
	return result


func _chunk_key(coordinate: Vector2i) -> String:
	return "%d,%d" % [coordinate.x, coordinate.y]
