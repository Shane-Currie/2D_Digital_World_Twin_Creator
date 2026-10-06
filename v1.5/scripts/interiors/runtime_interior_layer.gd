class_name RuntimeInteriorLayer
extends Node2D

signal room_discovery_changed

## Draws and confines the currently occupied creator-authored interior floor.
## Interior coordinates are stored in real metres and converted with the same
## town pixels-per-metre scale used by roads and building footprints.

const BACKGROUND := Color("#101815")
const FLOOR := Color("#d8d1bf")
const WALL := Color("#35463f")
const EXIT := Color("#55d681")
const LOCKED_DOOR := Color("#e45b55")
const WALL_JOIN_DISTANCE_METRES := 1.0
const FloorMaterialLibraryScript = preload("res://scripts/interiors/interior_floor_material_library.gd")

var floor_data: Dictionary = {}
var building_name := "Building"
var pixels_per_metre := 1.0
var exit_position := Vector2.ZERO
var town_directory := ""
var custom_textures: Dictionary = {}
var floor_material_definitions: Dictionary = {}
var floor_material_textures: Dictionary = {}
var visibility_cell_world := 8.0
var visibility_columns := 0
var visibility_rows := 0
var visibility_components: Dictionary = {}
var discovered_components: Dictionary = {}
var fog_texture: ImageTexture


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false


func set_town_directory(path_value: String) -> void:
	town_directory = path_value
	custom_textures.clear()
	_load_floor_materials()


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
	_build_room_visibility()
	update_player_position(safe_position)
	visible = true
	queue_redraw()
	return {"ok": true, "position": safe_position}


func close_floor() -> void:
	visible = false
	floor_data = {}
	visibility_components.clear()
	discovered_components.clear()
	fog_texture = null
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
	for furniture_value in floor_data.get("furniture", []):
		if bool(furniture_value.get("collision", true)) and _inside_furniture(position, furniture_value, clearance):
			return false
	for wall_value in floor_data.get("walls", []):
		if wall_value is Dictionary and _inside_wall(position, wall_value, clearance):
			return false
	return true


func furniture_at_world(position_world: Vector2) -> Dictionary:
	if not is_position_discovered(position_world):
		return {}
	# Reverse order matches drawing order when furniture overlaps in old/manual
	# data. New placement validation still prevents solid overlaps.
	var furniture: Array = floor_data.get("furniture", [])
	for index in range(furniture.size() - 1, -1, -1):
		var item: Dictionary = furniture[index]
		if _inside_furniture(position_world, item, 0.0):
			return item.duplicate(true)
	return {}


func update_player_position(position_world: Vector2) -> void:
	if visibility_components.is_empty() or visibility_columns <= 0 or visibility_rows <= 0:
		return
	var column := clampi(floori(position_world.x / visibility_cell_world), 0, visibility_columns - 1)
	var row := clampi(floori(position_world.y / visibility_cell_world), 0, visibility_rows - 1)
	var component = visibility_components.get(row * visibility_columns + column, null)
	if component == null or discovered_components.has(int(component)):
		return
	discovered_components[int(component)] = true
	_rebuild_fog_texture()
	queue_redraw()
	room_discovery_changed.emit()


func room_component_at_world(position_world: Vector2) -> int:
	if visibility_columns <= 0 or visibility_rows <= 0: return -1
	var column := clampi(floori(position_world.x / visibility_cell_world), 0, visibility_columns - 1)
	var row := clampi(floori(position_world.y / visibility_cell_world), 0, visibility_rows - 1)
	return int(visibility_components.get(row * visibility_columns + column, -1))


func is_position_discovered(position_world: Vector2) -> bool:
	# Floors without internal walls have no concealed rooms and remain fully
	# visible. On divided floors, only the player's discovered room components
	# expose their furniture, characters and interactions.
	if visibility_components.is_empty():
		return true
	var component := room_component_at_world(position_world)
	return component >= 0 and discovered_components.has(component)


