extends RefCounted

const Art = preload("res://scripts/runtime/runtime_actor_art.gd")
const Store = preload("res://scripts/npcs/creation/npc_creation_store.gd")
const RigArt = preload("res://scripts/npcs/rigging/npc_rig_art.gd")
const SITTING_PATH := "res://assets/actors/custom/generic_seated_v16.png"
# These complete sprites have uneven row spacing; equal-height cuts can include
# the next character's head. Keep the artwork unchanged and crop its actual rows.
const SITTING_ROWS := {
	"front": [0,262,516,759,1019,1265,1536],
	"left": [0,269,520,769,1026,1276,1536],
	"right": [0,270,521,769,1023,1271,1536],
	"back": [0,261,510,758,1009,1263,1536]
}
static var cache: Dictionary = {}
static var standing_body_scales: Dictionary={}

static func image_frame(path: String, column := 0, row := 0, columns := 1, rows := 1) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	if not cache.has(path):
		var image := Image.load_from_file(path)
		if image==null or image.is_empty(): cache[path]={}; return {}
		cache[path]={"image":image,"texture":ImageTexture.create_from_image(image),"regions":{}}
	var sheet: Dictionary = cache[path]
	if sheet.is_empty(): return {}
	var key := "%d:%d:%d:%d" % [column,row,columns,rows]
	if not sheet.regions.has(key):
		if path.begins_with("res://assets/actors/custom/generic_seated") and columns==3 and rows==6:
			sheet.regions[key]=seated_region(sheet.image,path,column,row)
		else: sheet.regions[key]=Art._directional_cell_region(sheet.image,column,row,columns,rows)
		# Faint transparent padding is not part of the character's body. It was
		# shrinking the seated player when fitted to the gameplay drawing box.
		var region: Rect2i=sheet.regions[key]
		if region.has_area():
			var body:=Art._subject_region(sheet.image.get_region(region),"npc_pose")
			sheet.regions[key]=Rect2i(region.position+body.position,body.size)
	return {"texture":sheet.texture,"region":Rect2(sheet.regions[key]),"pose":true}

static func seated_region(image: Image, path: String, column: int, row: int) -> Rect2i:
	var view := "front"
	for direction in ["left","right","back"]:
		if path.contains("seated_%s_" % direction): view=direction
	var cuts: Array = SITTING_ROWS[view]
	if view=="right" and column==0: cuts=[0,269,519,770,1022,1271,1536]
	var x0 := floori(float(column)*image.get_width()/3)
	var x1 := floori(float(column+1)*image.get_width()/3)
	var y0 := floori(float(cuts[row])*image.get_height()/1536)
	var y1 := floori(float(cuts[row+1])*image.get_height()/1536)
	var cell := Rect2i(x0,y0,x1-x0,y1-y0)
	var used := image.get_region(cell).get_used_rect()
	if not used.has_area(): return Rect2i()
	var start := Vector2i(maxi(0,used.position.x-2),maxi(0,used.position.y-2))
	var end := Vector2i(mini(cell.size.x,used.end.x+2),mini(cell.size.y,used.end.y+2))
	return Rect2i(cell.position+start,end-start)

static func artwork(appearance: Dictionary, catalog: Dictionary, directory: String, facing: Vector2, pose: String, time: float) -> Dictionary:
	var asset := str(appearance.get("npc_asset","npc_medium_man_adult"))
	if appearance.get("mode","")!="custom_creation":
		var library=preload("res://scripts/npcs/rigging/npc_animated_library.gd")
		var rig: Dictionary=library.sitting_for_actor(asset) if pose=="sit" else library.for_actor(asset)
		if not rig.is_empty(): return {"rig":rig,"pose":true}
	if asset == "player":
		if pose == "sit": return image_frame("res://assets/actors/custom/player_seated_v16.png",Art.direction_column(facing),0,4,1)
		return Art.directional_sprite("player",facing,int(time*8)%4 if pose=="walk" else 0)
	if appearance.get("mode","")=="custom_creation":
		var item := Store.find(catalog,str(appearance.get("template_id","")))
		if item.is_empty(): return {}
		if pose!="sit" and bool(item.get("rig",{}).get("enabled",false)):
			return {"rig":item.rig,"pose":true}
		if item.id=="morpheus" and item.get("poses",{}).get(pose,{}).get(Store.DIRECTIONS[Art.direction_column(facing)],[]).is_empty():
			var library=preload("res://scripts/npcs/rigging/npc_animated_library.gd")
			var built_in: Dictionary=library.sitting_for_actor("morpheus") if pose=="sit" else library.for_actor("morpheus")
			if not built_in.is_empty(): return {"rig":built_in,"pose":true}
			var row := 4 if pose=="sit" else (1+int(time*8)%3 if pose=="walk" else 0)
			return image_frame(Store.MORPHEUS_PATH,Art.direction_column(facing),row,4,5)
		var direction: String = Store.DIRECTIONS[Art.direction_column(facing)]
		var frames: Array = item.get("poses",{}).get(pose,{}).get(direction,[])
		var has_pose := not frames.is_empty()
		if frames.is_empty(): frames=item.get("poses",{}).get("idle",{}).get(direction,[])
		if frames.is_empty(): frames=item.get("poses",{}).get("idle",{}).get("front",[])
		if frames.is_empty():
			return {"rig":item.rig,"pose":false} if bool(item.get("rig",{}).get("enabled",false)) else {}
		var path := str(frames[int(time*8)%frames.size()] if pose=="walk" else frames[0])
		if not Store.safe_path(path): return {}
		var sprite := image_frame(directory.path_join(path))
		if sprite.is_empty(): return {}
		sprite["pose"]=has_pose
		return sprite
	if pose=="sit" and FileAccess.file_exists(SITTING_PATH):
		var tone := Store.TONES.find(str(appearance.get("skin_tone_group","medium")))
		var gender := Store.GENDERS.find(str(appearance.get("gender","man")))
		var age: int = Art.AGE_ROWS.get(str(appearance.get("age_group","adult")),1)
		var view: String = Store.DIRECTIONS[Art.direction_column(facing)]
		var seated_path := SITTING_PATH if view=="front" else "res://assets/actors/custom/generic_seated_%s_v16.png" % view
		if FileAccess.file_exists(seated_path): return image_frame(seated_path,age,maxi(0,tone)*2+maxi(0,gender),3,6)
	return Art.directional_sprite(asset,facing)

