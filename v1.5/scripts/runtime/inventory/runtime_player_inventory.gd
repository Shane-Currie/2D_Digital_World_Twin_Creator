class_name RuntimePlayerInventory
extends RefCounted

const SAVE_FILE := "player_inventory.json"
const SCHEMA_VERSION := 1

var quantities: Dictionary = {}
var trader_stock: Dictionary = {}
var save_path := ""
var saving_enabled := true
var dirty := false
var recovered_from_backup := false


func load_for_town(town_directory: String, enable_saving := true, catalog_data: Dictionary = {}) -> Dictionary:
	save_path = town_directory.path_join("saves").path_join(SAVE_FILE)
	saving_enabled = enable_saving
	quantities = default_quantities(catalog_data)
	trader_stock = {}
	dirty = false
	recovered_from_backup = false
	var primary := _read_save(save_path)
	if primary.ok:
		_apply_save(primary.data)
		var added_items := _merge_new_catalogue_items(catalog_data)
		if added_items > 0 and saving_enabled:
			var merge_save := save()
			if not merge_save.ok:
				return merge_save
		return {"ok": true, "message": "%d newly catalogued item(s) were added to this inventory." % added_items if added_items > 0 else ""}
	if not FileAccess.file_exists(save_path):
		return {"ok": true, "message": ""}
	var backup := _read_save(save_path + ".bak")
	if backup.ok:
		_apply_save(backup.data)
		_merge_new_catalogue_items(catalog_data)
		recovered_from_backup = true
		return {"ok": true, "message": "The player inventory was recovered from its backup."}
	saving_enabled = false
	return {"ok": false, "message": "The player inventory save could not be read. The existing file was left untouched."}


static func default_quantities(catalog_data: Dictionary = {}) -> Dictionary:
	if catalog_data.is_empty():
		return {"keks": 100, "bananas": 3, "water_bottles": 3}
	var result: Dictionary = {}
	for value in catalog_data.get("items", []):
		if value is Dictionary:
			result[str(value.get("id", ""))] = int(value.get("starting_quantity", 0))
	return result


func quantity(item_id: String) -> int:
	return int(quantities.get(item_id, 0))


func set_quantity(item_id: String, amount: int) -> Dictionary:
	if not item_id.is_valid_identifier() or amount < 0:
		return {"ok": false, "message": "Inventory quantities cannot be negative."}
	quantities[item_id] = amount
	dirty = true
	return save()


func add_quantity(item_id: String, amount: int) -> Dictionary:
	var next_amount := quantity(item_id) + amount
	if next_amount < 0:
		return {"ok": false, "message": "There are not enough %s in the backpack." % item_id}
	return set_quantity(item_id, next_amount)


func commit_trade(next_quantities: Dictionary, next_stock: Dictionary) -> Dictionary:
	var old_quantities := quantities
	var old_stock := trader_stock
	var old_dirty := dirty
	quantities = next_quantities
	trader_stock = next_stock
	dirty = true
	var result := save()
	if not result.ok:
		quantities = old_quantities
		trader_stock = old_stock
		dirty = old_dirty
	return result


func save() -> Dictionary:
	if not saving_enabled:
		return {"ok": false, "message": "Inventory saving is unavailable."}
	if not dirty:
		return {"ok": true, "message": ""}
	if save_path.is_empty() or DirAccess.make_dir_recursive_absolute(save_path.get_base_dir()) != OK:
		return {"ok": false, "message": "The player inventory save location is unavailable."}
	if FileAccess.file_exists(save_path) and not recovered_from_backup:
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			return {"ok": false, "message": "The previous player inventory could not be backed up."}
	# Write the complete trade to a sibling file first. A failed write never
	# truncates the last good inventory or saves only one side of the sale.
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "The player inventory could not be written."}
	file.store_string(JSON.stringify({"schema_version": SCHEMA_VERSION, "quantities": quantities, "trader_stock": trader_stock}, "  ") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "message": "The player inventory save could not be completed."}
	if DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		return {"ok": false, "message": "The completed inventory could not replace the previous save."}
	recovered_from_backup = false
	dirty = false
	return {"ok": true, "message": ""}


func _merge_new_catalogue_items(catalog_data: Dictionary) -> int:
	var defaults := default_quantities(catalog_data)
	var added := 0
	for item_id in defaults:
		if not quantities.has(item_id):
			quantities[item_id] = defaults[item_id]
			added += 1
	if added > 0:
		dirty = true
	return added


func _read_save(path_value: String) -> Dictionary:
	if not FileAccess.file_exists(path_value):
		return {"ok": false}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"ok": false}
	var saved_quantities = parsed.get("quantities", {})
	if not saved_quantities is Dictionary:
		return {"ok": false}
	for item_id in saved_quantities:
		var value: Variant = saved_quantities[item_id]
		if not str(item_id).is_valid_identifier() or typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return {"ok": false}
		if is_nan(float(value)) or is_inf(float(value)) or float(value) < 0.0 or not is_equal_approx(float(value), roundf(float(value))):
			return {"ok": false}
	var stock = parsed.get("trader_stock", {})
	if not stock is Dictionary: return {"ok": false}
	for npc_id in stock:
		if not str(npc_id).is_valid_identifier() or not stock[npc_id] is Dictionary: return {"ok": false}
		for item_id in stock[npc_id]:
			var entry = stock[npc_id][item_id]
			if item_id == "_keks_received":
				if typeof(entry) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(entry)) or float(entry) < 0 or float(entry) != floorf(float(entry)): return {"ok": false}
				continue
			if not str(item_id).is_valid_identifier() or not entry is Dictionary: return {"ok": false}
			for field in ["configured_stock", "remaining"]:
				var amount = entry.get(field)
				if typeof(amount) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(amount)) or float(amount) < 0 or float(amount) > 1000000 or float(amount) != floorf(float(amount)): return {"ok": false}
			if float(entry.remaining) > float(entry.configured_stock): return {"ok": false}
	return {"ok": true, "data": parsed}


func _apply_save(data: Dictionary) -> void:
	trader_stock = data.get("trader_stock", {}).duplicate(true)
	# JSON numbers load as floats; normalise stored stock to integer counts.
	for npc_id in trader_stock:
		for item_id in trader_stock[npc_id]:
			if item_id == "_keks_received": trader_stock[npc_id][item_id] = int(trader_stock[npc_id][item_id])
			else:
				for field in ["configured_stock", "remaining"]:
					trader_stock[npc_id][item_id][field] = int(trader_stock[npc_id][item_id][field])
	quantities.clear()
	for item_id in data.quantities:
		quantities[str(item_id)] = int(data.quantities[item_id])
	dirty = false
