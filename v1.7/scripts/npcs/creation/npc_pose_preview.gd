extends Control

const PoseArt = preload("res://scripts/npcs/creation/npc_pose_art.gd")
const Store = preload("res://scripts/npcs/creation/npc_creation_store.gd")
const Furniture = preload("res://scripts/interiors/interior_furniture_catalog.gd")
class Seat:
	extends "res://scripts/interiors/runtime_interior_layer.gd"
	var item: Dictionary = {}
	func _draw() -> void:
		if not item.is_empty(): _draw_furniture(item)
class Figure:
	extends Node2D
	func _draw() -> void:
		var preview = get_parent()
		PoseArt.draw_actor(self,preview.appearance,preview.catalog,preview.directory,Vector2.ZERO,preview.facing,preview.pose,preview.time)

var appearance: Dictionary = {"npc_asset":"npc_medium_man_adult","gender":"man","age_group":"adult","skin_tone_group":"medium"}
var catalog: Dictionary = Store.empty_data()
var directory := ""
var pose := "idle"
var facing := Vector2.DOWN
var seat_id := "dining_chair"
var time := 0.0
var frozen := false
var seat
var figure

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents=true
	seat=Seat.new(); seat.z_index=0; add_child(seat)
	seat.pixels_per_metre=8.0
	figure=Figure.new(); figure.z_index=1; add_child(figure)

func _process(delta: float) -> void:
	if not frozen: time+=delta
	queue_redraw()

func _draw() -> void:
	# Same furniture renderer and 8 px/m actor scale as playable interiors.
	var actor_rect := PoseArt.sitting_rect(appearance,catalog,facing,directory) if pose=="sit" else preload("res://scripts/runtime/runtime_actor_art.gd").grounded_character_rect()
	var zoom := minf(maxf(1,size.y-70)/actor_rect.size.y,maxf(1,size.x-40)/actor_rect.size.x)
	var centre := Vector2(size.x*.5,35-actor_rect.position.y*zoom+(size.y-70-actor_rect.size.y*zoom)*.5)
	draw_rect(Rect2(Vector2.ZERO,size),Color("#303b35"))
	if is_instance_valid(seat):
		var definition := Furniture.definition(seat_id)
		seat.item=definition.duplicate(true)
		seat.item.merge({"id":"preview_seat","catalog_id":seat_id,"x_metres":0.0,"y_metres":0.0,"width_metres":definition.size_metres[0],"depth_metres":definition.size_metres[1],"rotation_degrees":0.0})
		seat.item.rotation_degrees=rad_to_deg(Vector2.DOWN.angle_to(facing))
		seat.position=centre; seat.scale=Vector2.ONE*zoom; seat.visible=pose=="sit"
		seat.queue_redraw()
		var hip: Vector2 = preload("res://scripts/npcs/creation/seat_orientation.gd").position(seat.item)*8.0 if pose=="sit" else Vector2.ZERO
		figure.position=centre+hip*zoom; figure.scale=Vector2.ONE*zoom; figure.queue_redraw()
	var view: String = Store.DIRECTIONS[preload("res://scripts/runtime/runtime_actor_art.gd").direction_column(facing)].capitalize()
	var text := "Game %s · %s" % [seat_id.replace("_"," "),view] if pose=="sit" else "Animation preview · " + view
	draw_string(ThemeDB.fallback_font,Vector2(10,22),text,HORIZONTAL_ALIGNMENT_LEFT,size.x-20,13,Color("#ecf3e8"))
