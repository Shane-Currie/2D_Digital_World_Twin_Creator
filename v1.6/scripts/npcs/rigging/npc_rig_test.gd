extends Window

const Population=preload("res://scripts/runtime/runtime_population.gd")
const Player=preload("res://scripts/runtime/runtime_player_character.gd")
var population
var player
var camera
var agent: Dictionary
var corners: Array[Vector2]=[Vector2(-20,-14),Vector2(20,-14),Vector2(20,14),Vector2(-20,14)]
var target_index:=1
var distance:=0.0
var help: Label

class Ground:
	extends Node2D
	func _draw() -> void:
		draw_rect(Rect2(-200,-150,400,300),Color("#7c9380"))
		draw_rect(Rect2(-30,-24,60,48),Color("#b7b49c"))
		for x in range(-30,31,6): draw_line(Vector2(x,-24),Vector2(x,24),Color("#989a86"),.12)
		for y in range(-24,25,6): draw_line(Vector2(-30,y),Vector2(30,y),Color("#989a86"),.12)

func setup(item: Dictionary,directory: String) -> void:
	title="NPC walking test — "+str(item.name)
	size=Vector2i(980,680); min_size=Vector2i(640,480); transient=true
	close_requested.connect(queue_free)
	var floor_view:=Ground.new(); add_child(floor_view)
	population=Population.new(); add_child(population); population.set_process(false)
	population.npc_creation_data={"schema_version":1,"kind":"npc_creations","creations":[item.duplicate(true)]}
	population.npc_artwork_directory=directory
	var appearance:=preload("res://scripts/npcs/creation/npc_creation_store.gd").appearance(item,not str(item.id).begins_with("npc_"))
	appearance.animation_type="animated"; population.npc_art_type="animated"
	agent={"kind":"person","position":corners[0],"angle":0.0,"phase":0.0,"moving":true,"appearance":appearance,"space":"outdoors"}
	population.agents.append(agent)
	player=Player.new(); add_child(player); player.position=Vector2(0,5); player.walk_speed=22; player.art_type="animated"
	camera=Camera2D.new(); add_child(camera); camera.zoom=Vector2.ONE*7
	var ui:=CanvasLayer.new(); add_child(ui)
	help=Label.new(); help.position=Vector2(15,12); help.add_theme_color_override("font_color",Color("#fff7df")); ui.add_child(help)
	_set_help()

func _process(delta: float) -> void:
	if population==null: return
	var point: Vector2=agent.position
	var target: Vector2=corners[target_index]
	var step: float=minf(point.distance_to(target),12*delta)
	agent.angle=point.direction_to(target).angle()
	agent.position=point.move_toward(target,step); agent.phase+=delta; distance+=step
	if Vector2(agent.position).distance_to(target)<.05: target_index=(target_index+1)%corners.size()
	population.queue_redraw(); _set_help()

func _set_help() -> void:
	help.text="Walking test · NPC turns through all four views\nWASD moves the normal player for a scale comparison · Esc closes\nThis scene does not change your town, inventory, NPC placement or dialogue."

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: queue_free()
