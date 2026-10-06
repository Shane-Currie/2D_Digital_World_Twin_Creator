class_name BuildingInteriorStore
extends RefCounted

## Canonical, town-specific interior layouts keyed to stable OSM building IDs.
## Stores footprint-shaped floors and exterior-entrance spawn links.

const InteriorFurnitureCatalogScript = preload("res://scripts/interiors/interior_furniture_catalog.gd")

const SCHEMA_VERSION := 1
const FILE_NAME := "building_interiors.json"
const METRES_PER_LATITUDE_DEGREE := 110540.0
const METRES_PER_LONGITUDE_DEGREE := 111320.0
const MAX_INTERIOR_EDGE_METRES := 2000.0
const MAX_FLOORS := 20
const MAX_WALLS_PER_FLOOR := 500
const MAX_ROOMS_PER_FLOOR := 200
const MIN_FLOOR_SCALE := 1.0
const MAX_FLOOR_SCALE := 3.0
const DEFAULT_WALL_THICKNESS_METRES := 0.18
const WALL_SNAP_DISTANCE_METRES := 1.0
const WALL_GRID_METRES := 0.25
const EXTERIOR_WALL_INSET_METRES := 0.04
const FLOOR_PAINT_CELL_METRES := 0.5
const FLOOR_PAINT_BRUSH_RADIUS_METRES := 0.65
const MAX_FLOOR_PAINT_CELLS := 100000


func empty_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "kind": "creator_building_interiors", "buildings": {}}


func load_from_town(town_directory: String) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value):
		return {"ok": true, "data": empty_data(), "created_default": true}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	if not parsed is Dictionary:
		return {"ok": false, "message": "data/%s is damaged or is not valid JSON." % FILE_NAME}
	var validation := validate(parsed)
	if not validation.ok:
		return validation
	return {"ok": true, "data": parsed, "created_default": false}


func save_to_town(town_directory: String, data: Dictionary) -> Dictionary:
	var validation := validate(data)
	if not validation.ok:
		return validation
	var data_directory := town_directory.path_join("data")
	if DirAccess.make_dir_recursive_absolute(data_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	var saved: Dictionary = data.duplicate(true)
	saved["updated_utc"] = Time.get_datetime_string_from_system(true)
	var file := FileAccess.open(data_directory.path_join(FILE_NAME), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save data/%s." % FILE_NAME}
	file.store_string(JSON.stringify(saved, "  "))
	return {"ok": true, "data": saved, "message": "Building interiors saved."}


func create_blank_ground_floor(data: Dictionary, feature: Dictionary) -> Dictionary:
	var feature_id := str(feature.get("id", ""))
	var outer := _points(feature.get("points", []))
	if feature_id.is_empty() or str(feature.get("kind", "")) != "building" or outer.size() < 3:
		return {"ok": false, "message": "Select a valid imported building before creating its interior."}
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if buildings.has(feature_id):
		return {"ok": false, "message": "This building already has an interior. Its saved floor was left unchanged."}
	var origin := _polygon_centre(outer)
	var projected_outer := _project_ring(outer, origin)
	var projected_holes: Array[PackedVector2Array] = []
	for hole_value in feature.get("holes", []):
		var hole := _points(hole_value)
		if hole.size() >= 3:
			projected_holes.append(_project_ring(hole, origin))
	var bounds := _bounds(projected_outer)
	if bounds.size.x <= 0.25 or bounds.size.y <= 0.25 or bounds.size.x > MAX_INTERIOR_EDGE_METRES or bounds.size.y > MAX_INTERIOR_EDGE_METRES:
		return {"ok": false, "message": "This footprint cannot produce a safe editable interior size."}
	var floor := {
		"id": "ground_floor", "name": "Ground floor", "level": 0,
		"layout_source": "creator_blank_from_osm_footprint", "survey_status": "not_surveyed",
		"width_metres": snappedf(bounds.size.x, 0.01), "height_metres": snappedf(bounds.size.y, 0.01),
		"grid_metres": 1.0,
		"footprint_scale": 1.0,
		"boundary_metres": _shifted_values(projected_outer, bounds.position),
		"holes_metres": [], "walls": [], "rooms": [], "furniture": [], "entry_links": [],
		"flooring": {"cell_size_metres": FLOOR_PAINT_CELL_METRES, "cells": {}}
	}
	for hole in projected_holes:
		floor.holes_metres.append(_shifted_values(hole, bounds.position))
	buildings[feature_id] = {
		"feature_id": feature_id,
		"name": str(feature.get("tags", {}).get("name", "Unnamed building")),
		"floors": [floor]
	}
	var updated: Dictionary = data.duplicate(true)
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "record": buildings[feature_id], "message": "Blank ground floor created from the building footprint."}


func synchronize_with_exteriors(data: Dictionary, exterior_data: Dictionary, features: Array) -> Dictionary:
	# Interior identity always remains the stable OSM feature ID. A creator name is
	# display text only and must never replace that ID or an exterior entrance ID.
	var updated := data.duplicate(true)
	var feature_names: Dictionary = {}
	for feature_value in features:
		if not feature_value is Dictionary:
			continue
		var feature: Dictionary = feature_value
		feature_names[str(feature.get("id", ""))] = str(feature.get("tags", {}).get("name", "")).strip_edges()
	var renamed := 0
	var repaired_links := 0
	var unresolved_links := 0
	var buildings: Dictionary = updated.get("buildings", {}).duplicate(true)
	for feature_id_value in buildings.keys():
		var feature_id := str(feature_id_value)
		var record: Dictionary = buildings[feature_id].duplicate(true)
		var exterior: Dictionary = exterior_data.get("buildings", {}).get(feature_id, {})
		var display_name := str(exterior.get("custom_name", "")).strip_edges()
		if display_name.is_empty():
			display_name = str(feature_names.get(feature_id, "")).strip_edges()
		if display_name.is_empty():
			display_name = str(record.get("name", "Unnamed building")).strip_edges()
		if str(record.get("name", "")) != display_name:
			record["name"] = display_name
			renamed += 1
		var doors: Array = exterior.get("doors", [exterior.door] if exterior.has("door") else [])
		var door_ids: Dictionary = {}
		for door_value in doors:
			if door_value is Dictionary:
				door_ids[str(door_value.get("id", ""))] = true
		var floors: Array = record.get("floors", []).duplicate(true)
		for floor_index in floors.size():
			var floor: Dictionary = floors[floor_index].duplicate(true)
			var links: Array = floor.get("entry_links", []).duplicate(true)
			for link_index in links.size():
				var link: Dictionary = links[link_index].duplicate(true)
				var linked_id := str(link.get("exterior_entrance_id", ""))
				if door_ids.has(linked_id):
					continue
				# One exterior door and one saved link is unambiguous legacy data. Repair
				# only that case; never guess between several creator-placed doors.
				if doors.size() == 1 and links.size() == 1:
					var current_id := str(doors[0].get("id", ""))
					if not current_id.is_empty():
						link["exterior_entrance_id"] = current_id
						link["id"] = "entry_%s" % _safe_id(current_id)
						links[link_index] = link
						repaired_links += 1
						continue
				unresolved_links += 1
			floor["entry_links"] = links
			floors[floor_index] = floor
		record["floors"] = floors
		buildings[feature_id] = record
	updated["buildings"] = buildings
	return {"ok": unresolved_links == 0, "data": updated, "renamed": renamed, "repaired_links": repaired_links, "unresolved_links": unresolved_links}


func add_upper_floor(data: Dictionary, feature_id: String) -> Dictionary:
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Create the ground floor before adding an upper floor."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	if floors.is_empty() or floors.size() >= MAX_FLOORS:
		return {"ok": false, "message": "This building cannot contain more than %d editable floors." % MAX_FLOORS}
	var level := floors.size()
	var floor: Dictionary = floors[0].duplicate(true)
	floor["id"] = "floor_%d" % level
	floor["name"] = "Floor %d" % (level + 1)
	floor["level"] = level
	floor["layout_source"] = "creator_copy_of_footprint_shape"
	floor["survey_status"] = "creator_adjusted"
	floor["rooms"] = []
	floor["walls"] = []
	floor["furniture"] = []
	floor["entry_links"] = []
	floor["flooring"] = {"cell_size_metres": FLOOR_PAINT_CELL_METRES, "cells": {}}
	floors.append(floor)
	record["floors"] = floors
	buildings[feature_id] = record
	var updated: Dictionary = data.duplicate(true)
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "floor_id": floor.id, "message": "%s added using the building footprint shape." % floor.name}


