extends SceneTree

## Codex-friendly equivalent of Building Creator's Export footprint for Paint button.
## Usage: godot --headless --path <creator> --script res://tools/export_building_footprint.gd -- <town> <feature-id> <output.png>

const FootprintExporterScript = preload("res://scripts/buildings/building_footprint_exporter.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		_fail("Provide a town directory, building feature ID and output PNG path.")
		return
	var town_directory := str(args[0])
	var feature_id := str(args[1])
	var map_path := town_directory.path_join("data/map_features.json")
	if not FileAccess.file_exists(map_path):
		_fail("The selected town does not contain data/map_features.json.")
		return
	var map_data = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	if not map_data is Dictionary:
		_fail("The selected town's map feature file could not be read.")
		return
	var selected_feature: Dictionary = {}
	for feature_value in map_data.get("features", []):
		if feature_value is Dictionary and str(feature_value.get("id", "")) == feature_id:
			selected_feature = feature_value
			break
	if selected_feature.is_empty():
		_fail("Building %s was not found in the selected town." % feature_id)
		return
	var result: Dictionary = FootprintExporterScript.new().export_png(selected_feature, str(args[2]))
	if not result.get("ok", false):
		_fail(str(result.get("message", "The footprint could not be exported.")))
		return
	print(JSON.stringify(result))
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
