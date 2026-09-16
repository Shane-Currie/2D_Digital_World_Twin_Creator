extends SceneTree

const MapScript = preload("res://scripts/towns/map_canvas.gd")
const WriterScript = preload("res://scripts/content/content_pack.gd")
const ImporterScript = preload("res://scripts/towns/osm_importer.gd")

class TestStudio:
	extends "res://scripts/app/creator_studio.gd"
	func _save_workspace_preference(_path_value: String) -> void:
		pass
	func _save_recent_project(_path_value: String) -> void:
		pass

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source := ProjectSettings.globalize_path("res://../OSM/gold.osm")
	var imported: Dictionary = ImporterScript.new().parse_files(PackedStringArray([source]))
	assert(imported.ok)
	var canvas := MapScript.new()
	root.add_child(canvas)
	canvas.size = Vector2(700,500)
	canvas.set_map_data(imported)
	canvas.drag_start = Vector2(200,200)
	canvas.drag_current = canvas.size
	canvas._set_cbd_from_drag()
	print("CBD edge reproduction: map=",JSON.stringify(imported.bounds)," selected=",JSON.stringify(canvas.cbd_bounds))
	if not WriterScript.new()._bounds_contains_bounds(imported.bounds,canvas.cbd_bounds):
		push_error("A CBD drawn on the map was stored outside its bounds")
		quit(1)
		return
	var writer := WriterScript.new()
	var selections_checked := 0
	var bounds_cases := [imported.bounds, {"west":-74.01991,"east":-73.98137,"south":40.70031,"north":40.73529}, {"west":146.00123,"east":146.02457,"south":-36.11891,"north":-36.09543}]
	for bounds in bounds_cases:
		canvas.geographic_bounds = bounds
		for zoom in [1.0,4.0,12.0]:
			canvas.view_zoom = zoom
			canvas.view_center_ratio = Vector2(0.65,0.75)
			canvas._clamp_view_center()
			for reverse in [false,true]:
				canvas.drag_start = canvas.size if reverse else Vector2.ZERO
				canvas.drag_current = Vector2.ZERO if reverse else canvas.size
				canvas._set_cbd_from_drag()
				assert(writer._bounds_contains_bounds(bounds,canvas.cbd_bounds), "A panned/zoomed selection escaped the map")
				if zoom==1.0: assert(canvas.cbd_bounds==bounds,"Map-edge selections must retain the exact OSM bounds")
				var saved: Dictionary = JSON.parse_string(JSON.stringify(canvas.cbd_bounds))
				assert(writer._bounds_contains_bounds(bounds,saved),"JSON serialization moved a valid selection outside the map")
				selections_checked += 1
		var invalid: Dictionary = bounds.duplicate()
		invalid.east += 0.001
		assert(not writer._bounds_contains_bounds(bounds,invalid),"Genuinely outside CBDs must still be rejected")
	canvas.queue_free()
	await _verify_gui_create(imported,source,"Gold Coast CBD Edge Regression",selections_checked)
	var sun_source := ProjectSettings.globalize_path("res://../OSM/sun.osm")
	var sun_import: Dictionary = ImporterScript.new().parse_files(PackedStringArray([sun_source]))
	assert(sun_import.ok)
	await _verify_gui_create(sun_import,sun_source,"Sun CBD Edge Regression",selections_checked)
	print("CBD SELECTION AND GUI CREATE PASSED: Gold Coast and Sun saved/reopened; ",selections_checked," coordinate cases")
	quit(0)

func _verify_gui_create(imported: Dictionary,source: String,town_name: String,selections_checked: int) -> void:
	# Exercise the real GUI's selection signal and Create handler with the user's
	# OSM, writing only into a clearly named disposable regression-test directory.
	var studio: Control = load("res://scenes/creator_studio.tscn").instantiate()
	studio.set_script(TestStudio)
	root.add_child(studio)
	await process_frame
	studio._show_town_import_page()
	await process_frame
	studio.imported_town = imported
	studio.selected_osm_files = PackedStringArray([source])
	studio.map_canvas.set_map_data(imported)
	studio.map_canvas.drag_start = Vector2.ZERO
	studio.map_canvas.drag_current = studio.map_canvas.size
	studio.map_canvas._set_cbd_from_drag()
	assert(studio.selected_cbd==imported.bounds, "The GUI did not receive the drawn full-map CBD")
	for feature in imported.features:
		if str(feature.kind)!="road": continue
		for point in feature.points:
			if point.x<=imported.bounds.west or point.x>=imported.bounds.east or point.y<=imported.bounds.south or point.y>=imported.bounds.north: continue
			studio.map_canvas._set_start_from_screen(studio.map_canvas._geographic_to_screen(point))
			if not studio.selected_start.is_empty(): break
		if not studio.selected_start.is_empty(): break
	assert(not studio.selected_start.is_empty(), "The real-map start fixture must pass footprint/water safety")
	studio.town_name_edit.text = town_name
	studio.workspace_edit.text = ProjectSettings.globalize_path("res://tools/tests/output/cbd-edge-projects")
	studio._refresh_create_button()
	assert(studio.creation_readiness_label.text.begins_with("Ready."))
	assert(studio._create_town_project(), "Create failed for the actual Gold Coast map and GUI-drawn CBD")
	var town: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(studio.last_created_directory.path_join("town.json")))
	assert(town.cbd.bounds==imported.bounds)
	assert(FileAccess.file_exists(studio.last_created_directory.path_join("data/navigation_graphs.json")))
	assert(FileAccess.file_exists(studio.last_created_directory.path_join("data/building_collisions.json")))
	var reopened: Dictionary = studio.project_loader.load_project(studio.last_created_directory)
	assert(reopened.ok,"The generated edge-CBD project must reopen")
	assert(WriterScript.new().validate_town(town.display_name,reopened.import_result,town.cbd.bounds,town.starting_location).passed)
	var valid_cbd: Dictionary = studio.selected_cbd.duplicate()
	studio.selected_cbd.east += 0.001
	studio._refresh_create_button()
	assert(not studio.creation_readiness_label.text.begins_with("Ready."),"An invalid saved CBD must not be called Ready")
	assert(not studio._create_town_project(), "GUI must reject a genuinely invalid CBD")
	studio.message_dialog.hide()
	studio.selected_cbd = valid_cbd
	studio.map_canvas.cbd_bounds = valid_cbd
	studio._load_existing_project(studio.last_created_directory)
	await process_frame
	if DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/tests/output/%s_cbd_create_verified.png" % source.get_file().get_basename())
	var report := {"passed":true,"selection_cases":selections_checked,"source":source,"created_project":studio.last_created_directory,"checks":["exact edge coordinates","zoom/pan and reverse drags","northern/western and southern/eastern hemispheres","JSON round trip","real GUI Create with supplied OSM","generated collisions/navigation","reopen and validate","outside selections still rejected","invalid CBD never marked Ready"]}
	var file := FileAccess.open("res://tools/tests/output/%s_cbd_selection_validation.json" % source.get_file().get_basename(),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("GUI CREATE PASSED: generated and reopened ",studio.last_created_directory)
	studio.queue_free()
	await process_frame
