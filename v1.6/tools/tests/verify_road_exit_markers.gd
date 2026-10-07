extends SceneTree

const Markers = preload("res://scripts/runtime/map_limits/road_exit_markers.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const Wagon = preload("res://scripts/runtime/runtime_player_vehicle.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAILED: ", message)


func _road(points: Array, id: String = "test", extra: Dictionary = {}) -> Dictionary:
	var road := {"points": PackedVector2Array(points), "path_id": id, "walkway": false, "bridge": false, "tunnel": false, "layer": 0}
	road.merge(extra, true)
	return road


func _run() -> void:
	var markers = Markers.new()
	var bounds := Rect2(0, 0, 100, 100)
	markers.setup([
		_road([Vector2(-20, 50), Vector2(120, 50)], "horizontal"),
		_road([Vector2(50, -20), Vector2(50, 120)], "vertical"),
		_road([Vector2(20, 20), Vector2(40, 40)], "inside_dead_end"),
		_road([Vector2(-20, -20), Vector2(-10, -10)], "outside"),
		_road([Vector2(0, -20), Vector2(0, 120)], "along_edge"),
		_road([Vector2(-10, 10), Vector2(10, -10)], "corner_touch"),
		_road([Vector2(25, 20), Vector2(25, 120)], "footpath", {"walkway": true})
	], bounds, 1.0)
	_expect(markers.exits.size() == 4, "Expected four real road exits, no dead ends, tangencies or footpaths.")
	for exit in markers.exits:
		_expect(markers._on_edge(exit.position), "Marker did not use the actual export edge.")
		_expect(bounds.has_point(markers.marker_position(exit)), "The X is outside the map.")
	markers.setup([
		_road([Vector2(20, 30), Vector2(100, 30)], "ends_at_edge"),
		_road([Vector2(100, 30), Vector2(20, 30)], "duplicate"),
		_road([Vector2(20, 60), Vector2(100, 60), Vector2(120, 60)], "node_on_edge"),
		_road([Vector2(20, 70), Vector2(100, 70), Vector2(20, 80)], "turns_back_inside"),
		_road([Vector2(10, 10), Vector2(120, 120)], "corner_exit"),
		_road([Vector2(0, 30), Vector2(20, 30)], "tunnel", {"tunnel": true, "layer": -1}),
		_road([Vector2(20, 99.9), Vector2(50, 99.9)], "rounding_at_edge")
	], bounds, 1.0)
	_expect(markers.exits.size() == 6, "Endpoints, duplicates, boundary nodes, corners, tunnel layers or rounding failed.")
	_expect(not markers.exits.any(func(exit): return exit.road_id == "turns_back_inside"), "An interior turn touching the edge was mistaken for an exit.")
	for zoom in [0.1, 1.0, 2.7]:
		markers.update_presentation(zoom, bounds, true, false)
		_expect(is_equal_approx(markers.camera_zoom, zoom), "Zoom presentation did not update.")
		for exit in markers.exits:
			_expect(bounds.has_point(markers.marker_position(exit)), "Zoom moved an X outside the map.")
	_expect(markers.get_child_count() == 0 and markers is Node2D and not markers is CollisionObject2D, "Map markers added physical obstacles.")
	for map_scale in [1.0, 8.0, 32.0]:
		var origin := Vector2(-30000, 17000)
		markers.setup([
			_road([origin + Vector2(-20, 50) * map_scale, origin + Vector2(120, 50) * map_scale]),
			_road([origin + Vector2(50, -20) * map_scale, origin + Vector2(50, 120) * map_scale]),
			_road([origin + Vector2(20, 20) * map_scale, origin + Vector2(40, 40) * map_scale], "inside_dead_end")
		], Rect2(origin, Vector2.ONE * 100.0 * map_scale), map_scale)
		_expect(markers.exits.size() == 4, "Exit detection depends on town coordinates or runtime scale.")
	markers.free()
	var town_path := _argument("--town")
	if not town_path.is_empty(): await _check_real_town(town_path)
	if failures == 0: print("ROAD EXIT MARKERS PASSED: clipped roads, all four edges, endpoints, internal dead ends, duplicate ways, corner tangency, vertical layers, zoom and collision separation.")
	quit(1 if failures else 0)


func _argument(key: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""


func _check_real_town(town_path: String) -> void:
	var town: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(town_path.path_join("town.json")))
	var features: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(town_path.path_join("data/map_features.json")))
	var collisions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(town_path.path_join("data/building_collisions.json")))
	var renderer = Renderer.new()
	renderer.setup(features.features, collisions, town.map_bounds)
	_expect(not renderer.road_exit_markers.exits.is_empty(), "Real town did not generate any edge exits.")
	for exit in renderer.road_exit_markers.exits:
		_expect(renderer.road_exit_markers._on_edge(exit.position), "Real-town exit is not at the playable boundary.")
	var road_count: int = renderer.road_segments.size()
	var before: bool = renderer.is_ground_traversable(renderer.world_bounds.position - Vector2.ONE)
	renderer.road_exit_markers.update_presentation(1.5, renderer.world_bounds, false, false)
	_expect(not before and not renderer.is_ground_traversable(renderer.world_bounds.position - Vector2.ONE), "Boundary movement protection changed.")
	_expect(renderer.road_segments.size() == road_count, "Markers changed the road graph.")
	print("REAL MAP EXIT CHECK: ", town.display_name, " / ", renderer.road_exit_markers.exits.size(), " exits / ", road_count, " unchanged road segments")
	if not OS.get_cmdline_user_args().has("--render"):
		renderer.free()
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(renderer)
	var exit: Dictionary = renderer.road_exit_markers.exits[0]
	var camera := Camera2D.new()
	camera.position = exit.position - exit.outward * 100.0
	camera.zoom = Vector2.ONE * 1.5
	viewport.add_child(camera)
	var wagon = Wagon.new()
	wagon.controls_enabled = false
	wagon.position = exit.position - exit.outward * 70.0
	wagon.rotation = Vector2(exit.outward).angle() + PI * 0.5
	viewport.add_child(wagon)
	var overlay := CanvasLayer.new()
	viewport.add_child(overlay)
	var caption := Label.new()
	caption.text = "ALBURY · MAP LIMIT / red X is visual only"
	caption.position = Vector2(18, 15)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 5)
	overlay.add_child(caption)
	renderer.update_detail_view(camera.position, camera.zoom.x, Vector2(viewport.size))
	renderer.update_street_label_presentation(camera.zoom.x, 1.0, false)
	await _capture(viewport, "albury_map_edge_gameplay.png")
	wagon.visible = false
	caption.text = "ALBURY · ACTUAL RUNTIME MAP / red X = map limit"
	camera.position = renderer.world_bounds.get_center()
	camera.zoom = Vector2.ONE * minf(850.0 / renderer.world_bounds.size.x, 410.0 / renderer.world_bounds.size.y)
	renderer.set_map_overview(true)
	renderer.update_street_label_presentation(camera.zoom.x, 1.0, true)
	await _capture(viewport, "albury_map_edge_overview.png")
	viewport.queue_free()
	await process_frame


func _capture(viewport: SubViewport, file_name: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(directory)
	_expect(viewport.get_texture().get_image().save_png(directory.path_join(file_name)) == OK, "Could not save actual renderer capture.")
