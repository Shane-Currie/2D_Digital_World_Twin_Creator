extends SceneTree

const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")


func _initialize() -> void:
	var population = PopulationScript.new()
	population.set_simulation_focus(Vector2.ZERO)
	var distant_car := {"kind": "traffic", "position": Vector2(2000, 0)}
	var distant_person := {"kind": "person", "position": Vector2(2000, 0)}
	assert(is_equal_approx(population._traffic_update_delta(distant_person, 0.05), 0.05), "Pedestrians must retain full-rate simulation.")
	for _step in 3:
		assert(is_zero_approx(population._traffic_update_delta(distant_car, 0.05)), "Distant traffic updated before the safe interval.")
	assert(is_equal_approx(population._traffic_update_delta(distant_car, 0.05), 0.20), "Distant traffic lost accumulated simulation time.")
	distant_car.position = Vector2(100, 0)
	assert(is_equal_approx(population._traffic_update_delta(distant_car, 0.05), 0.05), "Nearby traffic was throttled.")
	distant_car.position = Vector2(2000, 0)
	assert(is_equal_approx(population._traffic_update_delta(distant_car, 0.40), 0.20), "A stalled frame produced an oversized movement step.")
	assert(is_equal_approx(population._traffic_update_delta(distant_car, 0.05), 0.20), "A stalled frame lost remaining simulation time.")
	population.free()
	print("POPULATION UPDATE BUDGET PASSED: NPCs and nearby cars full-rate; remote cars batched with bounded steps.")
	quit(0)
