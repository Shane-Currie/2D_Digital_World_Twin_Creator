extends RefCounted

## Shared contract for future furniture interactions: object ID + hip anchor + facing.
## This does not bypass object collisions or automatically seat a character.
static func supported(item: Dictionary) -> bool:
	return str(item.get("catalog_id","")) in ["dining_chair","bar_stool","toilet","toilet_cubicle","toilet_cubicle_grey"] or str(item.get("object_type","")).to_lower() in ["chair","seat","stool","toilet","dining chair","bar stool"]

static func angle(item: Dictionary) -> float:
	return fposmod(float(item.get("seat_direction_degrees",item.get("rotation_degrees",0.0))),360.0)

static func facing(item: Dictionary) -> Vector2:
	return Vector2.DOWN.rotated(deg_to_rad(angle(item)))

static func position(item: Dictionary) -> Vector2:
	var centre := Vector2(float(item.get("x_metres",0)),float(item.get("y_metres",0)))
	var offset := Vector2.ZERO
	if str(item.get("catalog_id",""))=="toilet": offset.y=float(item.depth_metres)*.1
	# Cubicle SVG bowl is at (58/120,64/160), not at the rear cistern.
	if str(item.get("catalog_id","")) in ["toilet_cubicle","toilet_cubicle_grey"]: offset=Vector2(-float(item.width_metres)/60.0,-float(item.depth_metres)*.10)
	return centre+offset.rotated(deg_to_rad(float(item.get("rotation_degrees",0))))

static func set_direction(data: Dictionary, building_id: String, floor_id: String, item_id: String, degrees: float) -> Dictionary:
	if not is_finite(degrees): return {"ok":false,"message":"Choose a finite seating angle."}
	var updated := data.duplicate(true)
	for floor_value in updated.get("buildings",{}).get(building_id,{}).get("floors",[]):
		if str(floor_value.id)!=floor_id: continue
		for item in floor_value.get("furniture",[]):
			if str(item.id)!=item_id: continue
			if not supported(item): return {"ok":false,"message":"Select a chair, seat or toilet."}
			item["seat_direction_degrees"]=fposmod(snappedf(degrees,.1),360)
			return {"ok":true,"data":updated}
	return {"ok":false,"message":"The selected seat is no longer on this floor."}
