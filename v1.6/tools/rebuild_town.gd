extends SceneTree

const ImporterScript = preload("res://scripts/towns/osm_importer.gd")
const ContentPackScript = preload("res://scripts/content/content_pack.gd")
const GameSettingsScript = preload("res://scripts/settings/game_settings_store.gd")


func _initialize() -> void:
	var town_directory := _argument_value("--town")
	if town_directory.is_empty():
		_fail("Use --town followed by a Creator Studio project folder.")
		return
	if not town_directory.is_absolute_path():
		town_directory = ProjectSettings.globalize_path(town_directory)
	var town_result := _read_json(town_directory.path_join("town.json"))
	if not town_result.ok:
		_fail(town_result.message)
		return
	var town: Dictionary = town_result.data
	var sources := PackedStringArray()
	for original_value in town.get("source", {}).get("original_files", []):
		var original := str(original_value)
		if FileAccess.file_exists(original):
			sources.append(original)
	if sources.is_empty():
		for relative_value in town.get("source", {}).get("files", []):
			var copied := town_directory.path_join(str(relative_value))
			if FileAccess.file_exists(copied):
				sources.append(copied)
	if sources.is_empty():
		_fail("The project's original and copied OSM source files are missing.")
		return
	var imported: Dictionary = ImporterScript.new().parse_files(sources)
	if not imported.ok:
		_fail(imported.message)
		return
	var settings_result: Dictionary = GameSettingsScript.load_from_town(town_directory)
	if not settings_result.ok:
		_fail(settings_result.message)
		return
	var result: Dictionary = ContentPackScript.new().update_town(
		town_directory, str(town.display_name), imported,
		town.get("cbd", {}).get("bounds", {}), town.get("starting_location", {}),
		settings_result.settings
	)
	if not result.ok:
		_fail(result.message)
		return
	print(JSON.stringify({"ok": true, "town_directory": town_directory, "statistics": imported.statistics, "warnings": imported.warnings}))
	quit(0)


func _argument_value(flag: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find(flag)
	return str(arguments[index + 1]) if index >= 0 and index + 1 < arguments.size() else ""


func _read_json(path_value: String) -> Dictionary:
	if not FileAccess.file_exists(path_value):
		return {"ok": false, "message": "%s is missing." % path_value.get_file()}
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "%s could not be read." % path_value.get_file()}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "%s is not valid project data." % path_value.get_file()}
	return {"ok": true, "data": parsed}


func _fail(message: String) -> void:
	printerr(JSON.stringify({"ok": false, "error": message}))
	quit(1)
