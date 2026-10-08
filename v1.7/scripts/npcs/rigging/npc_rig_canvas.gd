extends Control

signal selected(part: String)
signal edited(rig: Dictionary)
const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")
const Art=preload("res://scripts/npcs/rigging/npc_rig_art.gd")
var rig: Dictionary=Rig.new_rig()
var directory: String=""
var view: String="front"
var selected_part: String="head"
var walking:=false
var show_joints:=true
var time:=0.0
var draft: Dictionary={}
var dragging:=false
var rotating:=false
var start_mouse:=Vector2.ZERO
var original_angle:=0.0
var drag_offset:=Vector2.ZERO

func _ready() -> void:
	clip_contents=true; texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size=Vector2(280,320)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if walking: time+=delta
	queue_redraw()

func canvas_transform() -> Transform2D:
	var scale_value:=minf(maxf(1,size.x-90)/120,maxf(1,size.y-55)/200)
	return Transform2D(0,Vector2.ONE*scale_value,0,Vector2(size.x*.5-50*scale_value,30))

func current() -> Dictionary: return draft if not draft.is_empty() else rig

func bones() -> Dictionary: return Art.transforms(current(),view,time,walking and not dragging and not rotating)

func cancel_drag() -> void:
	draft={}; dragging=false; rotating=false; queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#182d28"))
	var transform:=canvas_transform()
	var rig_value:=current()
	var values:=bones()
	var keys:=Rig.PARTS.duplicate()
	keys.sort_custom(func(a,b):return rig_value.views[view].parts[a].z_index<rig_value.views[view].parts[b].z_index)
	for key in keys:
		var part: Dictionary=rig_value.views[view].parts[key]
		var points:=Art.corners(part,values[key])
		for i in points.size(): points[i]=transform*points[i]
		var texture:=Art.texture(part.image if str(part.image).begins_with("res://") else directory.path_join(part.image)) if not str(part.image).is_empty() else null
		if texture!=null:
			var uv:=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
			if part.flip_h:
				for i in uv.size(): uv[i].x=1-uv[i].x
			if part.get("region",[]).size()==4:
				var region:=Rect2(part.region[0],part.region[1],part.region[2],part.region[3])
				for i in uv.size(): uv[i]=(region.position+uv[i]*region.size)/Vector2(texture.get_size())
			draw_polygon(points,PackedColorArray([Color.WHITE]),uv,texture)
		else: draw_colored_polygon(points,Color(.5,.65,.6,.16))
		if key==selected_part:
			draw_polyline(points+PackedVector2Array([points[0]]),Color("#e9c773"),2)
	if show_joints:
		for key in Rig.PARTS:
			var point: Vector2=transform*values[key].origin
			var parent: String=Rig.PARENTS.get(key,"")
			if values.has(parent): draw_line(transform*values[parent].origin,point,Color(.4,.8,.7,.7),1.5)
			draw_circle(point,6 if key==selected_part else 4,Color("#f5c66c") if key==selected_part else Color("#65d0b2"))
	draw_string(ThemeDB.fallback_font,Vector2(10,20),"%s · %s" % [view.capitalize(),"Walking" if walking else "Drag a joint or body part"],HORIZONTAL_ALIGNMENT_LEFT,size.x-20,13,Color("#ecf3e8"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: cancel_drag(); accept_event(); return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			walking=false
			var picked:=pick_part(event.position)
			if picked.is_empty(): return
			selected_part=picked; selected.emit(picked)
			draft=rig.duplicate(true); start_mouse=event.position
			original_angle=float(draft.views[view].parts[picked].rotation_degrees)
			var point: Vector2=canvas_transform().affine_inverse()*event.position
			var parent: String=Rig.PARENTS.get(picked,"")
			var rest:=Art.transforms(draft,view,0,false)
			if rest.has(parent): point=rest[parent].affine_inverse()*point
			var part: Dictionary=draft.views[view].parts[picked]
			drag_offset=Vector2(part.position[0],part.position[1])-point
			dragging=event.button_index==MOUSE_BUTTON_LEFT; rotating=not dragging
			grab_focus(); accept_event(); queue_redraw()
		elif dragging or rotating:
			var value:=draft.duplicate(true); cancel_drag(); rig=value
			edited.emit(value); accept_event()
	elif event is InputEventMouseMotion and (dragging or rotating):
		var part: Dictionary=draft.views[view].parts[selected_part]
		if rotating: part.rotation_degrees=clampf(original_angle+(event.position.x-start_mouse.x)*.6,-180,180)
		else:
			var point: Vector2=canvas_transform().affine_inverse()*event.position
			var parent: String=Rig.PARENTS.get(selected_part,"")
			var rest:=Art.transforms(draft,view,0,false)
			if rest.has(parent): point=rest[parent].affine_inverse()*point
			point+=drag_offset
			part.position=[clampf(point.x,-200,200),clampf(point.y,-200,200)]
		accept_event(); queue_redraw()

func pick_part(point: Vector2) -> String:
	var values:=bones(); var transform:=canvas_transform()
	var closest: String=""; var distance:=13.0
	for key in Rig.PARTS:
		var length: float=point.distance_to(transform*values[key].origin)
		if length<distance: closest=key; distance=length
	if not closest.is_empty(): return closest
	var keys:=Rig.PARTS.duplicate()
	keys.sort_custom(func(a,b):return rig.views[view].parts[a].z_index>rig.views[view].parts[b].z_index)
	for key in keys:
		var quad:=Art.corners(rig.views[view].parts[key],values[key])
		for i in quad.size(): quad[i]=transform*quad[i]
		if Geometry2D.is_point_in_polygon(point,quad): return key
	return ""
