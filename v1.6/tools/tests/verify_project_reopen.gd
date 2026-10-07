extends SceneTree

const ProjectLoaderScript = preload("res://scripts/content/project_loader.gd")


func _initialize() -> void:
	var town_directory := ProjectSettings.globalize_path("res://../test/wodonga_test")
	var result: Dictionary = ProjectLoaderScript.new().load_project(town_directory)
	assert(result.ok, result.message)
	assert(result.town.display_name == "Wodonga Test")
	assert(result.import_result.statistics.buildings > 0)
	assert(result.import_result.statistics.roads > 0)
	assert(result.import_result.features.size() == result.import_result.statistics.buildings + result.import_result.statistics.roads)
	assert(not result.source_files.is_empty())
	assert(result.runtime_ready, "The upgraded project must expose the shared playable preview.")
	assert(str(result.runtime_profile.get("template_status", "")) == "preview_ready")
	assert(result.navigation_ready, "The saved Wodonga navigation graphs were not detected.")
	assert(not result.town.cbd.bounds.is_empty())
	assert(result.town.starting_location.has("vehicle"))
	var albury_workspace := ProjectSettings.globalize_path("res://../test/albury test")
	var nested_result: Dictionary = ProjectLoaderScript.new().load_project(albury_workspace)
	assert(nested_result.ok, "A workspace containing one generated town was not resolved: %s" % nested_result.message)
	assert(nested_result.town_directory.get_file() == "albury_test")
	assert(nested_result.runtime_ready, "The nested Albury project was not recognised as playable.")
	print("PROJECT REOPEN PASSED: direct and single-town parent folders restore playable projects.")
	quit(0)
