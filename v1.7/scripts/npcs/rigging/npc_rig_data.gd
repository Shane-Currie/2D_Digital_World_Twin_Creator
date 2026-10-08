extends RefCounted

## A shared human bone hierarchy, saved as data, not executable content.
const PARTS := ["torso","head","left_upper_arm","left_forearm","right_upper_arm","right_forearm","left_thigh","left_shin","right_thigh","right_shin"]
const LABELS := ["Torso","Head","Left upper arm","Left forearm + hand","Right upper arm","Right forearm + hand","Left thigh","Left shin + foot","Right thigh","Right shin + foot"]
const VIEWS := ["front","left","right","back"]
const PARENTS := {"head":"torso","left_upper_arm":"torso","left_forearm":"left_upper_arm","right_upper_arm":"torso","right_forearm":"right_upper_arm","left_thigh":"torso","left_shin":"left_thigh","right_thigh":"torso","right_shin":"right_thigh"}

static func template(view: String="front") -> Dictionary:
	var side:=view in ["left","right"]
	var sign_x: float=-1 if view=="back" else 1
	var parts: Dictionary={}
	for key in PARTS:
		var position:=Vector2.ZERO
		var size:=Vector2(16,34)
		var pivot:=Vector2(.5,.08)
		var order:=2
		match key:
			"torso": position=Vector2(50,110); size=Vector2(30 if side else 42,60); pivot=Vector2(.5,1); order=5
			"head": position=Vector2(0,-52); size=Vector2(34 if side else 42,42); pivot=Vector2(.5,.88); order=9
			"left_upper_arm": position=Vector2(3 if side else 22*sign_x,-52); order=7 if view!="right" else 0
			"right_upper_arm": position=Vector2(-3 if side else -22*sign_x,-52); order=7 if view=="right" else 0
			"left_forearm": position=Vector2(0,28); order=8 if view!="right" else 1
			"right_forearm": position=Vector2(0,28); order=8 if view=="right" else 1
			"left_thigh": position=Vector2(3 if side else 10*sign_x,0); size=Vector2(18,36); order=3
			"right_thigh": position=Vector2(-3 if side else -10*sign_x,0); size=Vector2(18,36); order=2
			"left_shin": position=Vector2(0,30); size=Vector2(20,42); order=4
			"right_shin": position=Vector2(0,30); size=Vector2(20,42); order=3
		parts[key]={"image":"","position":[position.x,position.y],"size":[size.x,size.y],"pivot":[pivot.x,pivot.y],"rotation_degrees":0.0,"z_index":order,"flip_h":false}
	return {"parts":parts}

static func new_rig() -> Dictionary:
	var views: Dictionary={}
	for view in VIEWS: views[view]=template(view)
	return {"version":1,"enabled":true,"walk_cycles_per_second":1.4,"stride_degrees":22.0,"views":views}

static func count_parts(rig: Dictionary, view: String) -> int:
	var count:=0
	var parts: Dictionary=rig.get("views",{}).get(view,{}).get("parts",{})
	for key in PARTS:
		if not str(parts.get(key,{}).get("image","")).is_empty(): count+=1
	return count

static func complete(rig: Dictionary, view: String) -> bool:
	return count_parts(rig,view)==PARTS.size()

static func safe_path(value: Variant) -> bool:
	return value is String and value.begins_with("assets/npcs/") and not value.contains("..") and not value.contains("\\") and value.get_extension().to_lower() in ["png","webp"]

static func numeric(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum

static func pair(value: Variant, minimum: float, maximum: float) -> bool:
	return value is Array and value.size()==2 and numeric(value[0],minimum,maximum) and numeric(value[1],minimum,maximum)

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary: return {"ok":false,"message":"Invalid body-parts skeleton."}
	if value.get("version",0)!=1 or not value.get("enabled",null) is bool or not value.get("views",null) is Dictionary:
		return {"ok":false,"message":"Unsupported body-parts skeleton."}
	if not numeric(value.get("walk_cycles_per_second",null),.5,3) or not numeric(value.get("stride_degrees",null),0,40):
		return {"ok":false,"message":"Walking speed must be 0.5–3 cycles/sec and stride 0–40 degrees."}
	for view in value.views:
		if view not in VIEWS or not value.views[view] is Dictionary or not value.views[view].get("parts",null) is Dictionary:
			return {"ok":false,"message":"Choose Front, Left, Right or Back for body-part artwork."}
		if not PARTS.all(func(key):return value.views[view].parts.has(key)):
			return {"ok":false,"message":"Each saved view needs all ten joint records; unused images may be blank."}
		for key in value.views[view].parts:
			var part=value.views[view].parts[key]
			if key not in PARTS or not part is Dictionary: return {"ok":false,"message":"Unknown body part."}
			if not part.get("image",null) is String or (not part.image.is_empty() and not safe_path(part.image)):
				return {"ok":false,"message":"Body parts must use copied PNG/WebP images under assets/npcs."}
			if not pair(part.get("position",null),-200,200) or not pair(part.get("size",null),1,120) or not pair(part.get("pivot",null),0,1):
				return {"ok":false,"message":"Body-part position, size or image pivot is outside the supported range."}
			if part.has("region"):
				var region=part.region
				if not region is Array or region.size()!=4 or not numeric(region[0],0,4096) or not numeric(region[1],0,4096) or not numeric(region[2],.1,4096) or not numeric(region[3],.1,4096):
					return {"ok":false,"message":"Invalid body-part atlas region."}
			# JSON numbers reopen as floats in Godot; accept whole-number layers.
			if not numeric(part.get("rotation_degrees",null),-180,180) or not numeric(part.get("z_index",null),0,20) or float(part.z_index)!=floorf(float(part.z_index)) or not part.get("flip_h",null) is bool:
				return {"ok":false,"message":"Invalid body-part rotation, layer or mirror setting."}
	if value.enabled and not complete(value,"front"):
		return {"ok":false,"message":"Upload all ten Front body parts before saving. Other views are optional; incomplete views use Front."}
	return {"ok":true,"message":"Body-parts skeleton is valid."}

static func paths(rig: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	for view in rig.get("views",{}).values():
		for part in view.get("parts",{}).values():
			if not str(part.get("image","")).is_empty(): result.append(part.image)
	return result
