extends SceneTree

const ProjectLoaderScript = preload("res://scripts/content/project_loader.gd")
const ContentPackWriterScript = preload("res://scripts/content/content_pack.gd")
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")


func _initialize() -> void:
	var town_directory := _argument_value("--town")
	if town_directory.is_empty():
		_fail("Use --town followed by a Creator Studio project folder.")
		return
	var project: Dictionary = ProjectLoaderScript.new().load_project(town_directory)
	if not project.ok:
		_fail(project.message)
		return
	var settings_result: Dictionary = GameSettingsStoreScript.load_from_town(project.town_directory)
	if not settings_result.ok:
		_fail(settings_result.message)
		return
	var result: Dictionary = ContentPackWriterScript.new().update_town(
		project.town_directory,
		str(project.town.display_name),
		project.import_result,
		project.town.get("cbd", {}).get("bounds", {}),
		project.town.get("starting_location", {}),
		settings_result.settings
	)
	if not result.ok:
		_fail(result.message)
		return
	print(JSON.stringify({"ok": true, "town_directory": result.town_directory, "navigation": result.validation.navigation}))
	quit(0)


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index] == name and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""


func _fail(message: String) -> void:
	printerr(JSON.stringify({"ok": false, "error": message}))
	quit(1)
