extends SceneTree

class TestStudio:
	extends "res://scripts/app/creator_studio.gd"
	var launched: Array[String] = []
	var recent := ""
	func _launch_playable_preview(path_value: String) -> void: launched.append(path_value)
	func _save_workspace_preference(_path: String) -> void: pass
	func _save_recent_project(_path: String) -> void: pass
	func _load_recent_project() -> String: return recent

var checks := 0
var failures := 0
var studio

func _initialize() -> void: call_deferred("run")
func frames() -> void:
	for i in 5: await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func button_named(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := button_named(child, text)
		if found != null: return found
	return null
func hashes(directory: String) -> Dictionary:
	var result := {}
	for file in DirAccess.get_files_at(directory):
		var path := directory.path_join(file)
		result[path] = FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(directory): result.merge(hashes(directory.path_join(child)))
	return result
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
	create_timer(90).timeout.connect(func(): push_error("PROJECT REOPEN TIMEOUT"); quit(2))
	var albury := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var original_hashes := hashes(albury)
	var original_albury: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(albury.path_join("town.json")))
	# The user may have saved the recovery since this regression was introduced.
	# Check their current state; do not assume the live town is still damaged.
	var expect_recovery: bool = float(original_albury.get("map_bounds", {}).get("west", 0.0)) > 150.0 or original_albury.get("map_bounds", {}).is_empty()
	var workspace := ProjectSettings.globalize_path("res://tools/tests/output/reopen-%s" % OS.get_process_id())
	studio = load("res://scenes/creator_studio.tscn").instantiate()
	studio.set_script(TestStudio)
	root.add_child(studio); await frames()
	studio.recent = albury
	var open_button := button_named(studio.content_area, "Open previous project")
	check(open_button != null, "Welcome exposes Open previous project")
	if open_button == null: quit(1); return
	open_button.pressed.emit(); await frames()
	check(studio.existing_project_dialog.visible and studio.project_dialog_action == "load", "Welcome button opens correct picker")
	studio.existing_project_dialog.hide()
	studio.existing_project_dialog.dir_selected.emit(albury); await frames()
	check(studio.loaded_project_directory == albury, "Actual picker restores Albury identity")
	check(studio.map_canvas.geographic_bounds.west < 147.0 and studio.map_canvas.geographic_bounds.north < -36.0, "Albury framed using Albury coordinates, not Gold Coast")
	check(studio.imported_town.features.size() > 100, "Actual Albury geometry restored")
	if expect_recovery:
		check(studio.selected_cbd.is_empty() and studio.selected_start.is_empty(), "Unrelated Gold Coast CBD/player/car selections not reused")
	else:
		check(studio.selected_cbd == original_albury.cbd.bounds and studio.selected_start == original_albury.starting_location, "Repaired Albury selections preserved on opening")
	check(not str(studio.imported_town.get("recovery_message", "")).is_empty() == expect_recovery, "Recovery identified only when current metadata needs repair")
	check((studio.content_area.find_child("ProjectRecoveryNotice", true, false) != null) == expect_recovery, "Recovery notice matches current saved metadata")
	check(studio.create_town_button.text == "Save project changes", "Opening remains editing, not new town creation")
	check(studio.sidebar_navigation_buttons.play.text.begins_with("✗") == expect_recovery, "Play readiness reflects current saved Albury metadata")
	for size_value in [Vector2i(1280,800), Vector2i(1600,900)]:
		root.size = size_value; root.content_scale_size = size_value; await frames()
		check(studio.map_canvas.size.x >= 350 and studio.map_canvas.size.y >= 300, "Recovered map has usable viewport")
		var visible_buildings := 0
		for feature in studio.imported_town.features:
			if str(feature.kind) != "building": continue
			var screen: Vector2 = studio.map_canvas._geographic_to_screen(feature.points[0])
			if Rect2(Vector2.ZERO, studio.map_canvas.size).has_point(screen): visible_buildings += 1
		check(visible_buildings > 20, "Albury buildings actually inside viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/tests/output/albury_reopened_v17.png")) == OK, "Actual reopened map captured")
	studio._play_project(albury)
	if expect_recovery:
		check(studio.launched.is_empty() and studio.message_dialog.title == "Check the recovered town setup", "Play cannot use unrelated saved Gold Coast coordinates")
	else:
		check(studio.launched.size() == 1 and studio.launched[0] == albury, "Repaired saved Albury can play normally")
	studio.launched.clear()
	studio.message_dialog.hide()
	studio._load_existing_project(albury, "map_editor"); await frames()
	check(studio.editor_map_canvas.geographic_bounds.west < 147.0, "Advanced map editor restores Albury too")
	check(hashes(albury) == original_hashes, "All actual Albury files unchanged by opening and recovery")
	studio._show_town_import_page(); await frames()
	studio._on_osm_files_selected(PackedStringArray([ProjectSettings.globalize_path("res://tools/tests/fixtures/tiny_town.osm")]))
	studio._scan_osm_files()
	studio._on_cbd_changed(studio.imported_town.bounds)
	check(select_safe_start(), "New fixture safe start")
	studio.town_name_edit.text = "Reopen fixture"
	studio._on_town_name_changed(studio.town_name_edit.text)
	studio.workspace_edit.text = workspace
	check(studio._create_town_project(), "New import still creates playable project")
	var fixture: String = studio.loaded_project_directory
	if fixture.is_empty(): quit(1); return
	var original_town: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture.path_join("town.json")))
	var fixture_hashes := hashes(fixture)
	studio._show_play_test_page(); await frames()
	studio._load_existing_project(fixture.get_base_dir()); await frames()
	check(studio.loaded_project_directory == fixture, "Immediate parent resolves saved project")
	check(studio.selected_cbd == original_town.cbd.bounds and studio.selected_start == original_town.starting_location, "Valid saved CBD/player/car retained")
	check(str(studio.imported_town.get("recovery_message", "")).is_empty(), "Valid projects have no recovery warning")
	check(hashes(fixture) == fixture_hashes, "Valid load is read-only")
	studio._play_current_project()
	check(studio.launched.size() == 1 and studio.launched[0] == fixture, "Normal saved project still plays")
	studio.pending_osm_files = PackedStringArray(["res://missing.osm"])
	studio._load_existing_project(fixture); await frames()
	check(studio.pending_osm_files.is_empty(), "Explicit open clears pending replacement import")
	studio._load_existing_project(workspace.path_join("missing")); await frames()
	check(studio.loaded_project_directory == fixture and studio.imported_town.get("ok", false), "Failed open preserves current project")
	studio.message_dialog.hide()
	# Real sidebar actions: one confirmation, safe Cancel, no old write targets.
	studio._load_existing_project(fixture); await frames()
	studio.town_name_edit.text = "Unsaved name"
	studio.town_name_edit.text_changed.emit("Unsaved name")
	studio.npc_role_drafts = {"trader": {"name": "Old draft"}}
	studio.building_exterior_data = {"sentinel": "old building"}
	studio._record_section_edit()
	var previous_canvas: Control = studio.map_canvas
	var save_folder: String = studio.current_workspace
	var home_button := button_named(studio, "Home")
	check(home_button != null, "Actual sidebar Home button")
	home_button.pressed.emit(); await frames()
	check(studio.new_town_dialog.visible, "Home asks before clearing current project")
	check(not is_instance_valid(studio.section_leave_dialog) or not studio.section_leave_dialog.visible, "Fresh-session confirmation is one dialog, not two")
	check(studio.loaded_project_directory == fixture and studio.map_canvas == previous_canvas and studio.current_town_name == "Unsaved name", "Opening confirmation does not alter project or drafts")
	check(studio.new_town_dialog.dialog_text.contains("unsaved") and studio.new_town_dialog.dialog_text.contains("not be deleted"), "Confirmation explains unsaved edits and saved-file safety")
	studio.new_town_dialog.hide(); studio.new_town_dialog.canceled.emit(); await frames()
	check(studio.current_town_name == "Unsaved name" and studio.town_name_edit.text == "Unsaved name", "Cancel retains unsaved text")
	check(studio.map_canvas == previous_canvas and studio.npc_role_drafts.has("trader") and studio.building_exterior_data.has("sentinel"), "Cancel retains map and content drafts")
	check(studio.new_town_destination.is_empty(), "Cancel clears pending destructive action")
	studio.content_area.find_child("NewTownButton", true, false).pressed.emit(); await frames()
	check(studio.new_town_dialog.visible and studio.new_town_destination == "import", "Explicit New town confirms before clearing")
	studio.new_town_dialog.confirmed.emit(); await frames()
	check(studio.loaded_project_directory.is_empty() and studio.last_created_directory.is_empty(), "Confirm detaches old save/play targets")
	check(studio.imported_town.is_empty() and studio.selected_osm_files.is_empty() and studio.original_osm_files.is_empty() and studio.pending_osm_files.is_empty(), "Confirm clears all imported and pending source state")
	check(studio.current_town_name.is_empty() and studio.town_name_edit.text.is_empty() and studio.selected_cbd.is_empty() and studio.selected_start.is_empty(), "Fresh import has blank name and geographic selections")
	check(studio.map_canvas.features.is_empty(), "Fresh import has no previous map artwork")
	check(studio.npc_role_drafts.is_empty() and studio.building_exterior_data.is_empty() and studio.interior_data.is_empty(), "Old content drafts do not leak into next town")
	check(studio.current_workspace == save_folder and studio.workspace_edit.text == save_folder, "Chosen save folder retained")
	check(not studio._section_is_dirty() and studio.section_history.previous.is_empty(), "Old Undo cannot restore the previous town into a fresh session")
	studio._play_current_project()
	check(studio.launched.size() == 1 and studio.message_dialog.title == "Finish setup before Play test", "Blank session cannot play previous project")
	studio.message_dialog.hide()
	check(not studio._create_town_project(), "Blank session cannot Save over previous project")
	studio.message_dialog.hide()
	check(hashes(fixture) == fixture_hashes, "Confirmed clear leaves all saved project files unchanged")
	studio._load_existing_project(fixture); await frames()
	studio._show_play_test_page(); await frames()
	button_named(studio.content_area, "Back to town setup").pressed.emit(); await frames()
	check(studio.loaded_project_directory == fixture and not studio.imported_town.is_empty(), "Internal Back to setup retains loaded project")
	home_button.pressed.emit(); await frames()
	studio.new_town_dialog.confirmed.emit(); await frames()
	check(studio.loaded_project_directory.is_empty() and button_named(studio.content_area, "Open previous project") != null, "Confirmed Home clears session and shows Welcome")
	check(hashes(fixture) == fixture_hashes, "Home never changes saved files")
	button_named(studio.content_area, "Import a town").pressed.emit(); await frames()
	check(not studio.new_town_dialog.visible and studio.import_tools_navigation != null, "Welcome import opens immediately when no project needs clearing")
	studio._on_osm_files_selected(PackedStringArray([ProjectSettings.globalize_path("res://tools/tests/fixtures/tiny_town.osm")]))
	studio._scan_osm_files()
	studio._on_cbd_changed(studio.imported_town.bounds)
	check(select_safe_start(), "Fresh session accepts new map and safe start")
	studio.town_name_edit.text = "Fresh town"
	studio.town_name_edit.text_changed.emit("Fresh town")
	check(studio._create_town_project() and studio.loaded_project_directory != fixture, "Fresh session creates a separate project, never updates old town")
	check(hashes(fixture) == fixture_hashes, "New project creation preserves previous project")
	# Corrupt only a disposable fixture. Check recovery and explicit Save/reopen.
	var damaged := original_town.duplicate(true)
	damaged.map_bounds = {"west":153.4,"east":153.5,"south":-28.0,"north":-27.9}
	check(studio.content_pack_writer._write_json(fixture.path_join("town.json"), damaged) == OK, "Mismatch fixture prepared")
	studio._load_existing_project(fixture); await frames()
	check(studio.selected_cbd == original_town.cbd.bounds and studio.selected_start == original_town.starting_location, "Recovery keeps already valid local CBD/player/car")
	check(studio.imported_town.bounds == original_town.map_bounds, "Matching source export bounds restored")
	check(studio._create_town_project(), "Explicit Save repairs disposable metadata and regenerates runtime data")
	check(str(studio.imported_town.get("recovery_message", "")).is_empty(), "Successful Save clears recovery state")
	check(not studio.content_area.find_child("ProjectRecoveryNotice", true, false).visible, "Successful Save hides resolved warning")
	studio._load_existing_project(fixture); await frames()
	check(str(studio.imported_town.get("recovery_message", "")).is_empty(), "Saved repair reopens normally")
	check(studio.current_town_name == "Reopen fixture", "Custom name preserved during recovery")
	# No source: the retained geometry remains sufficient to frame the project.
	damaged = original_town.duplicate(true)
	damaged.map_bounds = {}
	damaged.source.files = []
	studio.content_pack_writer._write_json(fixture.path_join("town.json"), damaged)
	var without_source: Dictionary = studio.project_loader.load_project(fixture)
	check(without_source.ok and not str(without_source.recovery_message).is_empty(), "Missing bounds/source recovered from stored geometry")
	check(without_source.import_result.bounds.west < 147.0, "Geometry fallback uses local coordinates")
	check(hashes(albury) == original_hashes, "User Albury content remains untouched through every check")
	studio.queue_free(); await frames()
	print("PROJECT REOPEN: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
