class_name NotPlayableRobot
extends CharacterBody2D

const WALK_SPEED := 38.0
const ARRIVAL_DISTANCE := 3.0

var route: PackedVector2Array = []
var route_index := 0
var animation_time := 0.0
var artwork: Sprite2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8 | 16 | 32
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var hitbox := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	hitbox.shape = shape
	add_child(hitbox)
	artwork = Sprite2D.new()
	artwork.texture = load("res://assets/characters/npr_robot_walk_sheet.png")
	artwork.hframes = 4
	artwork.vframes = 2
	artwork.scale = Vector2.ONE * 0.055
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artwork.position.y = -10.0
	add_child(artwork)


func set_route(points: PackedVector2Array) -> void:
	route = points
	route_index = 0


func _physics_process(delta: float) -> void:
	if route_index >= route.size():
		velocity = Vector2.ZERO
		_update_frame(Vector2.DOWN, false)
		return
	var direction := global_position.direction_to(route[route_index])
	if global_position.distance_to(route[route_index]) <= ARRIVAL_DISTANCE:
		route_index += 1
		return
	velocity = direction * WALK_SPEED
	move_and_slide()
	animation_time += delta
	_update_frame(direction, true)


func _update_frame(direction: Vector2, moving: bool) -> void:
	if artwork == null:
		return
	var direction_frame := 0
	if absf(direction.x) > absf(direction.y):
		direction_frame = 2 if direction.x < 0.0 else 3
	elif direction.y < 0.0:
		direction_frame = 1
	var pose := int(animation_time * 5.0) % 2 if moving else 0
	artwork.frame = direction_frame + pose * 4
