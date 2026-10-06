extends SceneTree

const StoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const CatalogScript = preload("res://scripts/interiors/interior_floor_material_catalog.gd")
const LibraryScript = preload("res://scripts/interiors/interior_floor_material_library.gd")
const CanvasScript = preload("res://scripts/interiors/interior_floor_canvas.gd")
const RuntimeLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")

var emitted_points: Array = []
var emitted_fill := false


func _initialize() -> void:
	assert(CatalogScript.all().size() == 4, "The floor list should contain an eraser and three built-in floorboards.")
	assert(CatalogScript.thumbnail_texture(CatalogScript.definition("floor_light_oak")) != null, "The light-oak illustrated option could not be loaded.")
	var store = StoreScript.new()
	var data := store.empty_data()
	data.buildings["test_building"] = {
		"feature_id": "test_building", "name": "Floor paint test",
		"floors": [{
			"id": "ground_floor", "name": "Ground floor", "level": 0,
			"layout_source": "creator_blank_from_osm_footprint", "survey_status": "not_surveyed",
			"width_metres": 20.0, "height_metres": 12.0, "grid_metres": 1.0, "footprint_scale": 1.0,
			"boundary_metres": [[0.0, 0.0], [20.0, 0.0], [20.0, 12.0], [0.0, 12.0]],
			"holes_metres": [], "rooms": [], "furniture": [], "flooring": {"cell_size_metres": 0.5, "cells": {}},
			"walls": [{
				"id": "wall_1", "start_x_metres": 10.0, "start_y_metres": 0.0,
				"end_x_metres": 10.0, "end_y_metres": 12.0, "thickness_metres": 0.18,
				"doors": [{"id": "door_1", "offset_metres": 6.0, "width_metres": 1.0, "locked": false}]
			}],
			"entry_links": [{
				"id": "entry_front", "exterior_entrance_id": "front", "floor_id": "ground_floor",
				"spawn_x_metres": 2.0, "spawn_y_metres": 2.0, "placement_source": "creator_selected"
			}]
		}]
	}
	var stroke := store.paint_flooring(data, "test_building", "ground_floor", "floor_light_oak", [Vector2(2.0, 2.0), Vector2(3.0, 2.0)], false)
	assert(stroke.ok and int(stroke.painted_cell_count) > 2, str(stroke.get("message", "Drag painting failed.")))
	data = stroke.data
	var left_fill := store.paint_flooring(data, "test_building", "ground_floor", "floor_light_oak", [Vector2(5.0, 6.0)], true)
	assert(left_fill.ok and int(left_fill.painted_cell_count) > 300, str(left_fill.get("message", "Shift room fill failed.")))
	data = left_fill.data
	var cells: Dictionary = data.buildings.test_building.floors[0].flooring.cells
	for key_value in cells:
		var x_index := int(str(key_value).get_slice(":", 0))
		assert((float(x_index) + 0.5) * 0.5 < 10.0, "Room fill leaked through the full internal wall or its doorway.")
	var right_fill := store.paint_flooring(data, "test_building", "ground_floor", "floor_dark_walnut", [Vector2(15.0, 6.0)], true)
	assert(right_fill.ok, str(right_fill.get("message", "Second room fill failed.")))
	data = right_fill.data
	assert("floor_light_oak" in data.buildings.test_building.floors[0].flooring.cells.values() and "floor_dark_walnut" in data.buildings.test_building.floors[0].flooring.cells.values(), "Separate rooms did not retain separate floor materials.")
	var painted_before_resize: int = data.buildings.test_building.floors[0].flooring.cells.size()
	var resized := store.resize_floor(data, "test_building", "ground_floor", 1.5)
	assert(resized.ok and resized.data.buildings.test_building.floors[0].flooring.cells.size() > painted_before_resize and store.validate(resized.data).ok, "Expanding the floor did not preserve a continuous painted area.")
	var erase := store.paint_flooring(data, "test_building", "ground_floor", "default_floor", [Vector2(2.0, 2.0)], false)
	assert(erase.ok and erase.data.buildings.test_building.floors[0].flooring.cells.size() < data.buildings.test_building.floors[0].flooring.cells.size(), "Plain floor / eraser did not remove painted cells.")
	data = erase.data
	assert(store.validate(data).ok, "Painted floor data failed canonical validation.")

	var temporary_town := OS.get_temp_dir().path_join("dwt_creator_v15_custom_floor_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(temporary_town)
	var source_image_path := temporary_town.path_join("blue_floor.png")
	var source_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	source_image.fill(Color("#486c82"))
	assert(source_image.save_png(source_image_path) == OK, "The custom floor fixture image could not be written.")
	var library = LibraryScript.new()
	var imported := library.import_creation(temporary_town, library.empty_data(), source_image_path, "Blue boards")
	assert(imported.ok and str(imported.definition.id).begins_with("custom_floor_"), str(imported.get("message", "Custom floor import failed.")))
	assert(FileAccess.file_exists(temporary_town.path_join(str(imported.definition.image_path))), "Custom floor artwork was not copied into the town.")
	var custom_fill := store.paint_flooring(data, "test_building", "ground_floor", str(imported.definition.id), [Vector2(3.0, 3.0)], false)
	assert(custom_fill.ok and store.validate(custom_fill.data).ok, "A safe creator-imported material ID could not be painted and validated.")

	var canvas = CanvasScript.new()
	canvas.size = Vector2(600, 420)
	get_root().add_child(canvas)
	canvas.set_asset_root(temporary_town)
	canvas.set_floor_materials(library.all_definitions(imported.data))
	canvas.set_floor(custom_fill.data.buildings.test_building.floors[0], "paint-test")
	canvas.floor_paint_requested.connect(_on_floor_paint_requested)
	canvas.begin_floor_painting()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(240.0, 180.0)
	assert(canvas._handle_floor_paint_input(press), "Left press did not start floor painting.")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(300.0, 180.0)
	assert(canvas._handle_floor_paint_input(motion), "Held-mouse movement did not continue floor painting.")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	assert(canvas._handle_floor_paint_input(release) and emitted_points.size() >= 2 and not emitted_fill, "Click-drag did not emit a multi-point paint stroke.")
	emitted_points.clear()
	var shift_click := InputEventMouseButton.new()
	shift_click.button_index = MOUSE_BUTTON_LEFT
	shift_click.pressed = true
	shift_click.shift_pressed = true
	shift_click.position = Vector2(200.0, 180.0)
	assert(canvas._handle_floor_paint_input(shift_click) and emitted_points.size() == 1 and emitted_fill, "Shift-click did not request an enclosed-room fill.")

	var runtime = RuntimeLayerScript.new()
	get_root().add_child(runtime)
	runtime.set_town_directory(temporary_town)
	var runtime_floor: Dictionary = custom_fill.data.buildings.test_building.floors[0]
	assert(runtime.open_floor(custom_fill.data.buildings.test_building, runtime_floor, runtime_floor.entry_links[0], 10.0).ok, "The painted playable interior could not open.")
	assert(runtime.floor_material_textures.has(str(imported.definition.id)), "The playable interior did not load the copied custom floor texture.")
	print("INTERIOR FLOOR PAINTING PASSED: three built-ins, custom upload, drag strokes, Shift room fill, wall/door boundaries, eraser, saved validation and runtime texture loading.")
	quit(0)


func _on_floor_paint_requested(points_metres: Array, fill_room: bool) -> void:
	emitted_points = points_metres.duplicate()
	emitted_fill = fill_room
