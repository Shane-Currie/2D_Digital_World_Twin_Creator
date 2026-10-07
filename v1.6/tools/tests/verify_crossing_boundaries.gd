extends SceneTree

const Guard = preload("res://scripts/crossings/crossing_travel.gd")
const Vehicle = preload("res://scripts/runtime/runtime_player_vehicle.gd")
const Walker = preload("res://scripts/runtime/runtime_player_character.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for kind in ["bridge","tunnel"]:
		var corridor := {"id":kind,"kind":kind,"points":PackedVector2Array([Vector2.ZERO,Vector2(400,0)]),"half_width":26.0}
		var guard := Guard.new()
		guard.corridors = [corridor]
		guard.half_size = Vector2(10,21)
		assert(guard.can_move(Vector2(-30,0),Vector2(10,0),PI/2))
		guard.commit_move(Vector2(-30,0),Vector2(10,0))
		assert(guard.active.id == kind)
		assert(not guard.can_move(Vector2(100,0),Vector2(100,100),0), "Side exit was allowed")
		assert(not guard.can_move(Vector2(100,0),Vector2(100,1000),0), "Fast movement crossed the side")
		assert(guard.can_move(Vector2(100,14),Vector2(100,14),PI/2))
		assert(not guard.can_move(Vector2(100,14),Vector2(100,14),0), "A rotating nose crossed the railing")
		assert(guard.can_move(Vector2(380,0),Vector2(430,0),PI/2))
		guard.commit_move(Vector2(380,0),Vector2(430,0))
		assert(guard.active.is_empty(), "The exit did not release the actor")
		guard.commit_move(Vector2(-10,0),Vector2(10,0))
		assert(guard.can_move(Vector2(10,0),Vector2(-40,0),PI/2))
		guard.commit_move(Vector2(10,0),Vector2(-40,0))
		assert(guard.active.is_empty(), "Reversing out of the entry failed")
		guard.commit_move(Vector2(200,-40),Vector2(200,40))
		assert(guard.active.is_empty(), "Crossing below/above the route selected its layer")
		guard.commit_move(Vector2(0,-40),Vector2(0,40))
		assert(guard.active.is_empty(), "Sideways portal movement selected the route")
		var car := Vehicle.new()
		root.add_child(car)
		car.set_physics_process(false)
		car.occupied = true
		car.position = Vector2(100,0)
		car.speed = 108
		car.crossing_travel.active = corridor
		car._physics_process(1.0)
		assert(car.position == Vector2(100,0) and car.speed == 0, "Actual vehicle motion passed through the side")
		car.position = Vector2(100,14)
		car.rotation = PI/2
		assert(not car._can_rotate_to(0), "Actual vehicle rotation bypassed the guard")
		car.queue_free()
		var walker := Walker.new()
		root.add_child(walker)
		walker.set_physics_process(false)
		walker.position = Vector2(100,0)
		walker.crossing_travel.active = corridor
		var event := InputEventKey.new()
		event.keycode = KEY_UP
		event.pressed = true
		Input.parse_input_event(event)
		walker._physics_process(1.0)
		var release := InputEventKey.new()
		release.keycode = KEY_UP
		release.pressed = false
		Input.parse_input_event(release)
		assert(walker.position == Vector2(100,0), "Actual walking motion passed through the side")
		walker.queue_free()
	var curve := {"id":"bend","kind":"bridge","points":PackedVector2Array([Vector2.ZERO,Vector2(100,0),Vector2(200,100)]),"half_width":26.0}
	assert(Guard.contains_pose(curve,Vector2(145,45),PI*0.75,Vector2(10,21)))
	assert(not Guard.contains_pose(curve,Vector2(145,90),PI*0.75,Vector2(10,21)))
	print("CROSSING BOUNDARIES PASSED: bridge/tunnel entry, both ends, reverse, side/fast/rotation blocks, lower crossings, curved path, actual car and walker motion")
	quit()
