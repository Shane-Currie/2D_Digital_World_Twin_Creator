extends RefCounted

const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")
const ActorArt=preload("res://scripts/runtime/runtime_actor_art.gd")
# Use the existing shared character box. Rigging must not change gameplay scale.
const WORLD_SIZE:=ActorArt.GROUND_CHARACTER_DRAW_SIZE
static var textures: Dictionary={}
static var frames: Dictionary={}

static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		if path.begins_with("res://") and ResourceLoader.exists(path,"Texture2D"):
			textures[path]=load(path)
			return textures[path]
		if not FileAccess.file_exists(path): return null
		var image:=Image.load_from_file(path)
		if image==null or image.is_empty(): return null
		textures[path]=ImageTexture.create_from_image(image)
	return textures[path]

static func chosen_view(rig: Dictionary, requested: String) -> String:
	return requested if Rig.complete(rig,requested) else "front"

static func transforms(rig: Dictionary, view: String, time: float, walking: bool) -> Dictionary:
	var parts: Dictionary=rig.views[view].parts
	var bones: Dictionary={}
	var phase:=time*TAU*float(rig.walk_cycles_per_second)
	var swing:=sin(phase) if walking else 0.0
	var amplitude:=deg_to_rad(float(rig.stride_degrees))
	var side:=view in ["left","right"]
	var direction_sign: float=-1 if view=="right" else 1
	for key in Rig.PARTS:
		if not parts.has(key): continue
		var part: Dictionary=parts[key]
		var angle:=deg_to_rad(float(part.rotation_degrees))
		var left: bool=key.begins_with("left_")
		var limb_phase: float=1 if left else -1
		if key.ends_with("thigh"): angle+=swing*amplitude*limb_phase*(1.0 if side else .35)*direction_sign
		elif key.ends_with("shin") and walking: angle+=maxf(0,-swing*limb_phase)*amplitude*(1.45 if side else .65)*direction_sign
		elif key.ends_with("upper_arm"): angle-=swing*amplitude*limb_phase*(.8 if side else .3)*direction_sign
		elif key.ends_with("forearm") and walking: angle-=maxf(0,swing*limb_phase)*amplitude*.4*direction_sign
		var local:=Transform2D(angle,Vector2(part.position[0],part.position[1]))
		var parent: String=Rig.PARENTS.get(key,"")
		bones[key]=bones[parent]*local if bones.has(parent) else local
	return bones

static func corners(part: Dictionary, bone: Transform2D) -> PackedVector2Array:
	var size:=Vector2(part.size[0],part.size[1])
	var start: Vector2=-Vector2(part.pivot[0],part.pivot[1])*size
	return PackedVector2Array([bone*start,bone*(start+Vector2(size.x,0)),bone*(start+size),bone*(start+Vector2(0,size.y))])

static func rest_scale(rig: Dictionary,view: String) -> float:
	var bones:=transforms(rig,view,0,false)
	var bounds:=Rect2(); var first:=true
	for part in Rig.PARTS:
		for point in corners(rig.views[view].parts[part],bones[part]):
			if first: bounds=Rect2(point,Vector2.ZERO); first=false
			else: bounds=bounds.expand(point)
	return minf(WORLD_SIZE.y/maxf(1,bounds.size.y),WORLD_SIZE.x/maxf(1,bounds.size.x))

static func layout(rig: Dictionary, requested: String, time: float, walking: bool) -> Dictionary:
	var view:=chosen_view(rig,requested)
	if not Rig.complete(rig,view): return {}
	# Shared eight-frame geometry caches: no image reads or per-NPC nodes each tick.
	var frame:=int(floor(time*float(rig.walk_cycles_per_second)*8))%8 if walking else -1
	var key: String="%s:%s:%d:%s" % [rig.hash(),view,frame,walking]
	if frames.has(key): return frames[key]
	var parts: Dictionary=rig.views[view].parts
	var rest:=transforms(rig,view,0,false)
	var bounds:=Rect2()
	var first:=true
	for part_id in Rig.PARTS:
		for point in corners(parts[part_id],rest[part_id]):
			if first: bounds=Rect2(point,Vector2.ZERO); first=false
			else: bounds=bounds.expand(point)
	var phase_time:=float(frame)/8/float(rig.walk_cycles_per_second) if walking else 0.0
	var bones:=transforms(rig,view,phase_time,walking)
	# Keep artwork proportions, rather than stretching thin side views sideways.
	var scale_value:=minf(WORLD_SIZE.y/maxf(1,bounds.size.y),WORLD_SIZE.x/maxf(1,bounds.size.x))
	var anchor:=Vector2(rest.torso.origin.x,bounds.end.y)
	if bool(rig.get("seated",false)):
		scale_value=float(rig.get("standing_scale",scale_value))
		anchor=rest.torso.origin
	var output: Array=[]
	for part_id in Rig.PARTS:
		var part: Dictionary=parts[part_id]
		var quad:=corners(part,bones[part_id])
		for index in quad.size(): quad[index]=(quad[index]-anchor)*scale_value
		output.append({"part":part_id,"image":part.image,"region":part.get("region",[]),"points":quad,"z":part.z_index,"flip_h":part.flip_h})
	output.sort_custom(func(a,b):return a.z<b.z)
	var result: Dictionary={"pieces":output,"view":view}
	if frames.size()>=512: frames.clear()
	frames[key]=result
	return result

static func draw(canvas: CanvasItem, rig: Dictionary, directory: String, position: Vector2, facing: Vector2, walking: bool, time: float, scale_factor: float=1.0) -> bool:
	var requested: String=Rig.VIEWS[ActorArt.direction_column(facing)]
	var frame:=layout(rig,requested,time,walking)
	if frame.is_empty(): return false
	for piece in frame.pieces:
		var art:=texture(piece.image if str(piece.image).begins_with("res://") else directory.path_join(piece.image))
		if art==null: continue
		var points: PackedVector2Array=piece.points.duplicate()
		for index in points.size(): points[index]=position+points[index]*scale_factor
		var uv:=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
		if piece.flip_h:
			for index in uv.size(): uv[index].x=1-uv[index].x
		if piece.region.size()==4:
			var region:=Rect2(piece.region[0],piece.region[1],piece.region[2],piece.region[3])
			for index in uv.size(): uv[index]=(region.position+uv[index]*region.size)/Vector2(art.get_size())
		canvas.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,art)
	return true
