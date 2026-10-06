class_name RuntimePlayerCharacter
extends CharacterBody2D

const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
# Fallback pixel art uses this factor; the production texture uses the shared
# feet-anchored box in RuntimeActorArt. 27 source units become 13.75 world units.
const PLAYER_VISUAL_SCALE := 13.75 / 27.0

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
var actor_motion: Callable
var crossing_travel = preload("res://scripts/crossings/crossing_travel.gd").new()
var interior_mode := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var direction := direction_from_controls(
		Input.is_key_pressed(KEY_W), Input.is_key_pressed(KEY_S),
		Input.is_key_pressed(KEY_A), Input.is_key_pressed(KEY_D)
	)
	_move_on_foot(direction, delta)


func _move_on_foot(direction: Vector2, delta: float) -> void:
	if delta <= 0.0: return
	# Match the original game's deliberate four-way handheld movement.
	if direction != Vector2.ZERO:
		facing = direction
	velocity = direction * walk_speed
	var previous_position := global_position
	var proposed_position := previous_position + velocity * delta
	var radius := 4.0 * art_scale
	if actor_motion.is_valid():
		proposed_position = actor_motion.call(previous_position, proposed_position, radius, crossing_travel.active)
	velocity = (proposed_position - previous_position) / delta
	if not crossing_travel.can_move(previous_position, proposed_position, 0.0):
		velocity = Vector2.ZERO
		walking = false
		return
	move_and_slide()
	# A world-body slide can change the proposed path. Do not let that secondary
	# motion put the player inside a drawn actor that has no physics body.
	if actor_motion.is_valid() and global_position.distance_to(proposed_position) > 0.001 and Vector2(actor_motion.call(previous_position, global_position, radius, crossing_travel.active)).distance_to(global_position) > 0.001:
		global_position = previous_position
		velocity = Vector2.ZERO
	if ground_check.is_valid() and not _movement_stays_on_ground(previous_position, global_position, 4.0 * art_scale):
		global_position = previous_position
		velocity = Vector2.ZERO
	crossing_travel.commit_move(previous_position, global_position)
	refresh_collision_mask_for_crossing()
	walking = global_position.distance_to(previous_position) / delta > 1.0
	if walking:
		animation_time += delta
	queue_redraw()


static func direction_from_controls(forward: bool, backward: bool, left: bool, right: bool) -> Vector2:
	var direction := Vector2(float(right) - float(left), float(backward) - float(forward))
	# Preserve the established deliberate four-way movement: horizontal input
	# wins if two perpendicular WASD keys are held together.
	if direction.x != 0.0:
		direction.y = 0.0
	return direction


func set_ground_check(check: Callable) -> void:
	ground_check = check


func refresh_collision_mask_for_crossing() -> void:
	# Surface buildings exist on physics layer 1. A valid bridge/tunnel corridor
	# supplies its own side confinement, so an actor on that separate OSM level
	# must not collide with the building footprint above or below it.
	collision_mask = 0 if interior_mode else (4 if not crossing_travel.active.is_empty() else 1 | 4)


func set_interior_mode(enabled: bool) -> void:
	interior_mode = enabled
	crossing_travel.active = {}
	refresh_collision_mask_for_crossing()


func _movement_stays_on_ground(from: Vector2, to: Vector2, clearance: float) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 4.0))
	for step in range(1, steps + 1):
		if not bool(ground_check.call(from.lerp(to, float(step) / float(steps)), clearance)):
			return false
	return true


func _pixel(x: int, y: int, width: int, height: int, color: String) -> void:
	var visual_scale := art_scale * PLAYER_VISUAL_SCALE
	draw_rect(Rect2((x - 8) * visual_scale, (y - 21) * visual_scale, width * visual_scale, height * visual_scale), Color(color))


func _draw() -> void:
	if not active:
		return
	var walk_frame := int(animation_time * 8.0) % 4 if walking else 0
	var artwork: Dictionary = ActorArt.directional_sprite("player", facing, walk_frame)
	if not artwork.is_empty():
		var stride := sin(animation_time * 19.0) if walking else 0.0
		var visual_scale := art_scale * PLAYER_VISUAL_SCALE
		var lift := absf(stride) * 0.6 * visual_scale
		var lean := stride * 0.015 if walking else 0.0
		draw_circle(Vector2.ZERO, ActorArt.GROUND_CHARACTER_DRAW_SIZE.x * 0.32 * art_scale, Color(0.05, 0.10, 0.07, 0.25))
		draw_set_transform(Vector2(0.0, -lift), lean, Vector2.ONE)
		var grounded_rect := ActorArt.grounded_character_rect()
		grounded_rect.position *= art_scale
		grounded_rect.size *= art_scale
		draw_texture_rect_region(artwork.texture, grounded_rect, artwork.region)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
