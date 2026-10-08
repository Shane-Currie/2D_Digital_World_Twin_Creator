extends Control

## Small live preview using the production building renderer, not a second
## interpretation of roofs/walls. Never writes the town or changes collisions.
signal alignment_dragged(delta_percent: Vector2)
signal rotation_dragged(degrees: float)
signal scale_requested(change: float)
signal door_placement_requested(index: int, location: Dictionary)
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const Artwork = preload("res://scripts/buildings/building_artwork_settings.gd")
var renderer
var building_id := ""
var texture_signature := ""
var town_directory := ""
var preview_bounds := Rect2()
var selected_target := "roof"
var zoom := 1.0
var dragging := false
var rotating := false
var rotation_distance := 0.0
var drag_surface: Dictionary = {}
var editing_doors := false
var door_dragging := false
var door_index := -1
var door_pointer := Vector2.ZERO
var rejected_door_location: Dictionary = {}
var door_overlay: Control

func _ready() -> void:
	clip_contents=true
	custom_minimum_size=Vector2(280,250)
	mouse_filter=Control.MOUSE_FILTER_STOP
	focus_mode=Control.FOCUS_ALL
	resized.connect(_fit)
	queue_redraw()
	door_overlay=Control.new()
	door_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	door_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(door_overlay)
	door_overlay.draw.connect(_draw_door_overlay)

func set_design(feature: Dictionary, data: Dictionary, town_bounds: Dictionary, directory: String) -> void:
	if feature.is_empty():
		if is_instance_valid(renderer): renderer.hide()
		return
	var id := str(feature.id)
	var record: Dictionary = data.get("buildings",{}).get(id,{})
	var textures := record.duplicate(true)
	textures.erase("feature_id")
	for key in ["roof_alignment","wall_alignment"]: textures.erase(key)
	if textures.has("exterior"):
		for key in Artwork.LIMITS: textures.exterior.erase(key)
	for facade in textures.get("facades",{}).values(): facade.erase("alignment")
	var signature := JSON.stringify(textures)
	if building_id!=id or directory!=town_directory or not is_instance_valid(renderer):
		if is_instance_valid(renderer): renderer.free()
		renderer=Renderer.new()
		add_child(renderer)
		var collisions := Builder.new().build([feature],town_bounds)
		if not collisions.ok: renderer.hide(); return
		renderer.setup([feature],collisions.data,town_bounds,data,directory)
		building_id=id
		town_directory=directory
		zoom=1.0
		texture_signature=signature
		preview_bounds=renderer.building_height_meshes[id].visual_bounds
	elif signature!=texture_signature:
		renderer.building_exterior_data=data.duplicate(true)
		renderer._load_building_exterior_textures(directory)
		renderer._cache_building_heights(directory)
		renderer._cache_building_door_art()
		preview_bounds=renderer.building_height_meshes[id].visual_bounds
		texture_signature=signature
	else:
		# Dragging UVs does not rebuild geometry or decode texture files.
		renderer.building_exterior_data=data.duplicate(true)
	renderer.show()
	renderer.queue_redraw()
	if is_instance_valid(door_overlay):
		move_child(door_overlay,get_child_count()-1)
		door_overlay.queue_redraw()
	_fit()

func zoom_view(multiplier: float) -> void:
	zoom=clampf(zoom*multiplier,0.5,4.0)
	_fit()

func fit_view() -> void:
	zoom=1.0
	_fit()

