extends Control

const OsmImporterScript = preload("res://scripts/towns/osm_importer.gd")
const TownMapCanvasScript = preload("res://scripts/towns/map_canvas.gd")
const ContentPackWriterScript = preload("res://scripts/content/content_pack.gd")
const LocalLlmProbeScript = preload("res://scripts/npcs/local_llm_probe.gd")
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")
const ProjectLoaderScript = preload("res://scripts/content/project_loader.gd")
const BuildingInformationScript = preload("res://scripts/places/osm_building_information.gd")

const BACKGROUND := Color("#0f1715")
const PANEL := Color("#18241f")
const PANEL_LIGHT := Color("#21332b")
const ACCENT := Color("#4bc7a1")
const ACCENT_BLUE := Color("#72a7ff")
const TEXT := Color("#edf6f1")
const MUTED := Color("#a8bbb2")
const WARNING := Color("#efc56c")

var importer = OsmImporterScript.new()
var content_pack_writer = ContentPackWriterScript.new()
var project_loader = ProjectLoaderScript.new()
var llm_probe: Node

var content_area: VBoxContainer
var status_label: Label
var osm_file_dialog: FileDialog
var workspace_dialog: FileDialog
var settings_town_dialog: FileDialog
var existing_project_dialog: FileDialog
var message_dialog: AcceptDialog

var town_name_edit: LineEdit
var osm_files_label: Label
var scan_button: Button
var import_summary_label: Label
var workspace_edit: LineEdit
var create_town_button: Button
var creation_readiness_label: Label
var rebuild_project_button: Button
var map_canvas: Control
var selection_instructions: Label
var building_information: Label
var open_folder_button: Button
var cbd_button: Button
var start_button: Button
var map_zoom_label: Label

var selected_osm_files := PackedStringArray()
var original_osm_files := PackedStringArray()
var imported_town: Dictionary = {}
var selected_cbd: Dictionary = {}
var selected_start: Dictionary = {}
var last_created_directory := ""
var provider_status_labels: Dictionary = {}
var settings_town_edit: LineEdit
var settings_controls: Dictionary = {}
var jam_recovery_check: CheckBox
var loaded_project_directory := ""
var current_town_name := ""
var current_workspace := ""
var project_dialog_action := "load"
var play_test_button: Button
var setup_driving_side_option: OptionButton
var driving_side_option: OptionButton
var selected_driving_side := "left"
var skin_tone_total_label: Label
var equalize_skin_tones_button: Button
var updating_skin_tones := false
var rebuild_in_progress := false
var rebuild_source_note := ""


func _ready() -> void:
	if not _argument_value("--play-town").is_empty():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/runtime/town_runtime.tscn")
		return
	_build_file_dialogs()
	_build_shell()
	llm_probe = LocalLlmProbeScript.new()
	add_child(llm_probe)
	llm_probe.provider_checked.connect(_on_provider_checked)
	llm_probe.checks_finished.connect(_on_provider_checks_finished)
	_show_welcome_page()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)

	var header := _panel_container(PANEL_LIGHT, 0)
	header.custom_minimum_size.y = 74
	page.add_child(header)
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 26)
	header_margin.add_theme_constant_override("margin_right", 26)
	header_margin.add_theme_constant_override("margin_top", 14)
	header_margin.add_theme_constant_override("margin_bottom", 12)
	header.add_child(header_margin)
	var header_row := HBoxContainer.new()
	header_margin.add_child(header_row)
	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_group)
	title_group.add_child(_label("2D Digital World Twin Creator", 25, TEXT))
	title_group.add_child(_label("v1.2 · No-code digital-world development", 13, MUTED))
	var version_badge := _label("CREATOR STUDIO", 13, ACCENT)
	version_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(version_badge)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	page.add_child(body)

	var sidebar_panel := _panel_container(Color("#131e1a"), 0)
	sidebar_panel.custom_minimum_size.x = 238
	body.add_child(sidebar_panel)
	var sidebar_margin := MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 16)
	sidebar_margin.add_theme_constant_override("margin_right", 16)
	sidebar_margin.add_theme_constant_override("margin_top", 22)
	sidebar_margin.add_theme_constant_override("margin_bottom", 18)
	sidebar_panel.add_child(sidebar_margin)
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 9)
	sidebar_margin.add_child(sidebar)
	sidebar.add_child(_navigation_button("Home", _show_welcome_page))
	sidebar.add_child(_navigation_button("Import a town", _show_town_import_page, true))
	sidebar.add_child(_navigation_button("Game settings", _show_game_settings_page))
	sidebar.add_child(_navigation_button("System setup", _show_system_page))
	sidebar.add_child(HSeparator.new())
	sidebar.add_child(_section_caption("COMING NEXT"))
	sidebar.add_child(_disabled_navigation_button("Building exteriors"))
	sidebar.add_child(_disabled_navigation_button("Interior designer"))
	sidebar.add_child(_disabled_navigation_button("NPCs and personas"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	var privacy_note := _label("Local models are used only\nfor NPC conversations.", 12, MUTED)
	privacy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(privacy_note)

	var content_panel := _panel_container(BACKGROUND, 0)
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content_panel)
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 28)
	content_margin.add_theme_constant_override("margin_right", 28)
	content_margin.add_theme_constant_override("margin_top", 24)
	content_margin.add_theme_constant_override("margin_bottom", 18)
	content_panel.add_child(content_margin)
	content_area = VBoxContainer.new()
	content_area.add_theme_constant_override("separation", 14)
	content_margin.add_child(content_area)

	var footer := _panel_container(Color("#111b17"), 0)
	footer.custom_minimum_size.y = 36
	page.add_child(footer)
	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 20)
	footer_margin.add_theme_constant_override("margin_right", 20)
	footer_margin.add_theme_constant_override("margin_top", 8)
	footer.add_child(footer_margin)
	status_label = _label("Ready", 12, MUTED)
	footer_margin.add_child(status_label)


func _build_file_dialogs() -> void:
	osm_file_dialog = FileDialog.new()
	osm_file_dialog.title = "Choose OpenStreetMap files"
	osm_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	osm_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	osm_file_dialog.filters = PackedStringArray(["*.osm ; OpenStreetMap XML files"])
	osm_file_dialog.files_selected.connect(_on_osm_files_selected)
	add_child(osm_file_dialog)

	workspace_dialog = FileDialog.new()
	workspace_dialog.title = "Choose where your game files will be saved"
	workspace_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	workspace_dialog.access = FileDialog.ACCESS_FILESYSTEM
	workspace_dialog.dir_selected.connect(_on_workspace_selected)
	add_child(workspace_dialog)

	settings_town_dialog = FileDialog.new()
	settings_town_dialog.title = "Choose the town project to change"
	settings_town_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	settings_town_dialog.access = FileDialog.ACCESS_FILESYSTEM
	settings_town_dialog.dir_selected.connect(_on_settings_town_selected)
	add_child(settings_town_dialog)

	existing_project_dialog = FileDialog.new()
	existing_project_dialog.title = "Choose a saved Creator Studio project"
	existing_project_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	existing_project_dialog.access = FileDialog.ACCESS_FILESYSTEM
	existing_project_dialog.dir_selected.connect(_on_existing_project_selected)
	add_child(existing_project_dialog)

	message_dialog = AcceptDialog.new()
	message_dialog.min_size = Vector2i(560, 220)
	add_child(message_dialog)


