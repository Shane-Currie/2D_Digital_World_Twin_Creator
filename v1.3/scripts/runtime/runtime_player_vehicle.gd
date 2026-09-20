class_name RuntimePlayerVehicle
extends CharacterBody2D

signal gear_changed(gear_name: String)
signal gear_change_denied()

const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const OdometerScript = preload("res://scripts/runtime/vehicle/runtime_odometer.gd")

## The player-owned Holden VZ wagon and handling conventions migrated from the
## existing game. Creator Studio supplies the editable numbers at runtime.
var occupied := false
var controls_enabled := true
var speed := 0.0
var target_speed_kmh := 0.0
var cruise_step_kmh := 1.0
var wheel_animation := 0.0
var art_scale := 1.0
var shape: RectangleShape2D
var max_speed_kmh := 200.0
var reverse_max_speed_kmh := 20.0
var gear := "D"
var pixels_per_metre := 2.0
var forward_speed := 108.0
var reverse_speed := 36.0
var acceleration := 42.0
var zero_to_hundred_seconds := 7.2
var reverse_acceleration := 70.0
var coast_deceleration := 30.0
var brake_deceleration := 140.0
var steering_rate := 1.9
var ground_check: Callable
var pedestrian_check: Callable
var crossing_travel = preload("res://scripts/crossings/crossing_travel.gd").new()
var odometer = OdometerScript.new()


func configure(driving_settings: Dictionary, runtime_pixels_per_metre: float = 2.0) -> void:
	pixels_per_metre = maxf(0.01, runtime_pixels_per_metre)
	max_speed_kmh = float(driving_settings.get("max_speed_kmh", max_speed_kmh))
	reverse_max_speed_kmh = float(driving_settings.get("reverse_max_speed_kmh", reverse_max_speed_kmh))
	forward_speed = kilometres_per_hour_to_world_speed(max_speed_kmh)
	reverse_speed = float(driving_settings.get("reverse_speed", reverse_speed))
	zero_to_hundred_seconds = float(driving_settings.get("zero_to_hundred_seconds", zero_to_hundred_seconds))
	# A physically meaningful 0–100 time stays consistent when another OSM map
	# uses a different pixels-per-metre scale. Legacy acceleration remains saved
	# for older projects but no longer controls the player's forward ramp.
	acceleration = kilometres_per_hour_to_world_speed(100.0) / maxf(0.1, zero_to_hundred_seconds)
	reverse_acceleration = float(driving_settings.get("reverse_acceleration", reverse_acceleration))
	coast_deceleration = float(driving_settings.get("coast_deceleration", coast_deceleration))
	brake_deceleration = float(driving_settings.get("brake_deceleration", brake_deceleration))
	steering_rate = float(driving_settings.get("steering_rate", steering_rate))


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 4
	collision_mask = 1 | 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	shape = RectangleShape2D.new()
	shape.size = Vector2(17.0, 40.0) * art_scale
	crossing_travel.half_size = shape.size * 0.5
	var hit := CollisionShape2D.new()
	hit.shape = shape
	add_child(hit)


func _physics_process(delta: float) -> void:
	refresh_collision_mask_for_crossing()
	if not occupied or not controls_enabled:
		if not occupied:
			target_speed_kmh = 0.0
		speed = 0.0
		velocity = Vector2.ZERO
		return
	var steer := float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
	update_speed_toward_cruise(Input.is_key_pressed(KEY_SPACE), delta)
	if absf(speed) > 1.0 and steer != 0.0:
		var next_angle := rotation + steer * signf(speed) * minf(absf(speed) / 32.0, 1.0) * steering_rate * delta
		if _can_rotate_to(next_angle):
			rotation = next_angle
	velocity = Vector2.UP.rotated(rotation) * speed
	var previous_position := global_position
	if pedestrian_check.is_valid() and crossing_travel.active.is_empty() and not bool(pedestrian_check.call(previous_position, previous_position + velocity * delta)):
		# A walker already committed to the crossing; the owned wagon obeys the
		# same reservation as NPC cars instead of driving through a drawn actor.
		target_speed_kmh = 0.0
		speed = 0.0
		velocity = Vector2.ZERO
		return
	if not crossing_travel.can_move(previous_position, previous_position + velocity * delta, rotation):
		target_speed_kmh = 0.0
		speed = 0.0
		velocity = Vector2.ZERO
		return
	var collision := move_and_collide(velocity * delta)
	if collision:
		target_speed_kmh = 0.0
		speed = 0.0
		velocity = Vector2.ZERO
	elif ground_check.is_valid() and not _movement_stays_on_ground(previous_position, global_position, 10.0 * art_scale):
		global_position = previous_position
		target_speed_kmh = 0.0
		speed = 0.0
		velocity = Vector2.ZERO
	odometer.record_world_displacement(previous_position, global_position, pixels_per_metre)
	crossing_travel.commit_move(previous_position, global_position)
	refresh_collision_mask_for_crossing()
	wheel_animation += absf(speed) * delta * 0.25
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not occupied or not controls_enabled or not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_UP:
		adjust_cruise_target(cruise_step_kmh)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DOWN:
		adjust_cruise_target(-cruise_step_kmh)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_SPACE:
		set_cruise_target(0.0)
	elif event.keycode == KEY_SHIFT and not event.echo:
		if not toggle_gear():
			gear_change_denied.emit()
		get_viewport().set_input_as_handled()


