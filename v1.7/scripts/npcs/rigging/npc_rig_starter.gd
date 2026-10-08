extends RefCounted

const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")

## Code-native cutout artwork for a ready-to-test character, not sliced flat art.
## Each joint has overlapping coverage. Front/back are drawn separately.
static func svg(part: String,view: String,appearance: Dictionary={}) -> String:
	var shape: String=""
	var side:=view in ["left","right"]
	if part=="head":
		shape='<path d="M12 5 Q30 -1 34 17 L33 29 Q22 41 10 28 L8 15Z" fill="#b67d53"/><path d="M8 19 L7 10 Q10 0 25 2 Q36 3 35 14 L29 11 L25 8 L14 11 L13 20Z" fill="#39291f"/>'
		if view=="front": shape+='<path d="M15 21h3m8 0h3" stroke="#20262a" stroke-width="2"/><path d="M20 29q3 2 6 0" stroke="#6c4232" stroke-width="1.5" fill="none"/>'
		elif side:
			shape+='<path d="M10 19 L5 23 L11 25" fill="#b67d53"/><path d="M11 18h3" stroke="#20262a" stroke-width="2"/>'
		else: shape+='<path d="M10 15 Q22 24 34 15 L32 29 Q22 34 11 28Z" fill="#39291f"/>'
	elif part=="torso":
		shape='<path d="M7 3 Q21 -1 35 3 L39 16 L34 57 L8 57 L3 16Z" fill="#356c9b"/><path d="M11 4 L21 14 L31 4 L28 49 L14 49Z" fill="#e7e0c8"/><path d="M21 14v42M7 49h27" stroke="#24425d" fill="none" stroke-width="2"/>'
		if view=="back": shape='<path d="M7 3 Q21 -1 35 3 L39 16 L34 57 L8 57 L3 16Z" fill="#356c9b"/><path d="M10 7 Q21 14 32 7 M8 49h26" stroke="#24425d" fill="none" stroke-width="2"/>'
	elif part.ends_with("upper_arm"):
		shape='<path d="M5 2 Q10 0 14 5 L14 29 Q9 34 3 29 L2 7Z" fill="#356c9b"/><path d="M4 26h9" stroke="#24425d" stroke-width="2"/>'
	elif part.ends_with("forearm"):
		shape='<path d="M4 2 Q9 0 13 3 L13 24 L3 24Z" fill="#356c9b"/><path d="M3 23h10v7Q8 35 3 30Z" fill="#b67d53"/><path d="M3 22h10" stroke="#24425d" stroke-width="2"/>'
	elif part.ends_with("thigh"):
		shape='<path d="M3 2 Q9 0 16 2 L15 34 L3 34Z" fill="#435364"/><path d="M5 5v24" stroke="#657485" stroke-width="2"/>'
	else:
		shape='<path d="M4 2h12v30H4Z" fill="#435364"/><path d="M4 29h12l3 7v4H2v-8Z" fill="#322e29"/><path d="M3 37h14" stroke="#857b64" stroke-width="2"/>'
	var woman: bool=appearance.get("gender","man")=="woman"
	var older: bool=appearance.get("age_group","adult")=="older"
	var skin: String=str(appearance.get("skin","#b67d53"))
	var hair: String=str(appearance.get("hair","#39291f"))
	if part=="head" and view=="back" and not woman:
		shape='<path d="M14 28h15v9H14Z" fill="#b67d53"/><path d="M8 15 Q8 2 22 2 Q36 2 35 17 L33 30 Q22 36 10 29Z" fill="#39291f"/><path d="M12 9 Q17 4 27 7" stroke="#756650" fill="none"/>'
	if part=="head" and woman:
		var long_hair: String='<path d="M8 16 Q5 2 22 1 Q39 2 36 20 L38 43 L31 47 L28 25 L14 25 L13 47 L5 43Z" fill="%s"/>' % hair
		shape=long_hair+shape
		if view=="back": shape='<path d="M8 16 Q5 2 22 1 Q39 2 36 20 L38 43 Q22 49 5 43Z" fill="%s"/><path d="M10 13 Q15 4 24 5" fill="none" stroke="#756650"/>' % hair
		elif view=="front": shape+='<path d="M10 13 Q20 6 29 12 L34 18 L35 8 Q23 -1 11 7Z" fill="%s"/>' % hair
	if part=="head" and older and view!="back":
		shape+='<path d="M16 16h7M17 25l-2 2M27 25l2 2" fill="none" stroke="#7b6356" stroke-width=".8"/>'
	if part=="torso" and woman:
		shape=shape.replace("M7 3 Q21 -1 35 3 L39 16 L34 57 L8 57 L3 16Z","M7 3 Q21 -1 35 3 L38 17 L31 36 L34 57 L8 57 L11 36 L4 17Z")
	if bool(appearance.get("glasses",false)) and part=="head" and view=="front":
		shape+='<path d="M13 18h8v7h-8Zm11 0h8v7h-8ZM21 21h3" fill="#232a29" stroke="#101918"/>'
	shape=shape.replace("#b67d53",skin).replace("#39291f",hair)
	shape=shape.replace("#356c9b",str(appearance.get("jacket","#356c9b"))).replace("#24425d",str(appearance.get("jacket_shadow","#24425d")))
	shape=shape.replace("#435364",str(appearance.get("trousers","#435364"))).replace("#657485",str(appearance.get("trouser_highlight","#657485")))
	var size: Array=Rig.template(view).parts[part].size
	var source_size:=Vector2(42,60) if part=="torso" else (Vector2(42,42) if part=="head" else (Vector2(18,36) if part.ends_with("thigh") else (Vector2(20,42) if part.ends_with("shin") else Vector2(16,34))))
	if part=="head" and woman: source_size.y=52; size=[42 if not side else 34,52]
	var mirror: String='translate(%s 0) scale(-1 1)' % source_size.x if view=="right" else ""
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s"><g transform="%s" stroke="#26332f" stroke-width="1.2" stroke-linejoin="round">%s</g></svg>' % [size[0]*4,size[1]*4,source_size.x,source_size.y,mirror,shape]

static func install(directory: String,id: String) -> Dictionary:
	var rig:=Rig.new_rig()
	var relative: String="assets/npcs/custom/"+id+"/starter"
	if DirAccess.make_dir_recursive_absolute(directory.path_join(relative))!=OK: return {"ok":false,"message":"Could not create the body-parts artwork folder."}
	for view in Rig.VIEWS:
		for part in Rig.PARTS:
			var image:=Image.new()
			if image.load_svg_from_string(svg(part,view))!=OK: return {"ok":false,"message":"Could not draw the starter body part."}
			var path: String=relative.path_join(view+"_"+part+".png")
			# Starter is only installed for a new stable ID; never replace uploads.
			if FileAccess.file_exists(directory.path_join(path)): return {"ok":false,"message":"Starter files already exist; create a new character rather than overwriting them."}
			if image.save_png(directory.path_join(path))!=OK: return {"ok":false,"message":"Could not save starter artwork."}
			rig.views[view].parts[part].image=path
	return {"ok":true,"rig":rig}
