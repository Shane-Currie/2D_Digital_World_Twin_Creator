extends RefCounted

const FILE_NAME := "trader_npcs.json"
const Catalog = preload("res://scripts/inventory/item_catalog_store.gd")

static func empty_data() -> Dictionary:
	return {"schema_version": 1, "traders": {}}

static func presets() -> Array:
	var result: Array = [
		{"id": "trader_barkeep", "name": "Barkeep", "actor_kind": "npc", "background": "Runs the local pub and sells drinks.", "personality": "Welcoming and practical", "speaking_style": "Short, friendly sentences", "greeting": "Hello, what can I get you?", "trader_only": true},
		{"id": "trader_general", "name": "Shopkeeper", "actor_kind": "npc", "background": "Sells supplies to visitors and residents.", "personality": "Helpful and straightforward", "speaking_style": "Short, natural sentences", "greeting": "Hello, looking for supplies?", "trader_only": true}
	]
	for entry in result:
		entry["schema_version"] = 1
		entry["knowledge"] = []
		entry["boundaries"] = ["Do not claim to control the game world."]
		entry["robotic"] = false
	return result

static func persona(id_value: String, library: Dictionary) -> Dictionary:
	# Creator-edited presets take priority over the built-in fallback.
	for value in library.get("personas", []) + presets():
		if str(value.get("id", "")) == id_value: return value.duplicate(true)
	return {}

static func shared_personas(library: Dictionary) -> Dictionary:
	var result := library.duplicate(true)
	var existing: Dictionary = {}
	for entry in result.get("personas", []): existing[str(entry.get("id", ""))] = true
	for entry in presets():
		if existing.has(str(entry.id)): continue
		entry["built_in"] = true
		result.get_or_add("personas", []).append(entry)
	return result

static func npc_role(npc: Dictionary, data: Dictionary = {}) -> String:
	if npc.has("npc_role"): return str(npc.npc_role)
	var profile: Dictionary = data.get("traders", {}).get(str(npc.get("id", "")), {})
	return "trader" if bool(profile.get("enabled", false)) or not profile.get("offers", []).is_empty() else "storyline"

static func classify_placements(placements: Dictionary, data: Dictionary) -> Dictionary:
	var result := placements.duplicate(true)
	for npc in result.get("npcs", []):
		var role := npc_role(npc, data)
		if not npc.has("npc_role") and role == "trader":
			var profile: Dictionary = data.get("traders", {}).get(str(npc.id), {})
			if not str(profile.get("persona_id", "")).is_empty(): npc.persona_id = str(profile.persona_id)
		npc["npc_role"] = role
	return result

func load_from_town(directory: String) -> Dictionary:
	var path := directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path): return {"ok": true, "data": empty_data(), "message": ""}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema_version") != 1 or not data.get("traders") is Dictionary:
		return {"ok": false, "message": "Trader settings could not be read; the existing file was preserved."}
	for npc_id in data.traders:
		var profile = data.traders[npc_id]
		if not profile is Dictionary or not profile.get("offers", []) is Array:
			return {"ok": false, "message": "A trader's stock list is damaged. Repair it before saving traders."}
		for offer in profile.get("offers", []):
			if not offer is Dictionary or not offer.get("item_id") is String or not valid_amount(offer.get("stock")) or not valid_amount(offer.get("price_keks")):
				return {"ok": false, "message": "A trader item has invalid stock or pricing. The existing file was preserved."}
	return {"ok": true, "data": data, "message": ""}

func save_to_town(directory: String, data: Dictionary, npcs: Dictionary, catalog: Dictionary, library: Dictionary) -> Dictionary:
	var valid_ids: Dictionary = {}
	for npc in npcs.get("npcs", []): valid_ids[str(npc.id)] = true
	for npc_id in data.traders:
		var profile: Dictionary = data.traders[npc_id]
		if not valid_ids.has(str(npc_id)): continue # Removed placements are inert, not reassigned.
		if persona(str(profile.get("persona_id", "")), library).is_empty():
			return {"ok": false, "message": "Choose an available trader persona."}
		var seen: Dictionary = {}
		for offer in profile.get("offers", []):
			var item_id := str(offer.get("item_id", ""))
			if seen.has(item_id) or Catalog.find_item(catalog, item_id).is_empty() or item_id == "keks":
				return {"ok": false, "message": "Select each stock item once from Inventory items (Keks is the payment currency)."}
			seen[item_id] = true
			for field in ["stock", "price_keks"]:
				if not valid_amount(offer.get(field)):
					return {"ok": false, "message": "Stock and prices must be whole numbers from 0 to 1,000,000."}
	var path := directory.path_join("data").path_join(FILE_NAME)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return {"ok": false, "message": "Cannot create the trader settings folder."}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"ok": false, "message": "Cannot save trader settings."}
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	return {"ok": file.get_error() == OK, "message": "Trader settings saved. Reopen Play test to load them."}

static func valid_amount(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0 and float(value) <= 1000000 and float(value) == floorf(float(value))
