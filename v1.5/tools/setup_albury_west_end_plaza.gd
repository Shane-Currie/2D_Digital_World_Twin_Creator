extends SceneTree

## Reproducible demo setup for the West End Plaza Building Creator asset.
## This script edits only the generated Albury town project supplied as its first argument.

const BuildingExteriorStoreScript = preload("res://scripts/buildings/building_exterior_store.gd")
const FEATURE_ID := "115073717"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		_fail("Provide the Albury town directory and the source PNG path.")
		return
	var town_directory := str(args[0]).replace("\\", "/")
	var source_png := str(args[1]).replace("\\", "/")
	var town := _read_json(town_directory.path_join("town.json"))
	var feature_data := _read_json(town_directory.path_join("data/map_features.json"))
	var navigation := _read_json(town_directory.path_join("data/navigation_graphs.json"))
	if town.is_empty() or feature_data.is_empty() or navigation.is_empty():
		_fail("The selected Albury project is missing its generated town data.")
		return
	var features: Array = feature_data.get("features", [])
	var plaza: Dictionary = {}
	for feature_value in features:
		if feature_value is Dictionary and str(feature_value.get("id", "")) == FEATURE_ID:
			plaza = feature_value
			break
	if plaza.is_empty() or str(plaza.get("tags", {}).get("name", "")) != "West End Plaza":
		_fail("The imported Albury map does not contain the expected West End Plaza footprint.")
		return
	var store = BuildingExteriorStoreScript.new()
	var load_result: Dictionary = store.load_from_town(town_directory)
	if not load_result.get("ok", false):
		_fail(str(load_result.get("message", "Could not load building designs.")))
		return
	var import_result: Dictionary = store.import_exterior(town_directory, load_result.data, FEATURE_ID, source_png)
	if not import_result.get("ok", false):
		_fail(str(import_result.get("message", "Could not import the plaza artwork.")))
		return
	var data: Dictionary = import_result.data
	# Keep the setup repeatable: these are demo entrances, not claims that OSM mapped a door.
	data.buildings[FEATURE_ID]["doors"] = []
	var requests := [
		{"longitude": 146.91400, "latitude": -36.08096}, # Dean Street/public north edge
		{"longitude": 146.91558, "latitude": -36.08173}, # Kiewa Street/east edge
	]
	for requested_location in requests:
		var door_result: Dictionary = store.set_door(
			data, plaza, requested_location, features,
			town.get("map_bounds", {}), navigation
		)
		if door_result.get("ok", false):
			data = door_result.data
		else:
			print("Skipped one demo entrance: %s" % str(door_result.get("message", "no clear approach")))
	var doors: Array = data.buildings[FEATURE_ID].get("doors", [])
	if doors.is_empty():
		_fail("The plaza artwork imported, but no safe test entrance could be placed.")
		return
	var save_result: Dictionary = store.save_to_town(town_directory, data)
	if not save_result.get("ok", false):
		_fail(str(save_result.get("message", "Could not save the plaza design.")))
		return
	print("WEST END PLAZA READY")
	print("Exterior: %s" % str(save_result.data.buildings[FEATURE_ID].exterior.relative_path))
	print("Entrances: %d" % doors.size())
	quit()


func _read_json(path_value: String) -> Dictionary:
	if not FileAccess.file_exists(path_value):
		return {}
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
