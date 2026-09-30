extends SceneTree

const RuntimeScene = preload("res://scenes/runtime/town_runtime.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime = RuntimeScene.instantiate()
	root.add_child(runtime)
	await process_frame
	assert(runtime.population != null)
	var population = runtime.population
	runtime.set_process(false)
	population.set_process(false)
	var zone_nodes: Dictionary = population.graphs.traffic.junction_zone_by_node
	assert(not zone_nodes.is_empty(), "This check requires a town with mapped signals.")
	var reasons: Dictionary = {}
	var commitments := 0
	var moved: Dictionary = {}
	for frame in 900:
		population._process(1.0/30.0)
		for agent in population.agents:
			if str(agent.kind) != "traffic":
				continue
			if bool(agent.get("moving",false)):
				moved[int(agent.traffic_id)] = true
			var reason := str(agent.get("blocked_reason",""))
			if not reason.is_empty():
				reasons[reason] = int(reasons.get(reason,0)) + 1
			if int(agent.get("signal_zone",-1)) >= 0:
				commitments += 1
				assert(reason != "Traffic signal", "An admitted car stopped for a signal inside its junction.")
	assert(commitments > 0, "The real-town sample did not exercise signal commitments.")
	print("TOWN SIGNAL FLOW PASSED: ", JSON.stringify({"zone_nodes":zone_nodes.size(), "committed_samples":commitments, "cars_with_movement":moved.size(), "wait_samples":reasons, "simulated_seconds":30, "note":"Brief deterministic diagnostic, not a full-town congestion or graphical performance certification."}))
	quit()
