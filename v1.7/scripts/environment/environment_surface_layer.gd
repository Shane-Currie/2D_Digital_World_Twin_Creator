extends Node2D

## Each surface has its own GPU material. Water animation never redraws roads.
const Cover = preload("res://scripts/land_cover/land_cover.gd")
var world
var surface_kind := "grass"

func setup(renderer, kind: String) -> void:
	world = renderer
	surface_kind = kind
	var surface := ShaderMaterial.new()
	surface.shader = load("res://scripts/environment/%s_surface.gdshader" % ("water" if kind == "water" else "grass"))
	surface.set_shader_parameter("pixels_per_metre",world.pixels_per_metre)
	material = surface
	queue_redraw()

func refresh() -> void:
	if material != null: material.set_shader_parameter("overview",world.map_overview)
	queue_redraw()

func _draw() -> void:
	if world == null: return
	if surface_kind == "grass":
		var visible: Rect2 = world.world_bounds.grow(80.0)
		if not world.map_overview and world.draw_view_bounds.has_area(): visible = visible.intersection(world.draw_view_bounds)
		_draw_piece(PackedVector2Array([visible.position,Vector2(visible.end.x,visible.position.y),visible.end,Vector2(visible.position.x,visible.end.y)]),world.GRASS)
		return
	if surface_kind == "cover":
		for area in world.land_cover.areas:
			if not world._draws_bounds(area.bounds): continue
			var soft: bool = area.category in ["grass","wood","scrub","park","farmland"]
			for piece in area.pieces: _draw_piece(piece,Cover.colour(area.category),soft)
		return
	for area in world.water_areas:
		if not world._draws_bounds(area.bounds): continue
		for piece in area.pieces: _draw_piece(piece,Color("#287d95"))
		# Both outer shores and island/courtyard shores use their real outlines.
		var rings: Array = [area.outer]
		rings.append_array(area.holes)
		for ring in rings:
			var closed: PackedVector2Array = ring.duplicate()
			closed.append(ring[0])
			draw_polyline(closed,Color("#76b5b5"),world.pixels_per_metre*0.42,true)
			draw_polyline(closed,Color("#bdd5c6"),world.pixels_per_metre*0.10,true)

func _draw_piece(piece: PackedVector2Array, colour: Color, vegetated: bool = true) -> void:
	var indices := Geometry2D.triangulate_polygon(piece)
	for index in range(0,indices.size(),3):
		var triangle := PackedVector2Array([piece[indices[index]],piece[indices[index+1]],piece[indices[index+2]]])
		var uv := Vector2(1,0) if vegetated else Vector2.ZERO
		draw_primitive(triangle,PackedColorArray([colour,colour,colour]),PackedVector2Array([uv,uv,uv]))
