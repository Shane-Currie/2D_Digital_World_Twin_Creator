extends SceneTree

const StoreScript = preload("res://scripts/interiors/building_interior_store.gd")


func _initialize() -> void:
	var store = StoreScript.new()
	var feature := {
		"id": "way/interior-test", "kind": "building", "tags": {"name": "Interior Test"},
		"points": [[149.0000, -35.0000], [149.0004, -35.0000], [149.0004, -35.0004], [149.00025, -35.0004], [149.00025, -35.0002], [149.0000, -35.0002], [149.0000, -35.0000]],
		"holes": [[[149.00028, -35.00008], [149.00035, -35.00008], [149.00035, -35.00015], [149.00028, -35.00015], [149.00028, -35.00008]]]
	}
	var data: Dictionary = store.empty_data()
	var create_result: Dictionary = store.create_blank_ground_floor(data, feature)
	assert(create_result.ok, str(create_result.get("message", "")))
	data = create_result.data
	var ground: Dictionary = data.buildings[feature.id].floors[0]
	assert(ground.boundary_metres.size() == 6, "The footprint shape was not preserved.")
	assert(ground.holes_metres.size() == 1, "The footprint courtyard was not preserved.")
	assert(is_equal_approx(float(ground.footprint_scale), 1.0), "The ground floor did not begin at the exact footprint scale.")
	var entry_position := Vector2(float(ground.width_metres) * 0.1, float(ground.height_metres) * 0.1)
	var entry_result: Dictionary = store.set_entry_spawn(data, feature.id, "entrance_1", entry_position)
	assert(entry_result.ok, str(entry_result.get("message", "")))
	data = entry_result.data
	var outside_result: Dictionary = store.set_entry_spawn(data, feature.id, "entrance_2", Vector2(-2, -2))
	assert(not outside_result.ok, "An entry point outside the footprint was accepted.")
	var hole_values: Array = ground.holes_metres[0]
	var hole_centre := Vector2.ZERO
	for point in hole_values:
		hole_centre += Vector2(float(point[0]), float(point[1]))
	hole_centre /= hole_values.size()
	var hole_result: Dictionary = store.set_entry_spawn(data, feature.id, "entrance_2", hole_centre)
	assert(not hole_result.ok, "An entry point inside a courtyard hole was accepted.")
	var add_result: Dictionary = store.add_upper_floor(data, feature.id)
	assert(add_result.ok, str(add_result.get("message", "")))
	data = add_result.data
	assert(data.buildings[feature.id].floors.size() == 2, "The upper floor was not added.")
	assert(data.buildings[feature.id].floors[1].boundary_metres == data.buildings[feature.id].floors[0].boundary_metres, "The upper floor did not inherit the building footprint shape.")
	var resize_result: Dictionary = store.resize_floor(data, feature.id, "floor_1", 1.5)
	assert(resize_result.ok, str(resize_result.get("message", "")))
	data = resize_result.data
	var upper: Dictionary = data.buildings[feature.id].floors[1]
	assert(is_equal_approx(float(upper.footprint_scale), 1.5), "The creator-adjusted floor size was not stored.")
	assert(absf(float(upper.width_metres) - float(ground.width_metres) * 1.5) <= 0.02, "Resizing did not preserve the footprint proportions.")
	var exterior_data := {"buildings": {}}
	exterior_data.buildings[feature.id] = {"feature_id": feature.id, "custom_name": "Renamed Creator Building", "doors": [{"id": "front_door"}]}
	var synchronized := store.synchronize_with_exteriors(data, exterior_data, [feature])
	assert(synchronized.ok and synchronized.renamed == 1 and synchronized.repaired_links == 1, "The renamed exterior was not safely synchronised with its interior.")
	data = synchronized.data
	assert(data.buildings[feature.id].name == "Renamed Creator Building", "The interior retained its old display name.")
	assert(data.buildings[feature.id].floors[0].entry_links[0].exterior_entrance_id == "front_door", "An unambiguous legacy entrance link was not repaired.")
	var town_directory := ProjectSettings.globalize_path("res://tools/tests/output/building-interior-town")
	var save_result: Dictionary = store.save_to_town(town_directory, data)
	assert(save_result.ok, str(save_result.get("message", "")))
	var loaded: Dictionary = store.load_from_town(town_directory)
	assert(loaded.ok and loaded.data.buildings[feature.id].floors.size() == 2, "The multi-floor interior did not reopen.")
	print("BUILDING INTERIORS PASSED: exact footprint ground floor, courtyard, safe entry, renamed-building link synchronisation, upper floor, proportional resizing and persistence.")
	quit(0)
