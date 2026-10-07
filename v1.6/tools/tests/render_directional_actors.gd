extends SceneTree

const RuntimeScene = preload("res://scenes/runtime/town_runtime.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime = RuntimeScene.instantiate()
	root.add_child(runtime)
	for _frame in 6:
		await process_frame
	assert(runtime.player != null and runtime.population != null)
	runtime.player.controls_enabled = false
	runtime.player.walking = true
	runtime.player.facing = Vector2.RIGHT
	runtime.player.animation_time = 0.3
	var centre: Vector2 = runtime.player.position
	var people: Array[Dictionary] = []
	var robots: Array[Dictionary] = []
	for agent_value in runtime.population.agents:
		var agent: Dictionary = agent_value
		if str(agent.kind) == "person" and people.size() < 8:
			people.append(agent)
		elif str(agent.kind) == "robot" and robots.size() < 4:
			robots.append(agent)
	var directions := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
	for index in people.size():
		var direction: Vector2 = directions[index % directions.size()]
		people[index].position = centre + Vector2(-80.0 + float(index % 4) * 42.0, -42.0 + float(index / 4) * 52.0)
		people[index].angle = direction.angle()
		people[index].moving = true
		people[index].phase = 0.2 + index * 0.11
	for index in robots.size():
		var direction: Vector2 = directions[index]
		robots[index].position = centre + Vector2(-66.0 + index * 44.0, 72.0)
		robots[index].angle = direction.angle()
		robots[index].moving = true
		robots[index].phase = 0.15 + index * 0.2
	runtime.population.set_draw_view(centre, runtime.character_zoom, false)
	runtime.population.queue_redraw()
	for _frame in 4:
		await process_frame
	var output_directory := ProjectSettings.globalize_path("res://tools/tests/output")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_path := output_directory.path_join("directional_actors_albury.png")
	var image := root.get_viewport().get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(output_path) == OK)
	print("DIRECTIONAL ACTOR CAPTURE SAVED: %s" % output_path)
	quit(0)