static func sitting_rect(appearance: Dictionary, catalog: Dictionary, facing:=Vector2.DOWN, directory: String="") -> Rect2:
	var item := Store.find(catalog,str(appearance.get("template_id","")))
	var anchor := clampf(float(item.get("seat_anchor_y",.58)),.35,.75)
	# The approved seated player's arms are closer to the torso. Calibrate its
	# head to standing scale, with shorter folded legs rather than a tiny body.
	var is_player:=str(appearance.get("npc_asset",""))=="player"
	var size := Art.GROUND_CHARACTER_DRAW_SIZE*Vector2(.86,.84) if is_player else Art.GROUND_CHARACTER_DRAW_SIZE*Vector2(1,.76)
	var reference_appearance:=appearance.duplicate()
	reference_appearance.animation_type="static"
	var standing:=artwork(reference_appearance,catalog,directory,facing,"idle",0)
	if standing.has("region"):
		var reference: Rect2i=standing.region
		var key: String="%d:%s" % [standing.texture.get_instance_id(),str(reference)]
		if not standing_body_scales.has(key):
			var body:=Art._subject_region(standing.texture.get_image().get_region(reference),"npc_pose")
			standing_body_scales[key]=Vector2(body.size)/Vector2(reference.size)
		# Standing atlases still have faint padding. Match their visible body,
		# not their transparent rectangle, without changing standing-world scale.
		size*=Vector2(standing_body_scales[key])
	return Rect2(Vector2(-size.x*.5,-size.y*anchor),size)

static func draw_actor(canvas: CanvasItem, appearance: Dictionary, catalog: Dictionary, directory: String, position: Vector2, facing: Vector2, pose: String, time: float, scale_factor := 1.0) -> void:
	var sprite := artwork(appearance,catalog,directory,facing,pose,time)
	if sprite.is_empty(): return
	if sprite.has("rig"):
		RigArt.draw(canvas,sprite.rig,directory,position,facing,pose=="walk",time,scale_factor)
		return
	# Never fake a ground-sit with standing art. Missing sitting views stay standing.
	var rect := sitting_rect(appearance,catalog,facing,directory) if pose=="sit" and bool(sprite.get("pose",false)) else Art.grounded_character_rect()
	rect.position=position+rect.position*scale_factor; rect.size*=scale_factor
	if pose!="walk" or bool(sprite.get("pose",false)):
		canvas.draw_texture_rect_region(sprite.texture,rect,sprite.region); return
	# Articulated steps reuse the original face/torso unchanged, not random face generation.
	# Two leg strips swing in opposite phase; feet stop immediately when standing.
	var region: Rect2 = sprite.region
	var leg_top := .69
	var stride := sin(time*12)*.7*scale_factor
	for side in 2:
		var source := Rect2(region.position+Vector2(region.size.x*.5*side,region.size.y*leg_top),region.size*Vector2(.5,1-leg_top))
		var target := Rect2(rect.position+Vector2(rect.size.x*.5*side,rect.size.y*leg_top),rect.size*Vector2(.5,1-leg_top))
		target.position+=Vector2(stride if absf(facing.x)>absf(facing.y) else 0,stride*.7)*(1 if side==0 else -1)
		canvas.draw_texture_rect_region(sprite.texture,target,source)
	canvas.draw_texture_rect_region(sprite.texture,Rect2(rect.position,rect.size*Vector2(1,leg_top+.015)),Rect2(region.position,region.size*Vector2(1,leg_top+.015)))
