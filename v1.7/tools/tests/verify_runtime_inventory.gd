extends SceneTree

const InventoryScript = preload("res://scripts/runtime/inventory/runtime_player_inventory.gd")
const InventoryPanelScript = preload("res://scripts/runtime/ui/runtime_inventory_panel.gd")
const ItemCatalogStoreScript = preload("res://scripts/inventory/item_catalog_store.gd")
const PlayerStatsScript = preload("res://scripts/runtime/inventory/runtime_player_stats.gd")
const PlayerStatsPanelScript = preload("res://scripts/runtime/ui/runtime_player_stats_panel.gd")
const TownRuntimeScript = preload("res://scripts/runtime/town_runtime.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var town_directory := ProjectSettings.globalize_path("res://tools/tests/output/inventory_test_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(town_directory)
	var catalog := ItemCatalogStoreScript.default_data()
	var inventory = InventoryScript.new()
	var load_result: Dictionary = inventory.load_for_town(town_directory, true, catalog)
	assert(load_result.ok, "A new player inventory did not load.")
	assert(inventory.quantity("keks") == 100, "A new player did not start with 100 Keks.")
	assert(inventory.quantity("bananas") == 3, "A new player did not start with 3 bananas.")
	assert(inventory.quantity("water_bottles") == 3, "A new player did not start with 3 water bottles.")
	var stats = PlayerStatsScript.new()
	assert(stats.load_for_town(town_directory).ok and stats.nutrient == 50 and stats.hydration == 50, "New health stats did not start at 50/100.")

	var panel = InventoryPanelScript.new()
	root.add_child(panel)
	await process_frame
	panel.bind_inventory(inventory, catalog, town_directory)
	var stats_panel = PlayerStatsPanelScript.new()
	root.add_child(stats_panel)
	await process_frame
	stats_panel.bind_stats(stats)
	assert(panel.backpack_button.texture_normal != null, "The clickable backpack artwork did not load.")
	assert(panel.BACKPACK_RECT.position.x >= 580.0 and panel.BACKPACK_RECT.end.y <= 330.0, "The backpack is not in the lower-right play-area safe zone.")
	assert(panel.LIST_RECT.position.y >= 34.0 and panel.LIST_RECT.end.y < panel.BACKPACK_RECT.position.y, "The item list overlaps the backpack or screen HUD.")
	assert(panel.ITEM_ICON_SIZE.x <= 24.0 and panel.ITEM_ICON_SIZE.y <= 24.0, "Inventory item icons are too large for a future multi-item list.")
	assert(panel.keks_quantity_label.text == "100" and panel.bananas_quantity_label.text == "3" and panel.water_quantity_label.text == "3", "The itemised list lost its starting quantities.")
	assert(not stats_panel.is_open() and stats_panel.nutrient_bar.value == 50 and stats_panel.hydration_bar.value == 50, "Health stats were not hidden behind a 50/100 Player Stats menu.")
	stats_panel.stats_button.emit_signal("pressed")
	assert(stats_panel.is_open(), "Clicking Player Stats did not reveal the nutrient and hydration bars.")
	stats_panel.stats_button.emit_signal("pressed")
	assert(not panel.is_open(), "The backpack item list should begin closed.")
	panel.backpack_button.emit_signal("pressed")
	assert(panel.is_open(), "Clicking the backpack did not open the itemised list.")
	assert(panel.contains_screen_point(panel.LIST_RECT.get_center()), "The open item list did not reserve its clickable screen area.")
	panel.backpack_button.emit_signal("pressed")
	assert(not panel.is_open(), "Clicking the backpack again did not close the itemised list.")
	panel.set_open(true)
	var runtime = TownRuntimeScript.new()
	runtime.inventory_panel = panel
	runtime.player_stats_panel = stats_panel
	runtime.player_inventory = inventory
	runtime.player_stats = stats
	runtime.item_catalog_data = catalog
	panel.consume_requested.connect(runtime._on_inventory_consume_requested)
	assert(not runtime._screen_can_select_building(panel.LIST_RECT.get_center()), "An inventory click was allowed to reach an OSM building.")
	panel.request_item("bananas")
	assert(panel.confirmation_is_open() and panel.confirmation_label.text.contains("20 nutrient"), "Clicking bananas did not open the nutrient confirmation prompt.")
	panel._confirm_consumption()
	assert(inventory.quantity("bananas") == 2 and stats.nutrient == 70, "Consuming a banana did not remove one item and restore 20 nutrient points.")
	panel.request_item("water_bottles")
	assert(panel.confirmation_is_open() and panel.confirmation_label.text.contains("25 hydration"), "Clicking water did not open the hydration confirmation prompt.")
	panel._confirm_consumption()
	assert(inventory.quantity("water_bottles") == 2 and stats.hydration == 75, "Consuming water did not remove one bottle and restore 25 hydration points.")
	stats.hydration = 90
	stats.dirty = true
	assert(stats.save().ok, "The capped-stat fixture could not be saved.")
	panel.request_item("water_bottles")
	panel._confirm_consumption()
	assert(inventory.quantity("water_bottles") == 1 and stats.hydration == 100, "Hydration was not capped at 100 while consuming water.")
	runtime._on_inventory_consume_requested("water_bottles")
	assert(inventory.quantity("water_bottles") == 1 and stats.hydration == 100, "An item was consumed even though hydration was already full.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	runtime._unhandled_input(escape)
	assert(not panel.is_open(), "Escape did not close the backpack before closing the game.")
	runtime.free()

	assert(inventory.set_quantity("keks", 88).ok, "Kek currency could not be saved.")
	assert(not inventory.add_quantity("bananas", -3).ok, "Inventory quantities were allowed to become negative.")
	var reopened = InventoryScript.new()
	assert(reopened.load_for_town(town_directory, true, catalog).ok, "The saved player inventory could not be reopened.")
	assert(reopened.quantity("keks") == 88 and reopened.quantity("bananas") == 2 and reopened.quantity("water_bottles") == 1, "Saved inventory quantities changed after reopening.")
	var reopened_stats = PlayerStatsScript.new()
	assert(reopened_stats.load_for_town(town_directory).ok and reopened_stats.nutrient == 70 and reopened_stats.hydration == 100, "Saved health stats changed after reopening.")

	panel.queue_free()
	stats_panel.queue_free()
	await process_frame
	var save_directory := town_directory.path_join("saves")
	DirAccess.remove_absolute(save_directory.path_join("player_inventory.json.bak"))
	DirAccess.remove_absolute(save_directory.path_join("player_inventory.json"))
	DirAccess.remove_absolute(save_directory.path_join("player_stats.json.bak"))
	DirAccess.remove_absolute(save_directory.path_join("player_stats.json"))
	DirAccess.remove_absolute(save_directory)
	DirAccess.remove_absolute(town_directory)
	print("PLAYER INVENTORY PASSED: catalogue-driven Keks/bananas/water, consume confirmation, compact list, 50/100 stats, 100 caps and persistence.")
	quit(0)
