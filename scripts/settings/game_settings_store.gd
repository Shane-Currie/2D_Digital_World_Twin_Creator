class_name CreatorGameSettingsStore
extends RefCounted

const SCHEMA_VERSION := 1
const FILE_NAME := "game_settings.json"


static func recommended_settings() -> Dictionary:
	# These defaults match the proven v1.3 Central Wodonga gameplay settings.
	return {
		"schema_version": SCHEMA_VERSION,
		"population": {
			"traffic_car_count": 150,
			"pedestrian_count": 150,
			"cbd_car_percent": 65,
			"cbd_pedestrian_percent": 65,
			"robot_count": 20,
			"cbd_robot_percent": 100,
			"drone_count": 10,
			"cbd_drone_percent": 90
		},
		"road_rules": {
			"driving_side": "left"
		},
		"skin_tone_distribution": equalized_skin_tones(),
		"camera": {
			"character_zoom": 2.0
		},
		"driving": {
			"forward_speed": 108.0,
			"reverse_speed": 36.0,
			"acceleration": 42.0,
			"reverse_acceleration": 70.0,
			"coast_deceleration": 30.0,
			"brake_deceleration": 140.0,
			"steering_rate": 1.9,
			"camera_zoom_multiplier": 1.5
		},
		"traffic_recovery": {
			"enabled": true,
			"jam_timeout_seconds": 30.0,
			"recovery_spacing_seconds": 2.0,
			"respawn_distance_pixels": 800.0,
			"respawn_attempts": 24
		}
	}


static func load_from_town(town_directory: String) -> Dictionary:
	var path_value := town_directory.path_join(FILE_NAME)
	if not FileAccess.file_exists(path_value):
		return {"ok": false, "message": "This town does not have game settings yet.", "settings": recommended_settings()}
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not read the game settings.", "settings": recommended_settings()}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "The game settings file is damaged or incomplete.", "settings": recommended_settings()}
	if not parsed.has("road_rules"):
		parsed["road_rules"] = recommended_settings().road_rules.duplicate(true)
	var recommended := recommended_settings()
	if not parsed.get("camera", {}) is Dictionary:
		parsed["camera"] = recommended.camera.duplicate(true)
	elif not parsed.get("camera", {}).has("character_zoom"):
		parsed["camera"] = recommended.camera.duplicate(true)
	for key in recommended.population:
		if not parsed.get("population", {}).has(key):
			parsed["population"][key] = recommended.population[key]
	parsed["skin_tone_distribution"] = migrate_skin_tones(parsed.get("skin_tone_distribution", {}))
	if not parsed.get("driving", {}) is Dictionary:
		parsed["driving"] = recommended.driving.duplicate(true)
	elif not parsed.get("driving", {}).has("camera_zoom_multiplier"):
		parsed["driving"]["camera_zoom_multiplier"] = recommended.driving.camera_zoom_multiplier
	# A pre-release draft briefly used identity labels. They are deliberately not
	# part of the saved format; only neutral visual tone ranges are retained.
	parsed.erase("community_representation")
	var validation := validate(parsed)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0], "settings": recommended_settings(), "validation": validation}
	return {"ok": true, "message": "Game settings loaded.", "settings": parsed, "validation": validation}


