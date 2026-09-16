class_name NonPlayableDrone
extends CharacterBody2D

const FLIGHT_SPEED := 72.0
const ARRIVAL_DISTANCE := 5.0

var route: PackedVector2Array = []
var route_index := 0
var animation_time := 0.0
var artwork: Sprite2D


func _ready() -> void:
	# NPDs deliberately do not collide with ground buildings. Their generated
	# aerial route remains inside the imported map instead.
	collision_layer = 0
	collision_mask = 0
	z_index = 20
	artwork = Sprite2D.new()
	artwork.texture = load("res://assets/characters/npd_drone_flight_sheet.png")
	artwork.hframes = 4
	artwork.vframes = 2
	artwork.scale = Vector2.ONE * 0.055
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(artwork)


func set_route(points: PackedVector2Array) -> void:
	route = points
	route_index = 0


func _physics_process(delta: float) -> void:
	if route_index >= route.size():
		velocity = Vector2.ZERO
		_update_frame(Vector2.UP)
		return
	var direction := global_position.direction_to(route[route_index])
	if global_position.distance_to(route[route_index]) <= ARRIVAL_DISTANCE:
		route_index += 1
		return
	velocity = direction * FLIGHT_SPEED
	move_and_slide()
	animation_time += delta
	_update_frame(direction)


func _update_frame(direction: Vector2) -> void:
	if artwork == null:
		return
	var direction_frame := 0 if direction.y < 0.0 else 1
	if absf(direction.x) > absf(direction.y):
		direction_frame = 2 if direction.x < 0.0 else 3
	artwork.frame = direction_frame + (int(animation_time * 10.0) % 2) * 4
