extends SceneTree


func _initialize() -> void:
	call_deferred("_run_check")


func _run_check() -> void:
	var packed_scene: PackedScene = load("res://scenes/creator_studio.tscn")
	var studio: Control = packed_scene.instantiate()
	root.add_child(studio)
	await process_frame
	var albury_workspace := ProjectSettings.globalize_path("res://../test/albury test")
	studio._load_existing_project(albury_workspace)
	await process_frame
	assert(studio.loaded_project_directory.get_file() == "albury_test", "Creator Studio did not resolve the Albury workspace to its generated town.")
	assert(not studio.rebuild_project_button.disabled, "The Albury rebuild action did not become available.")
	studio._rebuild_loaded_project()
	assert(studio.status_label.text.begins_with("Town rebuilt:"), "The GUI rebuild did not complete: %s" % studio.status_label.text)
	assert(studio.selection_instructions.text.contains("saved project copy"), "The GUI did not identify which OSM source rebuilt Albury.")
	var navigation_file := FileAccess.open(studio.loaded_project_directory.path_join("data").path_join("navigation_graphs.json"), FileAccess.READ)
	assert(navigation_file != null)
	var navigation: Dictionary = JSON.parse_string(navigation_file.get_as_text())
	assert(int(navigation.vehicle.traffic_control_counts.traffic_signals) > 0, "Rebuilt Albury did not retain its OSM traffic signals.")
	print("CREATOR REBUILD PASSED: Albury regenerated from its saved OSM copy with %d traffic-signal nodes." % int(navigation.vehicle.traffic_control_counts.traffic_signals))
	studio.queue_free()
	quit(0)
