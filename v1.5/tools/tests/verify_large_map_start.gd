extends SceneTree

const OsmImporterScript = preload("res://scripts/towns/osm_importer.gd")
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const NavigationBuilderScript = preload("res://scripts/navigation/osm_navigation_builder.gd")


func _initialize() -> void:
	var source_directory := ProjectSettings.globalize_path("res://../../v1.3/data/towns/central_wodonga/central_osm_chunks")
	var source_paths := PackedStringArray()
	for file_name in DirAccess.get_files_at(source_directory):
		if file_name.get_extension().to_lower() == "osm":
			source_paths.append(source_directory.path_join(file_name))
	source_paths.sort()
	assert(source_paths.size() == 18, "The full Central Wodonga performance fixture is incomplete.")
	var imported: Dictionary = OsmImporterScript.new().parse_files(source_paths)
	assert(imported.ok, "The Central Wodonga OSM performance fixture could not be read.")
	assert(imported.statistics.buildings >= 4000)
	assert(imported.statistics.roads >= 3000)

	var started_at := Time.get_ticks_msec()
	var result: Dictionary = SpawnSafetyScript.create_starting_location(
		{"longitude": 146.86555713, "latitude": -36.1436397},
		imported.features
	)
	var elapsed_milliseconds := Time.get_ticks_msec() - started_at
	assert(result.ok, "A clear vehicle start was not found on the large-map fixture.")
	assert(elapsed_milliseconds < 1000, "Starting-location search took too long: %d ms" % elapsed_milliseconds)
	var navigation_started_at := Time.get_ticks_msec()
	var navigation: Dictionary = NavigationBuilderScript.new().build(
		imported.features,
		{"west": 146.86, "south": -36.16, "east": 146.90, "north": -36.11},
		result.starting_location,
		{"road_rules": {"driving_side": "right"}}
	)
	var navigation_milliseconds := Time.get_ticks_msec() - navigation_started_at
	assert(navigation.ok)
	assert(navigation.data.vehicle.nodes.size() > 1000)
	assert(navigation.data.pedestrian.nodes.size() > 1000)
	assert(navigation.data.road_rules.driving_side == "right")
	assert(navigation_milliseconds < 5000, "Navigation generation took too long: %d ms" % navigation_milliseconds)
	print("LARGE MAP CHECK PASSED: %d buildings, %d roads, safe start in %d ms, navigation in %d ms." % [
		imported.statistics.buildings,
		imported.statistics.roads,
		elapsed_milliseconds,
		navigation_milliseconds
	])
	quit(0)