func _fit() -> void:
	if not is_instance_valid(renderer) or not preview_bounds.has_area(): return
	var frame := preview_bounds
	if selected_target in ["front","left"]:
		var face_bounds := Rect2()
		for wall in renderer.building_height_meshes[building_id].walls:
			if not wall.facing_camera or Artwork.facade_key(wall)!=selected_target: continue
			for surface in wall.surfaces:
				var bounds: Rect2 = renderer.HeightGeometry.polygon_bounds(surface.points)
				face_bounds=face_bounds.merge(bounds) if face_bounds.has_area() else bounds
		if face_bounds.has_area(): frame=face_bounds.grow(renderer.pixels_per_metre*0.5)
	var available := (size-Vector2(32,32)).max(Vector2.ONE)
	var ratio := minf(available.x/frame.size.x,available.y/frame.size.y)*zoom
	renderer.scale=Vector2.ONE*ratio
	renderer.position=size*0.5-frame.get_center()*ratio
	if is_instance_valid(door_overlay): door_overlay.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#172b23"))
	if not is_instance_valid(renderer) or not renderer.visible:
		draw_string(ThemeDB.fallback_font,Vector2(12,32),"Select a building to edit its artwork.",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#cadbd1"))

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(renderer) or not renderer.visible: return
	if editing_doors and _handle_door_input(event): accept_event(); return
	if editing_doors: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			dragging=event.pressed
			if dragging: _choose_drag_surface(event.position)
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			if not event.pressed and rotating and rotation_distance<3.0: rotation_dragged.emit(15.0)
			rotating=event.pressed
			if rotating: rotation_distance=0.0
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			scale_requested.emit(5.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -5.0)
		accept_event()
	elif event is InputEventMouseMotion:
		if dragging:
			alignment_dragged.emit(_texture_drag_delta(event.relative))
		elif rotating:
			rotation_distance+=event.relative.length()
			rotation_dragged.emit(event.relative.x*0.5)
		if dragging or rotating: accept_event()
	elif event is InputEventMouse and not Rect2(Vector2.ZERO,size).has_point(event.position):
		dragging=false
		rotating=false

func _choose_drag_surface(screen_position: Vector2) -> void:
	drag_surface={}
	if selected_target=="roof": return
	var world_point: Vector2 = (screen_position-renderer.position)/renderer.scale
	var nearest := INF
	for wall in renderer.building_height_meshes[building_id].walls:
		if not wall.facing_camera or (selected_target!="walls" and Artwork.facade_key(wall)!=selected_target): continue
		for surface in wall.surfaces:
			if Geometry2D.is_point_in_polygon(world_point,surface.points): drag_surface=surface; return
			var centre: Vector2 = (surface.points[0]+surface.points[1]+surface.points[2])/3.0
			var distance := world_point.distance_squared_to(centre)
			if distance<nearest: nearest=distance; drag_surface=surface


func _handle_door_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		door_dragging=false
		door_overlay.queue_redraw()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_view(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8)
		return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			door_pointer=event.position
			door_index=_door_at_pointer(door_pointer)
			door_dragging=door_index>=0 or not _door_location_at(door_pointer).is_empty()
		elif door_dragging:
			door_dragging=false
			var location := _door_location_at(event.position)
			if not location.is_empty(): door_placement_requested.emit(door_index,location)
			else:
				var geographic: Vector2=renderer.ProjectionScript.world_to_geographic((event.position-renderer.position)/renderer.scale,renderer.projection,renderer.pixels_per_metre)
				rejected_door_location={"longitude":geographic.x,"latitude":geographic.y}
		if is_instance_valid(door_overlay): door_overlay.queue_redraw()
		return true
	if event is InputEventMouseMotion and door_dragging:
		door_pointer=event.position
		door_overlay.queue_redraw()
		return true
	return false


func _door_at_pointer(screen_point: Vector2) -> int:
	var point: Vector2=(screen_point-renderer.position)/renderer.scale
	var doors: Array=renderer.building_exterior_data.get("buildings",{}).get(building_id,{}).get("doors",[])
	for index in doors.size():
		var art: Dictionary=renderer.building_door_art.get("%s:%d" % [building_id,index],{})
		for surface in art.get("surfaces",[]):
			if Geometry2D.is_point_in_polygon(point,surface.points): return index
		if art.has("anchor") and point.distance_to(art.anchor)*renderer.scale.x<18: return index
	return -1


func _door_location_at(screen_point: Vector2) -> Dictionary:
	if not Rect2(Vector2.ZERO,size).has_point(screen_point): return {}
	var point: Vector2=(screen_point-renderer.position)/renderer.scale
	var nearest := Vector2.INF
	var distance := INF
	for wall in renderer.building_height_meshes[building_id].walls:
		if not wall.facing_camera or wall.surfaces.is_empty(): continue
		var on_wall := false
		for surface in wall.surfaces:
			if Geometry2D.is_point_in_polygon(point,surface.points): on_wall=true; break
		var candidate := Geometry2D.get_closest_point_to_segment(point,wall.a,wall.b)
		var separation: float=point.distance_to(candidate)
		if not on_wall and separation*renderer.scale.x>24: continue
		if separation<distance: nearest=candidate; distance=separation
	if nearest==Vector2.INF: return {}
	var geographic: Vector2=renderer.ProjectionScript.world_to_geographic(nearest,renderer.projection,renderer.pixels_per_metre)
	return {"longitude":geographic.x,"latitude":geographic.y}


func _draw_door_overlay() -> void:
	if not editing_doors or not is_instance_valid(renderer) or not renderer.visible: return
	var doors: Array=renderer.building_exterior_data.get("buildings",{}).get(building_id,{}).get("doors",[])
	for index in doors.size():
		var art: Dictionary=renderer.building_door_art.get("%s:%d" % [building_id,index],{})
		if not art.has("anchor"): continue
		var point: Vector2=art.anchor*renderer.scale+renderer.position
		door_overlay.draw_circle(point,18,Color("#55d681"),false,2,true)
		door_overlay.draw_string(ThemeDB.fallback_font,point+Vector2(20,-4),"Door %d" % (index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	if door_dragging:
		var location := _door_location_at(door_pointer)
		var colour := Color("#55d681") if not location.is_empty() else Color("#ff6262")
		door_overlay.draw_circle(door_pointer,13,colour,false,3,true)
	if not rejected_door_location.is_empty():
		var point: Vector2=renderer._world(Vector2(rejected_door_location.longitude,rejected_door_location.latitude))*renderer.scale+renderer.position
		for slope in [-1,1]: door_overlay.draw_line(point-Vector2(10,10*slope),point+Vector2(10,10*slope),Color("#ff6262"),3,true)

func _texture_drag_delta(screen_delta: Vector2) -> Vector2:
	var delta: Vector2 = screen_delta/renderer.scale
	if selected_target=="roof":
		return delta/renderer.building_height_meshes[building_id].roof_bounds.size*100.0
	if drag_surface.is_empty(): return Vector2.ZERO
	# Use the real facade's UV basis. Screen percentages alone made alignment
	# sluggish on narrow buildings and wrong on angled/left-facing walls.
	var origin: Vector2 = drag_surface.points[0]
	var first: Vector2 = renderer.HeightGeometry._triangle_uv(origin,drag_surface.points,drag_surface.uvs)
	var second: Vector2 = renderer.HeightGeometry._triangle_uv(origin+delta,drag_surface.points,drag_surface.uvs)
	return (second-first)*100.0
