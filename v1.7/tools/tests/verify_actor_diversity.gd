extends SceneTree

const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(is_equal_approx(PopulationScript.NPC_VISUAL_SCALE * 25.0, 13.75), "NPC artwork did not receive the requested 25% increase.")
	assert(is_equal_approx(PopulationScript.NPR_VISUAL_SCALE, 0.625), "NPR artwork did not receive the requested 25% increase.")
	assert(is_equal_approx(PlayerScript.PLAYER_VISUAL_SCALE * 27.0, 13.75), "Player artwork did not receive the requested 25% increase.")
	assert(ActorArt.GROUND_CHARACTER_DRAW_SIZE == Vector2(7.5, 13.75), "Player and NPC production artwork does not share the enlarged visual size.")
	var grounded_rect := ActorArt.grounded_character_rect()
	assert(is_equal_approx(grounded_rect.end.y, 0.0), "The shared actor box is not anchored at the characters' feet.")
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
		if str(asset_name).begins_with("npc_"):
			for facing in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
				assert(not ActorArt.directional_sprite(str(asset_name), facing).is_empty(), "NPC direction missing: %s %s" % [asset_name, facing])
	assert(ActorArt.direction_column(Vector2.DOWN) == 0)
	assert(ActorArt.direction_column(Vector2.LEFT) == 1)
	assert(ActorArt.direction_column(Vector2.RIGHT) == 2)
	assert(ActorArt.direction_column(Vector2.UP) == 3)
	for atlas_name in ActorArt.DIRECTIONAL_ATLASES:
		var atlas_path := str(ActorArt.DIRECTIONAL_ATLASES[atlas_name].path)
		var atlas_image := Image.load_from_file(atlas_path)
		assert(atlas_image != null and not atlas_image.is_empty(), "Directional atlas did not load: %s" % atlas_name)
		assert(atlas_image.get_pixel(0, 0).a == 0.0, "Directional atlas padding must have genuine alpha: %s" % atlas_name)
	var facing_regions := {}
	for facing in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		var directional := ActorArt.directional_sprite("npc_medium_woman_older", facing)
		assert(not directional.is_empty())
		assert(Rect2(directional.region).has_area())
		facing_regions[str(directional.region)] = true
	assert(facing_regions.size() == 4, "NPC directions must use four distinct atlas cells.")
	var player_frames := {}
	var robot_frames := {}
	for frame in 4:
		var player_frame := ActorArt.directional_sprite("player", Vector2.RIGHT, frame)
		var robot_frame := ActorArt.directional_sprite("npr", Vector2.LEFT, frame)
		assert(not player_frame.is_empty() and not robot_frame.is_empty())
		player_frames[str(player_frame.region)] = true
		robot_frames[str(robot_frame.region)] = true
	assert(player_frames.size() == 4 and robot_frames.size() == 4, "Player and NPR need four walk frames per direction.")
	population.free()
	print("ACTOR DIVERSITY PASSED: static catalogue, four directions, player/NPR walk frames, balanced genders, traffic bodies and transparent PNGs")
	quit()


func _gender_counts(agents: Array[Dictionary]) -> Dictionary:
	var counts := {"man": 0, "woman": 0}
	for person in agents:
		counts[str(person.gender)] += 1
	return counts