func _show_welcome_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Create a digital world without writing code", "Import real map data, mark important places and save an editable town project."))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(cards)
	cards.add_child(_feature_card(
		"1 · Import",
		"Choose ordinary .osm files and preview the roads and building footprints.",
		"Import a town",
		_show_town_import_page
	))
	cards.add_child(_feature_card(
		"2 · Continue",
		"Open a town you previously saved and continue changing its CBD, starting locations or settings.",
		"Open previous project",
		_choose_project_to_load
	))
	cards.add_child(_feature_card(
		"3 · Play test",
		"Check whether a saved town has a generated playable runtime and launch it when ready.",
		"Choose project to play",
		_choose_project_to_play
	))

	var note := _notice_panel(
		"v1.2 foundation",
		"v1.2 builds on the proven v1.1 town workflow while adding the next map-independent information, gameplay and editing stages.",
		ACCENT
	)
	content_area.add_child(note)


func _show_town_import_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Import a town", "Six guided steps create a playable town project."))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 390
	left_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	split.add_child(left_scroll)
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_right", 18)
	left_scroll.add_child(left_margin)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 360
	form.add_theme_constant_override("separation", 10)
	left_margin.add_child(form)

	form.add_child(_step_heading("1", "Name your town"))
	town_name_edit = LineEdit.new()
	town_name_edit.placeholder_text = "Example: Benalla"
	town_name_edit.text = current_town_name
	town_name_edit.text_changed.connect(_on_town_name_changed)
	form.add_child(town_name_edit)

	form.add_child(_step_heading("2", "Choose OpenStreetMap files"))
	var choose_files := _action_button("Choose .osm files…", _choose_osm_files, true)
	form.add_child(choose_files)
	osm_files_label = _label("No files selected", 12, MUTED)
	osm_files_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(osm_files_label)
	scan_button = _action_button("Read files and show preview", _scan_osm_files, false)
	scan_button.disabled = true
	form.add_child(scan_button)
	import_summary_label = _label("", 12, MUTED)
	import_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(import_summary_label)

	form.add_child(_step_heading("3", "Draw the CBD area"))
	var cbd_help := _label("Select Draw CBD, then drag a box around the central business district on the map.", 12, MUTED)
	cbd_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(cbd_help)
	cbd_button = _action_button("Draw CBD on map", func(): _set_map_mode(TownMapCanvasScript.EditMode.DRAW_CBD), false)
	cbd_button.disabled = true
	form.add_child(cbd_button)

	form.add_child(_step_heading("4", "Set the player and vehicle start"))
	selection_instructions = _label("Read the OSM files and draw the CBD first.", 12, MUTED)
	selection_instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(selection_instructions)
	start_button = _action_button("Choose start on map", _activate_start_tool, true)
	start_button.disabled = true
	form.add_child(start_button)
	var start_help := _label("After selecting the button, click an open position on the map. Creator Studio places the vehicle separately on a nearby clear road.", 11, MUTED)
	start_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(start_help)

	var inspect_row := HBoxContainer.new()
	form.add_child(inspect_row)
	var inspect_button := _action_button("Inspect", func(): _set_map_mode(TownMapCanvasScript.EditMode.INSPECT), false)
	inspect_row.add_child(inspect_button)
	inspect_row.add_child(_label("Optional: inspect an imported building footprint.", 11, MUTED))
	building_information = _label("", 12, MUTED)
	building_information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(building_information)

	form.add_child(_step_heading("5", "Choose the local road rule"))
	var road_rule_help := _label("Choose which side of the road moving traffic uses. This is saved with the town and will control lane placement, turning paths and intersection priorities in the generated game.", 12, MUTED)
	road_rule_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(road_rule_help)
	setup_driving_side_option = OptionButton.new()
	setup_driving_side_option.add_item("Drive on the left (Australia, UK, Japan)")
	setup_driving_side_option.set_item_metadata(0, "left")
	setup_driving_side_option.add_item("Drive on the right (USA, Europe, Canada)")
	setup_driving_side_option.set_item_metadata(1, "right")
	setup_driving_side_option.select(0 if selected_driving_side == "left" else 1)
	setup_driving_side_option.item_selected.connect(_on_setup_driving_side_selected)
	form.add_child(setup_driving_side_option)

	form.add_child(_step_heading("6", "Choose where to save"))
	workspace_edit = LineEdit.new()
	workspace_edit.text = current_workspace if not current_workspace.is_empty() else _load_workspace_preference()
	workspace_edit.placeholder_text = "Choose a folder for your game files"
	workspace_edit.text_changed.connect(_refresh_create_button)
	form.add_child(workspace_edit)
	form.add_child(_action_button("Choose save directory…", _choose_workspace, false))
	var save_note := _label("Creator Studio will make a new town folder inside this directory. Your original OSM files will be copied, not moved.", 11, MUTED)
	save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(save_note)

	create_town_button = _action_button("Save project changes" if not loaded_project_directory.is_empty() else "Create town project", _create_town_project, true)
	form.add_child(create_town_button)
	creation_readiness_label = _label("", 11, MUTED)
	creation_readiness_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(creation_readiness_label)
	rebuild_project_button = _action_button("Rebuild project", _rebuild_loaded_project, false)
	rebuild_project_button.disabled = loaded_project_directory.is_empty()
	form.add_child(rebuild_project_button)
	open_folder_button = _action_button("Open created folder", _open_created_folder, false)
	open_folder_button.disabled = last_created_directory.is_empty()
	form.add_child(open_folder_button)
	play_test_button = _action_button("Play test project", _play_current_project, true)
	form.add_child(play_test_button)

	var map_panel := _panel_container(PANEL, 12)
	map_panel.name = "MapPreviewPanel"
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.clip_contents = true
	split.add_child(map_panel)
	var map_margin := MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 10)
	map_margin.add_theme_constant_override("margin_right", 10)
	map_margin.add_theme_constant_override("margin_top", 10)
	map_margin.add_theme_constant_override("margin_bottom", 10)
	map_panel.add_child(map_margin)
	map_canvas = TownMapCanvasScript.new()
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_canvas.cbd_changed.connect(_on_cbd_changed)
	map_canvas.start_changed.connect(_on_start_changed)
	map_canvas.start_rejected.connect(_on_start_rejected)
	map_canvas.building_selected.connect(_on_building_selected)
	map_canvas.view_changed.connect(_on_map_view_changed)
	var map_group := VBoxContainer.new()
	map_group.add_theme_constant_override("separation", 8)
	map_margin.add_child(map_group)
	var zoom_row := HBoxContainer.new()
	map_group.add_child(zoom_row)
	zoom_row.add_child(_label("Map preview", 14, TEXT))
	var zoom_spacer := Control.new()
	zoom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom_spacer)
	zoom_row.add_child(_action_button("−", _zoom_map_out, false))
	zoom_row.add_child(_action_button("Reset", _reset_map_zoom, false))
	zoom_row.add_child(_action_button("+", _zoom_map_in, false))
	map_zoom_label = _label("100%", 12, MUTED)
	map_zoom_label.custom_minimum_size.x = 58
	map_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zoom_row.add_child(map_zoom_label)
	var zoom_help := _label("Mouse wheel also zooms. Hold the middle mouse button and drag to move around.", 11, MUTED)
	zoom_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_group.add_child(zoom_help)
	var map_clip := PanelContainer.new()
	map_clip.name = "MapCanvasClip"
	map_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_clip.clip_contents = true
	map_group.add_child(map_clip)
	map_clip.add_child(map_canvas)

	# Restore an import preview if the user briefly visited another page.
	if imported_town.get("ok", false):
		map_canvas.set_map_data(imported_town)
		cbd_button.disabled = false
		import_summary_label.text = _statistics_text(imported_town.statistics)
		if not selected_cbd.is_empty():
			map_canvas.cbd_bounds = selected_cbd
			start_button.disabled = false
		if not selected_start.is_empty():
			map_canvas.start_location = selected_start
			start_button.text = "Change starting locations"
			selection_instructions.text = "Safe player and vehicle starting locations selected."
	if not selected_osm_files.is_empty():
		osm_files_label.text = _file_selection_text()
		scan_button.disabled = false
	_refresh_create_button()


