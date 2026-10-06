class_name InteriorFloorMaterialLibrary
extends RefCounted

## Town-specific creator floor textures. Imported images are copied into the
## town and referenced by safe relative paths, never by the original location.

const CatalogScript = preload("res://scripts/interiors/interior_floor_material_catalog.gd")
const SCHEMA_VERSION := 1
const FILE_NAME := "interior_floor_materials.json"
const ASSET_FOLDER := "assets/interiors/floors"
const MAX_IMAGE_BYTES := 20 * 1024 * 1024
const MAX_IMAGE_EDGE := 4096
const MAX_ITEMS := 200


func empty_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "kind": "creator_interior_floor_materials", "items": []}


func load_from_town(town_directory: String) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value): return {"ok": true, "data": empty_data(), "created_default": true}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	if not parsed is Dictionary: return {"ok": false, "message": "data/%s is damaged or is not valid JSON." % FILE_NAME}
	var validation := validate(parsed, town_directory)
	if not validation.ok: return validation
	return {"ok": true, "data": parsed, "created_default": false}


func save_to_town(town_directory: String, data: Dictionary) -> Dictionary:
	var validation := validate(data, town_directory)
	if not validation.ok: return validation
	var directory := town_directory.path_join("data")
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	var saved := data.duplicate(true)
	saved["updated_utc"] = Time.get_datetime_string_from_system(true)
	var file := FileAccess.open(directory.path_join(FILE_NAME), FileAccess.WRITE)
	if file == null: return {"ok": false, "message": "Creator Studio could not save the custom floor materials."}
	file.store_string(JSON.stringify(saved, "  "))
	return {"ok": true, "data": saved}


func all_definitions(data: Dictionary) -> Array:
	var result := CatalogScript.all()
	for value in data.get("items", []):
		if value is Dictionary: result.append(value.duplicate(true))
	return result


func definition(data: Dictionary, material_id: String) -> Dictionary:
	var built_in := CatalogScript.definition(material_id)
	if not built_in.is_empty(): return built_in
	for value in data.get("items", []):
		if value is Dictionary and str(value.get("id", "")) == material_id: return value.duplicate(true)
	return {}


func import_creation(town_directory: String, data: Dictionary, source_path: String, display_name: String) -> Dictionary:
	var clean_name := _clean_text(display_name, 80)
	if clean_name.is_empty(): return {"ok": false, "message": "Enter a name for this floor texture."}
	var extension := source_path.get_extension().to_lower()
	if extension not in ["png", "jpg", "jpeg", "webp"]: return {"ok": false, "message": "Choose a PNG, JPEG or WebP floor texture."}
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null or source.get_length() <= 0 or source.get_length() > MAX_IMAGE_BYTES: return {"ok": false, "message": "The selected picture is unreadable, empty or larger than 20 MB."}
	var image := Image.new()
	if image.load(source_path) != OK or image.is_empty() or image.get_width() > MAX_IMAGE_EDGE or image.get_height() > MAX_IMAGE_EDGE:
		return {"ok": false, "message": "The picture could not be read or is larger than 4096 × 4096 pixels."}
	var items: Array = data.get("items", []).duplicate(true)
	if items.size() >= MAX_ITEMS: return {"ok": false, "message": "This town already has the maximum of %d custom floor textures." % MAX_ITEMS}
	var material_id := _unique_id(items, "custom_floor_%s" % _safe_id(clean_name))
	var asset_directory := town_directory.path_join(ASSET_FOLDER)
	if DirAccess.make_dir_recursive_absolute(asset_directory) != OK: return {"ok": false, "message": "Creator Studio could not create the town's floor-texture folder."}
	var file_name := "%s.%s" % [material_id, extension]
	var destination := asset_directory.path_join(file_name)
	if DirAccess.copy_absolute(source_path, destination) != OK: return {"ok": false, "message": "Creator Studio could not copy that floor texture into the town project."}
	var definition_value := {
		"id": material_id, "name": clean_name, "category": "My creations", "fill": "#8a735d",
		"catalog_source": "creator_imported", "image_path": "%s/%s" % [ASSET_FOLDER, file_name],
		"original_file_name": source_path.get_file(), "imported_utc": Time.get_datetime_string_from_system(true)
	}
	items.append(definition_value)
	var updated := data.duplicate(true)
	updated["items"] = items
	var save_result := save_to_town(town_directory, updated)
	if not save_result.ok:
		DirAccess.remove_absolute(destination)
		return save_result
	return {"ok": true, "data": save_result.data, "definition": definition_value, "message": "%s was added to the floor-texture list." % clean_name}


func validate(data: Dictionary, town_directory := "") -> Dictionary:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or str(data.get("kind", "")) != "creator_interior_floor_materials" or not data.get("items", []) is Array:
		return {"ok": false, "message": "The custom floor-material catalogue uses an unsupported or incomplete format."}
	var ids := {}
	var items: Array = data.get("items", [])
	if items.size() > MAX_ITEMS: return {"ok": false, "message": "The custom floor-material catalogue contains too many items."}
	for value in items:
		if not value is Dictionary: return {"ok": false, "message": "The custom floor-material catalogue contains invalid item data."}
		var item: Dictionary = value
		var item_id := str(item.get("id", ""))
		var image_path := str(item.get("image_path", "")).replace("\\", "/")
		if item_id.is_empty() or ids.has(item_id) or not item_id.begins_with("custom_floor_") or str(item.get("name", "")).strip_edges().is_empty():
			return {"ok": false, "message": "The custom floor-material catalogue contains a missing or duplicate identity."}
		if str(item.get("catalog_source", "")) != "creator_imported" or not _safe_relative_asset_path(image_path):
			return {"ok": false, "message": "Custom floor materials must use copied town artwork."}
		if not town_directory.is_empty() and not FileAccess.file_exists(town_directory.path_join(image_path)):
			return {"ok": false, "message": "Custom floor artwork is missing: %s" % image_path}
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
		if character >= "a" and character <= "z" or character >= "0" and character <= "9": result += character
		elif not result.ends_with("_"): result += "_"
	return result.trim_prefix("_").trim_suffix("_") if not result.is_empty() else "texture"


static func _unique_id(items: Array, preferred: String) -> String:
	var used := {}
	for value in items:
		if value is Dictionary: used[str(value.get("id", ""))] = true
	if not used.has(preferred): return preferred
	var number := 2
	while used.has("%s_%d" % [preferred, number]): number += 1
	return "%s_%d" % [preferred, number]