func resize_floor(data: Dictionary, feature_id: String, floor_id: String, scale_value: float) -> Dictionary:
	var safe_scale := clampf(scale_value, MIN_FLOOR_SCALE, MAX_FLOOR_SCALE)
	if not is_equal_approx(safe_scale, scale_value):
		return {"ok": false, "message": "Choose an interior size from 100% to 300%."}
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Create the building interior before changing its size."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	var found := false
	for index in floors.size():
		var floor: Dictionary = floors[index].duplicate(true)
		if str(floor.get("id", "")) != floor_id:
			continue
		var old_scale := float(floor.get("footprint_scale", 1.0))
		if old_scale <= 0.0:
			old_scale = 1.0
		var ratio := safe_scale / old_scale
		floor["boundary_metres"] = _scaled_values(floor.get("boundary_metres", []), ratio)
		var holes: Array = []
		for hole in floor.get("holes_metres", []):
			holes.append(_scaled_values(hole, ratio))
		floor["holes_metres"] = holes
		var links: Array = floor.get("entry_links", []).duplicate(true)
		for link_index in links.size():
			var link: Dictionary = links[link_index].duplicate(true)
			link["spawn_x_metres"] = snappedf(float(link.get("spawn_x_metres", 0.0)) * ratio, 0.01)
			link["spawn_y_metres"] = snappedf(float(link.get("spawn_y_metres", 0.0)) * ratio, 0.01)
			links[link_index] = link
		floor["entry_links"] = links
		var walls: Array = floor.get("walls", []).duplicate(true)
		for wall_index in walls.size():
			var wall: Dictionary = walls[wall_index].duplicate(true)
			wall["start_x_metres"] = snappedf(float(wall.get("start_x_metres", 0.0)) * ratio, 0.01)
			wall["start_y_metres"] = snappedf(float(wall.get("start_y_metres", 0.0)) * ratio, 0.01)
			wall["end_x_metres"] = snappedf(float(wall.get("end_x_metres", 0.0)) * ratio, 0.01)
			wall["end_y_metres"] = snappedf(float(wall.get("end_y_metres", 0.0)) * ratio, 0.01)
			var wall_doors: Array = wall.get("doors", []).duplicate(true)
			for door_index in wall_doors.size():
				var wall_door: Dictionary = wall_doors[door_index].duplicate(true)
				wall_door["offset_metres"] = snappedf(float(wall_door.get("offset_metres", 0.0)) * ratio, 0.01)
				wall_doors[door_index] = wall_door
			wall["doors"] = wall_doors
			walls[wall_index] = wall
		floor["walls"] = walls
		var rooms: Array = floor.get("rooms", []).duplicate(true)
		for room_index in rooms.size():
			var room: Dictionary = rooms[room_index].duplicate(true)
			room["label_x_metres"] = snappedf(float(room.get("label_x_metres", 0.0)) * ratio, 0.01)
			room["label_y_metres"] = snappedf(float(room.get("label_y_metres", 0.0)) * ratio, 0.01)
			rooms[room_index] = room
		floor["rooms"] = rooms
		var furniture: Array = floor.get("furniture", []).duplicate(true)
		for furniture_index in furniture.size():
			var item: Dictionary = furniture[furniture_index].duplicate(true)
			item["x_metres"] = snappedf(float(item.get("x_metres", 0.0)) * ratio, 0.01)
			item["y_metres"] = snappedf(float(item.get("y_metres", 0.0)) * ratio, 0.01)
			furniture[furniture_index] = item
		floor["furniture"] = furniture
		var previous_flooring: Dictionary = floor.get("flooring", {})
		var flooring_cell_size := float(previous_flooring.get("cell_size_metres", FLOOR_PAINT_CELL_METRES))
		var resized_cells: Dictionary = {}
		for cell_key in previous_flooring.get("cells", {}):
			var cell := _floor_cell_from_key(str(cell_key))
			if cell == Vector2i(-2147483648, -2147483648): continue
			# Scale the full painted square, not only its centre. Expanding a floor
			# therefore keeps a continuous painted area instead of a dotted grid.
			var scaled_min := Vector2(cell.x, cell.y) * flooring_cell_size * ratio
			var scaled_max := Vector2(cell.x + 1, cell.y + 1) * flooring_cell_size * ratio
			var first_cell := _floor_cell_at(scaled_min + Vector2.ONE * 0.0001, flooring_cell_size)
			var last_cell := _floor_cell_at(scaled_max - Vector2.ONE * 0.0001, flooring_cell_size)
			for paint_y in range(first_cell.y, last_cell.y + 1):
				for paint_x in range(first_cell.x, last_cell.x + 1):
					var resized_cell := Vector2i(paint_x, paint_y)
					if _floor_cell_inside_floor(resized_cell, flooring_cell_size, floor):
						resized_cells[_floor_cell_key(resized_cell)] = str(previous_flooring.get("cells", {}).get(cell_key, ""))
						if resized_cells.size() > MAX_FLOOR_PAINT_CELLS:
							return {"ok": false, "message": "The resized floor would contain too much paint detail. Restore some areas to Plain floor first."}
		floor["flooring"] = {"cell_size_metres": flooring_cell_size, "cells": resized_cells}
		floor["width_metres"] = snappedf(float(floor.get("width_metres", 0.0)) * ratio, 0.01)
		floor["height_metres"] = snappedf(float(floor.get("height_metres", 0.0)) * ratio, 0.01)
		floor["footprint_scale"] = safe_scale
		floor["survey_status"] = "not_surveyed" if is_equal_approx(safe_scale, 1.0) and int(floor.get("level", 0)) == 0 else "creator_adjusted"
		for furniture_value in furniture:
			if not _furniture_fits_floor(furniture_value, floor, str(furniture_value.get("id", ""))):
				return {"ok": false, "message": "The resized floor would place furniture through a wall or another item. Move or remove that furniture first."}
		floors[index] = floor
		found = true
		break
	if not found:
		return {"ok": false, "message": "The selected floor could not be found."}
	record["floors"] = floors
	buildings[feature_id] = record
	var updated: Dictionary = data.duplicate(true)
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "message": "Floor size changed to %d%% while preserving its footprint shape." % int(round(safe_scale * 100.0))}


