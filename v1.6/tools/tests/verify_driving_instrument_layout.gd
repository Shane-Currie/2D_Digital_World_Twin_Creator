extends SceneTree

const RuntimeScene = preload("res://scenes/runtime/town_runtime.tscn")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime = RuntimeScene.instantiate()
	root.add_child(runtime)
	await process_frame
	var speedometer: Control = runtime.speedometer_gauge
	var odometer: Control = runtime.odometer_panel
	assert(is_equal_approx(speedometer.scale.x, 0.55) and speedometer.scale == odometer.scale, "Driving instruments were not uniformly reduced.")
	var speed_rect := Rect2(speedometer.position, speedometer.size * speedometer.scale)
	var odometer_rect := Rect2(odometer.position, odometer.size * odometer.scale)
	var combined := speed_rect.merge(odometer_rect)
	assert(combined.position.x <= 8.0 and combined.end.x < 130.0, "Driving instruments are not in the lower-left safe area.")
	assert(combined.position.y >= 240.0 and combined.end.y <= 330.0, "Driving instruments overlap the road centre or lower HUD.")
	assert(combined.size.x <= 120.0 and combined.size.y <= 85.0, "Driving instruments were not reduced to approximately half size.")
	speedometer.visible = true
	odometer.set_display_state(true, false)
	speedometer.update_readings(64.0, 87.0, 200.0, "D")
	assert(speedometer.visible and odometer.visible, "The compact instruments did not appear while driving.")
	assert(speedometer.actual_kmh > 0 and speedometer.cruise_kmh == 87, "The compact speedometer lost actual or cruise readings.")
	odometer.update_readings(12345.0, 678.0)
	assert(is_equal_approx(odometer.total_metres, 12345.0) and is_equal_approx(odometer.trip_metres, 678.0), "The compact odometer lost ODO or TRIP A readings.")
	var reset_state := {"count": 0}
	odometer.trip_reset_requested.connect(func() -> void: reset_state.count += 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = odometer.RESET_RECT.get_center()
	odometer._gui_input(click)
	assert(int(reset_state.count) == 1, "The compact trip Reset control is not clickable.")
	print("DRIVING INSTRUMENT LAYOUT PASSED: %.1fx%.1f lower-left block; speed, cruise, gear, ODO, TRIP A and Reset retained." % [combined.size.x, combined.size.y])
	quit()