static func save_to_town(town_directory: String, settings: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(town_directory.path_join("town.json")):
		return {"ok": false, "message": "Choose a town project folder containing town.json."}
	var validation := validate(settings)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0], "validation": validation}
	var file := FileAccess.open(town_directory.path_join(FILE_NAME), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save the game settings."}
	file.store_string(JSON.stringify(settings, "\t") + "\n")
	return {"ok": true, "message": "Game settings saved.", "validation": validation}


static func validate(settings: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if int(settings.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("The game settings use an unsupported format.")
	var population: Dictionary = settings.get("population", {})
	var road_rules: Dictionary = settings.get("road_rules", {})
	var skin_tones: Dictionary = settings.get("skin_tone_distribution", {})
	var camera: Dictionary = settings.get("camera", {})
	var driving: Dictionary = settings.get("driving", {})
	var recovery: Dictionary = settings.get("traffic_recovery", {})
	_check_number(errors, population, "traffic_car_count", 0.0, 1000.0, "Traffic count")
	_check_number(errors, population, "pedestrian_count", 0.0, 2000.0, "Pedestrian count")
	_check_number(errors, population, "cbd_car_percent", 0.0, 100.0, "CBD traffic percentage")
	_check_number(errors, population, "cbd_pedestrian_percent", 0.0, 100.0, "CBD pedestrian percentage")
	_check_number(errors, population, "robot_count", 0.0, 1000.0, "NPR count")
	_check_number(errors, population, "cbd_robot_percent", 0.0, 100.0, "NPR CBD percentage")
	_check_number(errors, population, "drone_count", 0.0, 1000.0, "NPD count")
	_check_number(errors, population, "cbd_drone_percent", 0.0, 100.0, "NPD CBD percentage")
	if str(road_rules.get("driving_side", "")) not in ["left", "right"]:
		errors.append("Choose whether traffic drives on the left or right side of the road.")
	var skin_tone_total := 0.0
	for key in recommended_settings().skin_tone_distribution:
		_check_number(errors, skin_tones, key, 0.0, 100.0, "Skin tone percentage")
		skin_tone_total += float(skin_tones.get(key, 0.0))
	if absf(skin_tone_total - 100.0) > 0.05:
		errors.append("Skin pigmentation tone percentages must total 100%%. They currently total %.2f%%." % skin_tone_total)
	# v1.1 and early v1.2 saves lacked this group. They retain 1.0x on foot
	# until loaded and resaved; a present but damaged group must still fail.
	if settings.has("camera"):
		_check_number(errors, camera, "character_zoom", 0.2, 3.0, "On-foot camera zoom")
	_check_number(errors, driving, "forward_speed", 1.0, 400.0, "Forward speed")
	_check_number(errors, driving, "reverse_speed", 1.0, 200.0, "Reverse speed")
	_check_number(errors, driving, "acceleration", 1.0, 400.0, "Acceleration")
	_check_number(errors, driving, "reverse_acceleration", 1.0, 400.0, "Reverse acceleration")
	_check_number(errors, driving, "coast_deceleration", 1.0, 400.0, "Coasting slowdown")
	_check_number(errors, driving, "brake_deceleration", 1.0, 800.0, "Brake strength")
	_check_number(errors, driving, "steering_rate", 0.1, 8.0, "Steering speed")
	_check_number(errors, driving, "camera_zoom_multiplier", 0.2, 3.0, "In-car camera zoom")
	if not recovery.has("enabled") or not recovery.enabled is bool:
		errors.append("Traffic jam recovery must be on or off.")
	_check_number(errors, recovery, "jam_timeout_seconds", 5.0, 300.0, "Jam timeout")
	_check_number(errors, recovery, "recovery_spacing_seconds", 0.25, 30.0, "Recovery spacing")
	_check_number(errors, recovery, "respawn_distance_pixels", 100.0, 10000.0, "Traffic respawn distance")
	_check_number(errors, recovery, "respawn_attempts", 1.0, 200.0, "Traffic respawn attempts")
	if int(population.get("traffic_car_count", 0)) > 400:
		warnings.append("More than 400 traffic cars may run slowly on some computers.")
	if int(population.get("pedestrian_count", 0)) > 500:
		warnings.append("More than 500 pedestrians may run slowly on some computers.")
	if int(population.get("robot_count", 0)) > 200:
		warnings.append("More than 200 walking robots may run slowly on some computers.")
	if int(population.get("drone_count", 0)) > 200:
		warnings.append("More than 200 flying drones may run slowly on some computers.")
	return {"schema_version": SCHEMA_VERSION, "passed": errors.is_empty(), "errors": errors, "warnings": warnings}


static func equalized_skin_tones() -> Dictionary:
	var equal_share := 100.0 / 3.0
	return {
		"light_percent": equal_share,
		"medium_percent": equal_share,
		"dark_percent": equal_share
	}


static func migrate_skin_tones(saved: Variant) -> Dictionary:
	if not saved is Dictionary:
		return equalized_skin_tones()
	var values: Dictionary = saved
	# Early v1.2 projects used seven closely spaced tone controls. Combine those
	# values into the three static-art groups without losing the creator's total.
	if values.has("very_light_percent") or values.has("medium_light_percent") or values.has("medium_dark_percent") or values.has("very_dark_percent"):
		return {
			"light_percent": float(values.get("very_light_percent", 0.0)) + float(values.get("light_percent", 0.0)) + float(values.get("medium_light_percent", 0.0)),
			"medium_percent": float(values.get("medium_percent", 0.0)) + float(values.get("medium_dark_percent", 0.0)),
			"dark_percent": float(values.get("dark_percent", 0.0)) + float(values.get("very_dark_percent", 0.0))
		}
	for key in equalized_skin_tones():
		if not values.has(key):
			return equalized_skin_tones()
	return {
		"light_percent": float(values.light_percent),
		"medium_percent": float(values.medium_percent),
		"dark_percent": float(values.dark_percent)
	}


static func _check_number(errors: Array[String], group: Dictionary, key: String, minimum: float, maximum: float, label: String) -> void:
	if not group.has(key) or not group[key] is int and not group[key] is float:
		errors.append("%s is missing or is not a number." % label)
		return
	var value := float(group[key])
	if value < minimum or value > maximum:
		errors.append("%s must be between %s and %s." % [label, minimum, maximum])
