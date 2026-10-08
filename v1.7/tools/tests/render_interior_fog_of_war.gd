extends SceneTree

const InteriorLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")

var viewport: SubViewport
var interior
var population
var player
var state_label: Label


func _initialize() -> void:
	call_deferred("_render")


func _render() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var world := Node2D.new()
	world.position = Vector2(220, 135)
	viewport.add_child(world)

	var floor := {
		"id": "ground_floor", "name": "Ground floor", "level": 0,
		"width_metres": 26.0, "height_metres": 14.0,
		"boundary_metres": [[0, 0], [26, 0], [26, 14], [0, 14]],
		"holes_metres": [],
		"walls": [{
			"id": "wall_1", "start_x_metres": 13.0, "start_y_metres": 0.1,
			"end_x_metres": 13.0, "end_y_metres": 13.9, "thickness_metres": 0.18,
			"doors": [{"id": "door_1", "offset_metres": 7.0, "width_metres": 1.2, "locked": false}]
		}],
		"rooms": [
			{"id": "lounge", "name": "Lounge", "label_x_metres": 6.0, "label_y_metres": 7.0},
			{"id": "bedroom", "name": "Bedroom", "label_x_metres": 20.0, "label_y_metres": 7.0}
		],
		"furniture": [
			{"id": "left_sofa", "catalog_id": "sofa", "object_type": "sofa", "x_metres": 5.0, "y_metres": 4.0, "width_metres": 2.2, "depth_metres": 0.9, "rotation_degrees": 0.0, "fill": "#9b735c", "outline": "#45352d", "collision": true},
			{"id": "left_table", "catalog_id": "dining_table", "object_type": "table", "x_metres": 8.0, "y_metres": 9.5, "width_metres": 1.8, "depth_metres": 1.0, "rotation_degrees": 0.0, "fill": "#89613f", "outline": "#3c2b20", "collision": true},
			{"id": "hidden_bed", "catalog_id": "single_bed", "object_type": "bed", "x_metres": 19.0, "y_metres": 4.0, "width_metres": 1.0, "depth_metres": 2.0, "rotation_degrees": 90.0, "fill": "#8f87ac", "outline": "#4d4863", "collision": true},
			{"id": "hidden_desk", "catalog_id": "office_desk", "object_type": "desk", "x_metres": 21.0, "y_metres": 10.0, "width_metres": 1.4, "depth_metres": 0.7, "rotation_degrees": 0.0, "fill": "#7b624e", "outline": "#3f3127", "collision": true}
		]
	}
	interior = InteriorLayerScript.new()
	world.add_child(interior)
	var opened: Dictionary = interior.open_floor(
		{"name": "Fog-of-war demonstration home"}, floor,
		{"exterior_entrance_id": "front", "spawn_x_metres": 3.0, "spawn_y_metres": 7.0}, 20.0
	)
	assert(opened.ok)

	population = PopulationScript.new()
	population.z_index = 3
	population.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(population)
	population.agents.assign([
		{"kind": "person", "space": "interior", "building_id": "demo", "floor_id": "ground_floor", "position": Vector2(180, 90), "phase": 0.0, "angle": PI, "moving": false, "npc_asset": "npc_medium_woman_adult"},
		{"kind": "person", "space": "interior", "building_id": "demo", "floor_id": "ground_floor", "position": Vector2(390, 150), "phase": 0.0, "angle": PI, "moving": false, "npc_asset": "npc_dark_man_older"}
	])
	population.set_active_interior("demo", "ground_floor")
	population.set_interior_visibility_check(interior.is_position_discovered)
	interior.room_discovery_changed.connect(population.queue_redraw)

	player = PlayerScript.new()
	player.z_index = 5
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector2(opened.position)
	player.set_interior_mode(true)
	world.add_child(player)

	_add_interface()
	for _frame in 6:
		await process_frame
	_save_capture("interior_fog_before_entry.png")

	player.position = Vector2(360, 140)
	interior.update_player_position(player.position)
	state_label.text = "AFTER ENTRY  ·  BEDROOM DISCOVERED"
	for _frame in 6:
		await process_frame
	_save_capture("interior_fog_after_entry.png")
	print("INTERIOR FOG CAPTURES WRITTEN")
	quit(0)


func _add_interface() -> void:
	var interface := CanvasLayer.new()
	viewport.add_child(interface)
	var top_bar := ColorRect.new()
	top_bar.color = Color("#213d32")
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(960, 86)
	interface.add_child(top_bar)
	var title := Label.new()
	title.text = "FOG-OF-WAR DEMONSTRATION HOME  ·  GROUND FLOOR"
	title.position = Vector2(28, 16)
	title.add_theme_font_size_override("font_size", 21)
	top_bar.add_child(title)
	state_label = Label.new()
	state_label.text = "BEFORE ENTRY  ·  BEDROOM UNDISCOVERED"
	state_label.position = Vector2(28, 50)
	state_label.add_theme_color_override("font_color", Color("#7fe0b8"))
	state_label.add_theme_font_size_override("font_size", 16)
	top_bar.add_child(state_label)
	var hint := Label.new()
	hint.text = "E enters through the green doorway  ·  concealed furniture and NPCs are not drawn or clickable"
	hint.position = Vector2(178, 492)
	hint.add_theme_color_override("font_color", Color("#dce9df"))
	hint.add_theme_font_size_override("font_size", 15)
	interface.add_child(hint)


func _save_capture(file_name: String) -> void:
	var directory := ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(directory)
	var error := viewport.get_texture().get_image().save_png(directory.path_join(file_name))
	assert(error == OK, "Could not save %s" % file_name)