func current_room_name(position_world: Vector2) -> String:
	var current_component := room_component_at_world(position_world)
	if current_component < 0: return ""
	var nearest_name := ""
	var nearest_distance := INF
	for room_value in floor_data.get("rooms", []):
		if not room_value is Dictionary: continue
		var room: Dictionary = room_value
		var label_position := metres_to_world(Vector2(float(room.get("label_x_metres", 0.0)), float(room.get("label_y_metres", 0.0))))
		if room_component_at_world(label_position) != current_component: continue
		var distance := position_world.distance_to(label_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_name = str(room.get("name", "Room")).strip_edges()
	return nearest_name


func nearest_internal_door(position_world: Vector2, maximum_distance: float) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := maximum_distance
	for wall_value in floor_data.get("walls", []):
		if not wall_value is Dictionary: continue
		var wall: Dictionary = wall_value
		var segment := _effective_wall_segment(wall)
		var start: Vector2 = segment[0]
		var finish: Vector2 = segment[1]
		var delta := finish - start
		var length := delta.length()
		if length <= 0.001: continue
		var direction := delta / length
		for door_value in wall.get("doors", []):
			var door: Dictionary = door_value
			var centre := start + direction * float(door.get("offset_metres", 0.0)) * pixels_per_metre
			var distance := position_world.distance_to(centre)
			if distance > nearest_distance: continue
			nearest_distance = distance
			nearest = {"wall": wall, "door": door, "centre": centre, "direction": direction, "distance": distance}
	return nearest


func cross_internal_door(position_world: Vector2, clearance_world: float) -> Dictionary:
	var threshold := maxf(12.0, pixels_per_metre * 1.8)
	var portal := nearest_internal_door(position_world, threshold)
	if portal.is_empty():
		return {"ok": false, "message": "Move closer to a green internal doorway, then press E."}
	if bool(portal.get("door", {}).get("locked", false)):
		return {"ok": false, "locked": true, "message": "The door is locked."}
	var normal: Vector2 = Vector2(portal.direction).orthogonal().normalized()
	var side := signf((position_world - Vector2(portal.centre)).dot(normal))
	if is_zero_approx(side): side = 1.0
	var wall: Dictionary = portal.wall
	var target_distance := clearance_world + float(wall.get("thickness_metres", 0.18)) * pixels_per_metre * 0.5 + 2.0
	var target := Vector2(portal.centre) - normal * side * target_distance
	if not is_traversable(target, clearance_world):
		return {"ok": false, "message": "The other side of this doorway is blocked. Move its furniture or widen the clear area."}
	return {"ok": true, "position": target, "message": "Entered through the internal doorway."}


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
	_draw_flooring()
	for hole_value in floor_data.get("holes_metres", []):
		var hole := _world_ring(hole_value)
		if hole.size() >= 3:
			draw_colored_polygon(hole, BACKGROUND)
			draw_polyline(_closed(hole), WALL, 3.0, true)
	for furniture_value in floor_data.get("furniture", []):
		var furniture_position := metres_to_world(Vector2(float(furniture_value.get("x_metres", 0.0)), float(furniture_value.get("y_metres", 0.0))))
		if is_position_discovered(furniture_position):
			_draw_furniture(furniture_value)
	_draw_undiscovered_rooms()
	# Redraw courtyard holes over the visibility grid so fog never fills them.
	for hole_value in floor_data.get("holes_metres", []):
		var hole := _world_ring(hole_value)
		if hole.size() >= 3:
			draw_colored_polygon(hole, BACKGROUND)
			draw_polyline(_closed(hole), WALL, 3.0, true)
	for wall_value in floor_data.get("walls", []):
		if wall_value is Dictionary: _draw_internal_wall(wall_value)
	draw_circle(exit_position, 6.0, Color("#173b29"))
	draw_circle(exit_position, 3.5, EXIT)
	draw_line(exit_position, exit_position + Vector2(0, -11), EXIT, 2.0, true)


func _inside_furniture(position_world: Vector2, item: Dictionary, clearance_world: float) -> bool:
	var centre := metres_to_world(Vector2(float(item.get("x_metres", 0.0)), float(item.get("y_metres", 0.0))))
	var local := (position_world - centre).rotated(-deg_to_rad(float(item.get("rotation_degrees", 0.0))))
	var half_size := Vector2(float(item.get("width_metres", 0.5)), float(item.get("depth_metres", 0.5))) * pixels_per_metre * 0.5 + Vector2.ONE * clearance_world
	return absf(local.x) <= half_size.x and absf(local.y) <= half_size.y


func _inside_wall(position_world: Vector2, wall: Dictionary, clearance_world: float) -> bool:
	var segment := _effective_wall_segment(wall)
	var start: Vector2 = segment[0]
	var finish: Vector2 = segment[1]
	var delta := finish - start
	var length := delta.length()
	if length <= 0.001: return false
	var direction := delta / length
	var offset := clampf((position_world - start).dot(direction), 0.0, length)
	var projected := start + direction * offset
	if position_world.distance_to(projected) > float(wall.get("thickness_metres", 0.18)) * pixels_per_metre * 0.5 + clearance_world:
		return false
	# Internal doorway gaps are interaction portals. The player cannot walk
	# through them accidentally; E moves the player safely to the other side.
	return true


func _draw_internal_wall(wall: Dictionary) -> void:
	var segment := _effective_wall_segment(wall)
	var start: Vector2 = segment[0]
	var finish: Vector2 = segment[1]
	var delta := finish - start
	var length := delta.length()
	if length <= 0.001: return
	var direction := delta / length
	var openings: Array = []
	for door_value in wall.get("doors", []):
		var door: Dictionary = door_value
		var centre := float(door.get("offset_metres", 0.0)) * pixels_per_metre
		var half_width := float(door.get("width_metres", 0.9)) * pixels_per_metre * 0.5
		openings.append({"start": maxf(0.0, centre - half_width), "finish": minf(length, centre + half_width), "locked": bool(door.get("locked", false))})
	openings.sort_custom(func(a, b): return float(a.start) < float(b.start))
	var cursor := 0.0
	var line_width := maxf(2.0, float(wall.get("thickness_metres", 0.18)) * pixels_per_metre)
	for opening in openings:
		if float(opening.start) > cursor:
			draw_line(start + direction * cursor, start + direction * float(opening.start), WALL, line_width, true)
		var door_centre := start + direction * ((float(opening.start) + float(opening.finish)) * 0.5)
		var indicator := LOCKED_DOOR if bool(opening.locked) else EXIT
		draw_line(door_centre - direction.orthogonal() * 3.0, door_centre + direction.orthogonal() * 3.0, indicator, 1.5, true)
		cursor = maxf(cursor, float(opening.finish))
	if cursor < length:
		draw_line(start + direction * cursor, finish, WALL, line_width, true)


func _build_room_visibility() -> void:
	visibility_components.clear()
	discovered_components.clear()
	if floor_data.get("walls", []).is_empty():
		visibility_columns = 0
		visibility_rows = 0
		fog_texture = null
		return
	var extent := Vector2(float(floor_data.get("width_metres", 1.0)), float(floor_data.get("height_metres", 1.0))) * pixels_per_metre
	visibility_cell_world = maxf(pixels_per_metre * 0.5, maxf(extent.x, extent.y) / 96.0)
	visibility_columns = maxi(1, ceili(extent.x / visibility_cell_world))
	visibility_rows = maxi(1, ceili(extent.y / visibility_cell_world))
	var available: Dictionary = {}
	for row in visibility_rows:
		for column in visibility_columns:
			var index := row * visibility_columns + column
			var centre := Vector2((column + 0.5) * visibility_cell_world, (row + 0.5) * visibility_cell_world)
			if _inside_floor(centre): available[index] = centre
	var component_id := 0
	var neighbour_steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for start_index in available:
		if visibility_components.has(start_index): continue
		var queue: Array[int] = [int(start_index)]
		visibility_components[int(start_index)] = component_id
		var cursor := 0
		while cursor < queue.size():
			var current_index := queue[cursor]
			cursor += 1
			var current_column: int = current_index % visibility_columns
			var current_row: int = floori(float(current_index) / float(visibility_columns))
			for step: Vector2i in neighbour_steps:
				var next_column: int = current_column + step.x
				var next_row: int = current_row + step.y
				if next_column < 0 or next_row < 0 or next_column >= visibility_columns or next_row >= visibility_rows: continue
				var next_index: int = next_row * visibility_columns + next_column
				if not available.has(next_index) or visibility_components.has(next_index): continue
				if _visibility_crosses_wall(available[current_index], available[next_index]): continue
				visibility_components[next_index] = component_id
				queue.append(next_index)
		component_id += 1
	_rebuild_fog_texture()


func _visibility_crosses_wall(start: Vector2, finish: Vector2) -> bool:
	for wall_value in floor_data.get("walls", []):
		if not wall_value is Dictionary: continue
		var segment := _effective_wall_segment(wall_value)
		var wall_start: Vector2 = segment[0]
		var wall_finish: Vector2 = segment[1]
		if Geometry2D.segment_intersects_segment(start, finish, wall_start, wall_finish) != null:
			return true
	return false


func _draw_undiscovered_rooms() -> void:
	if fog_texture == null or visibility_columns <= 0 or visibility_rows <= 0:
		return
	# One filtered texture replaces the old collection of visible square cells.
	# Its gently varied opacity creates a continuous, soft-edged fog bank while
	# the underlying content is independently withheld from drawing.
	draw_texture_rect(
		fog_texture,
		Rect2(Vector2.ZERO, Vector2(visibility_columns, visibility_rows) * visibility_cell_world),
		false
	)


func _rebuild_fog_texture() -> void:
	if visibility_components.is_empty() or visibility_columns <= 0 or visibility_rows <= 0:
		fog_texture = null
		return
	var image := Image.create(visibility_columns, visibility_rows, false, Image.FORMAT_RGBA8)
	for row in visibility_rows:
		for column in visibility_columns:
			var component := int(visibility_components.get(row * visibility_columns + column, -1))
			if component < 0 or discovered_components.has(component):
				image.set_pixel(column, row, Color.TRANSPARENT)
				continue
			# Layer two deterministic waves instead of random pixels. Linear texture
			# filtering turns these small variations into broad smoky patches.
			var cloud := (sin(float(column) * 0.63 + float(row) * 0.31) + sin(float(column) * 0.19 - float(row) * 0.77)) * 0.5
			var shade := 0.025 * cloud
			var alpha := clampf(0.94 + 0.025 * cloud, 0.90, 0.985)
			image.set_pixel(column, row, Color(0.115 + shade, 0.135 + shade, 0.13 + shade, alpha))
	fog_texture = ImageTexture.create_from_image(image)


func _draw_furniture(item: Dictionary) -> void:
	var centre := metres_to_world(Vector2(float(item.get("x_metres", 0.0)), float(item.get("y_metres", 0.0))))
	var half_size := Vector2(float(item.get("width_metres", 0.5)), float(item.get("depth_metres", 0.5))) * pixels_per_metre * 0.5
	var rotation := deg_to_rad(float(item.get("rotation_degrees", 0.0)))
	var polygon := PackedVector2Array()
	for corner in [Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)]:
		polygon.append(centre + corner.rotated(rotation))
	var outline := Color(str(item.get("outline", "#41362d")))
	var custom_texture := _texture_for_item(item)
	if custom_texture == null:
		draw_colored_polygon(polygon, Color(str(item.get("fill", "#8a735d"))))
	draw_polyline(_closed(polygon), outline, 1.5, true)
	draw_set_transform(centre, rotation, Vector2.ONE)
	if custom_texture != null:
		draw_texture_rect(custom_texture, Rect2(-half_size, half_size * 2.0), false)
	else:
		_draw_furniture_details(str(item.get("catalog_id", "")), half_size, outline)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _load_floor_materials() -> void:
	floor_material_definitions.clear()
	floor_material_textures.clear()
	var library = FloorMaterialLibraryScript.new()
	var custom_data := library.empty_data()
	if not town_directory.is_empty():
		var loaded: Dictionary = library.load_from_town(town_directory)
		if bool(loaded.get("ok", false)): custom_data = loaded.data
	for definition_value in library.all_definitions(custom_data):
		if not definition_value is Dictionary: continue
		var definition: Dictionary = definition_value
		var material_id := str(definition.get("id", ""))
		floor_material_definitions[material_id] = definition
		var path_value := str(definition.get("image_path", "")).replace("\\", "/")
		var texture: Texture2D
		if path_value.begins_with("res://"):
			if ResourceLoader.exists(path_value):
				var loaded_texture = load(path_value)
				if loaded_texture is Texture2D: texture = loaded_texture
			if texture == null:
				var built_in_image := Image.new()
				if built_in_image.load(ProjectSettings.globalize_path(path_value)) == OK and not built_in_image.is_empty(): texture = ImageTexture.create_from_image(built_in_image)
		elif not path_value.is_empty() and not path_value.contains("..") and not path_value.is_absolute_path() and not town_directory.is_empty():
			var image := Image.new()
			if image.load(town_directory.path_join(path_value)) == OK and not image.is_empty(): texture = ImageTexture.create_from_image(image)
		if texture != null: floor_material_textures[material_id] = texture


