extends SceneTree
const RuntimeScene = preload("res://scenes/runtime/town_runtime.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime = RuntimeScene.instantiate()
	root.add_child(runtime)
	var graph: Dictionary = runtime.population.graphs.traffic
	var grouped: Dictionary = {}
	for post in graph.signal_posts:
		grouped.get_or_add(int(post.zone),[]).append(post)
	var selected: Array = []
	var most_tags := -1
	for zone in grouped:
		if grouped[zone].size() != 4:
			continue
		var count := 0
		for node in graph.control_by_node:
			if str(graph.control_by_node[node]) == "traffic_signals" and int(graph.junction_zone_by_node.get(node,-1)) == int(zone):
				count += 1
		if count > most_tags:
			selected = grouped[zone]
			most_tags = count
	assert(selected.size() == 4, "No four-approach town junction available for visual review.")
	var bounds := Rect2(Vector2(selected[0].stop_position),Vector2.ZERO)
	for post in selected:
		bounds = bounds.expand(post.stop_position)
	bounds = bounds.grow(95)
	runtime.capture_camera_locked = true
	runtime.camera.position_smoothing_enabled = false
	runtime.camera.position = bounds.get_center()
	var zoom_value := minf(600.0/bounds.size.x,260.0/bounds.size.y)
	runtime.camera.zoom = Vector2.ONE*zoom_value
	runtime.renderer.update_detail_view(bounds.get_center(),zoom_value,Vector2i(640,360))
	runtime.population.elapsed = 5.0
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/tests/output"))
	assert(root.get_texture().get_image().save_png("res://tools/tests/output/albury_approach_signals.png") == OK)
	print("SIGNAL VISUAL CAPTURE: ",most_tags," raw OSM signal nodes -> 4 displayed approach lights; total town posts=",graph.signal_posts.size())
	quit()
