extends RefCounted

const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")
static var checked_images: Dictionary={}

static func image_valid(path: String,region: Array=[]) -> bool:
	if path.get_extension().to_lower() not in ["png","webp"]: return false
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>4*1024*1024: return false
	var key: String="%s:%d:%d" % [path,FileAccess.get_modified_time(path),file.get_length()]
	# Decode a shared atlas once, not separately for every part/view/identity.
	if not checked_images.has(key):
		var image:=Image.load_from_file(path)
		var metadata: Dictionary={"valid":image!=null and not image.is_empty()}
		if metadata.valid:
			metadata.size=image.get_size(); metadata.valid=image.get_used_rect().has_area()
		if checked_images.size()>=512: checked_images.clear()
		checked_images[key]=metadata
	var metadata: Dictionary=checked_images[key]
	if not metadata.valid: return false
	var image_size: Vector2i=metadata.size
	var limit:=4096 if region.size()==4 else 1024
	var valid: bool=image_size.x<=limit and image_size.y<=limit
	if valid and region.size()==4:
		valid=Rig.numeric(region[0],0,4096) and Rig.numeric(region[1],0,4096) and Rig.numeric(region[2],.1,4096) and Rig.numeric(region[3],.1,4096) and float(region[0])+float(region[2])<=image_size.x+.01 and float(region[1])+float(region[3])<=image_size.y+.01
	elif not region.is_empty(): valid=false
	return valid

static func import_parts(directory: String,id: String,rig: Dictionary,view: String,files: PackedStringArray,selected_part: String="") -> Dictionary:
	if id.is_empty() or id.length()>80 or id.begins_with("npc_") or not Array(id.split("")).all(func(letter):return letter in "abcdefghijklmnopqrstuvwxyz0123456789_-") or view not in Rig.VIEWS or files.is_empty() or files.size()>10:
		return {"ok":false,"message":"Choose a custom character, view and 1–10 body-part images."}
	var assignments: Dictionary={}
	for path in files:
		var part:=selected_part if files.size()==1 and selected_part in Rig.PARTS else path.get_file().get_basename().to_lower().trim_prefix(view+"_")
		if part not in Rig.PARTS or assignments.has(part): return {"ok":false,"message":"Use unique filenames such as front_head.png, torso.png, left_upper_arm.png, left_forearm.png, left_thigh.png and left_shin.png (right limbs likewise)."}
		if not image_valid(path): return {"ok":false,"message":"Body parts need readable PNG/WebP images: at most 1024 pixels per side and 4 MB each. Transparent backgrounds are recommended."}
		assignments[part]=path
	var relative: String="assets/npcs/custom/"+id+"/parts"
	if DirAccess.make_dir_recursive_absolute(directory.path_join(relative))!=OK: return {"ok":false,"message":"Could not create the body-parts folder."}
	var updated:=rig.duplicate(true)
	if not updated.views.has(view): updated.views[view]=Rig.template(view)
	for part in assignments:
		var source: String=assignments[part]
		var target: String=relative.path_join(FileAccess.get_sha256(source)+"."+source.get_extension().to_lower())
		if not FileAccess.file_exists(directory.path_join(target)) and DirAccess.copy_absolute(source,directory.path_join(target))!=OK:
			return {"ok":false,"message":"Could not copy artwork. Previous part assignments were kept."}
		updated.views[view].parts[part].image=target
		updated.views[view].parts[part].erase("region")
	return {"ok":true,"rig":updated,"message":"%d parts copied. Top Save keeps your character." % assignments.size()}
