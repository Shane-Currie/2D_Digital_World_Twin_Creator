extends SceneTree
const RuntimeScene = preload("res://scenes/runtime/town_runtime.tscn")
const Flow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime = RuntimeScene.instantiate()
	root.add_child(runtime)
	assert(runtime.population != null)
	var count := 0
	var minimum := INF
	for car in runtime.population.agents:
		if str(car.kind) != "traffic":
			continue
		count += 1
		var centre := Flow.visible_vehicle_position(car,car.position)
		minimum = minf(minimum,centre.distance_to(runtime.wagon.position))
		assert(centre.distance_to(runtime.wagon.position) >= 160.0, "A real-town traffic spawn boxed in the wagon.")
		for other in runtime.population.agents:
			if car != other and str(other.kind) == "traffic":
				assert(centre.distance_to(Flow.visible_vehicle_position(other,other.position)) >= 70.0, "Real-town cars spawned too close.")
	assert(count > 0)
	for direction in [Vector2.UP,Vector2.DOWN]:
		assert(runtime.population.player_vehicle_may_move(runtime.wagon.position,runtime.wagon.position+direction*8.0,runtime.wagon.rotation,runtime.wagon.shape.size*0.5,{}), "An actor blocked the wagon's first forward/reverse movement.")
	print("TOWN STARTUP CLEARANCE PASSED: ",count," traffic cars; nearest wagon/traffic centre distance=",minimum,"; forward and reverse actor-clear.")
	quit()
