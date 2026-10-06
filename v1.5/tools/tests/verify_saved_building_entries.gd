extends SceneTree

const ExteriorStore = preload("res://scripts/buildings/building_exterior_store.gd")
const InteriorStore = preload("res://scripts/interiors/building_interior_store.gd")
const InteriorLayer = preload("res://scripts/interiors/runtime_interior_layer.gd")


func _initialize() -> void:
	var town_directory := ""
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index] == "--town" and index + 1 < arguments.size():
			town_directory = arguments[index + 1]
	if town_directory.is_empty():
		push_error("Pass --town followed by a saved Creator Studio town directory.")
		quit(2)
		return
	var exteriors := ExteriorStore.new().load_from_town(town_directory)
	var interiors := InteriorStore.new().load_from_town(town_directory)
	assert(exteriors.ok and interiors.ok, "The saved building files could not be read.")
	var layer = InteriorLayer.new()
	root.add_child(layer)
	layer.set_town_directory(town_directory)
	var checked := 0
	var creator_names: Array[String] = []
	for feature_id_value in interiors.data.get("buildings", {}).keys():
		var feature_id := str(feature_id_value)
		var record: Dictionary = interiors.data.buildings[feature_id]
		var exterior: Dictionary = exteriors.data.get("buildings", {}).get(feature_id, {})
		var door_ids: Dictionary = {}
		for door_value in exterior.get("doors", []):
			if door_value is Dictionary: door_ids[str(door_value.get("id", ""))] = true
		var floors: Array = record.get("floors", [])
		if floors.is_empty(): continue
		var ground: Dictionary = floors[0]
		for link_value in ground.get("entry_links", []):
			var link: Dictionary = link_value
			assert(door_ids.has(str(link.get("exterior_entrance_id", ""))), "Building %s has an interior link to a missing exterior door." % feature_id)
			var opened: Dictionary = layer.open_floor(record, ground, link, 8.0)
			assert(opened.ok, "Building %s could not open: %s" % [feature_id, str(opened.get("message", "unknown entry error"))])
			layer.close_floor()
			checked += 1
		var custom_name := str(exterior.get("custom_name", ""))
		if not custom_name.is_empty(): creator_names.append(custom_name)
	assert(checked > 0, "The selected town has no saved interior entry links to check.")
	print("SAVED BUILDING ENTRIES PASSED: %d linked entrances opened; creator names: %s" % [checked, ", ".join(creator_names)])
	quit(0)
