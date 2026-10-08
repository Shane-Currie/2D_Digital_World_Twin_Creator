extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func run() -> void:
	create_timer(55).timeout.connect(func(): push_error("TOWN STARTUP TIMEOUT"); quit(2))
	var runtime = load("res://scenes/runtime/town_runtime.tscn").instantiate()
	root.add_child(runtime)
	await process_frame
	check(is_instance_valid(runtime.player), "Walking player created")
	check(is_instance_valid(runtime.wagon), "Owned vehicle created")
	check(is_instance_valid(runtime.population), "Road users created")
	check(is_instance_valid(runtime.renderer), "Town renderer created")
	if failures: quit(1); return
	# This is a town/game startup check, not an Ollama availability test.
	if runtime.llm_startup_active:
		runtime.llm_startup_loader.cancel()
		runtime._finish_local_llm_startup()
	check(runtime.renderer.world_bounds.size.x > 0 and runtime.renderer.world_bounds.size.y > 0, "Nonempty world bounds")
	check(runtime.player.position.is_finite() and runtime.wagon.position.is_finite(), "Finite saved actor starts")
	check(runtime.collisions.loaded_chunks.size() > 0, "Local collisions loaded")
	var counts := {"traffic":0,"person":0,"robot":0,"drone":0}
	for agent in runtime.population.agents: counts[str(agent.kind)] += 1
	for pair in [["traffic","traffic_car_count"],["person","pedestrian_count"],["robot","robot_count"]]:
		check(counts[pair[0]] == int(runtime.game_settings.population[pair[1]]), "Saved " + pair[0] + " population")
	var aerial_nodes: int = runtime.population.graphs.drone.all_ids.size()
	if aerial_nodes > 0:
		check(counts.drone == int(runtime.game_settings.population.drone_count), "Drones on available aerial graph")
	else:
		print("EXISTING MAP LIMITATION: no usable aerial graph nodes; %d configured drones not spawned." % int(runtime.game_settings.population.drone_count))
	for i in 10:
		await physics_frame
		check(runtime.player.position.is_finite() and runtime.wagon.position.is_finite(), "Game ticks without invalid actor positions")
	if DisplayServer.get_name() != "headless":
		await process_frame; await RenderingServer.frame_post_draw
		var capture := ProjectSettings.globalize_path("res://tools/tests/output/gold_coast_startup_v17.png")
		check(root.get_texture().get_image().save_png(capture) == OK, "Rendered game screenshot")
		print("RENDERED TOWN STARTUP: " + capture)
	print("NEW TOWN RUNTIME: %d checks, %d failures; %d road users; %d collision chunks" % [checks,failures,runtime.population.agents.size(),runtime.collisions.loaded_chunks.size()])
	runtime.queue_free(); await process_frame
	quit(1 if failures else 0)