func set_entry_spawn(data: Dictionary, feature_id: String, exterior_entrance_id: String, position_metres: Vector2) -> Dictionary:
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Create the blank ground floor before placing its entry point."}
	if exterior_entrance_id.is_empty():
		return {"ok": false, "message": "Choose an exterior entrance to connect."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	if floors.is_empty():
		return {"ok": false, "message": "This building does not have an editable ground floor."}
	var floor: Dictionary = floors[0].duplicate(true)
	if not _position_inside_floor(position_metres, floor):
		return {"ok": false, "message": "Place the entry point inside the floor and outside any courtyard opening."}
	for furniture_value in floor.get("furniture", []):
		if bool(furniture_value.get("collision", true)) and _point_inside_furniture(position_metres, furniture_value, 0.8):
			return {"ok": false, "message": "Keep the interior entry point clear of furniture."}
	if _point_blocked_by_wall(position_metres, floor, 0.8):
		return {"ok": false, "message": "Keep the interior entry point clear of internal walls."}
	var links: Array = floor.get("entry_links", []).duplicate(true)
	var link := {
		"id": "entry_%s" % _safe_id(exterior_entrance_id),
		"exterior_entrance_id": exterior_entrance_id,
		"floor_id": "ground_floor",
		"spawn_x_metres": snappedf(position_metres.x, 0.01),
		"spawn_y_metres": snappedf(position_metres.y, 0.01),
		"placement_source": "creator_selected"
	}
	var replaced := false
	for index in links.size():
		if str(links[index].get("exterior_entrance_id", "")) == exterior_entrance_id:
			links[index] = link
			replaced = true
			break
	if not replaced:
		links.append(link)
	floor["entry_links"] = links
	floors[0] = floor
	record["floors"] = floors
	buildings[feature_id] = record
	var updated: Dictionary = data.duplicate(true)
	updated["buildings"] = buildings
	return {"ok": true, "data": updated, "record": record, "message": "Interior entry point linked to %s." % exterior_entrance_id}


func paint_flooring(data: Dictionary, feature_id: String, floor_id: String, material_id: String, positions: Array, fill_room := false) -> Dictionary:
	if not _valid_floor_material_id(material_id):
		return {"ok": false, "message": "Choose a valid floor material before painting."}
	if positions.is_empty():
		return {"ok": false, "message": "Drag over the floor or Shift-click inside a room."}
	var updated := data.duplicate(true)
	var floor_result := _editable_floor(updated, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var floor: Dictionary = floor_result.floor
	var flooring: Dictionary = floor.get("flooring", {"cell_size_metres": FLOOR_PAINT_CELL_METRES, "cells": {}}).duplicate(true)
	var cell_size := float(flooring.get("cell_size_metres", FLOOR_PAINT_CELL_METRES))
	if cell_size < 0.25 or cell_size > 2.0: cell_size = FLOOR_PAINT_CELL_METRES
	var cells: Dictionary = flooring.get("cells", {}).duplicate(true)
	var target_cells: Dictionary = {}
	if fill_room:
		target_cells = _room_floor_cells(Vector2(positions[0]), floor, cell_size)
		if target_cells.is_empty(): return {"ok": false, "message": "Shift-click inside a closed room or usable floor area."}
	else:
		for position_value in positions:
			for cell in _brush_floor_cells(Vector2(position_value), floor, cell_size): target_cells[_floor_cell_key(cell)] = true
	if material_id == "default_floor":
		for key in target_cells: cells.erase(key)
	else:
		var future_size := cells.size()
		for key in target_cells:
			if not cells.has(key): future_size += 1
		if future_size > MAX_FLOOR_PAINT_CELLS:
			return {"ok": false, "message": "This floor has reached the maximum paint detail. Restore some cells to Plain floor first."}
		for key in target_cells: cells[key] = material_id
	flooring["cell_size_metres"] = cell_size
	flooring["cells"] = cells
	floor["flooring"] = flooring
	_set_editable_floor(updated, feature_id, floor_id, floor)
	var action := "restored to the plain floor" if material_id == "default_floor" else "painted"
	return {"ok": true, "data": updated, "floor": floor, "painted_cell_count": target_cells.size(), "message": "%d floor tile(s) %s." % [target_cells.size(), action]}


func place_furniture(data: Dictionary, feature_id: String, floor_id: String, catalog_id: String, position_metres: Vector2, rotation_degrees: float, definition_override: Dictionary = {}) -> Dictionary:
	var definition := definition_override.duplicate(true) if not definition_override.is_empty() else InteriorFurnitureCatalogScript.definition(catalog_id)
	if definition.is_empty():
		return {"ok": false, "message": "Choose a furniture example from the library."}
	if str(definition.get("id", "")) != catalog_id:
		return {"ok": false, "message": "The selected furniture definition does not match its saved catalogue ID."}
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Create the building interior before placing furniture."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	for floor_index in floors.size():
		var floor: Dictionary = floors[floor_index].duplicate(true)
		if str(floor.get("id", "")) != floor_id:
			continue
		var furniture: Array = floor.get("furniture", []).duplicate(true)
		var furniture_id := _next_furniture_id(furniture)
		var size_value: Array = definition.get("size_metres", [1.0, 1.0])
		var item := {
			"id": furniture_id,
			"catalog_id": catalog_id,
			"name": str(definition.get("name", "Furniture")),
			"x_metres": snappedf(position_metres.x, 0.01),
			"y_metres": snappedf(position_metres.y, 0.01),
			"width_metres": float(size_value[0]),
			"depth_metres": float(size_value[1]),
			"rotation_degrees": snappedf(fposmod(rotation_degrees, 360.0), 1.0),
			"collision": bool(definition.get("collision", true)),
			"fill": str(definition.get("fill", "#8a735d")),
			"outline": str(definition.get("outline", "#41362d")),
			"object_type": str(definition.get("object_type", definition.get("name", "object"))).strip_edges().to_lower(),
			"catalog_source": str(definition.get("catalog_source", "built_in"))
		}
		var image_path := str(definition.get("image_path", ""))
		if not image_path.is_empty():
			item["image_path"] = image_path.replace("\\", "/")
		if not _furniture_fits_floor(item, floor):
			return {"ok": false, "message": "Place the furniture fully inside the floor, clear of entrances and other furniture."}
		furniture.append(item)
		floor["furniture"] = furniture
		floors[floor_index] = floor
		record["floors"] = floors
		buildings[feature_id] = record
		var updated: Dictionary = data.duplicate(true)
		updated["buildings"] = buildings
		return {"ok": true, "data": updated, "furniture_id": furniture_id, "message": "%s placed on %s." % [item.name, str(floor.get("name", "the selected floor"))]}
	return {"ok": false, "message": "The selected floor could not be found."}


func move_furniture(data: Dictionary, feature_id: String, floor_id: String, furniture_id: String, position: Vector2, duplicate := false, rotation_degrees: float = NAN) -> Dictionary:
	var updated := data.duplicate(true)
	var result := _editable_floor(updated, feature_id, floor_id)
	if not result.ok: return result
	var floor: Dictionary = result.floor
	var items: Array = floor.get("furniture", [])
	for index in items.size():
		if str(items[index].get("id", "")) != furniture_id: continue
		var item: Dictionary = items[index].duplicate(true)
		item.x_metres = snappedf(position.x, 0.01)
		item.y_metres = snappedf(position.y, 0.01)
		if is_finite(rotation_degrees): item.rotation_degrees = snappedf(fposmod(rotation_degrees, 360.0), 1.0)
		if not _furniture_fits_floor(item, floor, "" if duplicate else furniture_id):
			return {"ok": false, "message": "Choose a clear position inside the floor, away from walls, entrances and other items."}
		if duplicate:
			item.id = _next_furniture_id(items)
			items.append(item)
		else: items[index] = item
		floor.furniture = items
		_set_editable_floor(updated, feature_id, floor_id, floor)
		return {"ok": true, "data": updated, "furniture_id": str(item.id), "message": "Item copied." if duplicate else "Item moved."}
	return {"ok": false, "message": "Select an existing item."}


func move_wall_door(data: Dictionary, feature_id: String, floor_id: String, wall_id: String, door_id: String, position: Vector2) -> Dictionary:
	var floor_result := _editable_floor(data, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var original: Dictionary = {}
	for wall in floor_result.floor.get("walls", []):
		if str(wall.id) != wall_id: continue
		for door in wall.get("doors", []):
			if str(door.id) == door_id: original = door.duplicate(true)
	if original.is_empty(): return {"ok": false, "message": "Select an existing doorway."}
	var removed := remove_wall_door(data, feature_id, floor_id, wall_id, door_id)
	if not removed.ok: return removed
	var placed := add_wall_door(removed.data, feature_id, floor_id, wall_id, position, float(original.width_metres))
	if not placed.ok: return placed
	var floor: Dictionary = _editable_floor(placed.data, feature_id, floor_id).floor
	for wall in floor.walls:
		if str(wall.id) != str(placed.wall_id): continue
		# Door IDs are scoped to their wall. Keep the old ID unless a door on
		# the new wall already uses it; lock state and width always travel.
		var occupied: bool = wall.doors.any(func(door): return str(door.id) == door_id and str(door.id) != str(placed.door_id))
		for door in wall.doors:
			if str(door.id) != str(placed.door_id): continue
			door.locked = bool(original.get("locked", false))
			if not occupied: door.id = door_id
			placed.door_id = str(door.id)
	_set_editable_floor(placed.data, feature_id, floor_id, floor)
	placed.message = "Doorway moved."
	return placed


func rotate_furniture(data: Dictionary, feature_id: String, floor_id: String, furniture_id: String, change_degrees: float) -> Dictionary:
	var updated := data.duplicate(true)
	var result := _editable_floor(updated, feature_id, floor_id)
	if not result.ok: return result
	var floor: Dictionary = result.floor
	for item in floor.get("furniture", []):
		if str(item.get("id", "")) != furniture_id: continue
		item["rotation_degrees"] = snappedf(fposmod(float(item.get("rotation_degrees", 0.0)) + change_degrees, 360.0), 1.0)
		if not _furniture_fits_floor(item, floor, furniture_id):
			return {"ok": false, "message": "That rotation would overlap a wall, doorway or another item."}
		_set_editable_floor(updated, feature_id, floor_id, floor)
		return {"ok": true, "data": updated}
	return {"ok": false, "message": "Select a placed item to rotate."}


func remove_furniture(data: Dictionary, feature_id: String, floor_id: String, furniture_id: String) -> Dictionary:
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	if not buildings.has(feature_id):
		return {"ok": false, "message": "The building interior could not be found."}
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	for floor_index in floors.size():
		var floor: Dictionary = floors[floor_index].duplicate(true)
		if str(floor.get("id", "")) != floor_id:
			continue
		var furniture: Array = floor.get("furniture", []).duplicate(true)
		for item_index in furniture.size():
			if str(furniture[item_index].get("id", "")) != furniture_id:
				continue
			var removed_name := str(furniture[item_index].get("name", "Furniture"))
			furniture.remove_at(item_index)
			floor["furniture"] = furniture
			floors[floor_index] = floor
			record["floors"] = floors
			buildings[feature_id] = record
			var updated: Dictionary = data.duplicate(true)
			updated["buildings"] = buildings
			return {"ok": true, "data": updated, "message": "%s removed." % removed_name}
	return {"ok": false, "message": "The selected furniture could not be found."}


func add_wall(data: Dictionary, feature_id: String, floor_id: String, start: Vector2, finish: Vector2, snap_distance := WALL_SNAP_DISTANCE_METRES, prepared_endpoints := false) -> Dictionary:
	var updated := data.duplicate(true)
	var floor_result := _editable_floor(updated, feature_id, floor_id)
	if not floor_result.ok:
		return floor_result
	var floor: Dictionary = floor_result.floor
	var walls: Array = floor.get("walls", []).duplicate(true)
	if walls.size() >= MAX_WALLS_PER_FLOOR:
		return {"ok": false, "message": "This floor already has the maximum of %d internal walls." % MAX_WALLS_PER_FLOOR}
	var snapped_start := {"position": start, "snapped": false} if prepared_endpoints else snap_wall_endpoint(start, floor, "", snap_distance)
	var snapped_finish := {"position": finish, "snapped": false} if prepared_endpoints else snap_wall_endpoint(finish, floor, "", snap_distance)
	start = Vector2(snapped_start.position)
	finish = Vector2(snapped_finish.position)
	if start.distance_to(finish) < 0.5:
		return {"ok": false, "message": "Draw a wall at least 0.5 metres long after its ends snap into place."}
	if not _position_inside_floor(start, floor) or not _position_inside_floor(finish, floor):
		return {"ok": false, "message": "Both ends of the wall must be inside the floor and outside courtyard openings."}
	var wall_length := start.distance_to(finish)
	var sample_count := maxi(2, ceili(wall_length / 0.25))
	for sample_index in sample_count + 1:
		if not _position_inside_floor(start.lerp(finish, float(sample_index) / float(sample_count)), floor):
			return {"ok": false, "message": "The wall cannot cross outside the floor or through a courtyard opening."}
	var wall := {
		"id": _next_indexed_id(walls, "wall"),
		"start_x_metres": snappedf(start.x, 0.01), "start_y_metres": snappedf(start.y, 0.01),
		"end_x_metres": snappedf(finish.x, 0.01), "end_y_metres": snappedf(finish.y, 0.01),
		"thickness_metres": DEFAULT_WALL_THICKNESS_METRES,
		"doors": []
	}
	if _wall_conflicts_with_floor_contents(wall, floor):
		return {"ok": false, "message": "The wall would cross furniture, an entrance, a storyline location, or another internal wall. Choose a clear line."}
	walls.append(wall)
	floor["walls"] = walls
	_set_editable_floor(updated, feature_id, floor_id, floor)
	var snap_count := int(bool(snapped_start.snapped)) + int(bool(snapped_finish.snapped))
	var snap_message := " Both ends snapped to nearby walls." if snap_count == 2 else " One end snapped to a nearby wall." if snap_count == 1 else ""
	return {"ok": true, "data": updated, "wall_id": wall.id, "message": "Internal wall added.%s Add a doorway before expecting characters to pass through it." % snap_message}


func move_wall(data: Dictionary, feature_id: String, floor_id: String, wall_id: String, start: Vector2, finish: Vector2, snap_distance := WALL_SNAP_DISTANCE_METRES, prepared_endpoints := false) -> Dictionary:
	# Validate the edited wall against the floor with only its old copy removed.
	# Invalid drags return without altering the saved layout or its door IDs.
	var floor_result := _editable_floor(data, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var original_floor: Dictionary = floor_result.floor
	var original_walls: Array = original_floor.get("walls", [])
	var old_wall: Dictionary = {}
	var original_index := -1
	for index in original_walls.size():
		if str(original_walls[index].get("id", "")) == wall_id:
			old_wall = original_walls[index].duplicate(true)
			original_index = index
			break
	if old_wall.is_empty(): return {"ok": false, "message": "The wall to move could not be found."}
	var removed := remove_wall(data, feature_id, floor_id, wall_id)
	var placed := add_wall(removed.data, feature_id, floor_id, start, finish, snap_distance, prepared_endpoints)
	if not placed.ok: return placed
	var new_floor: Dictionary = _editable_floor(placed.data, feature_id, floor_id).floor
	var new_wall: Dictionary = new_floor.walls.back().duplicate(true)
	var old_length: float = _wall_segment(old_wall)[0].distance_to(_wall_segment(old_wall)[1])
	var new_length: float = _wall_segment(new_wall)[0].distance_to(_wall_segment(new_wall)[1])
	new_wall["id"] = wall_id
	new_wall["thickness_metres"] = old_wall.get("thickness_metres", DEFAULT_WALL_THICKNESS_METRES)
	new_wall["doors"] = old_wall.get("doors", []).duplicate(true)
	for door in new_wall.doors:
		door["offset_metres"] = snappedf(float(door.get("offset_metres", 0.0)) * new_length / old_length, 0.01)
		var half_width := float(door.get("width_metres", 0.9)) * 0.5
		if float(door.offset_metres) - half_width < 0.15 or float(door.offset_metres) + half_width > new_length - 0.15:
			return {"ok": false, "message": "This wall would be too short for its doorway. Make it longer or remove that door first."}
		for other_door in new_wall.doors:
			if str(other_door.id) == str(door.id): continue
			if absf(float(other_door.offset_metres) - float(door.offset_metres)) < half_width + float(other_door.width_metres) * 0.5 + 0.15:
				return {"ok": false, "message": "This move would bring two doorways too close together. Make the wall longer or remove a doorway first."}
	var restored_walls := original_walls.duplicate(true)
	restored_walls[original_index] = new_wall
	new_floor["walls"] = restored_walls
	var updated: Dictionary = placed.data
	_set_editable_floor(updated, feature_id, floor_id, new_floor)
	var validation := validate(updated)
	if not validation.ok: return validation
	return {"ok": true, "data": updated, "wall_id": wall_id, "message": "Wall moved. Its doorways and lock settings were kept."}


func remove_wall(data: Dictionary, feature_id: String, floor_id: String, wall_id: String) -> Dictionary:
	var updated := data.duplicate(true)
	var floor_result := _editable_floor(updated, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var floor: Dictionary = floor_result.floor
	var walls: Array = floor.get("walls", []).duplicate(true)
	for index in walls.size():
		if str(walls[index].get("id", "")) != wall_id: continue
		walls.remove_at(index)
		floor["walls"] = walls
		_set_editable_floor(updated, feature_id, floor_id, floor)
		return {"ok": true, "data": updated, "message": "Internal wall removed."}
	return {"ok": false, "message": "The selected internal wall could not be found."}


func add_wall_door(data: Dictionary, feature_id: String, floor_id: String, wall_id: String, near_position: Vector2, width_metres: float) -> Dictionary:
	if width_metres < 0.7 or width_metres > 3.0:
		return {"ok": false, "message": "Choose a doorway width from 0.7 to 3 metres."}
	var updated := data.duplicate(true)
	var floor_result := _editable_floor(updated, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var floor: Dictionary = floor_result.floor
	var walls: Array = floor.get("walls", []).duplicate(true)
	var nearest_index := -1
	var nearest_distance := INF
	for candidate_index in walls.size():
		var candidate: Dictionary = walls[candidate_index]
		var candidate_segment := _wall_segment(candidate)
		var candidate_projection := _projection_on_segment(near_position, candidate_segment[0], candidate_segment[1])
		var candidate_distance := float(candidate_projection.distance)
		# Keep the selected wall only as a tie-breaker. The visible wall that the
		# creator actually clicked is the authoritative target.
		if candidate_distance < nearest_distance - 0.001 or is_equal_approx(candidate_distance, nearest_distance) and str(candidate.get("id", "")) == wall_id:
			nearest_distance = candidate_distance
			nearest_index = candidate_index
	if nearest_index < 0 or nearest_distance > 2.0:
		return {"ok": false, "message": "Click on or close to any visible internal wall."}
	for wall_index in walls.size():
		var wall: Dictionary = walls[wall_index].duplicate(true)
		if wall_index != nearest_index: continue
		var segment := _wall_segment(wall)
		var length: float = segment[0].distance_to(segment[1])
		if length < width_metres + 0.4:
			return {"ok": false, "message": "This wall is too short for that doorway width."}
		var projection := _projection_on_segment(near_position, segment[0], segment[1])
		var offset := clampf(float(projection.offset), width_metres * 0.5 + 0.2, length - width_metres * 0.5 - 0.2)
		var doors: Array = wall.get("doors", []).duplicate(true)
		for existing_value in doors:
			var existing: Dictionary = existing_value
			if absf(float(existing.get("offset_metres", 0.0)) - offset) < (float(existing.get("width_metres", 0.9)) + width_metres) * 0.5 + 0.15:
				return {"ok": false, "message": "That doorway would overlap an existing opening."}
		var door := {"id": _next_indexed_id(doors, "door"), "offset_metres": snappedf(offset, 0.01), "width_metres": snappedf(width_metres, 0.01), "locked": false}
		doors.append(door)
		wall["doors"] = doors
		walls[wall_index] = wall
		floor["walls"] = walls
		_set_editable_floor(updated, feature_id, floor_id, floor)
		return {"ok": true, "data": updated, "wall_id": str(wall.get("id", "")), "door_id": door.id, "message": "Doorway added to the wall you clicked. In Play test, stand at its green marker and press E to enter."}
	return {"ok": false, "message": "The clicked wall could not accept a doorway."}


func set_wall_door_locked(data: Dictionary, feature_id: String, floor_id: String, wall_id: String, door_id: String, locked: bool) -> Dictionary:
	var updated := data.duplicate(true)
	var floor_result := _editable_floor(updated, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var floor: Dictionary = floor_result.floor
	var walls: Array = floor.get("walls", []).duplicate(true)
	for wall_index in walls.size():
		var wall: Dictionary = walls[wall_index].duplicate(true)
		if str(wall.get("id", "")) != wall_id: continue
		var doors: Array = wall.get("doors", []).duplicate(true)
		for door_index in doors.size():
			var door: Dictionary = doors[door_index].duplicate(true)
			if str(door.get("id", "")) != door_id: continue
			door["locked"] = locked
			doors[door_index] = door
			wall["doors"] = doors
			walls[wall_index] = wall
			floor["walls"] = walls
			_set_editable_floor(updated, feature_id, floor_id, floor)
			return {"ok": true, "data": updated, "message": "Door locked. Its indicator will be red in Play test." if locked else "Door unlocked. Its indicator will be green in Play test."}
	return {"ok": false, "message": "The selected doorway could not be found."}


func remove_wall_door(data: Dictionary, feature_id: String, floor_id: String, wall_id: String, door_id: String) -> Dictionary:
	var updated := data.duplicate(true)
	var floor_result := _editable_floor(updated, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var floor: Dictionary = floor_result.floor
	var walls: Array = floor.get("walls", []).duplicate(true)
	for wall_index in walls.size():
		var wall: Dictionary = walls[wall_index].duplicate(true)
		if str(wall.get("id", "")) != wall_id: continue
		var doors: Array = wall.get("doors", []).duplicate(true)
		for door_index in doors.size():
			if str(doors[door_index].get("id", "")) != door_id: continue
			doors.remove_at(door_index)
			wall["doors"] = doors
			walls[wall_index] = wall
			floor["walls"] = walls
			_set_editable_floor(updated, feature_id, floor_id, floor)
			return {"ok": true, "data": updated, "message": "Doorway removed; this part of the wall is solid again."}
	return {"ok": false, "message": "The selected doorway could not be found."}


func add_room_label(data: Dictionary, feature_id: String, floor_id: String, room_name: String, position: Vector2) -> Dictionary:
	var safe_name := room_name.strip_edges()
	if safe_name.is_empty() or safe_name.length() > 60 or safe_name.contains("\n") or safe_name.contains("\r"):
		return {"ok": false, "message": "Enter a one-line room name of 1 to 60 characters."}
	var updated := data.duplicate(true)
	var floor_result := _editable_floor(updated, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var floor: Dictionary = floor_result.floor
	if not _position_inside_floor(position, floor) or _point_blocked_by_wall(position, floor, 0.2):
		return {"ok": false, "message": "Place the room name in clear floor space, away from walls and courtyard openings."}
	for furniture_value in floor.get("furniture", []):
		if furniture_value is Dictionary and _point_inside_furniture(position, furniture_value, 0.1):
			return {"ok": false, "message": "Place the room name in clear floor space rather than on furniture."}
	var rooms: Array = floor.get("rooms", []).duplicate(true)
	if rooms.size() >= MAX_ROOMS_PER_FLOOR:
		return {"ok": false, "message": "This floor already has the maximum of %d named rooms." % MAX_ROOMS_PER_FLOOR}
	var room := {"id": _next_indexed_id(rooms, "room"), "name": safe_name, "label_x_metres": snappedf(position.x, 0.01), "label_y_metres": snappedf(position.y, 0.01)}
	rooms.append(room)
	floor["rooms"] = rooms
	_set_editable_floor(updated, feature_id, floor_id, floor)
	return {"ok": true, "data": updated, "room_id": room.id, "message": "%s room label added." % safe_name}


func remove_room_label(data: Dictionary, feature_id: String, floor_id: String, room_id: String) -> Dictionary:
	var updated := data.duplicate(true)
	var floor_result := _editable_floor(updated, feature_id, floor_id)
	if not floor_result.ok: return floor_result
	var floor: Dictionary = floor_result.floor
	var rooms: Array = floor.get("rooms", []).duplicate(true)
	for index in rooms.size():
		if str(rooms[index].get("id", "")) != room_id: continue
		rooms.remove_at(index)
		floor["rooms"] = rooms
		_set_editable_floor(updated, feature_id, floor_id, floor)
		return {"ok": true, "data": updated, "message": "Room name removed. Its walls were left unchanged."}
	return {"ok": false, "message": "The selected room name could not be found."}


func validate_location(data: Dictionary, location: Dictionary) -> Dictionary:
	if str(location.get("space", "")) != "interior":
		return {"ok": false, "message": "This is not an interior building location."}
	var feature_id := str(location.get("building_id", ""))
	var floor_id := str(location.get("floor_id", ""))
	if feature_id.is_empty() or floor_id.is_empty():
		return {"ok": false, "message": "The interior location needs a stable building and floor ID."}
	var record: Dictionary = data.get("buildings", {}).get(feature_id, {})
	if record.is_empty():
		return {"ok": false, "message": "The selected building no longer has a saved interior."}
	var floor := floor_by_id(record, floor_id)
	if floor.is_empty():
		return {"ok": false, "message": "The selected interior floor no longer exists."}
	var position := Vector2(float(location.get("x_metres", -INF)), float(location.get("y_metres", -INF)))
	if not is_finite(position.x) or not is_finite(position.y) or not _position_inside_floor(position, floor):
		return {"ok": false, "message": "Choose a location inside the floor and outside any courtyard opening."}
	for furniture_value in floor.get("furniture", []):
		if bool(furniture_value.get("collision", true)) and _point_inside_furniture(position, furniture_value, 0.35):
			return {"ok": false, "message": "Choose a clear location that is not inside furniture."}
	if _point_blocked_by_wall(position, floor, 0.35):
		return {"ok": false, "message": "Choose a clear location that is not inside an internal wall."}
	return {"ok": true, "record": record, "floor": floor, "position_metres": position}


static func floor_by_id(record: Dictionary, floor_id: String) -> Dictionary:
	for value in record.get("floors", []):
		if value is Dictionary and str(value.get("id", "")) == floor_id:
			return value
	return {}


func validate(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or str(data.get("kind", "")) != "creator_building_interiors" or not data.get("buildings", {}) is Dictionary:
		return {"ok": false, "message": "The building interior file uses an unsupported or incomplete format."}
	for feature_id in data.buildings:
		var record = data.buildings[feature_id]
		if not record is Dictionary or str(record.get("feature_id", "")) != str(feature_id):
			return {"ok": false, "message": "Interior %s has an invalid stable building ID." % str(feature_id)}
		var floors = record.get("floors", [])
		if not floors is Array or floors.is_empty() or floors.size() > MAX_FLOORS:
			return {"ok": false, "message": "Interior %s must contain between 1 and %d floors." % [str(feature_id), MAX_FLOORS]}
		var floor_ids: Dictionary = {}
		for floor_index in floors.size():
			if not floors[floor_index] is Dictionary:
				return {"ok": false, "message": "Interior %s has invalid floor data." % str(feature_id)}
			var floor: Dictionary = floors[floor_index]
			var floor_id := str(floor.get("id", ""))
			var width := float(floor.get("width_metres", 0.0))
			var height := float(floor.get("height_metres", 0.0))
			var scale_value := float(floor.get("footprint_scale", 1.0))
			if floor_id.is_empty() or floor_ids.has(floor_id) or int(floor.get("level", -1)) != floor_index:
				return {"ok": false, "message": "Interior %s has an invalid or duplicate floor ID." % str(feature_id)}
			if width <= 0.25 or height <= 0.25 or width > MAX_INTERIOR_EDGE_METRES or height > MAX_INTERIOR_EDGE_METRES or scale_value < MIN_FLOOR_SCALE or scale_value > MAX_FLOOR_SCALE or _points(floor.get("boundary_metres", [])).size() < 3:
				return {"ok": false, "message": "Interior %s has invalid floor dimensions or boundary." % str(feature_id)}
			floor_ids[floor_id] = true
			var flooring = floor.get("flooring", {})
			if not flooring is Dictionary:
				return {"ok": false, "message": "Interior %s has invalid painted-floor data." % str(feature_id)}
			if not flooring.is_empty():
				var flooring_cell_size := float(flooring.get("cell_size_metres", 0.0))
				var painted_cells = flooring.get("cells", {})
				if flooring_cell_size < 0.25 or flooring_cell_size > 2.0 or not painted_cells is Dictionary or painted_cells.size() > MAX_FLOOR_PAINT_CELLS:
					return {"ok": false, "message": "Interior %s has invalid painted-floor data." % str(feature_id)}
				for cell_key in painted_cells:
					var cell := _floor_cell_from_key(str(cell_key))
					if cell == Vector2i(-2147483648, -2147483648) or not _valid_floor_material_id(str(painted_cells[cell_key])) or not _floor_cell_inside_floor(cell, flooring_cell_size, floor):
						return {"ok": false, "message": "Interior %s has an invalid or out-of-bounds painted floor tile." % str(feature_id)}
			var wall_ids: Dictionary = {}
			var walls = floor.get("walls", [])
			if not walls is Array or walls.size() > MAX_WALLS_PER_FLOOR:
				return {"ok": false, "message": "Interior %s has invalid internal-wall data." % str(feature_id)}
			for wall_value in walls:
				if not wall_value is Dictionary:
					return {"ok": false, "message": "Interior %s has invalid internal-wall data." % str(feature_id)}
				var wall: Dictionary = wall_value
				var wall_id := str(wall.get("id", ""))
				var segment := _wall_segment(wall)
				var thickness := float(wall.get("thickness_metres", 0.0))
				if wall_id.is_empty() or wall_ids.has(wall_id) or segment[0].distance_to(segment[1]) < 0.5 or thickness < 0.08 or thickness > 0.5 or not _position_inside_floor(segment[0], floor) or not _position_inside_floor(segment[1], floor):
					return {"ok": false, "message": "Interior %s has an invalid or out-of-bounds internal wall." % str(feature_id)}
				var door_ids: Dictionary = {}
				var wall_length: float = segment[0].distance_to(segment[1])
				for door_value in wall.get("doors", []):
					if not door_value is Dictionary:
						return {"ok": false, "message": "Interior %s has invalid doorway data." % str(feature_id)}
					var door: Dictionary = door_value
					var door_id := str(door.get("id", ""))
					var door_width := float(door.get("width_metres", 0.0))
					var door_offset := float(door.get("offset_metres", -1.0))
					var lock_value = door.get("locked", false)
					if door_id.is_empty() or door_ids.has(door_id) or door_width < 0.7 or door_width > 3.0 or door_offset - door_width * 0.5 < 0.15 or door_offset + door_width * 0.5 > wall_length - 0.15 or not lock_value is bool:
						return {"ok": false, "message": "Interior %s has an invalid doorway." % str(feature_id)}
					door_ids[door_id] = true
				wall_ids[wall_id] = true
			var room_ids: Dictionary = {}
			var rooms = floor.get("rooms", [])
			if not rooms is Array or rooms.size() > MAX_ROOMS_PER_FLOOR:
				return {"ok": false, "message": "Interior %s has invalid room-name data." % str(feature_id)}
			for room_value in rooms:
				if not room_value is Dictionary:
					return {"ok": false, "message": "Interior %s has invalid room-name data." % str(feature_id)}
				var room: Dictionary = room_value
				var room_id := str(room.get("id", ""))
				var room_name := str(room.get("name", "")).strip_edges()
				var label_position := Vector2(float(room.get("label_x_metres", -INF)), float(room.get("label_y_metres", -INF)))
				if room_id.is_empty() or room_ids.has(room_id) or room_name.is_empty() or room_name.length() > 60 or not is_finite(label_position.x) or not is_finite(label_position.y) or not _position_inside_floor(label_position, floor):
					return {"ok": false, "message": "Interior %s has an invalid room name or label position." % str(feature_id)}
				room_ids[room_id] = true
			var link_ids: Dictionary = {}
			for link_value in floor.get("entry_links", []):
				if not link_value is Dictionary:
					return {"ok": false, "message": "Interior %s has invalid entry data." % str(feature_id)}
				var link: Dictionary = link_value
				var link_id := str(link.get("id", ""))
				var position := Vector2(float(link.get("spawn_x_metres", -INF)), float(link.get("spawn_y_metres", -INF)))
				if link_id.is_empty() or link_ids.has(link_id) or str(link.get("exterior_entrance_id", "")).is_empty() or not _position_inside_floor(position, floor) or _point_blocked_by_wall(position, floor, 0.1):
					return {"ok": false, "message": "Interior %s has an invalid or duplicate entry link." % str(feature_id)}
				link_ids[link_id] = true
			var furniture_ids: Dictionary = {}
			for furniture_value in floor.get("furniture", []):
				if not furniture_value is Dictionary:
					return {"ok": false, "message": "Interior %s has invalid furniture data." % str(feature_id)}
				var furniture: Dictionary = furniture_value
				var furniture_id := str(furniture.get("id", ""))
				var catalog_id := str(furniture.get("catalog_id", ""))
				var furniture_position := Vector2(float(furniture.get("x_metres", -INF)), float(furniture.get("y_metres", -INF)))
				var furniture_size := Vector2(float(furniture.get("width_metres", 0.0)), float(furniture.get("depth_metres", 0.0)))
				var built_in_definition := InteriorFurnitureCatalogScript.definition(catalog_id)
				var is_custom := str(furniture.get("catalog_source", "")) == "creator_imported" and catalog_id.begins_with("custom_") and _safe_custom_image_path(str(furniture.get("image_path", ""))) and bool(furniture.get("collision", false))
				var object_type := str(furniture.get("object_type", built_in_definition.get("object_type", furniture.get("name", "object")))).strip_edges()
				if furniture_id.is_empty() or furniture_ids.has(furniture_id) or built_in_definition.is_empty() and not is_custom or object_type.is_empty() or not is_finite(furniture_position.x) or not is_finite(furniture_position.y) or furniture_size.x <= 0.1 or furniture_size.y <= 0.1 or furniture_size.x > 20.0 or furniture_size.y > 20.0 or not _furniture_fits_floor(furniture, floor, furniture_id):
					return {"ok": false, "message": "Interior %s has invalid, overlapping or out-of-bounds furniture." % str(feature_id)}
				furniture_ids[furniture_id] = true
	return {"ok": true}


static func object_description(item: Dictionary) -> String:
	var object_type := str(item.get("object_type", item.get("name", "object"))).strip_edges().to_lower()
	if object_type.is_empty(): object_type = "object"
	var article := "an" if object_type.left(1) in ["a", "e", "i", "o", "u"] else "a"
	return "It's %s %s." % [article, object_type]


func _position_inside_floor(position: Vector2, floor: Dictionary) -> bool:
	var outer := _points(floor.get("boundary_metres", []))
	if outer.size() < 3 or not Geometry2D.is_point_in_polygon(position, outer):
		return false
	for hole_value in floor.get("holes_metres", []):
		var hole := _points(hole_value)
		if hole.size() >= 3 and Geometry2D.is_point_in_polygon(position, hole):
			return false
	return true


func _brush_floor_cells(position: Vector2, floor: Dictionary, cell_size: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var radius := FLOOR_PAINT_BRUSH_RADIUS_METRES
	var first := _floor_cell_at(position - Vector2.ONE * radius, cell_size)
	var last := _floor_cell_at(position + Vector2.ONE * radius, cell_size)
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var cell := Vector2i(column, row)
			var centre := Vector2((column + 0.5) * cell_size, (row + 0.5) * cell_size)
			if centre.distance_to(position) <= radius + cell_size * 0.75 and _floor_cell_inside_floor(cell, cell_size, floor): result.append(cell)
	return result


func _room_floor_cells(seed_position: Vector2, floor: Dictionary, cell_size: float) -> Dictionary:
	var seed := _floor_cell_at(seed_position, cell_size)
	var seed_centre := Vector2((seed.x + 0.5) * cell_size, (seed.y + 0.5) * cell_size)
	if not _floor_cell_inside_floor(seed, cell_size, floor): return {}
	var result: Dictionary = {_floor_cell_key(seed): true}
	var queue: Array[Vector2i] = [seed]
	var cursor := 0
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	while cursor < queue.size() and result.size() <= MAX_FLOOR_PAINT_CELLS:
		var current := queue[cursor]
		cursor += 1
		var current_centre := Vector2((current.x + 0.5) * cell_size, (current.y + 0.5) * cell_size)
		for step in steps:
			var next := current + step
			var key := _floor_cell_key(next)
			if result.has(key): continue
			var next_centre := Vector2((next.x + 0.5) * cell_size, (next.y + 0.5) * cell_size)
			if not _floor_cell_inside_floor(next, cell_size, floor) or _floor_paint_crosses_wall(current_centre, next_centre, floor): continue
			result[key] = true
			queue.append(next)
	return result


func _floor_paint_crosses_wall(start: Vector2, finish: Vector2, floor: Dictionary) -> bool:
	for wall_value in floor.get("walls", []):
		if wall_value is Dictionary:
			var segment := _wall_segment(wall_value)
			if Geometry2D.segment_intersects_segment(start, finish, segment[0], segment[1]) != null: return true
	return false


func _floor_cell_inside_floor(cell: Vector2i, cell_size: float, floor: Dictionary) -> bool:
	var inset := minf(0.02, cell_size * 0.1)
	var origin := Vector2(cell.x, cell.y) * cell_size
	for corner in [
		origin + Vector2(inset, inset), origin + Vector2(cell_size - inset, inset),
		origin + Vector2(cell_size - inset, cell_size - inset), origin + Vector2(inset, cell_size - inset)
	]:
		if not _position_inside_floor(corner, floor): return false
	return true


func _floor_cell_at(position: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))


func _floor_cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


func _floor_cell_from_key(key: String) -> Vector2i:
	var parts := key.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return Vector2i(-2147483648, -2147483648)
	return Vector2i(int(parts[0]), int(parts[1]))


func _valid_floor_material_id(material_id: String) -> bool:
	if material_id in ["default_floor", "floor_light_oak", "floor_dark_walnut", "floor_weathered_grey"]: return true
	if not material_id.begins_with("custom_floor_") or material_id.length() > 100: return false
	for character in material_id:
		if not (character >= "a" and character <= "z" or character >= "0" and character <= "9" or character == "_"): return false
	return true


func _furniture_fits_floor(item: Dictionary, floor: Dictionary, ignored_id := "") -> bool:
	var polygon := _furniture_polygon(item)
	for point in polygon:
		if not _position_inside_floor(point, floor):
			return false
		if _point_blocked_by_wall(point, floor, 0.05):
			return false
	for wall_value in floor.get("walls", []):
		if not wall_value is Dictionary: continue
		var segment := _wall_segment(wall_value)
		for edge_index in polygon.size():
			var intersections: Variant = Geometry2D.segment_intersects_segment(polygon[edge_index], polygon[(edge_index + 1) % polygon.size()], segment[0], segment[1])
			if intersections != null:
				return false
	for link_value in floor.get("entry_links", []):
		var entry_position := Vector2(float(link_value.get("spawn_x_metres", 0.0)), float(link_value.get("spawn_y_metres", 0.0)))
		if _point_inside_furniture(entry_position, item, 0.8):
			return false
	if not bool(item.get("collision", true)):
		return true
	for other_value in floor.get("furniture", []):
		if not other_value is Dictionary or str(other_value.get("id", "")) == ignored_id or not bool(other_value.get("collision", true)):
			continue
		if not Geometry2D.intersect_polygons(polygon, _furniture_polygon(other_value)).is_empty():
			return false
	return true


func _editable_floor(data: Dictionary, feature_id: String, floor_id: String) -> Dictionary:
	var buildings: Dictionary = data.get("buildings", {})
	if not buildings.has(feature_id):
		return {"ok": false, "message": "Create the building interior first."}
	var record: Dictionary = buildings[feature_id]
	for floor_value in record.get("floors", []):
		if floor_value is Dictionary and str(floor_value.get("id", "")) == floor_id:
			return {"ok": true, "floor": floor_value.duplicate(true)}
	return {"ok": false, "message": "The selected interior floor could not be found."}


func _set_editable_floor(data: Dictionary, feature_id: String, floor_id: String, floor: Dictionary) -> void:
	var buildings: Dictionary = data.get("buildings", {}).duplicate(true)
	var record: Dictionary = buildings[feature_id].duplicate(true)
	var floors: Array = record.get("floors", []).duplicate(true)
	for index in floors.size():
		if str(floors[index].get("id", "")) == floor_id:
			floors[index] = floor
			break
	record["floors"] = floors
	buildings[feature_id] = record
	data["buildings"] = buildings


func _wall_conflicts_with_floor_contents(wall: Dictionary, floor: Dictionary) -> bool:
	var segment := _wall_segment(wall)
	var thickness := float(wall.get("thickness_metres", DEFAULT_WALL_THICKNESS_METRES))
	for existing_value in floor.get("walls", []):
		if not existing_value is Dictionary: continue
		var existing := _wall_segment(existing_value)
		var intersection = Geometry2D.segment_intersects_segment(segment[0], segment[1], existing[0], existing[1])
		if intersection != null:
			var at_joint := false
			for endpoint in [segment[0], segment[1], existing[0], existing[1]]:
				if Vector2(intersection).distance_to(endpoint) <= 0.025: at_joint = true
			if not at_joint: return true
		# Parallel segments may share a joint but must not lie on top of each other.
		var direction := (segment[1] - segment[0]).normalized()
		if absf(direction.cross((existing[1] - existing[0]).normalized())) < 0.001 and float(_projection_on_segment(existing[0], segment[0], segment[1]).distance) < thickness:
			var first_offset := (existing[0] - segment[0]).dot(direction)
			var last_offset := (existing[1] - segment[0]).dot(direction)
			if minf(maxf(first_offset, last_offset), segment[0].distance_to(segment[1])) - maxf(minf(first_offset, last_offset), 0.0) > 0.025: return true
	for furniture_value in floor.get("furniture", []):
		if not furniture_value is Dictionary: continue
		var polygon := _furniture_polygon(furniture_value)
		for point in polygon:
			if float(_projection_on_segment(point, segment[0], segment[1]).distance) <= thickness * 0.5 + 0.05:
				return true
		for edge_index in polygon.size():
			if Geometry2D.segment_intersects_segment(segment[0], segment[1], polygon[edge_index], polygon[(edge_index + 1) % polygon.size()]) != null:
				return true
	for link_value in floor.get("entry_links", []):
		var position := Vector2(float(link_value.get("spawn_x_metres", 0.0)), float(link_value.get("spawn_y_metres", 0.0)))
		if float(_projection_on_segment(position, segment[0], segment[1]).distance) < 0.9:
			return true
	return false


func _point_blocked_by_wall(point: Vector2, floor: Dictionary, clearance: float) -> bool:
	for wall_value in floor.get("walls", []):
		if not wall_value is Dictionary: continue
		var wall: Dictionary = wall_value
		var segment := _wall_segment(wall)
		var projection := _projection_on_segment(point, segment[0], segment[1])
		if float(projection.distance) > float(wall.get("thickness_metres", DEFAULT_WALL_THICKNESS_METRES)) * 0.5 + clearance:
			continue
		var through_door := false
		for door_value in wall.get("doors", []):
			var door: Dictionary = door_value
			var usable_half_width := float(door.get("width_metres", 0.9)) * 0.5 - clearance
			if usable_half_width > 0.0 and absf(float(projection.offset) - float(door.get("offset_metres", 0.0))) <= usable_half_width:
				through_door = true
				break
		if not through_door:
			return true
	return false


func _wall_segment(wall: Dictionary) -> Array[Vector2]:
	return [
		Vector2(float(wall.get("start_x_metres", 0.0)), float(wall.get("start_y_metres", 0.0))),
		Vector2(float(wall.get("end_x_metres", 0.0)), float(wall.get("end_y_metres", 0.0)))
	]


func _projection_on_segment(point: Vector2, start: Vector2, finish: Vector2) -> Dictionary:
	var delta := finish - start
	var length := delta.length()
	if length <= 0.0001:
		return {"point": start, "offset": 0.0, "distance": point.distance_to(start)}
	var direction := delta / length
	var offset := clampf((point - start).dot(direction), 0.0, length)
	var projected := start + direction * offset
	return {"point": projected, "offset": offset, "distance": point.distance_to(projected)}


func snap_wall_endpoint(point: Vector2, floor: Dictionary, ignored_wall_id := "", snap_distance := WALL_SNAP_DISTANCE_METRES) -> Dictionary:
	var best_point := point
	var best_distance := maxf(0.0, snap_distance) + 0.001
	var best_kind := ""
	# Existing internal wall endpoints and segments are valid joints. Snapping
	# to the whole segment also makes T-junctions close without pixel hunting.
	for wall_value in floor.get("walls", []):
		if not wall_value is Dictionary or str(wall_value.get("id", "")) == ignored_wall_id: continue
		var segment := _wall_segment(wall_value)
		var projection := _projection_on_segment(point, segment[0], segment[1])
		if float(projection.distance) < best_distance:
			best_distance = float(projection.distance)
			best_point = Vector2(projection.point)
			best_kind = "internal"
	# The footprint and courtyard edges are exterior walls. Keep the stored
	# point a few centimetres inside the usable polygon so validation remains
	# unambiguous while the runtime extends visibility to the actual boundary.
	var rings: Array = [floor.get("boundary_metres", [])]
	rings.append_array(floor.get("holes_metres", []))
	for ring_value in rings:
		var ring := _points(ring_value)
		for edge_index in ring.size():
			var projection := _projection_on_segment(point, ring[edge_index], ring[(edge_index + 1) % ring.size()])
			if float(projection.distance) >= best_distance: continue
			var inset_point := _boundary_inset_point(Vector2(projection.point), point, floor)
			if inset_point == Vector2.INF: continue
			best_distance = float(projection.distance)
			best_point = inset_point
			best_kind = "exterior"
	if not best_kind.is_empty():
		return {"position": best_point, "snapped": true, "kind": best_kind}
	var grid_point := Vector2(snappedf(point.x, WALL_GRID_METRES), snappedf(point.y, WALL_GRID_METRES))
	if _position_inside_floor(grid_point, floor):
		return {"position": grid_point, "snapped": false, "kind": "grid"}
	return {"position": point, "snapped": false, "kind": "free"}


func _boundary_inset_point(boundary_point: Vector2, original_point: Vector2, floor: Dictionary) -> Vector2:
	var directions: Array[Vector2] = []
	if _position_inside_floor(original_point, floor) and not original_point.is_equal_approx(boundary_point):
		directions.append((original_point - boundary_point).normalized())
	var floor_centre := Vector2(float(floor.get("width_metres", 1.0)), float(floor.get("height_metres", 1.0))) * 0.5
	if not floor_centre.is_equal_approx(boundary_point):
		directions.append((floor_centre - boundary_point).normalized())
	# Concave footprints and courtyard walls need an inward direction that
	# does not necessarily point toward the overall floor centre.
	for step in 16:
		directions.append(Vector2.RIGHT.rotated(TAU * float(step) / 16.0))
	for direction in directions:
		for multiplier in [1.0, 2.0, 4.0]:
			var candidate: Vector2 = boundary_point + direction * EXTERIOR_WALL_INSET_METRES * float(multiplier)
			if _position_inside_floor(candidate, floor): return candidate
	return Vector2.INF


func _next_indexed_id(values: Array, prefix: String) -> String:
	var used := {}
	for value in values:
		if value is Dictionary: used[str(value.get("id", ""))] = true
	var number := 1
	while used.has("%s_%d" % [prefix, number]): number += 1
	return "%s_%d" % [prefix, number]


func _furniture_polygon(item: Dictionary) -> PackedVector2Array:
	var centre := Vector2(float(item.get("x_metres", 0.0)), float(item.get("y_metres", 0.0)))
	var half_size := Vector2(float(item.get("width_metres", 0.5)), float(item.get("depth_metres", 0.5))) * 0.5
	var rotation := deg_to_rad(float(item.get("rotation_degrees", 0.0)))
	var result := PackedVector2Array()
	for corner in [Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)]:
		result.append(centre + corner.rotated(rotation))
	return result


func _point_inside_furniture(point: Vector2, item: Dictionary, clearance: float) -> bool:
	var centre := Vector2(float(item.get("x_metres", 0.0)), float(item.get("y_metres", 0.0)))
	var local := (point - centre).rotated(-deg_to_rad(float(item.get("rotation_degrees", 0.0))))
	var half_size := Vector2(float(item.get("width_metres", 0.5)), float(item.get("depth_metres", 0.5))) * 0.5 + Vector2.ONE * clearance
	return absf(local.x) <= half_size.x and absf(local.y) <= half_size.y


func _next_furniture_id(furniture: Array) -> String:
	var used := {}
	for value in furniture:
		used[str(value.get("id", ""))] = true
	var number := 1
	while used.has("furniture_%d" % number):
		number += 1
	return "furniture_%d" % number


func _points(values: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		if value is Vector2:
			result.append(value)
		elif value is Array and value.size() >= 2:
			result.append(Vector2(float(value[0]), float(value[1])))
	if result.size() > 2 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


func _polygon_centre(points: PackedVector2Array) -> Vector2:
	return _bounds(points).get_center()


func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _project_ring(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var longitude_scale := METRES_PER_LONGITUDE_DEGREE * cos(deg_to_rad(origin.y))
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2((point.x - origin.x) * longitude_scale, (origin.y - point.y) * METRES_PER_LATITUDE_DEGREE))
	return result


func _shifted_values(points: PackedVector2Array, offset: Vector2) -> Array:
	var result: Array = []
	for point in points:
		result.append([snappedf(point.x - offset.x, 0.01), snappedf(point.y - offset.y, 0.01)])
	return result


func _scaled_values(values: Variant, ratio: float) -> Array:
	var result: Array = []
	for point in _points(values):
		result.append([snappedf(point.x * ratio, 0.01), snappedf(point.y * ratio, 0.01)])
	return result


func _safe_id(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_") if not result.is_empty() else "entrance"


static func _safe_custom_image_path(value: String) -> bool:
	var normal := value.replace("\\", "/")
	return normal.begins_with("assets/interiors/furniture/") and not normal.contains("..") and not normal.is_absolute_path()
