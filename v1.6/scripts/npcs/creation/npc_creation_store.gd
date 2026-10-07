class_name NpcCreationStore
extends RefCounted

## Data-only character artwork. Human appearance never determines personality.
const FILE_NAME := "npc_creations.json"
const AGES := {"young": "Young adult", "adult": "Middle aged", "older": "Elderly"}
const TONES := ["light", "medium", "dark"]
const GENDERS := ["man", "woman"]
const POSES := ["idle", "walk", "sit"]
const DIRECTIONS := ["front", "left", "right", "back"]
const MORPHEUS_PATH := "res://assets/actors/custom/morpheus_v16.png"
const Rig = preload("res://scripts/npcs/rigging/npc_rig_data.gd")
static var checked_images: Dictionary = {}

static func image_valid(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>20*1024*1024: return false
	var key := "%s:%d:%d" % [path,FileAccess.get_modified_time(path),file.get_length()]
	if checked_images.has(key): return bool(checked_images[key])
	var image := Image.load_from_file(path)
	var valid := image!=null and not image.is_empty() and image.get_width()<=4096 and image.get_height()<=4096
	if checked_images.size()>512: checked_images.clear()
	checked_images[key]=valid
	return valid

static func empty_data() -> Dictionary:
	return {"schema_version": 1, "kind": "npc_creations", "creations": []}

static func built_ins() -> Array:
	var result: Array = []
	for tone in TONES:
		for gender in GENDERS:
			for age in AGES:
				result.append({"id":"npc_%s_%s_%s" % [tone,gender,age], "name":"%s · %s · %s" % [tone.capitalize(),gender.capitalize(),AGES[age]], "gender":gender,"age_group":age,"skin_tone_group":tone})
	return result

static func morpheus() -> Dictionary:
	return {"id":"morpheus", "name":"Morpheus", "gender":"man", "age_group":"adult", "skin_tone_group":"dark", "poses":{}, "seat_anchor_y":.58}

static func choices(data: Dictionary) -> Array:
	var items: Array = data.get("creations", []).duplicate(true)
	if FileAccess.file_exists(MORPHEUS_PATH) and not items.any(func(item): return str(item.get("id",""))=="morpheus"): items.push_front(morpheus())
	return items

static func find(data: Dictionary, id: String) -> Dictionary:
	for item in choices(data):
		if str(item.id) == id: return item
	return {}

static func safe_id(value: String) -> bool:
	if value.is_empty() or value.length()>80: return false
	for letter in value:
		if not (letter in "abcdefghijklmnopqrstuvwxyz0123456789_-"): return false
	return true

static func safe_path(value: String) -> bool:
	return value.begins_with("assets/npcs/") and not value.contains("..") and not value.contains("\\") and value.get_extension().to_lower() in ["png","webp","jpg","jpeg"]

static func validate(data: Dictionary, directory: String = "") -> Dictionary:
	var errors: Array[String] = []
	if data.get("schema_version",0)!=1 or data.get("kind", "")!="npc_creations" or not data.get("creations",null) is Array:
		return {"ok":false,"message":"Unsupported NPC artwork catalogue."}
	if data.creations.size()>100: errors.append("Use at most 100 custom NPC creations per town.")
	var ids: Dictionary = {}
	for item in data.creations:
		if not item is Dictionary: errors.append("Invalid NPC creation record."); continue
		var id := str(item.get("id",""))
		if not safe_id(id) or id.begins_with("npc_") or ids.has(id): errors.append("NPC creation IDs must be unique safe names.")
		ids[id]=true
		if str(item.get("name","")).strip_edges().is_empty() or str(item.get("name","")).length()>80: errors.append("Give each creation a name (up to 80 characters).")
		if item.get("gender","") not in GENDERS or not AGES.has(item.get("age_group","")) or item.get("skin_tone_group","") not in TONES: errors.append("Choose man/woman, age and skin pigmentation for each human creation.")
		var poses = item.get("poses",{})
		if not poses is Dictionary: errors.append("Invalid pose list."); continue
		var idle = poses.get("idle",{})
		var front = idle.get("front",[]) if idle is Dictionary else []
		var rig_enabled:=false
		if item.has("rig"):
			var rig_check:=Rig.validate(item.rig)
			if not rig_check.ok: errors.append(rig_check.message)
			else:
				rig_enabled=bool(item.rig.enabled)
				for view in item.rig.views.values():
					for part in view.parts.values():
						if not part.image.is_empty() and not directory.is_empty() and not preload("res://scripts/npcs/rigging/npc_rig_import.gd").image_valid(directory.path_join(part.image),part.get("region",[])): errors.append("Missing or invalid body-part image: "+part.image)
		if not rig_enabled and (not front is Array or front.is_empty()) and not (id=="morpheus" and FileAccess.file_exists(MORPHEUS_PATH)): errors.append("Upload at least one front standing image, or complete a Front body-parts skeleton.")
		var anchor = item.get("seat_anchor_y",.58)
		if not (anchor is float or anchor is int) or not is_finite(float(anchor)) or float(anchor)<.35 or float(anchor)>.75: errors.append("Sitting hip anchor must be between 35% and 75%.")
		for pose in poses:
			if pose not in POSES or not poses[pose] is Dictionary: errors.append("Unsupported NPC pose."); continue
			for direction in poses[pose]:
				var paths = poses[pose][direction]
				if direction not in DIRECTIONS or not paths is Array or paths.size()>8: errors.append("Use up to eight frames per direction/pose."); continue
				for path in paths:
					if not safe_path(str(path)): errors.append("NPC images must be copied into assets/npcs.")
					elif not directory.is_empty() and not FileAccess.file_exists(directory.path_join(path)): errors.append("Missing NPC image: " + str(path))
					elif not directory.is_empty() and not image_valid(directory.path_join(path)): errors.append("NPC images must decode correctly and fit the 20 MB / 4096-pixel limits.")
	return {"ok":errors.is_empty(), "message":"NPC artwork is valid." if errors.is_empty() else errors[0], "errors":errors}

static func load_from_town(directory: String) -> Dictionary:
	var path := directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path): return {"ok":true,"data":empty_data()}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return {"ok":false,"message":"Could not read NPC creations."}
	var checked := validate(data,directory)
	if checked.ok: checked["data"]=data
	return checked

