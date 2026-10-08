extends SceneTree

const StoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const RuntimeLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#0d1412")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)
	var world := Node2D.new()
	world.position = Vector2(45, 105)
	world.scale = Vector2.ONE * 2.7
	viewport.add_child(world)
	var store = StoreScript.new()
	var data := store.empty_data()
	data.buildings["preview"] = {
		"feature_id": "preview", "name": "Painted floor preview",
		"floors": [{
			"id": "ground_floor", "name": "Ground floor", "level": 0,
			"layout_source": "creator_blank_from_osm_footprint", "survey_status": "not_surveyed",
			"width_metres": 32.0, "height_metres": 23.0, "grid_metres": 1.0, "footprint_scale": 1.0,
			"boundary_metres": [[0.0, 0.0], [32.0, 0.0], [32.0, 23.0], [0.0, 23.0]],
			"holes_metres": [], "walls": [], "rooms": [], "furniture": [],
			"flooring": {"cell_size_metres": 0.5, "cells": {}},
			"entry_links": [{"id": "entry", "exterior_entrance_id": "front", "floor_id": "ground_floor", "spawn_x_metres": 2.0, "spawn_y_metres": 2.0, "placement_source": "creator_selected"}]
		}]
	}
	var base_fill := store.paint_flooring(data, "preview", "ground_floor", "floor_light_oak", [Vector2(8.0, 10.0)], true)
	assert(base_fill.ok)
	data = base_fill.data
	var walnut_points: Array = []
	for y in range(2, 21):
		for x in range(20, 31): walnut_points.append(Vector2(float(x), float(y)))
	var walnut := store.paint_flooring(data, "preview", "ground_floor", "floor_dark_walnut", walnut_points, false)
	assert(walnut.ok)
	data = walnut.data
	var grey_points: Array = []
	for y in range(15, 22):
		for x in range(2, 18): grey_points.append(Vector2(float(x), float(y)))
	var grey := store.paint_flooring(data, "preview", "ground_floor", "floor_weathered_grey", grey_points, false)
	assert(grey.ok)
	data = grey.data
	for placement in [["single_bed", Vector2(5, 5), 0], ["wardrobe", Vector2(9, 3), 0], ["sofa", Vector2(13, 9), 0], ["dining_table", Vector2(25, 8), 0], ["office_desk", Vector2(8, 18), 0], ["bar_counter", Vector2(25, 17), 0]]:
		var placed := store.place_furniture(data, "preview", "ground_floor", placement[0], placement[1], placement[2])
		assert(placed.ok, str(placed.get("message", "Furniture placement failed.")))
		data = placed.data
	var floor: Dictionary = data.buildings.preview.floors[0]
	var layer = RuntimeLayerScript.new()
	world.add_child(layer)
	layer.set_town_directory(ProjectSettings.globalize_path("res://"))
	assert(layer.open_floor(data.buildings.preview, floor, floor.entry_links[0], 8.0).ok)
	var player = PlayerScript.new()
	player.controls_enabled = false
	player.position = Vector2(16.0, 12.0) * 8.0
	player.z_index = 5
	player.set_interior_mode(true)
	world.add_child(player)
	var heading := Label.new()
	heading.position = Vector2(45, 25)
	heading.text = "2D DIGITAL WORLD TWIN CREATOR v1.5 · FLOOR PAINTING"
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color("#edf6f1"))
	viewport.add_child(heading)
	var instructions := Label.new()
	instructions.position = Vector2(790, 108)
	instructions.size = Vector2(370, 500)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.text = "ACTUAL GAME RUNTIME PREVIEW\n\nBuilt-in surfaces:\n• light oak floorboards\n• dark walnut floorboards\n• weathered grey floorboards\n\nCreator controls:\n• hold left mouse and drag to paint\n• Shift-click fills an enclosed room\n• Plain floor / eraser restores the base\n• upload a PNG, JPEG or WebP texture\n\nFloor paint is visual only. Furniture and walls keep their normal collision."
	instructions.add_theme_font_size_override("font_size", 18)
	instructions.add_theme_color_override("font_color", Color("#d6e6de"))
	viewport.add_child(instructions)
	for _frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	var output_directory := ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_path := output_directory.path_join("interior_floor_painting_v15.png")
	assert(viewport.get_texture().get_image().save_png(output_path) == OK)
	print("INTERIOR FLOOR PAINT CAPTURE SAVED: %s" % output_path)
	quit(0)