func toggle_gear() -> bool:
	# Switching direction while rolling would make cruise reverse the wagon
	# abruptly. Require a near-stop and cancel any selected cruise speed.
	if speed_kmh() > 2.0:
		return false
	gear = "R" if gear == "D" else "D"
	speed = 0.0
	target_speed_kmh = 0.0
	gear_changed.emit(gear)
	return true


func reset_gear() -> void:
	gear = "D"
	speed = 0.0
	target_speed_kmh = 0.0


func adjust_cruise_target(change_kmh: float) -> void:
	set_cruise_target(target_speed_kmh + change_kmh)


func set_cruise_target(value_kmh: float) -> void:
	target_speed_kmh = clampf(snappedf(value_kmh, cruise_step_kmh), 0.0, reverse_max_speed_kmh if gear == "R" else max_speed_kmh)


func update_speed_toward_cruise(emergency_brake: bool, delta: float) -> void:
	if emergency_brake:
		target_speed_kmh = 0.0
		speed = move_toward(speed, 0.0, brake_deceleration * delta)
		return
	var target_world_speed := kilometres_per_hour_to_world_speed(target_speed_kmh) * (-1.0 if gear == "R" else 1.0)
	if speed * target_world_speed < 0.0:
		speed = move_toward(speed, 0.0, brake_deceleration * delta)
	elif absf(speed) < absf(target_world_speed):
		speed = move_toward(speed, target_world_speed, (reverse_acceleration if gear == "R" else acceleration) * delta)
	else:
		speed = move_toward(speed, target_world_speed, coast_deceleration * delta)


func kilometres_per_hour_to_world_speed(value: float) -> float:
	return value / 3.6 * pixels_per_metre


func speed_kmh() -> float:
	return absf(speed) * 3.6 / pixels_per_metre


func set_ground_check(check: Callable) -> void:
	ground_check = check


func set_pedestrian_check(check: Callable) -> void:
	pedestrian_check = check


func refresh_collision_mask_for_crossing() -> void:
	# Keep player collision on layer 2 while ignoring ground-building layer 1
	# only when a mapped bridge or tunnel corridor owns the vehicle's movement.
	collision_mask = 2 if not crossing_travel.active.is_empty() else 1 | 2


func _movement_stays_on_ground(from: Vector2, to: Vector2, clearance: float) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 5.0))
	for step in range(1, steps + 1):
		if not bool(ground_check.call(from.lerp(to, float(step) / float(steps)), clearance)):
			return false
	return true


func driver_door() -> Vector2:
	return global_position + Vector2(16.0, -4.0).rotated(rotation) * art_scale


func _car_pixel(x: int, y: int, width: int, height: int, color: String) -> void:
	draw_rect(Rect2((x - 9.5) * art_scale, (y - 20.5) * art_scale, width * art_scale, height * art_scale), Color(color))


func _draw() -> void:
	var artwork: Dictionary = ActorArt.sprite("wagon")
	if not artwork.is_empty():
		draw_circle(Vector2(0.0, 2.0) * art_scale, 10.0 * art_scale, Color(0.05, 0.10, 0.07, 0.20))
		draw_texture_rect_region(artwork.texture, Rect2(Vector2(-9.5, -20.0) * art_scale, Vector2(19.0, 40.0) * art_scale), artwork.region)
		if absf(speed) > 8.0:
			var wheel_flash := Color("#96b9b9") if int(wheel_animation) % 2 == 0 else Color("#263d37")
			for tyre in [Vector2(-9.0, -12.0), Vector2(9.0, -12.0), Vector2(-9.0, 12.0), Vector2(9.0, 12.0)]:
				draw_rect(Rect2((tyre - Vector2(0.5, 2.0)) * art_scale, Vector2(1.0, 4.0) * art_scale), wheel_flash)
		return
	# Drawn from the original Holden VZ wagon asset so source builds and exported
	# builds use the same crisp pixel appearance without an import dependency.
	_car_pixel(2, 3, 15, 37, "34483f")
	_car_pixel(3, 1, 13, 39, "34483f")
	_car_pixel(4, 2, 11, 37, "f4f4e9")
	_car_pixel(3, 6, 13, 28, "f4f4e9")
	_car_pixel(3, 8, 1, 23, "a6afa2")
	_car_pixel(15, 8, 1, 23, "a6afa2")
	_car_pixel(5, 3, 9, 7, "ffffff")
	_car_pixel(4, 11, 11, 6, "355b5b")
	_car_pixel(5, 12, 9, 3, "87b4b5")
	_car_pixel(5, 18, 9, 11, "f4f4e9")
	_car_pixel(4, 29, 11, 7, "355b5b")
	_car_pixel(5, 30, 9, 3, "84aaad")
	_car_pixel(5, 36, 9, 2, "f4f4e9")
	_car_pixel(1, 8, 2, 6, "33403b")
	_car_pixel(1, 30, 2, 6, "33403b")
	_car_pixel(16, 8, 2, 6, "33403b")
	_car_pixel(16, 30, 2, 6, "33403b")
	_car_pixel(3, 3, 3, 2, "f7eab0")
	_car_pixel(13, 3, 3, 2, "f7eab0")
	_car_pixel(3, 37, 3, 2, "b46053")
	_car_pixel(13, 37, 3, 2, "b46053")
	_car_pixel(7, 39, 5, 1, "e3d39c")


func _can_rotate_to(angle: float) -> bool:
	var rotation_steps := maxi(1, ceili(absf(angle - rotation) / 0.08))
	for step in range(1, rotation_steps + 1):
		if not crossing_travel.can_move(global_position, global_position, lerpf(rotation, angle, float(step) / rotation_steps)):
			return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(angle, global_position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
