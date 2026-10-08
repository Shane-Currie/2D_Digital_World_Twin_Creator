extends RefCounted

## Optional data-only texture edits. These never change building geometry.
const TARGETS := ["roof", "walls", "front", "left"]
const MATERIALS := ["automatic", "brick", "concrete", "glass"]
const LIMITS := {"scale_percent": [50.0,300.0,100.0], "rotation_degrees": [-180.0,180.0,0.0], "offset_x_percent": [-100.0,100.0,0.0], "offset_y_percent": [-100.0,100.0,0.0]}

static func facade_key(wall: Dictionary) -> String:
	return "left" if wall.outward.x < -absf(wall.outward.y) else "front"

static func alignment(record: Dictionary, target: String) -> Dictionary:
	if target=="roof": return record.get("exterior",record.get("roof_alignment",{}))
	var fallback: Dictionary = record.get("wall_alignment",{})
	return record.get("facades",{}).get(target,{}).get("alignment",fallback) if target in ["front","left"] else fallback

static func wall_image(record: Dictionary, target: String) -> Dictionary:
	var facade: Dictionary = record.get("facades",{}).get(target,{})
	if facade.has("wall"): return facade.wall
	return {} if facade.get("material","automatic")!="automatic" else record.get("wall",{})

static func material(record: Dictionary, target: String) -> String:
	var fallback := str(record.get("wall_material","automatic"))
	var selected := str(record.get("facades",{}).get(target,{}).get("material","automatic"))
	return fallback if selected=="automatic" else selected

static func aligned_uv(uv: Vector2, values: Dictionary, centre: Vector2 = Vector2(0.5,0.5)) -> Vector2:
	var scale_value := maxf(0.5,float(values.get("scale_percent",100.0))/100.0)
	var offset := Vector2(float(values.get("offset_x_percent",0.0)),float(values.get("offset_y_percent",0.0)))/100.0
	return (uv-centre-offset).rotated(-deg_to_rad(float(values.get("rotation_degrees",0.0))))/scale_value+centre

static func valid_alignment(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in LIMITS:
		var number: Variant = value.get(key,LIMITS[key][2])
		if (not number is float and not number is int) or not is_finite(float(number)) or number<LIMITS[key][0] or number>LIMITS[key][1]: return false
	return true

static func set_alignment(data: Dictionary, id: String, target: String, values: Dictionary) -> Dictionary:
	if id.is_empty() or target not in TARGETS or not valid_alignment(values): return {"ok":false,"message":"Select an artwork surface and use valid alignment values."}
	var updated := data.duplicate(true)
	var record: Dictionary = updated.buildings.get(id,{"feature_id":id}).duplicate(true)
	var saved: Dictionary = {}
	for key in LIMITS: saved[key]=float(values.get(key,LIMITS[key][2]))
	if target=="roof" and record.has("exterior"):
		record.exterior.merge(saved,true) # Preserve legacy custom-image transforms.
	elif target=="roof": record["roof_alignment"]=saved
	elif target=="walls": record["wall_alignment"]=saved
	else:
		var facades: Dictionary = record.get("facades",{}).duplicate(true)
		var facade: Dictionary = facades.get(target,{}).duplicate(true)
		facade["alignment"]=saved
		facades[target]=facade
		record["facades"]=facades
	updated.buildings[id]=record
	return {"ok":true,"data":updated}

static func set_material(data: Dictionary, id: String, target: String, value: String) -> Dictionary:
	if id.is_empty() or target not in ["walls","front","left"] or value not in MATERIALS: return {"ok":false,"message":"Choose a wall surface and supported material."}
	var updated := data.duplicate(true)
	var record: Dictionary = updated.buildings.get(id,{"feature_id":id}).duplicate(true)
	if target=="walls":
		record["wall_material"]=value
		if value!="automatic": record.erase("wall")
	else:
		var facades: Dictionary = record.get("facades",{}).duplicate(true)
		var facade: Dictionary = facades.get(target,{}).duplicate(true)
		facade["material"]=value
		if value!="automatic": facade.erase("wall")
		facades[target]=facade
		record["facades"]=facades
	updated.buildings[id]=record
	return {"ok":true,"data":updated}

static func remove_override(data: Dictionary, id: String, target: String) -> Dictionary:
	var updated := data.duplicate(true)
	if not updated.buildings.has(id): return updated
	var record: Dictionary = updated.buildings[id]
	if target in ["front","left"]:
		var facades: Dictionary = record.get("facades",{})
		facades.erase(target)
		if facades.is_empty(): record.erase("facades")
	elif target=="walls":
		for key in ["wall","wall_material","wall_alignment"]: record.erase(key)
	else:
		record.erase("exterior")
		record.erase("roof_alignment")
	return updated
