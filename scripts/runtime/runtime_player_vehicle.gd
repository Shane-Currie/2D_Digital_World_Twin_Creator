class_name RuntimePlayerVehicle
extends CharacterBody2D

## The player-owned Holden VZ wagon and handling conventions migrated from the
## existing game. Creator Studio supplies the editable numbers at runtime.
var occupied := false
var controls_enabled := true
var speed := 0.0
var art_scale := 1.0
var shape: RectangleShape2D
var forward_speed := 108.0
var reverse_speed := 36.0
var acceleration := 42.0
var reverse_acceleration := 70.0
var coast_deceleration := 30.0
var brake_deceleration := 140.0
var steering_rate := 1.9
var ground_check: Callable
var crossing_travel = preload("res://scripts/crossings/crossing_travel.gd").new()


func configure(driving_settings: Dictionary) -> void:
	forward_speed = float(driving_settings.get("forward_speed", forward_speed))
	reverse_speed = float(driving_settings.get("reverse_speed", reverse_speed))
	acceleration = float(driving_settings.get("acceleration", acceleration))
	reverse_acceleration = float(driving_settings.get("reverse_acceleration", reverse_acceleration))
	coast_deceleration = float(driving_settings.get("coast_deceleration", coast_deceleration))
	brake_deceleration = float(driving_settings.get("brake_deceleration", brake_deceleration))
	steering_rate = float(driving_settings.get("steering_rate", steering_rate))


func _ready() -> void:
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
		speed = 0.0
		velocity = Vector2.ZERO
		return
	var throttle := float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))
	var steer := float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
	if Input.is_key_pressed(KEY_SPACE):
		speed = move_toward(speed, 0.0, brake_deceleration * delta)
	elif throttle > 0.0:
		speed = move_toward(speed, forward_speed, (brake_deceleration if speed < 0.0 else acceleration) * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -reverse_speed, (brake_deceleration if speed > 0.0 else reverse_acceleration) * delta)
	else:
		speed = move_toward(speed, 0.0, coast_deceleration * delta)
	if absf(speed) > 1.0 and steer != 0.0:
		var next_angle := rotation + steer * signf(speed) * minf(absf(speed) / 32.0, 1.0) * steering_rate * delta
		if _can_rotate_to(next_angle):
			rotation = next_angle
	velocity = Vector2.UP.rotated(rotation) * speed
	var previous_position := global_position
	if not crossing_travel.can_move(previous_position, previous_position + velocity * delta, rotation):
		speed = 0.0
		velocity = Vector2.ZERO
		return
	var collision := move_and_collide(velocity * delta)
	if collision:
		speed = 0.0
		velocity = Vector2.ZERO
	elif ground_check.is_valid() and not _movement_stays_on_ground(previous_position, global_position, 10.0 * art_scale):
		global_position = previous_position
		speed = 0.0
		velocity = Vector2.ZERO
	crossing_travel.commit_move(previous_position, global_position)
	refresh_collision_mask_for_crossing()


func set_ground_check(check: Callable) -> void:
	ground_check = check


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
