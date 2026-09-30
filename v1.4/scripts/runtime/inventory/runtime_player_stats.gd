class_name RuntimePlayerStats
extends RefCounted

const SAVE_FILE := "player_stats.json"
const SCHEMA_VERSION := 1
const MAXIMUM := 100
const STARTING_VALUE := 50

var nutrient := STARTING_VALUE
var hydration := STARTING_VALUE
var save_path := ""
var saving_enabled := true
var dirty := false
var recovered_from_backup := false


func load_for_town(town_directory: String, enable_saving := true) -> Dictionary:
	save_path = town_directory.path_join("saves").path_join(SAVE_FILE)
	saving_enabled = enable_saving
	nutrient = STARTING_VALUE
	hydration = STARTING_VALUE
	dirty = false
	var primary := _read_save(save_path)
	if primary.ok:
		_apply(primary.data)
		return {"ok": true, "message": ""}
	if not FileAccess.file_exists(save_path):
		return {"ok": true, "message": ""}
	var backup := _read_save(save_path + ".bak")
	if backup.ok:
		_apply(backup.data)
		recovered_from_backup = true
		return {"ok": true, "message": "Player nutrition and hydration were recovered from their backup."}
	saving_enabled = false
	return {"ok": false, "message": "The player-stat save could not be read. The existing file was left untouched."}


func available_gain(stat_type: String) -> int:
	if stat_type == "nutrient":
		return MAXIMUM - nutrient
	if stat_type == "hydration":
		return MAXIMUM - hydration
	return 0


func apply_points(stat_type: String, points: int) -> Dictionary:
	if stat_type not in ["nutrient", "hydration"] or points <= 0:
		return {"ok": false, "message": "This item does not restore nutrients or hydration."}
	var actual_gain := mini(points, available_gain(stat_type))
	if actual_gain <= 0:
		return {"ok": false, "message": "%s is already full." % ("Nutrients" if stat_type == "nutrient" else "Hydration")}
	if stat_type == "nutrient":
		nutrient += actual_gain
	else:
		hydration += actual_gain
	dirty = true
	var save_result := save()
	if not save_result.ok:
		if stat_type == "nutrient": nutrient -= actual_gain
		else: hydration -= actual_gain
		dirty = false
		return save_result
	return {"ok": true, "gained": actual_gain, "message": "%s restored by %d points." % ["Nutrients" if stat_type == "nutrient" else "Hydration", actual_gain]}


func save() -> Dictionary:
	if not saving_enabled:
		return {"ok": false, "message": "Player-stat saving is unavailable."}
	if not dirty:
		return {"ok": true, "message": ""}
	if save_path.is_empty() or DirAccess.make_dir_recursive_absolute(save_path.get_base_dir()) != OK:
		return {"ok": false, "message": "The player-stat save location is unavailable."}
	if FileAccess.file_exists(save_path) and not recovered_from_backup:
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			return {"ok": false, "message": "The previous player stats could not be backed up."}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Player stats could not be written."}
	file.store_string(JSON.stringify({"schema_version": SCHEMA_VERSION, "nutrient": nutrient, "hydration": hydration}, "  ") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "message": "The player-stat save could not be completed."}
	recovered_from_backup = false
	dirty = false
	return {"ok": true, "message": ""}


func _read_save(path_value: String) -> Dictionary:
	if not FileAccess.file_exists(path_value):
		return {"ok": false}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"ok": false}
	for key in ["nutrient", "hydration"]:
		var value: Variant = parsed.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_equal_approx(float(value), roundf(float(value))) or int(value) < 0 or int(value) > MAXIMUM:
			return {"ok": false}
	return {"ok": true, "data": parsed}


func _apply(data: Dictionary) -> void:
	nutrient = int(data.nutrient)
	hydration = int(data.hydration)
	dirty = false