func _draw_flooring() -> void:
	var flooring: Dictionary = floor_data.get("flooring", {})
	var cell_size_metres := float(flooring.get("cell_size_metres", 0.5))
	if cell_size_metres <= 0.0: return
	var cell_world := cell_size_metres * pixels_per_metre
	for cell_key in flooring.get("cells", {}):
		var parts := str(cell_key).split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var material_id := str(flooring.get("cells", {}).get(cell_key, ""))
		if material_id == "default_floor": continue
		var destination := Rect2(Vector2(cell) * cell_world, Vector2.ONE * (cell_world + 0.35))
		var texture: Texture2D = floor_material_textures.get(material_id)
		if texture != null:
			var source_cell := 64
			var source_columns := maxi(1, texture.get_width() / source_cell)
			var source_rows := maxi(1, texture.get_height() / source_cell)
			var source := Rect2(posmod(cell.x, source_columns) * source_cell, posmod(cell.y, source_rows) * source_cell, source_cell, source_cell)
			draw_texture_rect_region(texture, destination, source)
		else:
			var definition: Dictionary = floor_material_definitions.get(material_id, {})
			draw_rect(destination, Color(str(definition.get("fill", "#8a735d"))))


func _draw_furniture_details(catalog_id: String, half_size: Vector2, outline: Color) -> void:
	var light := outline.lightened(0.55)
	var dark := outline.darkened(0.18)
	var full := half_size * 2.0
	match catalog_id:
		"dining_table":
			draw_rect(Rect2(-half_size * 0.78, full * 0.78), light, false, 1.0)
			for corner in [Vector2(-0.65, -0.58), Vector2(0.65, -0.58), Vector2(0.65, 0.58), Vector2(-0.65, 0.58)]:
				draw_circle(corner * half_size, maxf(0.6, minf(half_size.x, half_size.y) * 0.12), dark)
		"dining_chair":
			draw_rect(Rect2(Vector2(-half_size.x * 0.7, -half_size.y * 0.45), Vector2(half_size.x * 1.4, half_size.y * 1.05)), light, false, 1.0)
			draw_line(Vector2(-half_size.x * 0.72, -half_size.y * 0.7), Vector2(half_size.x * 0.72, -half_size.y * 0.7), dark, 2.0)
		"sofa":
			draw_rect(Rect2(Vector2(-half_size.x * 0.82, -half_size.y * 0.5), Vector2(half_size.x * 1.64, half_size.y * 1.05)), light, false, 1.0)
			draw_rect(Rect2(Vector2(-half_size.x * 0.92, -half_size.y * 0.85), Vector2(half_size.x * 1.84, half_size.y * 0.28)), dark)
			draw_rect(Rect2(Vector2(-half_size.x * 0.95, -half_size.y * 0.5), Vector2(half_size.x * 0.16, half_size.y * 1.15)), dark)
			draw_rect(Rect2(Vector2(half_size.x * 0.79, -half_size.y * 0.5), Vector2(half_size.x * 0.16, half_size.y * 1.15)), dark)
			draw_line(Vector2.ZERO, Vector2(0, half_size.y * 0.55), outline, 1.0)
		"single_bed":
			draw_rect(Rect2(Vector2(-half_size.x * 0.82, -half_size.y * 0.82), Vector2(half_size.x * 1.64, half_size.y * 0.42)), Color("#e7ded0"), true)
			draw_rect(Rect2(Vector2(-half_size.x * 0.78, -half_size.y * 0.3), Vector2(half_size.x * 1.56, half_size.y * 1.02)), light, false, 1.0)
			draw_line(Vector2(-half_size.x * 0.78, half_size.y * 0.25), Vector2(half_size.x * 0.78, half_size.y * 0.25), outline, 1.0)
		"wardrobe":
			draw_line(Vector2(0, -half_size.y * 0.88), Vector2(0, half_size.y * 0.88), light, 1.0)
			draw_circle(Vector2(-half_size.x * 0.12, 0), 1.0, light)
			draw_circle(Vector2(half_size.x * 0.12, 0), 1.0, light)
		"kitchen_counter":
			draw_rect(Rect2(Vector2(-half_size.x * 0.9, -half_size.y * 0.82), Vector2(half_size.x * 1.8, half_size.y * 0.22)), light)
			draw_circle(Vector2(-half_size.x * 0.42, 0), minf(half_size.y * 0.38, 3.0), Color("#b9d0d2"))
			draw_circle(Vector2(half_size.x * 0.45, 0), minf(half_size.y * 0.3, 2.6), dark, false, 1.0)
		"bathroom_sink":
			draw_circle(Vector2(0, half_size.y * 0.05), minf(half_size.x, half_size.y) * 0.58, Color("#f2f5f2"))
			draw_circle(Vector2(0, half_size.y * 0.05), minf(half_size.x, half_size.y) * 0.32, Color("#9eb8ba"), false, 1.0)
			draw_line(Vector2(0, -half_size.y * 0.65), Vector2(0, -half_size.y * 0.15), dark, 1.5)
		"toilet":
			draw_rect(Rect2(Vector2(-half_size.x * 0.62, -half_size.y * 0.83), Vector2(half_size.x * 1.24, half_size.y * 0.4)), Color("#f5f6f1"))
			draw_circle(Vector2(0, half_size.y * 0.2), minf(half_size.x * 0.62, half_size.y * 0.48), Color("#f5f6f1"))
			draw_circle(Vector2(0, half_size.y * 0.2), minf(half_size.x * 0.35, half_size.y * 0.28), Color("#9fb7b8"), false, 1.0)
		"office_desk":
			draw_rect(Rect2(Vector2(-half_size.x * 0.25, -half_size.y * 0.45), Vector2(half_size.x * 0.5, half_size.y * 0.38)), Color("#314f5e"), true)
			draw_line(Vector2(0, -half_size.y * 0.07), Vector2(0, half_size.y * 0.35), light, 1.0)
			draw_rect(Rect2(Vector2(-half_size.x * 0.22, half_size.y * 0.3), Vector2(half_size.x * 0.44, half_size.y * 0.12)), dark)
		"shop_shelf":
			for fraction in [-0.55, 0.0, 0.55]:
				draw_line(Vector2(-half_size.x * 0.85, half_size.y * fraction), Vector2(half_size.x * 0.85, half_size.y * fraction), light, 1.0)
		"bar_counter":
			draw_rect(Rect2(Vector2(-half_size.x * 0.9, -half_size.y * 0.78), Vector2(half_size.x * 1.8, half_size.y * 0.28)), light)
			for fraction in [-0.55, 0.0, 0.55]:
				draw_line(Vector2(half_size.x * fraction, -half_size.y * 0.3), Vector2(half_size.x * fraction, half_size.y * 0.72), dark, 1.0)
		"bar_stool":
			draw_circle(Vector2.ZERO, minf(half_size.x, half_size.y) * 0.65, light)
			draw_circle(Vector2.ZERO, minf(half_size.x, half_size.y) * 0.38, dark, false, 1.0)
		_:
			draw_line(Vector2(-half_size.x * 0.7, 0), Vector2(half_size.x * 0.7, 0), light, 1.0)