func _show_game_settings_page() -> void:
	_clear_content()
	settings_controls.clear()
	content_area.add_child(_page_heading("Game settings", "Change how busy the town feels and how the player's vehicle handles. No code is required."))

	var town_row := HBoxContainer.new()
	content_area.add_child(town_row)
	settings_town_edit = LineEdit.new()
	settings_town_edit.placeholder_text = "Choose an existing town project folder"
	settings_town_edit.text = last_created_directory
	settings_town_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	town_row.add_child(settings_town_edit)
	town_row.add_child(_action_button("Choose town…", _choose_settings_town, false))
	town_row.add_child(_action_button("Load", _load_game_settings, false))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)

	form.add_child(_settings_group_heading("Town population", "Counts are totals across the town. CBD percentages decide how many should be in, or travelling toward, the CBD."))
	form.add_child(_settings_field("population", "traffic_car_count", "Traffic cars", "NPC vehicles; excludes the player's wagon.", 0, 1000, 1, " cars"))
	form.add_child(_settings_field("population", "pedestrian_count", "Walking NPCs", "Set this to zero for an empty pedestrian population.", 0, 2000, 1, " NPCs"))
	form.add_child(_settings_field("population", "cbd_car_percent", "Traffic in the CBD", "Target share in or heading toward the CBD.", 0, 100, 1, "%"))
	form.add_child(_settings_field("population", "cbd_pedestrian_percent", "Pedestrians in the CBD", "Target share in or heading toward the CBD.", 0, 100, 1, "%"))
	form.add_child(_settings_field("population", "robot_count", "Walking robots (NPR)", "Not Playable Robots use the pedestrian route network.", 0, 1000, 1, " NPRs"))
	form.add_child(_settings_field("population", "cbd_robot_percent", "NPRs in the CBD", "Target share of walking robots in, or travelling toward, the CBD.", 0, 100, 1, "%"))
	form.add_child(_settings_field("population", "drone_count", "Flying drones (NPD)", "Non-Playable Drones use the more lenient aerial route network.", 0, 1000, 1, " NPDs"))
	form.add_child(_settings_field("population", "cbd_drone_percent", "NPDs in the CBD", "Target share of flying drones in, or travelling toward, the CBD.", 0, 100, 1, "%"))

	form.add_child(_settings_group_heading("Road rules", "This saves which side moving traffic will use when playable lanes and turn paths are generated."))
	driving_side_option = OptionButton.new()
	driving_side_option.add_item("Drive on the left")
	driving_side_option.set_item_metadata(0, "left")
	driving_side_option.add_item("Drive on the right")
	driving_side_option.set_item_metadata(1, "right")
	form.add_child(driving_side_option)

	form.add_child(_settings_group_heading("Skin pigmentation tones", "Choose only the visual skin-tone mix for generated NPC artwork. These values do not affect any other NPC setting."))
	equalize_skin_tones_button = _action_button("Equalize percentages", Callable(), true)
	equalize_skin_tones_button.toggle_mode = true
	equalize_skin_tones_button.button_pressed = true
	equalize_skin_tones_button.toggled.connect(_on_equalize_skin_tones_toggled)
	form.add_child(equalize_skin_tones_button)
	form.add_child(_settings_field("skin_tone_distribution", "very_light_percent", "Very light", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	form.add_child(_settings_field("skin_tone_distribution", "light_percent", "Light", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	form.add_child(_settings_field("skin_tone_distribution", "medium_light_percent", "Medium-light", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	form.add_child(_settings_field("skin_tone_distribution", "medium_percent", "Medium", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	form.add_child(_settings_field("skin_tone_distribution", "medium_dark_percent", "Medium-dark", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	form.add_child(_settings_field("skin_tone_distribution", "dark_percent", "Dark", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	form.add_child(_settings_field("skin_tone_distribution", "very_dark_percent", "Very dark", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	skin_tone_total_label = _label("Total: 100%", 13, ACCENT)
	form.add_child(skin_tone_total_label)

	form.add_child(_settings_group_heading("Player vehicle", "These values control the same wagon handling used by the v1.3 game. Speeds are shown in the game's internal units."))
	form.add_child(_settings_field("driving", "forward_speed", "Maximum forward speed", "Higher values make the wagon faster.", 1, 400, 1, ""))
	form.add_child(_settings_field("driving", "reverse_speed", "Maximum reverse speed", "How quickly the wagon can reverse.", 1, 200, 1, ""))
	form.add_child(_settings_field("driving", "acceleration", "Forward acceleration", "How quickly the wagon reaches driving speed.", 1, 400, 1, ""))
	form.add_child(_settings_field("driving", "reverse_acceleration", "Reverse acceleration", "How quickly the wagon gains speed in reverse.", 1, 400, 1, ""))
	form.add_child(_settings_field("driving", "coast_deceleration", "Coasting slowdown", "How quickly the wagon slows when no pedal is pressed.", 1, 400, 1, ""))
	form.add_child(_settings_field("driving", "brake_deceleration", "Brake strength", "Higher values stop the wagon more sharply.", 1, 800, 1, ""))
	form.add_child(_settings_field("driving", "steering_rate", "Steering speed", "How quickly the wagon turns.", 0.1, 8, 0.1, ""))
	form.add_child(_settings_field("driving", "camera_zoom_multiplier", "Driving camera zoom", "Smaller values show more of the road.", 0.2, 2, 0.05, "×"))

	form.add_child(_settings_group_heading("Traffic jam recovery", "NPC cars that cannot make progress can be safely moved to another clear lane."))
	jam_recovery_check = CheckBox.new()
	jam_recovery_check.text = "Automatically relocate jammed NPC traffic"
	form.add_child(jam_recovery_check)
	form.add_child(_settings_field("traffic_recovery", "jam_timeout_seconds", "Wait before recovery", "Red and amber traffic-light waits do not count.", 5, 300, 1, " seconds"))
	form.add_child(_settings_field("traffic_recovery", "recovery_spacing_seconds", "Space out recoveries", "Prevents many cars moving at the same instant.", 0.25, 30, 0.25, " seconds"))
	form.add_child(_settings_field("traffic_recovery", "respawn_distance_pixels", "Minimum relocation distance", "Keeps the replacement away from the jam and player.", 100, 10000, 50, " pixels"))
	form.add_child(_settings_field("traffic_recovery", "respawn_attempts", "Safe-lane attempts", "How many legal, clear positions are tried.", 1, 200, 1, " tries"))

	var actions := HBoxContainer.new()
	form.add_child(actions)
	actions.add_child(_action_button("Restore recommended settings", _restore_recommended_settings, false))
	actions.add_child(_action_button("Save settings", _save_game_settings, true))
	_apply_settings_to_controls(GameSettingsStoreScript.recommended_settings())
	if not last_created_directory.is_empty():
		_load_game_settings()


func _choose_settings_town() -> void:
	if settings_town_edit != null and not settings_town_edit.text.strip_edges().is_empty():
		settings_town_dialog.current_dir = settings_town_edit.text.strip_edges()
	settings_town_dialog.popup_centered_ratio(0.72)


func _on_settings_town_selected(path_value: String) -> void:
	settings_town_edit.text = path_value
	_load_game_settings()


func _load_game_settings() -> void:
	if settings_town_edit == null or settings_town_edit.text.strip_edges().is_empty():
		_set_status("Choose a town project before loading settings.")
		return
	var result: Dictionary = GameSettingsStoreScript.load_from_town(settings_town_edit.text.strip_edges())
	_apply_settings_to_controls(result.settings)
	_set_status(result.message)


func _save_game_settings() -> void:
	if settings_town_edit == null or settings_town_edit.text.strip_edges().is_empty():
		_set_status("Choose a town project before saving settings.")
		return
	var town_directory := settings_town_edit.text.strip_edges()
	var settings := _settings_from_controls()
	var result: Dictionary = GameSettingsStoreScript.save_to_town(town_directory, settings)
	if not result.ok:
		_show_message("Settings need attention", result.message)
		_set_status(result.message)
		return
	selected_driving_side = str(settings.road_rules.driving_side)
	# Keep generated navigation metadata in sync with the chosen road side.
	var project_result: Dictionary = project_loader.load_project(town_directory)
	if project_result.ok:
		var update_result: Dictionary = content_pack_writer.update_town(
			town_directory,
			str(project_result.town.display_name),
			project_result.import_result,
			project_result.town.get("cbd", {}).get("bounds", {}),
			project_result.town.get("starting_location", {}),
			settings
		)
		if not update_result.ok:
			_show_message("Settings saved; pathfinding needs attention", update_result.message)
			_set_status(update_result.message)
			return
	_set_status("Game settings and pathfinding saved.")


func _restore_recommended_settings() -> void:
	_apply_settings_to_controls(GameSettingsStoreScript.recommended_settings())
	_set_status("Recommended values restored on screen. Select Save settings to keep them.")


func _apply_settings_to_controls(settings: Dictionary) -> void:
	updating_skin_tones = true
	for control_key in settings_controls:
		var parts: PackedStringArray = str(control_key).split(".")
		var group: Dictionary = settings.get(parts[0], {})
		var control: SpinBox = settings_controls[control_key]
		control.value = float(group.get(parts[1], control.value))
	if jam_recovery_check != null:
		jam_recovery_check.button_pressed = bool(settings.get("traffic_recovery", {}).get("enabled", true))
	if driving_side_option != null:
		var driving_side := str(settings.get("road_rules", {}).get("driving_side", "left"))
		driving_side_option.select(0 if driving_side == "left" else 1)
	updating_skin_tones = false
	if equalize_skin_tones_button != null:
		equalize_skin_tones_button.set_pressed_no_signal(_skin_tones_are_equal())
	_update_skin_tone_total()


func _settings_from_controls() -> Dictionary:
	var settings: Dictionary = GameSettingsStoreScript.recommended_settings()
	var integer_fields := ["population.traffic_car_count", "population.pedestrian_count", "population.cbd_car_percent", "population.cbd_pedestrian_percent", "population.robot_count", "population.cbd_robot_percent", "population.drone_count", "population.cbd_drone_percent", "traffic_recovery.respawn_attempts"]
	for control_key in settings_controls:
		var parts: PackedStringArray = str(control_key).split(".")
		var control: SpinBox = settings_controls[control_key]
		var value: Variant = roundi(control.value) if control_key in integer_fields else control.value
		settings[parts[0]][parts[1]] = value
	if equalize_skin_tones_button != null and equalize_skin_tones_button.button_pressed:
		settings.skin_tone_distribution = GameSettingsStoreScript.equalized_skin_tones()
	settings.traffic_recovery.enabled = jam_recovery_check.button_pressed
	settings.road_rules.driving_side = str(driving_side_option.get_selected_metadata())
	return settings


func _update_skin_tone_total(_unused := 0.0) -> void:
	if skin_tone_total_label == null:
		return
	var total := 0.0
	for control_key in settings_controls:
		if str(control_key).begins_with("skin_tone_distribution."):
			total += float(settings_controls[control_key].value)
	if equalize_skin_tones_button != null and equalize_skin_tones_button.button_pressed:
		skin_tone_total_label.text = "Equalized · Total: 100%"
	else:
		skin_tone_total_label.text = "Total: %.2f%% (must be 100%%)" % total
	skin_tone_total_label.add_theme_color_override("font_color", ACCENT if absf(total - 100.0) <= 0.05 else WARNING)


func _on_equalize_skin_tones_toggled(enabled: bool) -> void:
	if enabled:
		_equalize_skin_tones()


func _equalize_skin_tones() -> void:
	updating_skin_tones = true
	var equal_values: Dictionary = GameSettingsStoreScript.equalized_skin_tones()
	for key in equal_values:
		var control_key := "skin_tone_distribution.%s" % key
		if settings_controls.has(control_key):
			settings_controls[control_key].value = equal_values[key]
	updating_skin_tones = false
	_update_skin_tone_total()


func _on_skin_tone_changed(value: float) -> void:
	if not updating_skin_tones and equalize_skin_tones_button != null:
		equalize_skin_tones_button.set_pressed_no_signal(false)
	_update_skin_tone_total(value)


func _skin_tones_are_equal() -> bool:
	var lowest := INF
	var highest := -INF
	for control_key in settings_controls:
		if str(control_key).begins_with("skin_tone_distribution."):
			var value := float(settings_controls[control_key].value)
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
	return highest - lowest <= 0.02


func _show_system_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("System setup", "Clear checks for the software used by Creator Studio."))

	var version: Dictionary = Engine.get_version_info()
	var godot_ready: bool = int(version.major) == 4 and int(version.minor) >= 7
	var godot_message := "Godot %s is running Creator Studio." % version.string
	if not godot_ready:
		godot_message += " Version 4.7 or newer is recommended for this project."
	content_area.add_child(_status_card(
		"Godot",
		godot_message,
		"Ready" if godot_ready else "Needs attention",
		ACCENT if godot_ready else WARNING
	))

	content_area.add_child(_notice_panel(
		"Local model boundary",
		"A local LLM will only speak as NPC personas during player conversations. It is never used to create towns, artwork, interiors, personas or game code.",
		ACCENT_BLUE
	))

	var provider_panel := _panel_container(PANEL, 10)
	content_area.add_child(provider_panel)
	var provider_margin := MarginContainer.new()
	provider_margin.add_theme_constant_override("margin_left", 18)
	provider_margin.add_theme_constant_override("margin_right", 18)
	provider_margin.add_theme_constant_override("margin_top", 16)
	provider_margin.add_theme_constant_override("margin_bottom", 16)
	provider_panel.add_child(provider_margin)
	var providers := VBoxContainer.new()
	providers.add_theme_constant_override("separation", 8)
	provider_margin.add_child(providers)
	providers.add_child(_label("NPC dialogue providers", 18, TEXT))
	providers.add_child(_label("These checks are optional. Town creation works without a local model.", 12, MUTED))
	provider_status_labels.clear()
	for provider in LocalLlmProbeScript.PROVIDERS:
		var provider_label := _label("%s · Not checked" % provider.name, 13, MUTED)
		providers.add_child(provider_label)
		provider_status_labels[provider.id] = provider_label
	providers.add_child(_action_button("Check local model services", _check_local_models, false))


func _choose_osm_files() -> void:
	osm_file_dialog.popup_centered_ratio(0.75)


func _choose_workspace() -> void:
	if workspace_edit != null and not workspace_edit.text.strip_edges().is_empty():
		workspace_dialog.current_dir = workspace_edit.text.strip_edges()
	workspace_dialog.popup_centered_ratio(0.72)


func _on_osm_files_selected(paths: PackedStringArray) -> void:
	selected_osm_files = paths
	original_osm_files = paths.duplicate()
	osm_files_label.text = _file_selection_text()
	scan_button.disabled = selected_osm_files.is_empty()
	imported_town = {}
	selected_cbd = {}
	selected_start = {}
	_refresh_create_button()


func _on_workspace_selected(path_value: String) -> void:
	workspace_edit.text = path_value
	current_workspace = path_value
	_save_workspace_preference(path_value)
	_set_status("Game files will be saved inside %s" % path_value)
	_refresh_create_button()


func _on_town_name_changed(value: String) -> void:
	current_town_name = value
	_refresh_create_button()


func _scan_osm_files() -> void:
	_set_status("Reading OpenStreetMap files…")
	imported_town = importer.parse_files(selected_osm_files)
	if not imported_town.get("ok", false):
		import_summary_label.text = imported_town.message
		import_summary_label.add_theme_color_override("font_color", WARNING)
		_set_status("The OSM files need attention.")
		return
	if imported_town.get("warnings", []).is_empty():
		import_summary_label.remove_theme_color_override("font_color")
	else:
		import_summary_label.add_theme_color_override("font_color", WARNING)
	import_summary_label.text = _import_summary_text(imported_town)
	selected_cbd = {}
	selected_start = {}
	map_canvas.set_map_data(imported_town)
	cbd_button.disabled = false
	start_button.disabled = true
	start_button.text = "Choose start on map"
	selection_instructions.text = "Click Draw CBD and drag a rectangle. Then click Set start and choose a location."
	_set_map_mode(TownMapCanvasScript.EditMode.DRAW_CBD)
	_set_status("Town preview ready. Draw the CBD area." if imported_town.get("warnings", []).is_empty() else "Town preview ready with an OSM water warning shown above.")
	_refresh_create_button()


func _set_map_mode(mode: int) -> void:
	if map_canvas == null or not imported_town.get("ok", false):
		_set_status("Read OSM files before using the map tools.")
		return
	map_canvas.set_edit_mode(mode)
	match mode:
		TownMapCanvasScript.EditMode.DRAW_CBD:
			cbd_button.text = "CBD tool active — drag on map"
			selection_instructions.text = "CBD tool active. Drag a rectangle around the CBD area."
		TownMapCanvasScript.EditMode.SET_START:
			start_button.text = "Start tool active — click map"
			selection_instructions.remove_theme_color_override("font_color")
			selection_instructions.text = "Start tool active. Now click an open position on the map."
		_:
			selection_instructions.text = "Click a building to inspect its OSM identity."


func _activate_start_tool() -> void:
	if selected_cbd.is_empty():
		_set_status("Draw the CBD before choosing the starting locations.")
		return
	_set_map_mode(TownMapCanvasScript.EditMode.SET_START)
	_set_status("Start tool active. Click an open position on the map preview.")


func _zoom_map_in() -> void:
	if map_canvas != null:
		map_canvas.zoom_in()
		_update_map_zoom_label()


func _zoom_map_out() -> void:
	if map_canvas != null:
		map_canvas.zoom_out()
		_update_map_zoom_label()


func _reset_map_zoom() -> void:
	if map_canvas != null:
		map_canvas.reset_view()
		_update_map_zoom_label()


func _update_map_zoom_label() -> void:
	if map_zoom_label != null and map_canvas != null:
		map_zoom_label.text = "%d%%" % roundi(map_canvas.view_zoom * 100.0)


func _on_map_view_changed(zoom: float) -> void:
	if map_zoom_label != null:
		map_zoom_label.text = "%d%%" % roundi(zoom * 100.0)


func _on_cbd_changed(bounds: Dictionary) -> void:
	selected_cbd = bounds.duplicate(true)
	cbd_button.text = "Change CBD area"
	start_button.disabled = false
	selection_instructions.text = "CBD selected. Continue to Step 4 and select Choose start on map."
	_set_status("CBD area selected.")
	_refresh_create_button()


func _on_start_changed(location: Dictionary) -> void:
	selected_start = location.duplicate(true)
	selection_instructions.remove_theme_color_override("font_color")
	start_button.text = "Change starting locations"
	selection_instructions.text = "Safe player start selected. A separate clear road position was found for the player's vehicle."
	_set_status("Starting location selected.")
	_refresh_create_button()


func _on_start_rejected(message: String) -> void:
	selected_start = {}
	selection_instructions.text = message
	selection_instructions.add_theme_color_override("font_color", WARNING)
	start_button.text = "Try another position on map"
	_set_status("Choose another starting point: %s" % message)
	_refresh_create_button()


func _on_building_selected(building: Dictionary) -> void:
	var record: Dictionary = BuildingInformationScript.describe_feature(building)
	var lines: Array[String] = [
		str(record.name),
		"Mapped use: %s" % str(record.category)
	]
	if not str(record.address).is_empty():
		lines.append("Address: %s" % str(record.address))
	if not str(record.operator).is_empty():
		lines.append("Operator: %s" % str(record.operator))
	lines.append("Source: %s · %s" % [str(record.source_attribution), str(record.source_reference)])
	lines.append("Only tags attached to this footprint are shown; missing details are not invented.")
	building_information.text = "\n".join(PackedStringArray(lines))


func _refresh_create_button(_unused := "") -> void:
	if create_town_button == null:
		return
	var missing := _creation_missing_requirements()
	# Keep the button clickable so a non-technical creator can ask the program what
	# is missing instead of being left with an unexplained grey button.
	create_town_button.disabled = false
	if creation_readiness_label == null:
		return
	if missing.is_empty():
		creation_readiness_label.text = "Ready. Select %s, then Play test project." % ("Save project changes" if not loaded_project_directory.is_empty() else "Create town project")
		creation_readiness_label.add_theme_color_override("font_color", ACCENT)
	else:
		creation_readiness_label.text = "Still needed: %s." % ", ".join(missing)
		creation_readiness_label.add_theme_color_override("font_color", WARNING)


func _creation_missing_requirements() -> PackedStringArray:
	var missing := PackedStringArray()
	if town_name_edit == null or town_name_edit.text.strip_edges().is_empty():
		missing.append("enter a town name in Step 1")
	if not imported_town.get("ok", false):
		missing.append("read the OSM map in Step 2")
	if selected_cbd.is_empty():
		missing.append("draw the CBD in Step 3")
	elif imported_town.get("ok", false) and not content_pack_writer._bounds_contains_bounds(imported_town.bounds, selected_cbd):
		missing.append("redraw the CBD inside this imported map in Step 3")
	if selected_start.is_empty():
		missing.append("choose the player start in Step 4")
	if workspace_edit == null or workspace_edit.text.strip_edges().is_empty():
		missing.append("choose a save directory in Step 6")
	return missing


func _create_town_project() -> bool:
	var rebuilding := rebuild_in_progress
	var source_note := rebuild_source_note
	rebuild_in_progress = false
	rebuild_source_note = ""
	var missing := _creation_missing_requirements()
	if not missing.is_empty():
		_show_message(
			"Finish the town setup",
			"Before Creator Studio can make the playable project, please %s. Your imported map and selections are still safe in this window."
			% ", then ".join(missing)
		)
		_set_status("Town setup is incomplete: %s." % ", ".join(missing))
		return false
	_set_status("Rebuilding the town from its saved OSM files…" if rebuilding else "Creating the town project…")
	var project_settings := _settings_for_project_save()
	var result: Dictionary
	if not loaded_project_directory.is_empty():
		result = content_pack_writer.update_town(
			loaded_project_directory,
			town_name_edit.text,
			imported_town,
			selected_cbd,
			selected_start,
			project_settings
		)
	else:
		result = content_pack_writer.save_town(
			workspace_edit.text.strip_edges(),
			town_name_edit.text,
			selected_osm_files,
			imported_town,
			selected_cbd,
			selected_start,
			project_settings
		)
	if not result.ok:
		_set_status("Could not %s the town: %s" % ["rebuild" if rebuilding else "create", result.message])
		_show_message("Could not %s the town" % ("rebuild" if rebuilding else "create"), "%s Your imported map and selections are still safe in this window." % result.message)
		return false
	last_created_directory = result.town_directory
	loaded_project_directory = result.town_directory
	current_workspace = result.town_directory.get_base_dir()
	open_folder_button.disabled = false
	play_test_button.disabled = false
	rebuild_project_button.disabled = false
	create_town_button.text = "Save project changes"
	_save_workspace_preference(workspace_edit.text.strip_edges())
	_save_recent_project(last_created_directory)
	_set_status("Town rebuilt: %s" % last_created_directory if rebuilding else "Town created: %s" % last_created_directory)
	var navigation_summary: Dictionary = result.validation.get("navigation", {})
	var traffic_signal_count := int(navigation_summary.get("traffic_signal_nodes", 0))
	var stop_sign_count := int(navigation_summary.get("stop_sign_nodes", 0))
	var give_way_count := int(navigation_summary.get("give_way_nodes", 0))
	var control_message := " Imported controls: %d traffic lights, %d stop signs and %d give-way signs." % [traffic_signal_count, stop_sign_count, give_way_count]
	if traffic_signal_count + stop_sign_count + give_way_count == 0:
		control_message = " No mapped traffic controls were found, so cars will use basic safe intersection rules."
	var geometry_summary: Dictionary = navigation_summary.get("map_geometry", {})
	var blocked_segment_count := int(geometry_summary.get("blocked_ground_road_segments", 0))
	var vertical_road_count := int(geometry_summary.get("unclassified_vertical_roads", 0))
	var clearance_count := int(geometry_summary.get("road_clearance_conflicts", 0))
	var geometry_message := ""
	if blocked_segment_count > 0 or vertical_road_count > 0 or clearance_count > 0:
		geometry_message = " Safety check: %d road segment(s) through solid buildings and %d ambiguous layered road(s) were excluded; %d close but centre-line-clear segment(s) were kept for review. Details are saved in validation.json." % [blocked_segment_count, vertical_road_count, clearance_count]
	var parking_area_count := int(imported_town.get("statistics", {}).get("parking_areas", 0))
	var transport_message := " Roads, kerbs and footpaths use metre-based vehicle scale. %d mapped surface car park(s) were preserved; inferred bay guides are visual defaults." % parking_area_count
	var rebuild_note := " Rebuild source: %s." % source_note if rebuilding and not source_note.is_empty() else ""
	selection_instructions.text = "%s successfully. Building information, collisions, pathfinding and traffic rules were generated automatically from the OSM map.%s%s%s%s Hover or click a building during Play test to read its mapped details. Your source files remain unchanged." % ["Town project rebuilt" if rebuilding else "Town project created", control_message, geometry_message, transport_message, rebuild_note]
	return true


func _rebuild_loaded_project() -> void:
	if loaded_project_directory.is_empty():
		_show_message("Open a project to rebuild", "Open a previous project first, then select Rebuild project.")
		return
	var rebuild_sources := selected_osm_files
	var source_note := "the saved project copy"
	if original_osm_files.size() == selected_osm_files.size() and _all_source_files_exist(original_osm_files):
		rebuild_sources = original_osm_files
		source_note = "the original OSM location"
	if rebuild_sources.is_empty():
		_show_message("Saved map source is missing", "This project does not have a readable saved .osm source. Its existing generated files have not been changed.")
		return
	_set_status("Checking the saved OSM files before rebuilding…")
	var refreshed: Dictionary = importer.parse_files(rebuild_sources)
	if not refreshed.get("ok", false):
		_show_message("Could not rebuild the project", "%s The existing generated project has not been changed." % str(refreshed.get("message", "The saved OSM source could not be read.")))
		_set_status("Rebuild stopped because the saved OSM source needs attention.")
		return
	var validation: Dictionary = content_pack_writer.validate_town(town_name_edit.text, refreshed, selected_cbd, selected_start)
	if not validation.passed:
		_show_message("Could not rebuild the project", "%s The existing generated project has not been changed." % str(validation.errors[0]))
		_set_status("Rebuild stopped: %s" % str(validation.errors[0]))
		return
	imported_town = refreshed
	map_canvas.set_map_data(imported_town)
	map_canvas.cbd_bounds = selected_cbd.duplicate(true)
	map_canvas.start_location = selected_start.duplicate(true)
	map_canvas.queue_redraw()
	import_summary_label.text = _import_summary_text(imported_town)
	rebuild_in_progress = true
	rebuild_source_note = source_note
	_create_town_project()


func _all_source_files_exist(paths: PackedStringArray) -> bool:
	if paths.is_empty():
		return false
	for path_value in paths:
		if not FileAccess.file_exists(path_value):
			return false
	return true


func _settings_for_project_save() -> Dictionary:
	var settings: Dictionary = GameSettingsStoreScript.recommended_settings()
	if not loaded_project_directory.is_empty():
		var loaded_settings: Dictionary = GameSettingsStoreScript.load_from_town(loaded_project_directory)
		if loaded_settings.ok:
			settings = loaded_settings.settings.duplicate(true)
	settings.road_rules.driving_side = selected_driving_side
	return settings


func _on_setup_driving_side_selected(index: int) -> void:
	selected_driving_side = str(setup_driving_side_option.get_item_metadata(index))
	_set_status("Traffic will drive on the %s." % selected_driving_side)


func _open_created_folder() -> void:
	if not last_created_directory.is_empty():
		OS.shell_open(last_created_directory)


func _choose_project_to_load() -> void:
	project_dialog_action = "load"
	_prepare_existing_project_dialog()


func _choose_project_to_play() -> void:
	project_dialog_action = "play"
	_prepare_existing_project_dialog()


func _prepare_existing_project_dialog() -> void:
	var recent_project := _load_recent_project()
	if not recent_project.is_empty():
		existing_project_dialog.current_dir = recent_project
	elif not _load_workspace_preference().is_empty():
		existing_project_dialog.current_dir = _load_workspace_preference()
	existing_project_dialog.popup_centered_ratio(0.72)


func _on_existing_project_selected(path_value: String) -> void:
	if project_dialog_action == "play":
		_play_project(path_value)
	else:
		_load_existing_project(path_value)


func _load_existing_project(path_value: String) -> void:
	_set_status("Loading the saved project…")
	var result: Dictionary = project_loader.load_project(path_value)
	if not result.ok:
		_show_message("Could not open project", result.message)
		_set_status(result.message)
		return
	loaded_project_directory = result.town_directory
	last_created_directory = result.town_directory
	current_workspace = result.town_directory.get_base_dir()
	current_town_name = str(result.town.display_name)
	selected_osm_files = result.source_files
	original_osm_files = result.original_source_files
	imported_town = result.import_result
	selected_cbd = result.town.get("cbd", {}).get("bounds", {}).duplicate(true)
	selected_start = result.town.get("starting_location", {}).duplicate(true)
	var loaded_settings: Dictionary = GameSettingsStoreScript.load_from_town(result.town_directory)
	if loaded_settings.ok:
		selected_driving_side = str(loaded_settings.settings.get("road_rules", {}).get("driving_side", "left"))
	_save_recent_project(loaded_project_directory)
	_show_town_import_page()
	_set_status("Loaded %s. You can continue editing and save changes." % current_town_name)


func _play_current_project() -> void:
	if last_created_directory.is_empty():
		var missing := _creation_missing_requirements()
		if not missing.is_empty():
			_show_message(
				"Finish setup before Play test",
				"This test game cannot be built yet. Please %s. Your current map and completed selections are still safe in this window."
				% ", then ".join(missing)
			)
			_set_status("Play test is waiting for: %s." % ", ".join(missing))
		else:
			# The creator may reasonably press Play once setup is ready. Generate the
			# project for them instead of sending them back to a different button.
			if _create_town_project():
				_show_message("Town project created", "Creator Studio generated the collisions, pathfinding and playable files. Select Play test project again to open the game.")
		return
	_play_project(last_created_directory)


func _play_project(path_value: String) -> void:
	var result: Dictionary = project_loader.load_project(path_value)
	if not result.ok:
		_show_message("Could not open project", result.message)
		return
	_save_recent_project(result.town_directory)
	if not result.runtime_ready:
		var navigation_sentence := " Pathfinding data has been generated from this town's OSM roads." if result.navigation_ready else " Pathfinding data will be generated when you save the project changes."
		var collision_sentence := " Building collision shapes are ready." if result.building_collisions_ready else " Building collisions will be generated when you save the project changes."
		_show_message(
			"Playable game not generated yet",
			"%s is a valid Creator Studio content project, but it does not contain the town-independent playable runtime yet. Your town, CBD, starting locations and settings are safe.%s Use Open previous project to continue editing it."
			% [result.town.display_name, navigation_sentence + collision_sentence]
		)
		return
	_launch_playable_preview(result.town_directory)


func _launch_playable_preview(town_path: String) -> void:
	var executable := OS.get_executable_path()
	var arguments := PackedStringArray()
	if executable.get_file().to_lower().begins_with("godot"):
		arguments.append("--path")
		arguments.append(ProjectSettings.globalize_path("res://"))
		arguments.append("--")
	arguments.append("--play-town")
	arguments.append(town_path)
	var process_id := OS.create_process(executable, arguments)
	if process_id <= 0:
		_show_message("Could not start play test", "Creator Studio could not open the playable preview. Your project remains safe.")
		return
	_show_message("Play test launched", "The imported-town preview is opening in a separate window. Press Escape in the game window when you are finished.")
	_set_status("Play test launched for %s." % town_path.get_file())


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index] == name and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""


func _show_message(title: String, message: String) -> void:
	message_dialog.title = title
	message_dialog.dialog_text = message
	var message_label := message_dialog.get_label()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(680, 120)
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	message_dialog.popup_centered(Vector2i(760, 270))


func _check_local_models() -> void:
	for label_value in provider_status_labels.values():
		var label: Label = label_value
		label.text = label.text.get_slice(" · ", 0) + " · Checking…"
		label.add_theme_color_override("font_color", MUTED)
	_set_status("Checking optional local model services for future NPC dialogue…")
	llm_probe.check_all()


func _on_provider_checked(provider_id: String, available: bool, detail: String) -> void:
	if not provider_status_labels.has(provider_id):
		return
	var label: Label = provider_status_labels[provider_id]
	label.text = detail
	label.add_theme_color_override("font_color", ACCENT if available else MUTED)


func _on_provider_checks_finished() -> void:
	_set_status("Local model check finished. These services are only for future NPC dialogue.")


func _load_workspace_preference() -> String:
	var default_path := ProjectSettings.globalize_path("user://creator_projects")
	var preferences := ConfigFile.new()
	if preferences.load("user://creator_preferences.cfg") == OK:
		return str(preferences.get_value("files", "workspace", default_path))
	return default_path


func _save_workspace_preference(path_value: String) -> void:
	var preferences := ConfigFile.new()
	preferences.load("user://creator_preferences.cfg")
	preferences.set_value("files", "workspace", path_value)
	preferences.save("user://creator_preferences.cfg")


func _load_recent_project() -> String:
	var preferences := ConfigFile.new()
	if preferences.load("user://creator_preferences.cfg") == OK:
		var path_value := str(preferences.get_value("files", "recent_project", ""))
		if not path_value.is_empty() and FileAccess.file_exists(path_value.path_join("town.json")):
			return path_value
	return ""


func _save_recent_project(path_value: String) -> void:
	var preferences := ConfigFile.new()
	preferences.load("user://creator_preferences.cfg")
	preferences.set_value("files", "recent_project", path_value)
	preferences.save("user://creator_preferences.cfg")


func _file_selection_text() -> String:
	if selected_osm_files.is_empty():
		return "No files selected"
	if selected_osm_files.size() == 1:
		return selected_osm_files[0].get_file()
	return "%d files selected, beginning with %s" % [selected_osm_files.size(), selected_osm_files[0].get_file()]


func _statistics_text(statistics: Dictionary) -> String:
	return "Found %s building footprints, %s roads and %s closed water areas across %s source files. Bridges: %s · tunnels: %s · land-cover areas: %s." % [
		_format_number(statistics.buildings),
		_format_number(statistics.roads),
		_format_number(int(statistics.get("water_areas", 0))),
		statistics.source_files,
		_format_number(int(statistics.get("bridge_roads", 0))),
		_format_number(int(statistics.get("tunnel_roads", 0))),
		_format_number(int(statistics.get("land_cover_areas", 0)))
	]


func _import_summary_text(import_result: Dictionary) -> String:
	var result := _statistics_text(import_result.get("statistics", {}))
	var warnings: Array = import_result.get("warnings", [])
	if not warnings.is_empty():
		result += "\nMap data warning: %s" % str(warnings[0])
		if warnings.size() > 1:
			result += " (%d additional warnings will be saved in validation.json.)" % (warnings.size() - 1)
	return result


func _format_number(number: int) -> String:
	var digits := str(number)
	var result := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result


func _clear_content() -> void:
	for child in content_area.get_children():
		content_area.remove_child(child)
		child.queue_free()


func _set_status(message: String) -> void:
	status_label.text = message


func _label(text_value: String, font_size: int, colour: Color) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", colour)
	return result


func _section_caption(text_value: String) -> Label:
	var result := _label(text_value, 11, MUTED)
	result.add_theme_constant_override("outline_size", 1)
	return result


func _panel_container(colour: Color, corner_radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _page_heading(title: String, subtitle: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 3)
	group.add_child(_label(title, 26, TEXT))
	var subtitle_label := _label(subtitle, 14, MUTED)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(subtitle_label)
	return group


func _step_heading(number: String, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var badge := _label(number, 13, BACKGROUND)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(24, 24)
	var badge_panel := _panel_container(ACCENT, 12)
	badge_panel.add_child(badge)
	row.add_child(badge_panel)
	row.add_child(_label(title, 16, TEXT))
	return row


func _settings_group_heading(title: String, description: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 3)
	group.add_child(HSeparator.new())
	group.add_child(_label(title, 18, ACCENT))
	var description_label := _label(description, 12, MUTED)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(description_label)
	return group


func _settings_field(group_name: String, key: String, label_text: String, help_text: String, minimum: float, maximum: float, step: float, suffix: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 54
	var description := VBoxContainer.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description)
	description.add_child(_label(label_text, 14, TEXT))
	var help_label := _label(help_text, 11, MUTED)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_child(help_label)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.suffix = suffix
	input.custom_minimum_size.x = 145
	input.allow_greater = false
	input.allow_lesser = false
	if group_name == "skin_tone_distribution":
		input.value_changed.connect(_on_skin_tone_changed)
	row.add_child(input)
	settings_controls["%s.%s" % [group_name, key]] = input
	return row


func _navigation_button(text_value: String, callback: Callable, highlighted := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 39
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", ACCENT if highlighted else TEXT)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _disabled_navigation_button(text_value: String) -> Button:
	var button := _navigation_button(text_value, Callable())
	button.disabled = true
	return button


func _action_button(text_value: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size", 13)
	if primary:
		button.add_theme_color_override("font_color", ACCENT)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _feature_card(title: String, description: String, button_text: String, callback: Callable) -> PanelContainer:
	var card := _panel_container(PANEL, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	margin.add_child(contents)
	contents.add_child(_label(title, 19, TEXT))
	var description_label := _label(description, 13, MUTED)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(description_label)
	var button := _action_button(button_text, callback, callback.is_valid())
	button.disabled = not callback.is_valid()
	contents.add_child(button)
	return card


func _notice_panel(title: String, message: String, colour: Color) -> PanelContainer:
	var panel := _panel_container(PANEL, 10)
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.border_width_left = 4
	style.border_color = colour
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	margin.add_child(group)
	group.add_child(_label(title, 16, colour))
	var message_label := _label(message, 13, MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(message_label)
	return panel


func _status_card(title: String, message: String, status: String, colour: Color) -> PanelContainer:
	var panel := _panel_container(PANEL, 10)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var description_group := VBoxContainer.new()
	description_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description_group)
	description_group.add_child(_label(title, 17, TEXT))
	var message_label := _label(message, 12, MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_group.add_child(message_label)
	var status_label_value := _label(status, 13, colour)
	status_label_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(status_label_value)
	return panel
