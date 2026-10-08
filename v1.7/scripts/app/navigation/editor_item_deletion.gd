extends RefCounted

## Delete only an explicitly selected placed item, never catalogue artwork or OSM.
const Interiors = preload("res://scripts/interiors/building_interior_store.gd")

static func remove(interiors: Dictionary, npcs: Dictionary, traders: Dictionary, selection: Dictionary) -> Dictionary:
	var kind := str(selection.get("kind", ""))
	var id := str(selection.get("id", ""))
	var building_id := str(selection.get("building_id", ""))
	var floor_id := str(selection.get("floor_id", ""))
	var store := Interiors.new()
	var result: Dictionary
	match kind:
		"furniture": result = store.remove_furniture(interiors,building_id,floor_id,id)
		"wall": result = store.remove_wall(interiors,building_id,floor_id,id)
		"door": result = store.remove_wall_door(interiors,building_id,floor_id,str(selection.get("owner_id", "")),id)
		"room": result = store.remove_room_label(interiors,building_id,floor_id,id)
		"stairs": result = store.remove_stair_pair(interiors,building_id,id)
		"connection":
			var updated := interiors.duplicate(true)
			var pairs: Array = updated.get("building_connections", [])
			var found := false
			for index in range(pairs.size()-1,-1,-1):
				if str(pairs[index].id)==id: pairs.remove_at(index); found=true
			result={"ok":found,"data":updated,"message":"Both connecting door sides removed." if found else "Select a connecting door first."}
		"npc":
			var updated := npcs.duplicate(true)
			var profiles := traders.duplicate(true)
			var found := false
			for index in range(updated.get("npcs", []).size()-1,-1,-1):
				var npc: Dictionary = updated.npcs[index]
				if str(npc.id)!=id: continue
				var location: Dictionary = npc.get("location", {})
				if str(location.get("building_id", ""))!=building_id or str(location.get("floor_id", ""))!=floor_id: continue
				updated.npcs.remove_at(index); found=true
			profiles.get("traders", {}).erase(id)
			return {"ok":found,"data":interiors,"npcs":updated,"traders":profiles,"message":"Placed character removed; its persona and artwork are kept."}
		_: return {"ok":false,"message":"Select a placed item first."}
	if not result.get("ok",false): return {"ok":false,"message":result.get("message","The selected item no longer exists.")}
	result["npcs"]=npcs
	result["traders"]=traders
	return result
