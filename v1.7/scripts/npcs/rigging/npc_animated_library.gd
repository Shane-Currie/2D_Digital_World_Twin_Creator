extends RefCounted

## Shared animated cutout art for human NPCs and the player's matching style.
## Files are genuinely separate body parts, never strips of the old bitmap.
const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")
const FILE_NAME: String="res://assets/actors/cutout_v16/library.json"
static var cache: Dictionary={}
static var seats: Dictionary={}
static var loaded:=false

static func for_actor(asset: String) -> Dictionary:
	if not loaded:
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(FILE_NAME)) if FileAccess.file_exists(FILE_NAME) else null
		cache=parsed.get("rigs",{}) if parsed is Dictionary else {}; loaded=true
	return cache.get(asset,{})

static func sitting_for_actor(asset: String) -> Dictionary:
	if seats.has(asset): return seats[asset]
	var standing:=for_actor(asset)
	if standing.is_empty(): return {}
	var value:=standing.duplicate(true); value.seated=true
	# Match standing scale, not a new tiny folded-leg drawing box.
	var art=load("res://scripts/npcs/rigging/npc_rig_art.gd")
	value.standing_scale=art.rest_scale(standing,"front")
	for view in Rig.VIEWS:
		var parts: Dictionary=value.views[view].parts
		for side in ["left","right"]:
			var thigh: Dictionary=parts[side+"_thigh"]; var shin: Dictionary=parts[side+"_shin"]
			if view in ["left","right"]:
				thigh.rotation_degrees=75 if view=="left" else -75
				shin.rotation_degrees=-75 if view=="left" else 75
				thigh.size[1]=24; shin.position[1]=20
			else:
				thigh.size[1]=22; shin.position[1]=18
				thigh.rotation_degrees=(-15 if side=="left" else 15) if view=="front" else (15 if side=="left" else -15)
			shin.size[1]=30
		if view in ["left","right"]:
			parts.left_forearm.rotation_degrees=60 if view=="left" else -60
			parts.right_forearm.rotation_degrees=60 if view=="left" else -60
		else:
			parts.left_forearm.rotation_degrees=20 if view=="front" else -20
			parts.right_forearm.rotation_degrees=-20 if view=="front" else 20
	seats[asset]=value
	return value

static func install(directory: String,id: String,asset: String) -> Dictionary:
	if id.is_empty() or id.length()>80 or id.begins_with("npc_") or not Array(id.split("")).all(func(c):return c in "abcdefghijklmnopqrstuvwxyz0123456789_-") or not FileAccess.file_exists(directory.path_join("town.json")):
		return {"ok":false,"message":"Choose an existing town and a safe custom character ID."}
	var rig:=for_actor(asset).duplicate(true)
	if rig.is_empty(): return {"ok":false,"message":"This Animated NPC template is unavailable."}
	var folder: String="assets/npcs/custom/"+id+"/parts"
	if DirAccess.make_dir_recursive_absolute(directory.path_join(folder))!=OK: return {"ok":false,"message":"Could not create the body-parts folder."}
	for view in Rig.VIEWS:
		for part in Rig.PARTS:
			var source: String=rig.views[view].parts[part].image
			var relative: String=folder.path_join(FileAccess.get_sha256(source)+".png")
			if not FileAccess.file_exists(directory.path_join(relative)) and DirAccess.copy_absolute(ProjectSettings.globalize_path(source),directory.path_join(relative))!=OK:
				return {"ok":false,"message":"Could not copy the separate body-part artwork."}
			rig.views[view].parts[part].image=relative
	return {"ok":true,"rig":rig}
