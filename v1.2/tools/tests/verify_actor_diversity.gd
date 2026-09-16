extends SceneTree

const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var migrated_tones := GameSettingsStoreScript.migrate_skin_tones({
		"very_light_percent": 5, "light_percent": 10, "medium_light_percent": 15,
		"medium_percent": 20, "medium_dark_percent": 15, "dark_percent": 20, "very_dark_percent": 15
	})
	assert(migrated_tones == {"light_percent": 30.0, "medium_percent": 35.0, "dark_percent": 35.0})
	var graph := {
		"nodes": {0: Vector2.ZERO},
		"adjacency": {},
		"all_ids": [0],
		"cbd_ids": [0]
	}
	var population = PopulationScript.new()
	population.graphs = {"person": graph, "traffic": graph}
	population.rng.seed = 1409
	population.skin_tone_distribution = {"light_percent": 0, "medium_percent": 0, "dark_percent": 100}
	population._add_population("person", 5, 0, 30.0)
	var odd_gender_counts := _gender_counts(population.agents)
	assert(odd_gender_counts.woman == 3 and odd_gender_counts.man == 2)
	for person in population.agents:
		assert(person.skin_tone_group == "dark")
		assert(str(person.npc_asset).begins_with("npc_dark_%s_" % person.gender))
		assert(str(person.age_group) in PopulationScript.AGE_GROUPS)
	population.agents.clear()
	population._add_population("person", 6, 0, 30.0)
	var even_gender_counts := _gender_counts(population.agents)
	assert(even_gender_counts.woman == 3 and even_gender_counts.man == 3)
	population.agents.clear()
	population._add_population("traffic", 9, 0, 75.0)
	var style_counts := {"sedan": 0, "wagon": 0, "ute": 0}
	var static_car_assets := {}
	for car in population.agents:
		style_counts[str(car.vehicle_style)] += 1
		static_car_assets[str(car.vehicle_asset)] = true
	assert(style_counts == {"sedan": 4, "wagon": 4, "ute": 1})
	assert(static_car_assets.size() == 9)
	for asset_name in ActorArt.PATHS:
		var image := Image.load_from_file(str(ActorArt.PATHS[asset_name]))
		assert(image != null and not image.is_empty())
		assert(image.get_pixel(0, 0).a == 0.0, "Sprite padding must have genuine alpha: %s" % asset_name)
		assert(image.get_used_rect().has_area(), "Sprite body disappeared: %s" % asset_name)
	population.free()
	print("ACTOR DIVERSITY PASSED: fixed NPC catalogue, three tone groups, odd/even gender split, three traffic bodies and transparent PNGs")
	quit()


func _gender_counts(agents: Array[Dictionary]) -> Dictionary:
	var counts := {"man": 0, "woman": 0}
	for person in agents:
		counts[str(person.gender)] += 1
	return counts
