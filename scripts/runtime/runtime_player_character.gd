class_name RuntimePlayerCharacter
extends CharacterBody2D

## The four-direction pixel character used by Generational Australian Survival,
## kept data-independent so the same player can appear in every imported town.
var facing := Vector2.DOWN
var walking := false
var animation_time := 0.0
var active := true
var controls_enabled := true
var walk_speed := 42.0
var art_scale := 1.0
var ground_check: Callable
var crossing_travel = preload("res://scripts/crossings/crossing_travel.gd").new()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var hit := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0 * art_scale
	crossing_travel.half_size = Vector2.ONE * circle.radius
	hit.shape = circle
	add_child(hit)


func _physics_process(delta: float) -> void:
	refresh_collision_mask_for_crossing()
	if not active or not controls_enabled:
		walking = false
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var direction := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
	)
	# Match the original game's deliberate four-way handheld movement.
	if direction.x != 0.0:
		direction.y = 0.0
	if direction != Vector2.ZERO:
		facing = direction
	velocity = direction * walk_speed
	var previous_position := global_position
	if not crossing_travel.can_move(previous_position, previous_position + velocity * delta, 0.0):
		velocity = Vector2.ZERO
		walking = false
		return
	move_and_slide()
	if ground_check.is_valid() and not _movement_stays_on_ground(previous_position, global_position, 4.0 * art_scale):
		global_position = previous_position
		velocity = Vector2.ZERO
	crossing_travel.commit_move(previous_position, global_position)
	refresh_collision_mask_for_crossing()
	walking = get_real_velocity().length() > 1.0
	if walking:
		animation_time += delta
	queue_redraw()


func set_ground_check(check: Callable) -> void:
	ground_check = check


func refresh_collision_mask_for_crossing() -> void:
	# Surface buildings exist on physics layer 1. A valid bridge/tunnel corridor
	# supplies its own side confinement, so an actor on that separate OSM level
	# must not collide with the building footprint above or below it.
	collision_mask = 4 if not crossing_travel.active.is_empty() else 1 | 4


func _movement_stays_on_ground(from: Vector2, to: Vector2, clearance: float) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 4.0))
	for step in range(1, steps + 1):
		if not bool(ground_check.call(from.lerp(to, float(step) / float(steps)), clearance)):
			return false
	return true


func _pixel(x: int, y: int, width: int, height: int, color: String) -> void:
	draw_rect(Rect2((x - 8) * art_scale, (y - 21) * art_scale, width * art_scale, height * art_scale), Color(color))


func _draw() -> void:
	if not active:
		return
	var step := int(animation_time * 9.0) % 4
	var foot := 1 if walking and step == 1 else (-1 if walking and step == 3 else 0)
	_pixel(3, 20, 10, 2, "748667")
	_pixel(4, 16, 3, 4 + foot, "775b40")
	_pixel(9, 16, 3, 4 - foot, "775b40")
	_pixel(4, 20 + foot, 4, 2, "34483f")
	_pixel(9, 20 - foot, 4, 2, "34483f")
	_pixel(3, 9, 10, 8, "38679a")
	_pixel(5, 9, 6, 7, "598ec0")
	_pixel(1, 10 - foot, 3, 5, "e0b98e")
	_pixel(13, 10 + foot, 2, 5, "e0b98e")
	_pixel(4, 3, 9, 7, "e4bf94")
	_pixel(3, 1, 10, 4, "684a38")
	_pixel(5, 0, 7, 2, "684a38")
	_pixel(3, 4, 2, 3, "684a38")
	if facing == Vector2.UP:
		_pixel(4, 3, 9, 6, "684a38")
		_pixel(5, 3, 6, 2, "836046")
	elif facing == Vector2.LEFT:
		_pixel(3, 5, 1, 2, "624631")
		_pixel(2, 7, 2, 2, "e4bf94")
		_pixel(9, 3, 4, 5, "684a38")
	elif facing == Vector2.RIGHT:
		_pixel(12, 5, 1, 2, "624631")
		_pixel(12, 7, 2, 2, "e4bf94")
		_pixel(3, 3, 4, 5, "684a38")
	else:
		_pixel(6, 5, 1, 2, "624631")
		_pixel(10, 5, 1, 2, "624631")
		_pixel(7, 8, 3, 1, "bc8b6e")
