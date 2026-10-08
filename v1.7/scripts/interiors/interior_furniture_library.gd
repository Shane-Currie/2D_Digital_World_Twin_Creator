class_name InteriorFurnitureLibrary
extends RefCounted

## Town-specific custom furniture catalogue. Imported pictures are copied into
## the town so play tests never depend on a file left on the creator's Desktop.

const CatalogScript = preload("res://scripts/interiors/interior_furniture_catalog.gd")
const SCHEMA_VERSION := 1
const FILE_NAME := "interior_furniture_catalog.json"
const ASSET_FOLDER := "assets/interiors/furniture"
const MAX_IMAGE_BYTES := 20 * 1024 * 1024
const MAX_IMAGE_EDGE := 4096
const MAX_ITEMS := 500


func empty_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "kind": "creator_interior_furniture_catalog", "items": []}


func load_from_town(town_directory: String) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value):
		return {"ok": true, "data": empty_data(), "created_default": true}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	if not parsed is Dictionary:
		return {"ok": false, "message": "data/%s is damaged or is not valid JSON." % FILE_NAME}
	var validation := validate(parsed, town_directory)
	if not validation.ok:
		return validation
	return {"ok": true, "data": parsed, "created_default": false}


func save_to_town(town_directory: String, data: Dictionary) -> Dictionary:
	var validation := validate(data, town_directory)
	if not validation.ok:
		return validation
	var data_directory := town_directory.path_join("data")
	if DirAccess.make_dir_recursive_absolute(data_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	var saved := data.duplicate(true)
	saved["updated_utc"] = Time.get_datetime_string_from_system(true)
	var file := FileAccess.open(data_directory.path_join(FILE_NAME), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save the custom furniture catalogue."}
	file.store_string(JSON.stringify(saved, "  "))
	return {"ok": true, "data": saved}


func all_definitions(data: Dictionary) -> Array:
	var result: Array = CatalogScript.all()
	for value in data.get("items", []):
		if value is Dictionary:
			result.append(value.duplicate(true))
	return result


func definition(data: Dictionary, item_id: String) -> Dictionary:
	var built_in := CatalogScript.definition(item_id)
	if not built_in.is_empty():
		return built_in
	for value in data.get("items", []):
		if value is Dictionary and str(value.get("id", "")) == item_id:
			return value.duplicate(true)
	return {}


func import_creation(town_directory: String, data: Dictionary, source_path: String, display_name: String, object_type: String, width_metres: float, depth_metres: float, usage_category := "My creations") -> Dictionary:
	var clean_name := _clean_text(display_name, 80)
	var clean_type := _clean_text(object_type, 48).to_lower()
	var clean_category := _clean_text(usage_category, 48)
	if clean_name.is_empty() or clean_type.is_empty():
		return {"ok": false, "message": "Enter both a furniture name and an object type, such as Armchair and chair."}
	if clean_category.is_empty() or clean_category.to_lower() == "all items":
		return {"ok": false, "message": "Choose an existing furniture category or enter a custom category name."}
	if width_metres < 0.1 or depth_metres < 0.1 or width_metres > 20.0 or depth_metres > 20.0:
		return {"ok": false, "message": "Choose furniture dimensions from 0.1 to 20 metres."}
	var extension := source_path.get_extension().to_lower()
	if extension not in ["png", "jpg", "jpeg", "webp"]:
		return {"ok": false, "message": "Choose a PNG, JPEG or WebP picture."}
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null or source.get_length() <= 0 or source.get_length() > MAX_IMAGE_BYTES:
		return {"ok": false, "message": "The selected picture is unreadable, empty or larger than 20 MB."}
	var image := Image.new()
	var image_error := image.load(source_path)
	if image_error != OK or image.is_empty() or image.get_width() > MAX_IMAGE_EDGE or image.get_height() > MAX_IMAGE_EDGE:
		return {"ok": false, "message": "The picture could not be read or is larger than 4096 × 4096 pixels."}
	var items: Array = data.get("items", []).duplicate(true)
	if items.size() >= MAX_ITEMS:
		return {"ok": false, "message": "This town already has the maximum of %d custom furniture items." % MAX_ITEMS}
	var item_id := _unique_id(items, "custom_%s" % _safe_id(clean_name))
	var asset_directory := town_directory.path_join(ASSET_FOLDER)
	if DirAccess.make_dir_recursive_absolute(asset_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town's furniture artwork folder."}
	var file_name := "%s.%s" % [item_id, extension]
	var destination := asset_directory.path_join(file_name)
	if DirAccess.copy_absolute(source_path, destination) != OK:
		return {"ok": false, "message": "Creator Studio could not copy that picture into the town project."}
	var definition_value := {
		"id": item_id,
		"name": clean_name,
		"object_type": clean_type,
		"category": "My creations",
		"usage_categories": [clean_category] if clean_category == "My creations" else [clean_category, "My creations"],
		"size_metres": [snappedf(width_metres, 0.01), snappedf(depth_metres, 0.01)],
		"fill": "#8a735d",
		"outline": "#41362d",
		"collision": true,
		"catalog_source": "creator_imported",
		"image_path": "%s/%s" % [ASSET_FOLDER, file_name],
		"original_file_name": source_path.get_file(),
		"imported_utc": Time.get_datetime_string_from_system(true)
	}
	items.append(definition_value)
	var updated := data.duplicate(true)
	updated["items"] = items
	var save_result := save_to_town(town_directory, updated)
	if not save_result.ok:
		DirAccess.remove_absolute(destination)
		return save_result
	var category_message := "My creations" if clean_category == "My creations" else "%s and My creations" % clean_category
	return {"ok": true, "data": save_result.data, "definition": definition_value, "message": "%s was added to %s with collision enabled." % [clean_name, category_message]}


func validate(data: Dictionary, town_directory := "") -> Dictionary:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or str(data.get("kind", "")) != "creator_interior_furniture_catalog" or not data.get("items", []) is Array:
		return {"ok": false, "message": "The custom furniture catalogue uses an unsupported or incomplete format."}
	var ids := {}
	var items: Array = data.get("items", [])
	if items.size() > MAX_ITEMS:
		return {"ok": false, "message": "The custom furniture catalogue contains too many items."}
	for value in items:
		if not value is Dictionary:
			return {"ok": false, "message": "The custom furniture catalogue contains invalid item data."}
		var item: Dictionary = value
		var item_id := str(item.get("id", ""))
		var image_path := str(item.get("image_path", "")).replace("\\", "/")
		var size_value = item.get("size_metres", [])
		var usage_categories = item.get("usage_categories", [])
		if item_id.is_empty() or ids.has(item_id) or not item_id.begins_with("custom_") or str(item.get("name", "")).strip_edges().is_empty() or str(item.get("object_type", "")).strip_edges().is_empty():
			return {"ok": false, "message": "The custom furniture catalogue contains a missing or duplicate identity."}
		if not size_value is Array or size_value.size() != 2 or float(size_value[0]) < 0.1 or float(size_value[1]) < 0.1 or float(size_value[0]) > 20.0 or float(size_value[1]) > 20.0:
			return {"ok": false, "message": "Custom furniture dimensions must be between 0.1 and 20 metres."}
		if str(item.get("catalog_source", "")) != "creator_imported" or not bool(item.get("collision", false)) or not _safe_relative_asset_path(image_path):
			return {"ok": false, "message": "Custom furniture must use copied town artwork and automatic collision."}
		if not usage_categories is Array:
			return {"ok": false, "message": "A custom furniture category list is invalid."}
		if not usage_categories.is_empty():
			if usage_categories.size() > 8:
				return {"ok": false, "message": "Custom furniture may use no more than eight categories."}
			for category_value in usage_categories:
				var category_name := str(category_value).strip_edges()
				if category_name.is_empty() or category_name.length() > 48 or category_name.to_lower() == "all items":
					return {"ok": false, "message": "A custom furniture category name is invalid."}
		if not town_directory.is_empty() and not FileAccess.file_exists(town_directory.path_join(image_path)):
			return {"ok": false, "message": "Custom furniture artwork is missing: %s" % image_path}
		ids[item_id] = true
	return {"ok": true}


static func _safe_relative_asset_path(value: String) -> bool:
	var normal := value.replace("\\", "/")
	return normal.begins_with(ASSET_FOLDER + "/") and not normal.contains("..") and not normal.is_absolute_path()


static func _clean_text(value: String, maximum: int) -> String:
	return " ".join(value.replace("\r", " ").replace("\n", " ").split(" ", false)).strip_edges().left(maximum)


static func _safe_id(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_") if not result.is_empty() else "furniture"


static func _unique_id(items: Array, preferred: String) -> String:
	var used := {}
	for value in items:
		if value is Dictionary: used[str(value.get("id", ""))] = true
	if not used.has(preferred): return preferred
	var number := 2
	while used.has("%s_%d" % [preferred, number]): number += 1
	return "%s_%d" % [preferred, number]
