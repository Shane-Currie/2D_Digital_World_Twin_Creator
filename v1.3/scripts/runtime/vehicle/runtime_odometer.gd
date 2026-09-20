class_name RuntimeOdometer
extends RefCounted

## Distance belongs to the player's wagon, not to an OSM road route. Count only
## movement accepted by the vehicle physics, then convert town pixels to metres.
const SAVE_INTERVAL_SECONDS := 10.0
const SAVE_FILE := "vehicle_odometer.json"

var total_metres := 0.0
var trip_metres := 0.0
var save_path := ""
var saving_enabled := true
var dirty := false
var seconds_since_save := 0.0
var recovered_from_backup := false


func load_for_town(town_directory: String, enable_saving: bool = true) -> Dictionary:
	save_path = town_directory.path_join("saves").path_join(SAVE_FILE)
	saving_enabled = enable_saving
	var primary := _read_save(save_path)
	if primary.ok:
		_apply_save(primary.data)
		return {"ok": true, "message": ""}
	if not FileAccess.file_exists(save_path):
		return {"ok": true, "message": ""}
	var backup := _read_save(save_path + ".bak")
	if backup.ok:
		_apply_save(backup.data)
		recovered_from_backup = true
		return {"ok": true, "message": "The odometer was recovered from its backup."}
	# Do not replace unreadable mileage with a new zero-valued save.
	saving_enabled = false
	return {"ok": false, "message": "The odometer save could not be read. Your existing mileage file was left untouched."}


func record_world_displacement(previous_position: Vector2, new_position: Vector2, pixels_per_metre: float) -> void:
	if pixels_per_metre <= 0.0:
		return
	var metres := previous_position.distance_to(new_position) / pixels_per_metre
	if metres <= 0.0:
		return
	total_metres += metres
	trip_metres += metres
	dirty = true


func reset_trip() -> Dictionary:
	trip_metres = 0.0
	dirty = true
	return save()


func tick(delta: float) -> Dictionary:
	if not dirty or not saving_enabled:
		return {"ok": true}
	seconds_since_save += delta
	if seconds_since_save >= SAVE_INTERVAL_SECONDS:
		var result := save()
		if not result.ok:
			seconds_since_save = 0.0
		return result
	return {"ok": true}


func save() -> Dictionary:
	if not dirty or not saving_enabled:
		return {"ok": saving_enabled, "message": "Odometer saving is unavailable." if not saving_enabled else ""}
	if save_path.is_empty():
		return {"ok": false, "message": "No town save location was supplied for the odometer."}
	var directory_error := DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	if directory_error != OK:
		return {"ok": false, "message": "The town's saves folder could not be created."}
	if FileAccess.file_exists(save_path) and not recovered_from_backup:
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			return {"ok": false, "message": "The previous odometer reading could not be backed up."}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "The odometer save could not be written."}
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"total_metres": total_metres,
		"trip_metres": trip_metres
	}, "  ") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "message": "The odometer save could not be completed."}
	recovered_from_backup = false
	dirty = false
	seconds_since_save = 0.0
	return {"ok": true, "message": ""}


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"ok": false}
	if int(parsed.get("schema_version", 0)) != 1:
		return {"ok": false}
	for key in ["total_metres", "trip_metres"]:
		var value: Variant = parsed.get(key)
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or is_nan(float(value)) or is_inf(float(value)) or float(value) < 0.0:
			return {"ok": false}
	if float(parsed.trip_metres) > float(parsed.total_metres) + 0.001:
		return {"ok": false}
	return {"ok": true, "data": parsed}


func _apply_save(data: Dictionary) -> void:
	total_metres = float(data.total_metres)
	trip_metres = float(data.trip_metres)
	dirty = false
	seconds_since_save = 0.0
