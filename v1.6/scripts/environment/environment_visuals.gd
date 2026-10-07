extends Node2D

const Surface = preload("res://scripts/environment/environment_surface_layer.gd")
const Trees = preload("res://scripts/environment/tree_layer.gd")
var world
var surfaces: Array = []
var trees
var previous_bounds := Rect2()
var previous_overview := false
var previous_hidden := false

func setup(renderer, town_directory: String = "") -> void:
	world = renderer
	for kind in ["grass","cover","water"]:
		var surface := Surface.new()
		surface.z_index = -1
		add_child(surface)
		surface.setup(world,kind)
		surfaces.append(surface)
	trees = Trees.new()
	add_child(trees)
	trees.setup(world,town_directory)
	refresh()

func _process(_delta: float) -> void:
	var hidden: bool = world.tunnel_view_only or world.underpass_path_index >= 0
	if hidden != previous_hidden:
		visible = not hidden
		previous_hidden = hidden
	if world.draw_view_bounds != previous_bounds or world.map_overview != previous_overview: refresh()

func refresh() -> void:
	previous_bounds = world.draw_view_bounds
	previous_overview = world.map_overview
	for surface in surfaces: surface.refresh()
	trees.refresh()
