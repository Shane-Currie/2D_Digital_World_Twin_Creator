class_name ItemCatalogStore
extends RefCounted

## Creator-authored item definitions shared by Creator Studio and gameplay.
## The catalogue describes items; player quantities live in the save folder.
const FILE_NAME := "item_catalog.json"
const SCHEMA_VERSION := 1
const ITEM_TYPES := ["general", "currency", "nutrient", "hydration"]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const MAX_IMAGE_BYTES := 10 * 1024 * 1024


static func default_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"kind": "creator_item_catalog",
		"items": [
			_item("keks", "Keks", "currency", 100, "res://assets/inventory/kek_coins_icon_runtime.png", 0, 0, true),
			_item("bananas", "Bananas", "nutrient", 3, "res://assets/inventory/bananas_icon_runtime.png", 20, 0, true),
			_item("water_bottles", "Water bottles", "hydration", 3, "res://assets/inventory/water_bottle_icon_runtime.png", 0, 25, true),
			_item("beer", "Beer", "general", 0, "res://assets/inventory/beer.svg", 0, 0, true)
		]
	}


static func _item(id_value: String, name_value: String, type_value: String, starting_quantity: int, icon_path: String, nutrient_points: int, hydration_points: int, built_in: bool) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id_value,
		"display_name": name_value,
		"type": type_value,
		"starting_quantity": starting_quantity,
		"icon_path": icon_path,
		"nutrient_points": nutrient_points,
		"hydration_points": hydration_points,
		"built_in": built_in
	}


func load_from_town(town_directory: String) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value):
		return {"ok": true, "data": default_data(), "created_default": true, "message": "Default item catalogue loaded."}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	if not parsed is Dictionary:
		return {"ok": false, "message": "data/%s is damaged or is not valid JSON." % FILE_NAME}
	if parsed.get("items") is Array and find_item(parsed, "beer").is_empty():
		parsed.items.append(default_data().items[3])
	var validation := validate(parsed, town_directory)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0], "validation": validation}
	return {"ok": true, "data": parsed, "created_default": false, "message": "Item catalogue loaded."}


func save_to_town(town_directory: String, data: Dictionary) -> Dictionary:
	var validation := validate(data, town_directory)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0], "validation": validation}
	var data_directory := town_directory.path_join("data")
	if DirAccess.make_dir_recursive_absolute(data_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	var path_value := data_directory.path_join(FILE_NAME)
	var file := FileAccess.open(path_value, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save data/%s." % FILE_NAME}
	file.store_string(JSON.stringify(data, "\t") + "\n")
	return {"ok": true, "path": path_value, "message": "Item catalogue saved.", "validation": validation}


func add_custom_item(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var ids: Dictionary = {}
	for value in result.get("items", []):
		if value is Dictionary:
			ids[str(value.get("id", ""))] = true
	var number := 1
	while ids.has("custom_item_%d" % number):
		number += 1
	var item := _item("custom_item_%d" % number, "New item", "general", 0, "", 0, 0, false)
	result.get_or_add("items", []).append(item)
	return {"ok": true, "data": result, "item": item}


func import_icon(town_directory: String, item_id: String, source_path: String) -> Dictionary:
	if not FileAccess.file_exists(source_path):
		return {"ok": false, "message": "Choose an existing PNG, JPEG or WebP image."}
	var extension := source_path.get_extension().to_lower()
	if extension not in IMAGE_EXTENSIONS:
		return {"ok": false, "message": "Item pictures must be PNG, JPEG or WebP files."}
	if FileAccess.get_file_as_bytes(source_path).size() > MAX_IMAGE_BYTES:
		return {"ok": false, "message": "Keep item pictures under 10 MB."}
	var relative_path := "assets/items/%s.%s" % [item_id, extension]
	var destination := town_directory.path_join(relative_path)
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town item-art folder."}
	if DirAccess.copy_absolute(source_path, destination) != OK:
		return {"ok": false, "message": "Creator Studio could not copy the selected item picture."}
	return {"ok": true, "icon_path": relative_path, "absolute_path": destination, "message": "Item picture copied into the town project."}


static func find_item(data: Dictionary, item_id: String) -> Dictionary:
	for value in data.get("items", []):
		if value is Dictionary and str(value.get("id", "")) == item_id:
			return value
	return {}


static func load_icon(item: Dictionary, town_directory: String) -> Texture2D:
	var icon_path := str(item.get("icon_path", ""))
	if icon_path.is_empty():
		return null
	if icon_path.begins_with("res://"):
		return load(icon_path) as Texture2D
	if icon_path.is_absolute_path() or icon_path.contains(".."):
		return null
	var absolute_path := town_directory.path_join(icon_path)
	var image := Image.new()
	if image.load(absolute_path) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func validate(data: Dictionary, town_directory := "") -> Dictionary:
	var errors: Array[String] = []
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or str(data.get("kind", "")) != "creator_item_catalog":
		errors.append("The item catalogue uses an unsupported format.")
	var items = data.get("items", [])
	if not items is Array or items.is_empty():
		errors.append("Add at least one item to the catalogue.")
		return {"passed": false, "errors": errors}
	var ids: Dictionary = {}
	for value in items:
		if not value is Dictionary:
			errors.append("Every catalogue item needs a complete record.")
			continue
		var item: Dictionary = value
		var item_id := str(item.get("id", ""))
		if not item_id.is_valid_identifier() or item_id.to_lower() != item_id or ids.has(item_id):
			errors.append("Every item needs a unique lower-case ID.")
		ids[item_id] = true
		if str(item.get("display_name", "")).strip_edges().is_empty() or str(item.get("display_name", "")).length() > 60:
			errors.append("Item %s needs a name of 60 characters or fewer." % item_id)
		var type_value := str(item.get("type", ""))
		if type_value not in ITEM_TYPES:
			errors.append("Item %s has an unsupported type." % item_id)
		for field in ["starting_quantity", "nutrient_points", "hydration_points"]:
			var amount := int(item.get(field, -1))
			var maximum := 1000000 if field == "starting_quantity" else 100
			if amount < 0 or amount > maximum:
				errors.append("Item %s has an invalid %s." % [item_id, field.replace("_", " ")])
		if type_value == "nutrient" and int(item.get("nutrient_points", 0)) <= 0:
			errors.append("Nutrient item %s must restore at least 1 nutrient point." % item_id)
		if type_value == "hydration" and int(item.get("hydration_points", 0)) <= 0:
			errors.append("Hydration item %s must restore at least 1 hydration point." % item_id)
		var icon_path := str(item.get("icon_path", ""))
		if icon_path.is_empty():
			errors.append("Item %s needs a picture." % item_id)
		elif not icon_path.begins_with("res://"):
			if icon_path.is_absolute_path() or icon_path.contains("..") or icon_path.get_extension().to_lower() not in IMAGE_EXTENSIONS:
				errors.append("Item %s has an unsafe picture path." % item_id)
			elif not town_directory.is_empty() and not FileAccess.file_exists(town_directory.path_join(icon_path)):
				errors.append("Item %s picture is missing from the town project." % item_id)
	return {"passed": errors.is_empty(), "errors": errors, "item_count": items.size()}
