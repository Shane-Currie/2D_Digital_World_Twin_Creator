extends SceneTree

class TestStudio:
	extends "res://scripts/app/creator_studio.gd"
	var launched: Array[String] = []
	func _launch_playable_preview(path_value: String) -> void:
		launched.append(path_value)
	func _save_workspace_preference(_path: String) -> void: pass
	func _save_recent_project(_path: String) -> void: pass

var checks := 0
var failures := 0
var studio
var workspace := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames() -> void:
	for i in 4: await process_frame
func select_safe_start() -> bool:
	var bounds: Dictionary = studio.imported_town.bounds
	for feature in studio.imported_town.features:
		if str(feature.kind) != "road": continue
		for point in feature.points:
			if point.x <= bounds.west or point.x >= bounds.east or point.y <= bounds.south or point.y >= bounds.north: continue
			studio.map_canvas._set_start_from_screen(studio.map_canvas._geographic_to_screen(point))
			if not studio.selected_start.is_empty(): return true
	return false

func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("NEW TOWN CHECK TIMEOUT"); quit(2))
	workspace = ProjectSettings.globalize_path("res://tools/tests/output/new-town-%s" % OS.get_process_id())
	studio = load("res://scenes/creator_studio.tscn").instantiate()
	studio.set_script(TestStudio)
	root.add_child(studio); await frames()
	studio._show_town_import_page(); await frames()
	check(studio.import_tools_navigation.pages.size() == 9, "Nine separate import tools")
	check(studio.import_tools_navigation.current_page.is_empty(), "Import opens on tool hub")
	for size_value in [Vector2i(1280,800),Vector2i(1600,900)]:
		root.size = size_value; root.content_scale_size = size_value; await frames()
		for id_value in studio.import_tools_navigation.pages:
			studio.import_tools_navigation.open_page(id_value); await frames()
			check(studio.import_tools_navigation.current_page == id_value, "Tool open: " + id_value)
			check(studio.map_canvas.size.x >= 350 and studio.map_canvas.size.y >= 300, "Usable map: " + id_value)
			studio.import_tools_navigation.back_button.pressed.emit()
			check(studio.import_tools_navigation.current_page.is_empty(), "Back: " + id_value)
	studio._on_osm_files_selected(PackedStringArray([ProjectSettings.globalize_path("res://tools/tests/fixtures/tiny_town.osm")]))
	studio._scan_osm_files()
	check(studio.imported_town.get("ok",false), "Tiny new import")
	studio._on_cbd_changed(studio.imported_town.bounds)
	check(select_safe_start(), "Safe initial start")
	studio.town_name_edit.text = "Original saved town"
	studio.workspace_edit.text = workspace
	check(studio._create_town_project(), "Create original fixture")
	var old_directory: String = studio.loaded_project_directory
	var old_hash := FileAccess.get_sha256(old_directory.path_join("town.json"))
	studio._on_osm_files_selected(PackedStringArray(["res://missing_map.osm"]))
	studio._scan_osm_files()
	check(studio.loaded_project_directory == old_directory and studio.imported_town.get("ok",false), "Failed replacement preserves current project")
	studio._play_current_project()
	check(studio.launched.is_empty() and studio.message_dialog.title == "Read the new map first", "Pending map cannot launch old town")
	studio.message_dialog.hide()
	var source := ProjectSettings.globalize_path("res://../OSM/gold_coast.osm")
	check(FileAccess.file_exists(source), "Exact user Gold Coast source exists")
	var source_hash := FileAccess.get_sha256(source)
	studio._on_osm_files_selected(PackedStringArray([source]))
	studio._scan_osm_files()
	check(studio.imported_town.get("ok",false), "Exact Gold Coast parse")
	check(studio.loaded_project_directory.is_empty() and studio.last_created_directory.is_empty(), "Successful replacement detaches old save/play targets")
	check(studio.current_town_name == "Gold Coast", "New source name does not reuse old town name")
	check(studio.selected_cbd.is_empty() and studio.selected_start.is_empty(), "Old geographic selections cleared")
	check(studio.import_tools_navigation.current_page == "cbd", "Import opens next CBD tool")
	studio._on_cbd_changed(studio.imported_town.bounds)
	check(select_safe_start(), "Gold Coast production safe-start selection")
	studio.town_name_edit.text = "Gold Coast launch regression"
	studio._on_town_name_changed(studio.town_name_edit.text)
	studio.workspace_edit.text = workspace
	studio._show_play_test_page(); await frames()
	check(studio.sidebar_navigation_buttons.play.text.contains("Play test project"), "Correct sidebar label")
	studio._play_current_project()
	check(studio.launched.size() == 1 and studio.launched[0] == studio.loaded_project_directory, "One click creates and launches new town")
	var project: String = studio.loaded_project_directory
	check(project != old_directory and not project.is_empty(), "Correct fresh project launch target")
	if project.is_empty():
		push_error("Creation failed: " + studio.message_dialog.dialog_text)
		quit(1); return
	check(FileAccess.get_sha256(old_directory.path_join("town.json")) == old_hash, "Previous saved town unchanged")
	check(FileAccess.get_sha256(source) == source_hash, "OSM source unchanged")
	var reopened: Dictionary = studio.project_loader.load_project(project)
	check(reopened.ok and reopened.runtime_ready and reopened.navigation_ready and reopened.building_collisions_ready, "Fresh town is runtime ready")
	var saved_features: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(project.path_join("data/map_features.json")))
	var source_trees: Array = studio.imported_town.features.filter(func(feature): return str(feature.kind) == "tree")
	check(not source_trees.is_empty(), "Gold Coast fixture contains mapped trees")
	check(saved_features.features.filter(func(feature): return str(feature.kind) == "tree").size() == source_trees.size(), "Mapped trees survive save")
	check(reopened.import_result.features.filter(func(feature): return str(feature.kind) == "tree").size() == source_trees.size(), "Mapped trees survive reopen")
	# Exercise array pairs too, as accepted by content tools and tree fixtures.
	var array_feature: Dictionary = source_trees[0].duplicate(true)
	array_feature.points = [[array_feature.points[0].x, array_feature.points[0].y]]
	check(studio.content_pack_writer._write_map_features(workspace.path_join("array_tree.json"), [array_feature]) == OK, "JSON-pair tree coordinates serialize")
	check(studio._create_town_project(), "Saved Gold Coast update/rebuild serialization")
	var settings: Dictionary = studio._settings_for_project_save()
	var collision: Dictionary = studio.content_pack_writer.save_town(workspace, studio.current_town_name, studio.selected_osm_files, studio.imported_town, studio.selected_cbd, studio.selected_start, settings)
	check(not collision.ok and collision.message.contains("already exists"), "New import cannot overwrite same-name saved project")
	studio._show_town_import_page(); await frames()
	studio.import_tools_navigation.open_page("files")
	check(studio.osm_files_label.text.contains("gold_coast.osm"), "Selected OSM filename stays visible")
	check(studio.creation_readiness_label.is_visible_in_tree(), "Setup readiness visible outside tool pages")
	studio.import_tools_navigation.open_page("car")
	studio.import_tools_navigation.show_home()
	check(studio.map_canvas.edit_mode == studio.TownMapCanvasScript.EditMode.INSPECT, "Back cancels hidden placement mode")
	if DisplayServer.get_name() != "headless":
		await frames(); await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/tests/output/town_import_tools_v17.png")) == OK, "Rendered import tool hub")
	var report := FileAccess.open(workspace.path_join("launch_report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"project":project,"checks":checks,"failures":failures,"source":source},"  "))
	print("NEW TOWN LAUNCH CHECKS: %d checks, %d failures; project=%s" % [checks,failures,project])
	studio.queue_free(); await frames()
	quit(1 if failures else 0)
