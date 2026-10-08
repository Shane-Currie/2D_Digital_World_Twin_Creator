extends SceneTree

const StoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const RuntimeLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#0d1412")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)
	var world := Node2D.new()
	world.position = Vector2(46, 92)
	world.scale = Vector2.ONE * 2.5
	viewport.add_child(world)
	var store = StoreScript.new()
	var data := store.empty_data()
	data.buildings["preview"] = {
		"feature_id": "preview", "name": "v1.5 furniture example interior",
		"floors": [{
			"id": "ground_floor", "name": "Ground floor", "level": 0,
			"layout_source": "creator_blank_from_osm_footprint", "survey_status": "not_surveyed",
			"width_metres": 25.0, "height_metres": 20.0, "grid_metres": 1.0, "footprint_scale": 1.0,
			"boundary_metres": [[0.0, 0.0], [25.0, 0.0], [25.0, 20.0], [0.0, 20.0]],
			"holes_metres": [], "rooms": [], "furniture": [],
			"entry_links": [{"id": "entry_front", "exterior_entrance_id": "front", "floor_id": "ground_floor", "spawn_x_metres": 2.0, "spawn_y_metres": 2.0, "placement_source": "creator_selected"}]
		}]
	}
	var placements := [
		["single_bed", Vector2(4, 6), 0], ["wardrobe", Vector2(7, 3), 0],
		["sofa", Vector2(10, 7), 0], ["dining_table", Vector2(15, 7), 0],
		["dining_chair", Vector2(13.6, 7), 0], ["dining_chair", Vector2(16.4, 7), 0],
		["kitchen_counter", Vector2(21, 4), 90], ["bathroom_sink", Vector2(21, 8), 0],
		["toilet", Vector2(23, 8), 0], ["office_desk", Vector2(5, 15), 0],
		["shop_shelf", Vector2(11, 15), 0], ["bar_counter", Vector2(18, 15), 0],
		["bar_stool", Vector2(18, 13.8), 0]
	]
	for placement in placements:
		var result: Dictionary = store.place_furniture(data, "preview", "ground_floor", placement[0], placement[1], placement[2])
		assert(result.ok, "%s: %s" % [placement[0], result.get("message", "")])
		data = result.data
	var floor: Dictionary = data.buildings.preview.floors[0]
	var layer = RuntimeLayerScript.new()
	world.add_child(layer)
	var opened: Dictionary = layer.open_floor(data.buildings.preview, floor, floor.entry_links[0], 8.0)
	assert(opened.ok)
	var player = PlayerScript.new()
	player.controls_enabled = false
	player.position = Vector2(12.5, 11.0) * 8.0
	player.z_index = 5
	player.set_interior_mode(true)
	world.add_child(player)
	var heading := Label.new()
	heading.position = Vector2(46, 24)
	heading.text = "2D DIGITAL WORLD TWIN CREATOR v1.5 · FIRST FURNITURE LIBRARY"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("#edf6f1"))
	heading.z_index = 20
	viewport.add_child(heading)
	var note := Label.new()
	note.position = Vector2(584, 92)
	note.size = Vector2(340, 500)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "REAL-METRE GAMEPLAY PREVIEW\n\nFurniture shown:\n• single bed and wardrobe\n• sofa\n• dining table and chairs\n• kitchen counter\n• bathroom sink and toilet\n• office desk\n• shop shelf\n• bar counter and stool\n\nThe player uses the production sprite. Every item blocks walking at its saved rotated footprint."
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", Color("#d6e6de"))
	note.z_index = 20
	viewport.add_child(note)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var output_directory := ProjectSettings.globalize_path("res://tools/tests/output")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_path := output_directory.path_join("interior_furniture_v15.png")
	assert(viewport.get_texture().get_image().save_png(output_path) == OK)
	print("INTERIOR FURNITURE CAPTURE SAVED: %s" % output_path)
	quit(0)