func _effective_wall_segment(wall: Dictionary) -> Array[Vector2]:
	var start := metres_to_world(Vector2(float(wall.get("start_x_metres", 0.0)), float(wall.get("start_y_metres", 0.0))))
	var finish := metres_to_world(Vector2(float(wall.get("end_x_metres", 0.0)), float(wall.get("end_y_metres", 0.0))))
	var wall_id := str(wall.get("id", ""))
	return [_snap_runtime_wall_endpoint(start, wall_id), _snap_runtime_wall_endpoint(finish, wall_id)]


func _snap_runtime_wall_endpoint(point: Vector2, ignored_wall_id: String) -> Vector2:
	var maximum_distance := WALL_JOIN_DISTANCE_METRES * pixels_per_metre
	var nearest := point
	var nearest_distance := maximum_distance + 0.001
	var rings: Array[PackedVector2Array] = [_world_ring(floor_data.get("boundary_metres", []))]
	for hole_value in floor_data.get("holes_metres", []):
		rings.append(_world_ring(hole_value))
	for ring in rings:
		for edge_index in ring.size():
			var projection := _project_world_point(point, ring[edge_index], ring[(edge_index + 1) % ring.size()])
			if float(projection.distance) < nearest_distance:
				nearest_distance = float(projection.distance)
				nearest = Vector2(projection.point)
	for other_value in floor_data.get("walls", []):
		if not other_value is Dictionary or str(other_value.get("id", "")) == ignored_wall_id: continue
		var other_start := metres_to_world(Vector2(float(other_value.get("start_x_metres", 0.0)), float(other_value.get("start_y_metres", 0.0))))
		var other_finish := metres_to_world(Vector2(float(other_value.get("end_x_metres", 0.0)), float(other_value.get("end_y_metres", 0.0))))
		var projection := _project_world_point(point, other_start, other_finish)
		if float(projection.distance) < nearest_distance:
			nearest_distance = float(projection.distance)
			nearest = Vector2(projection.point)
	return nearest


func _project_world_point(point: Vector2, start: Vector2, finish: Vector2) -> Dictionary:
	var delta := finish - start
	var length := delta.length()
	if length <= 0.0001: return {"point": start, "distance": point.distance_to(start)}
	var projected := start + delta / length * clampf((point - start).dot(delta / length), 0.0, length)
	return {"point": projected, "distance": point.distance_to(projected)}


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


func _texture_for_item(item: Dictionary) -> Texture2D:
	var relative_path := str(item.get("image_path", "")).replace("\\", "/")
	if town_directory.is_empty() or relative_path.is_empty() or relative_path.contains("..") or relative_path.is_absolute_path(): return null
	if custom_textures.has(relative_path): return custom_textures[relative_path]
	var image := Image.new()
	if image.load(town_directory.path_join(relative_path)) != OK or image.is_empty():
		custom_textures[relative_path] = null
		return null
	var texture := ImageTexture.create_from_image(image)
	custom_textures[relative_path] = texture
	return texture