static func save_to_town(directory: String, data: Dictionary) -> Dictionary:
	var checked := validate(data,directory)
	if not checked.ok: return checked
	DirAccess.make_dir_recursive_absolute(directory.path_join("data"))
	var file := FileAccess.open(directory.path_join("data").path_join(FILE_NAME),FileAccess.WRITE)
	if file==null: return {"ok":false,"message":"Could not save NPC creations."}
	file.store_string(JSON.stringify(data,"\t")); file.flush()
	return {"ok":file.get_error()==OK,"message":"NPC creations saved.","data":data}

static func import_frames(directory: String, data: Dictionary, id: String, pose: String, direction: String, paths: PackedStringArray) -> Dictionary:
	if not safe_id(id) or pose not in POSES or direction not in DIRECTIONS or paths.is_empty() or paths.size()>8:
		return {"ok":false,"message":"Choose a creation and 1–8 images for this pose/view."}
	# Validate the entire batch before copying anything or changing the draft.
	for path in paths:
		if path.get_extension().to_lower() not in ["png","webp","jpg","jpeg"]: return {"ok":false,"message":"Choose PNG, WebP or JPEG images, not scripts."}
		if not image_valid(path): return {"ok":false,"message":"Choose readable NPC images within 20 MB and 4096 pixels per side."}
	var ordered := paths.duplicate(); ordered.sort()
	var imported: Array = []
	var relative := "assets/npcs/custom/" + id
	if DirAccess.make_dir_recursive_absolute(directory.path_join(relative))!=OK: return {"ok":false,"message":"Could not create the town's NPC image folder."}
	for path in ordered:
		var target := relative.path_join(FileAccess.get_sha256(path)+"."+path.get_extension().to_lower())
		if not FileAccess.file_exists(directory.path_join(target)) and DirAccess.copy_absolute(path,directory.path_join(target))!=OK: return {"ok":false,"message":"Could not copy image; current frames were kept."}
		imported.append(target)
	var updated := data.duplicate(true)
	for item in updated.creations:
		if str(item.id)!=id: continue
		if not item.poses.has(pose): item.poses[pose]={}
		item.poses[pose][direction]=imported
		return {"ok":true,"data":updated,"message":"%d frames copied in filename order. Top Save keeps the creation." % imported.size()}
	return {"ok":false,"message":"Select a custom creation first."}

static func appearance(item: Dictionary, custom: bool) -> Dictionary:
	return {"mode":"custom_creation" if custom else "built_in", "animation_type":"animated", "seed":"creator", "gender":item.gender,"age_group":item.age_group,"skin_tone_group":item.skin_tone_group,"npc_asset":"creation_"+str(item.id) if custom else str(item.id),"template_id":str(item.id) if custom else "","custom_artwork_path":""}

static func references_valid(npcs: Dictionary, data: Dictionary) -> Dictionary:
	for npc in npcs.get("npcs",[]):
		var appearance_data: Dictionary = npc.get("appearance",{})
		if appearance_data.get("mode","")!="custom_creation": continue
		var item := find(data,str(appearance_data.get("template_id","")))
		if item.is_empty(): return {"ok":false,"message":"Missing custom artwork for " + str(npc.get("display_name",npc.id))}
		for field in ["gender","age_group","skin_tone_group"]:
			if item[field]!=appearance_data.get(field,""): return {"ok":false,"message":"Custom artwork attributes changed. Reapply the creation to " + str(npc.display_name)}
	return {"ok":true}
