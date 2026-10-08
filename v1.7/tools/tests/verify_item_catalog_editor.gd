extends SceneTree

const ItemCatalogStoreScript = preload("res://scripts/inventory/item_catalog_store.gd")
const ItemCatalogEditorScript = preload("res://scripts/inventory/item_catalog_editor.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var town_directory := ProjectSettings.globalize_path("res://tools/tests/output/item_catalog_test_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(town_directory)
	var store = ItemCatalogStoreScript.new()
	var data: Dictionary = store.default_data()
	assert(data.items.size() == 3, "The default catalogue should contain Keks, bananas and water bottles.")
	var keks: Dictionary = store.find_item(data, "keks")
	var bananas: Dictionary = store.find_item(data, "bananas")
	var water: Dictionary = store.find_item(data, "water_bottles")
	assert(keks.type == "currency" and int(keks.starting_quantity) == 100, "Keks were not migrated as catalogue currency.")
	assert(bananas.type == "nutrient" and int(bananas.starting_quantity) == 3 and int(bananas.nutrient_points) == 20, "Bananas were not migrated as a nutrient consumable.")
	assert(water.type == "hydration" and int(water.starting_quantity) == 3 and int(water.hydration_points) == 25, "Water bottles were not configured as hydration consumables.")
	assert(store.save_to_town(town_directory, data).ok, "The default catalogue could not be saved.")

	var addition: Dictionary = store.add_custom_item(data)
	data = addition.data
	var custom: Dictionary = addition.item
	custom.display_name = "Test snack"
	custom.type = "nutrient"
	custom.starting_quantity = 2
	custom.nutrient_points = 12
	var import_result: Dictionary = store.import_icon(town_directory, str(custom.id), ProjectSettings.globalize_path("res://assets/inventory/bananas_icon_runtime.png"))
	assert(import_result.ok, "A creator-supplied item picture could not be copied into the town.")
	custom.icon_path = import_result.icon_path
	assert(store.save_to_town(town_directory, data).ok, "The custom catalogue item could not be saved.")
	var reopened: Dictionary = store.load_from_town(town_directory)
	assert(reopened.ok and reopened.data.items.size() == 4, "The item catalogue did not reopen with its custom item.")
	assert(FileAccess.file_exists(town_directory.path_join(str(import_result.icon_path))), "The imported picture was not retained in the town project.")

	var editor = ItemCatalogEditorScript.new()
	root.add_child(editor)
	await process_frame
	var setup_result: Dictionary = editor.setup(town_directory)
	assert(setup_result.ok, "Creator Studio could not open the item catalogue editor.")
	assert(editor.item_option.item_count == 4, "The creator item list did not display every saved item.")
	assert(editor.item_option.get_item_text(0).begins_with("Keks") and editor.item_option.get_item_text(1).begins_with("Bananas") and editor.item_option.get_item_text(2).begins_with("Water bottles"), "Migrated items were missing from the no-code editor.")
	assert(editor.picture_preview.texture != null, "The migrated Kek picture did not load in the editor.")

	editor.queue_free()
	await process_frame
	_remove_tree(town_directory)
	print("ITEM CATALOGUE PASSED: Keks and bananas migrated; water/custom items, pictures, types, points and persistence verified.")
	quit()


func _remove_tree(path_value: String) -> void:
	if not DirAccess.dir_exists_absolute(path_value):
		return
	var directory := DirAccess.open(path_value)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path_value.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path_value)
