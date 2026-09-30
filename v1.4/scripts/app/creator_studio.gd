extends Control

const OsmImporterScript = preload("res://scripts/towns/osm_importer.gd")
const TownMapCanvasScript = preload("res://scripts/towns/map_canvas.gd")
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const ContentPackWriterScript = preload("res://scripts/content/content_pack.gd")
const LocalLlmProbeScript = preload("res://scripts/npcs/local_llm_probe.gd")
const PersonaStoreScript = preload("res://scripts/npcs/persona_store.gd")
const TownKnowledgeStoreScript = preload("res://scripts/npcs/town_knowledge_store.gd")
const StorylineNpcStoreScript = preload("res://scripts/npcs/storyline_npc_store.gd")
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")
const ProjectLoaderScript = preload("res://scripts/content/project_loader.gd")
const BuildingInformationScript = preload("res://scripts/places/osm_building_information.gd")
const MapOverrideStoreScript = preload("res://scripts/editor/map_override_store.gd")
const BuildingExteriorStoreScript = preload("res://scripts/buildings/building_exterior_store.gd")
const BuildingFootprintExporterScript = preload("res://scripts/buildings/building_footprint_exporter.gd")
const BuildingInteriorStoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const InteriorFloorCanvasScript = preload("res://scripts/interiors/interior_floor_canvas.gd")
const ItemCatalogEditorScript = preload("res://scripts/inventory/item_catalog_editor.gd")
const ItemCatalogStoreScript = preload("res://scripts/inventory/item_catalog_store.gd")

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
var persona_store = PersonaStoreScript.new()
var persona_data: Dictionary = {}
var town_knowledge_store = TownKnowledgeStoreScript.new()
var town_knowledge_data: Dictionary = {}
var town_custom_text := ""
var storyline_npc_store = StorylineNpcStoreScript.new()
var storyline_npc_data: Dictionary = {}
var storyline_coordinate_edit: LineEdit
var storyline_name_edit: LineEdit
var storyline_persona_option: OptionButton
var storyline_npc_option: OptionButton
var storyline_npc_status_label: Label
var storyline_remove_button: Button
var persona_option: OptionButton
var persona_model_option: OptionButton
var persona_actor_label: Label
var persona_name_edit: LineEdit
var persona_background_edit: TextEdit
var persona_personality_edit: LineEdit
var persona_style_edit: LineEdit
var persona_greeting_edit: LineEdit
var persona_delete_button: Button
var persona_status_label: Label
var wikipedia_url_edit: LineEdit
var town_wikipedia_status_label: Label
var town_text_status_label: Label
var town_text_preview_label: Label
var persona_page_scroll: ScrollContainer
var persona_form_index := -1

var content_area: VBoxContainer
var status_label: Label
var osm_file_dialog: FileDialog
var workspace_dialog: FileDialog
var settings_town_dialog: FileDialog
var existing_project_dialog: FileDialog
var building_image_dialog: FileDialog
var building_footprint_dialog: FileDialog
var town_text_dialog: FileDialog
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
var map_override_store = MapOverrideStoreScript.new()
var editor_map_canvas: Control
var editor_overrides: Dictionary = {}
var editor_undo_stack: Array[Dictionary] = []
var editor_redo_stack: Array[Dictionary] = []
var editor_selected_building_id := ""
var editor_selection_label: Label
var editor_summary_label: Label
var editor_toggle_building_button: Button
var editor_undo_button: Button
var editor_redo_button: Button
var editor_remove_zone_button: Button
var editor_zoom_label: Label
var editor_coordinate_status_label: Label
var building_exterior_store = BuildingExteriorStoreScript.new()
var building_footprint_exporter = BuildingFootprintExporterScript.new()
var building_map_canvas: Control
var building_exterior_data: Dictionary = {}
var building_effective_features: Array = []
var building_selected_feature: Dictionary = {}
var building_selection_label: Label
var building_summary_label: Label
var building_import_button: Button
var building_export_button: Button
var building_door_button: Button
var building_remove_button: Button
var building_save_button: Button
var building_zoom_label: Label
var building_scale_control: SpinBox
var building_rotation_control: SpinBox
var building_offset_x_control: SpinBox
var building_offset_y_control: SpinBox
var building_entrance_option: OptionButton
var building_move_entrance_button: Button
var building_remove_entrance_button: Button
var building_pending_door_index := -1
var building_updating_controls := false
var building_interior_store = BuildingInteriorStoreScript.new()
var interior_data: Dictionary = {}
var interior_exterior_data: Dictionary = {}
var interior_eligible_features: Array[Dictionary] = []
var interior_selected_feature: Dictionary = {}
var interior_building_option: OptionButton
var interior_entrance_option: OptionButton
var interior_create_button: Button
var interior_add_floor_button: Button
var interior_floor_option: OptionButton
var interior_size_control: SpinBox
var interior_resize_button: Button
var interior_place_entry_button: Button
var interior_storyline_location_button: Button
var interior_storyline_location_label: Label
var interior_save_button: Button
var interior_summary_label: Label
var interior_floor_canvas: Control


func _ready() -> void:
	if not _argument_value("--play-town").is_empty():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/runtime/town_runtime.tscn")
		return
	_build_file_dialogs()
	_build_shell()
	llm_probe = LocalLlmProbeScript.new()
	add_child(llm_probe)
	llm_probe.provider_checked.connect(_on_provider_checked)
	llm_probe.provider_models.connect(_on_provider_models)
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
	title_group.add_child(_label("v1.4 · No-code digital-world development", 13, MUTED))
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
	sidebar.add_child(_navigation_button("Advanced map editor", _show_advanced_map_editor_page))
	sidebar.add_child(_navigation_button("Building Creator", _show_building_creator_page))
	sidebar.add_child(_navigation_button("Interior designer", _show_interior_designer_page))
	sidebar.add_child(_navigation_button("NPCs and personas", _show_personas_page))
	sidebar.add_child(_navigation_button("Inventory items", _show_inventory_page))
	sidebar.add_child(_navigation_button("System setup", _show_system_page))
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

	building_image_dialog = FileDialog.new()
	building_image_dialog.title = "Choose exterior artwork for the selected building"
	building_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	building_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	building_image_dialog.filters = PackedStringArray([
		"*.png ; PNG images", "*.jpg,*.jpeg ; JPEG images", "*.webp ; WebP images"
	])
	building_image_dialog.file_selected.connect(_on_building_exterior_image_selected)
	add_child(building_image_dialog)

	building_footprint_dialog = FileDialog.new()
	building_footprint_dialog.title = "Save a footprint template for Microsoft Paint"
	building_footprint_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	building_footprint_dialog.access = FileDialog.ACCESS_FILESYSTEM
	building_footprint_dialog.filters = PackedStringArray(["*.png ; Transparent PNG template"])
	building_footprint_dialog.file_selected.connect(_on_building_footprint_path_selected)
	add_child(building_footprint_dialog)

	town_text_dialog = FileDialog.new()
	town_text_dialog.title = "Choose optional town-information text"
	town_text_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	town_text_dialog.access = FileDialog.ACCESS_FILESYSTEM
	town_text_dialog.filters = PackedStringArray(["*.txt ; UTF-8 plain-text files"])
	town_text_dialog.file_selected.connect(_on_town_text_file_selected)
	add_child(town_text_dialog)

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
		"v1.4 completed release",
		"v1.4 preserves the completed v1.3 workflow and adds the first no-code map, building, interior, persona and inventory creator stages.",
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


func _show_advanced_map_editor_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Advanced map editor", "Correct selected OSM mistakes without changing the original map files."))
	if loaded_project_directory.is_empty() or not imported_town.get("ok", false):
		content_area.add_child(_notice_panel(
			"Open a saved town first",
			"The editor stores corrections inside one town project. Choose a project containing town.json; its copied and original OSM files remain unchanged.",
			WARNING
		))
		content_area.add_child(_action_button("Open town project…", _choose_project_for_map_editor, true))
		return
	var load_result := map_override_store.load_from_town(loaded_project_directory, imported_town.features, imported_town.bounds)
	if not load_result.ok:
		content_area.add_child(_notice_panel("Could not read map corrections", load_result.message, WARNING))
		return
	editor_overrides = load_result.data.duplicate(true)
	editor_undo_stack.clear()
	editor_redo_stack.clear()
	editor_selected_building_id = ""

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(split)
	var tools_scroll := ScrollContainer.new()
	tools_scroll.custom_minimum_size.x = 360
	split.add_child(tools_scroll)
	var tools_margin := MarginContainer.new()
	tools_margin.add_theme_constant_override("margin_right", 18)
	tools_scroll.add_child(tools_margin)
	var tools_column := VBoxContainer.new()
	tools_column.custom_minimum_size.x = 330
	tools_column.add_theme_constant_override("separation", 10)
	tools_margin.add_child(tools_column)
	tools_column.add_child(_label("Editing: %s" % current_town_name, 17, TEXT))
	var source_note := _label("Corrections are saved separately from OpenStreetMap and reapplied whenever the project is rebuilt.", 12, MUTED)
	source_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(source_note)
	tools_column.add_child(_settings_group_heading("Building footprints", "Select an imported building, then hide it if OSM placed it incorrectly. Select a hidden red footprint to restore it."))
	tools_column.add_child(_action_button("Select building", func(): _set_editor_mode(TownMapCanvasScript.EditMode.HIDE_BUILDING), false))
	editor_toggle_building_button = _action_button("Hide selected building", _toggle_editor_building, true)
	editor_toggle_building_button.disabled = true
	tools_column.add_child(editor_toggle_building_button)
	editor_selection_label = _label("No building selected.", 12, MUTED)
	editor_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(editor_selection_label)
	tools_column.add_child(_settings_group_heading("Water correction", "Draw a rectangle over missing water to block all ground actors, or over incorrectly mapped water to make that area passable. NPD drones remain aerial."))
	tools_column.add_child(_action_button("Draw blocked water", func(): _set_editor_mode(TownMapCanvasScript.EditMode.DRAW_BLOCKED_WATER), false))
	tools_column.add_child(_action_button("Draw passable ground", func(): _set_editor_mode(TownMapCanvasScript.EditMode.DRAW_ALLOWED_GROUND), false))
	editor_remove_zone_button = _action_button("Remove newest water correction", _remove_latest_editor_zone, false)
	tools_column.add_child(editor_remove_zone_button)
	var water_note := _label("Passable ground corrects water only; it does not erase a building. Hide an incorrect building separately.", 11, MUTED)
	water_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(water_note)
	tools_column.add_child(_settings_group_heading("Storyline NPC coordinates", "Select this tool, click an outdoor location, then paste the copied latitude and longitude into the Storyline NPC creator."))
	tools_column.add_child(_action_button("Select location and copy coordinates", func(): _set_editor_mode(TownMapCanvasScript.EditMode.COPY_COORDINATES), true))
	editor_coordinate_status_label = _label("No location copied yet. Coordinate order is latitude, longitude.", 11, MUTED)
	editor_coordinate_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(editor_coordinate_status_label)
	tools_column.add_child(_settings_group_heading("Review and save", "Undo or redo edits in this session. Save and rebuild regenerates collisions, navigation and destinations using the corrections."))
	var history_row := HBoxContainer.new()
	tools_column.add_child(history_row)
	editor_undo_button = _action_button("Undo", _editor_undo, false)
	editor_redo_button = _action_button("Redo", _editor_redo, false)
	history_row.add_child(editor_undo_button)
	history_row.add_child(editor_redo_button)
	tools_column.add_child(_action_button("Save corrections and rebuild", _save_map_editor_changes, true))
	editor_summary_label = _label("", 12, MUTED)
	editor_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(editor_summary_label)

	var map_panel := _panel_container(PANEL, 12)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.clip_contents = true
	split.add_child(map_panel)
	var map_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		map_margin.add_theme_constant_override("margin_%s" % side, 10)
	map_panel.add_child(map_margin)
	var map_group := VBoxContainer.new()
	map_group.add_theme_constant_override("separation", 8)
	map_margin.add_child(map_group)
	var zoom_row := HBoxContainer.new()
	map_group.add_child(zoom_row)
	zoom_row.add_child(_label("Correction preview", 14, TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(spacer)
	zoom_row.add_child(_action_button("−", func(): editor_map_canvas.zoom_out(), false))
	zoom_row.add_child(_action_button("Reset", func(): editor_map_canvas.reset_view(), false))
	zoom_row.add_child(_action_button("+", func(): editor_map_canvas.zoom_in(), false))
	editor_zoom_label = _label("100%", 12, MUTED)
	editor_zoom_label.custom_minimum_size.x = 58
	zoom_row.add_child(editor_zoom_label)
	var map_help := _label("Mouse wheel zooms. Hold the middle mouse button and drag to pan. Hidden buildings are red; blue and green rectangles are creator-authored corrections.", 11, MUTED)
	map_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_group.add_child(map_help)
	var map_clip := PanelContainer.new()
	map_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_clip.clip_contents = true
	map_group.add_child(map_clip)
	editor_map_canvas = TownMapCanvasScript.new()
	editor_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_map_canvas.set_map_data(imported_town)
	editor_map_canvas.set_override_data(editor_overrides)
	editor_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.HIDE_BUILDING)
	editor_map_canvas.building_selected.connect(_on_editor_building_selected)
	editor_map_canvas.override_zone_drawn.connect(_on_editor_zone_drawn)
	editor_map_canvas.coordinates_picked.connect(_on_editor_coordinates_picked)
	editor_map_canvas.view_changed.connect(func(zoom: float): editor_zoom_label.text = "%d%%" % roundi(zoom * 100.0))
	map_clip.add_child(editor_map_canvas)
	_refresh_editor_controls()
	if not load_result.warnings.is_empty():
		_show_message("Map corrections need review", " ".join(PackedStringArray(load_result.warnings)))


func _choose_project_for_map_editor() -> void:
	project_dialog_action = "map_editor"
	_prepare_existing_project_dialog()


func _set_editor_mode(mode: int) -> void:
	if editor_map_canvas == null:
		return
	editor_map_canvas.set_edit_mode(mode)
	match mode:
		TownMapCanvasScript.EditMode.HIDE_BUILDING:
			_set_status("Map editor: click a building footprint to hide or restore it.")
		TownMapCanvasScript.EditMode.DRAW_BLOCKED_WATER:
			_set_status("Map editor: drag a rectangle over missing water.")
		TownMapCanvasScript.EditMode.DRAW_ALLOWED_GROUND:
			_set_status("Map editor: drag within incorrectly mapped water to make it passable.")
		TownMapCanvasScript.EditMode.COPY_COORDINATES:
			_set_status("Map editor: click the outdoor location for a storyline NPC. Its latitude and longitude will be copied.")


func _on_editor_coordinates_picked(location: Dictionary) -> void:
	var coordinate_text := "%.8f, %.8f" % [float(location.latitude), float(location.longitude)]
	DisplayServer.clipboard_set(coordinate_text)
	if editor_coordinate_status_label != null:
		editor_coordinate_status_label.text = "Copied: %s\nPaste this into NPCs and personas → Outdoor storyline NPCs." % coordinate_text
	_set_status("Storyline NPC coordinates copied to the clipboard.")


func _on_editor_building_selected(building: Dictionary) -> void:
	editor_selected_building_id = str(building.get("id", ""))
	var hidden: bool = editor_selected_building_id in editor_overrides.get("hidden_feature_ids", [])
	editor_toggle_building_button.disabled = editor_selected_building_id.is_empty()
	editor_toggle_building_button.text = "Restore selected building" if hidden else "Hide selected building"
	var record := BuildingInformationScript.describe_feature(building)
	editor_selection_label.text = "%s\n%s · %s\nSource: %s" % [str(record.name), "Currently hidden" if hidden else "Currently active", str(record.category), str(record.source_reference)]


func _toggle_editor_building() -> void:
	if editor_selected_building_id.is_empty():
		return
	_editor_record_change()
	var hidden: Array = editor_overrides.get("hidden_feature_ids", []).duplicate()
	if editor_selected_building_id in hidden:
		hidden.erase(editor_selected_building_id)
	else:
		hidden.append(editor_selected_building_id)
	editor_overrides["hidden_feature_ids"] = hidden
	editor_map_canvas.set_override_data(editor_overrides)
	_refresh_editor_controls()
	# Refresh the wording while retaining the selected source feature.
	for feature in imported_town.features:
		if str(feature.get("id", "")) == editor_selected_building_id:
			_on_editor_building_selected(feature)
			break


func _on_editor_zone_drawn(zone: Dictionary) -> void:
	_editor_record_change()
	var zones: Array = editor_overrides.get("zones", []).duplicate(true)
	zone["id"] = _next_editor_zone_id(zones)
	zones.append(zone)
	editor_overrides["zones"] = zones
	editor_map_canvas.set_override_data(editor_overrides)
	_refresh_editor_controls()
	_set_status("Added %s correction. Save and rebuild when ready." % ("blocked-water" if str(zone.mode) == "blocked_water" else "passable-ground"))


func _next_editor_zone_id(zones: Array) -> String:
	var used: Dictionary = {}
	for zone in zones:
		used[str(zone.get("id", ""))] = true
	var number := 1
	while used.has("zone_%04d" % number):
		number += 1
	return "zone_%04d" % number


func _remove_latest_editor_zone() -> void:
	var zones: Array = editor_overrides.get("zones", []).duplicate(true)
	if zones.is_empty():
		return
	_editor_record_change()
	zones.pop_back()
	editor_overrides["zones"] = zones
	editor_map_canvas.set_override_data(editor_overrides)
	_refresh_editor_controls()
	_set_status("Removed the newest water correction. Save and rebuild when ready.")


func _editor_record_change() -> void:
	editor_undo_stack.append(editor_overrides.duplicate(true))
	if editor_undo_stack.size() > 50:
		editor_undo_stack.pop_front()
	editor_redo_stack.clear()


func _editor_undo() -> void:
	if editor_undo_stack.is_empty():
		return
	editor_redo_stack.append(editor_overrides.duplicate(true))
	editor_overrides = editor_undo_stack.pop_back()
	editor_selected_building_id = ""
	editor_map_canvas.selected_building_id = ""
	editor_map_canvas.set_override_data(editor_overrides)
	_refresh_editor_controls()


func _editor_redo() -> void:
	if editor_redo_stack.is_empty():
		return
	editor_undo_stack.append(editor_overrides.duplicate(true))
	editor_overrides = editor_redo_stack.pop_back()
	editor_selected_building_id = ""
	editor_map_canvas.selected_building_id = ""
	editor_map_canvas.set_override_data(editor_overrides)
	_refresh_editor_controls()


func _refresh_editor_controls() -> void:
	if editor_summary_label == null:
		return
	var hidden_count: int = editor_overrides.get("hidden_feature_ids", []).size()
	var blocked_count := 0
	var allowed_count := 0
	for zone in editor_overrides.get("zones", []):
		if str(zone.get("mode", "")) == "blocked_water": blocked_count += 1
		else: allowed_count += 1
	editor_summary_label.text = "%d hidden building(s) · %d blocked-water zone(s) · %d passable-ground zone(s)" % [hidden_count, blocked_count, allowed_count]
	editor_undo_button.disabled = editor_undo_stack.is_empty()
	editor_redo_button.disabled = editor_redo_stack.is_empty()
	editor_remove_zone_button.disabled = editor_overrides.get("zones", []).is_empty()
	if editor_toggle_building_button != null and editor_selected_building_id.is_empty():
		editor_toggle_building_button.disabled = true
	if editor_selection_label != null and editor_selected_building_id.is_empty():
		editor_selection_label.text = "No building selected."


func _save_map_editor_changes() -> void:
	if loaded_project_directory.is_empty():
		return
	var save_result := map_override_store.save_to_town(loaded_project_directory, editor_overrides, imported_town.features, imported_town.bounds)
	if not save_result.ok:
		_show_message("Could not save map corrections", save_result.message)
		return
	editor_overrides = save_result.data
	var settings_result := GameSettingsStoreScript.load_from_town(loaded_project_directory)
	if not settings_result.ok:
		_show_message("Corrections saved, but rebuild stopped", settings_result.message)
		return
	_set_status("Saving map corrections and rebuilding generated town data…")
	var display_name := current_town_name.strip_edges()
	var result := content_pack_writer.update_town(
		loaded_project_directory, display_name, imported_town, selected_cbd,
		selected_start, settings_result.settings
	)
	if not result.ok:
		_show_message("Corrections saved, but rebuild stopped", "%s Your correction file is safe and the original OSM files were not changed." % result.message)
		_set_status("Map corrections saved; rebuild needs attention.")
		return
	editor_undo_stack.clear()
	editor_redo_stack.clear()
	_refresh_editor_controls()
	var override_summary: Dictionary = result.validation.get("map_overrides", {})
	var unresolved := int(override_summary.get("unresolved_overrides", 0))
	_set_status("Map corrections saved and generated town data rebuilt.")
	_show_message(
		"Map corrections saved",
		"Creator Studio rebuilt collisions, pathfinding, destinations and the playable preview. %d correction(s) need review. Original and copied OSM files were not changed." % unresolved
	)


func _show_building_creator_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Building Creator", "Add exterior artwork and a usable entrance to an imported OSM building—without writing Godot code."))
	if loaded_project_directory.is_empty() or not imported_town.get("ok", false):
		content_area.add_child(_notice_panel(
			"Open a saved town first",
			"Choose a Creator Studio project containing town.json. Building designs are stored inside that town and the original OSM files are never changed.",
			WARNING
		))
		content_area.add_child(_action_button("Open town project…", _choose_project_for_building_creator, true))
		return
	var exterior_load := building_exterior_store.load_from_town(loaded_project_directory)
	if not exterior_load.ok:
		content_area.add_child(_notice_panel("Could not read building designs", exterior_load.message, WARNING))
		return
	var override_load := map_override_store.load_from_town(loaded_project_directory, imported_town.features, imported_town.bounds)
	if not override_load.ok:
		content_area.add_child(_notice_panel("Could not read map corrections", override_load.message, WARNING))
		return
	var override_apply := map_override_store.apply(imported_town.features, override_load.data)
	if not override_apply.ok:
		content_area.add_child(_notice_panel("Could not apply map corrections", override_apply.message, WARNING))
		return
	building_exterior_data = exterior_load.data.duplicate(true)
	building_effective_features = override_apply.features
	building_selected_feature = {}

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(split)
	var tools_scroll := ScrollContainer.new()
	tools_scroll.custom_minimum_size.x = 370
	split.add_child(tools_scroll)
	var tools_margin := MarginContainer.new()
	tools_margin.add_theme_constant_override("margin_right", 18)
	tools_scroll.add_child(tools_margin)
	var tools := VBoxContainer.new()
	tools.custom_minimum_size.x = 340
	tools.add_theme_constant_override("separation", 10)
	tools_margin.add_child(tools)
	tools.add_child(_label("Designing: %s" % current_town_name, 17, TEXT))
	var safety_note := _label("Artwork is copied into this town and clipped to the exact OSM footprint. Building collision remains based on the mapped footprint.", 12, MUTED)
	safety_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(safety_note)
	tools.add_child(_settings_group_heading("1. Select a building", "Click an active building footprint on the map. Hidden footprints must first be restored in Advanced map editor."))
	building_selection_label = _label("No building selected.", 12, MUTED)
	building_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(building_selection_label)
	tools.add_child(_settings_group_heading("2. Create or add exterior artwork", "Export the exact footprint as a transparent PNG for Microsoft Paint, or choose an artwork image you already made."))
	building_export_button = _action_button("Export footprint for Paint…", _choose_building_footprint_export_path, true)
	tools.add_child(building_export_button)
	building_import_button = _action_button("Choose exterior image…", _choose_building_exterior_image, true)
	tools.add_child(building_import_button)
	var paint_note := _label("In Paint, keep the exported canvas size unchanged and paint over the grey footprint. Save as PNG, then choose that PNG as the exterior image.", 11, MUTED)
	paint_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(paint_note)
	tools.add_child(_settings_group_heading("3. Align the artwork", "Adjust the image inside the footprint. Increasing scale crops closer; rotation and offsets position the artwork without changing collision."))
	var scale_field := _building_alignment_field("Image scale", 50.0, 300.0, 5.0, "%")
	building_scale_control = scale_field.control
	tools.add_child(scale_field.row)
	var rotation_field := _building_alignment_field("Rotation", -180.0, 180.0, 5.0, "°")
	building_rotation_control = rotation_field.control
	tools.add_child(rotation_field.row)
	var horizontal_field := _building_alignment_field("Move left/right", -100.0, 100.0, 2.0, "%")
	building_offset_x_control = horizontal_field.control
	tools.add_child(horizontal_field.row)
	var vertical_field := _building_alignment_field("Move up/down", -100.0, 100.0, 2.0, "%")
	building_offset_y_control = vertical_field.control
	tools.add_child(vertical_field.row)
	for control in [building_scale_control, building_rotation_control, building_offset_x_control, building_offset_y_control]:
		control.value_changed.connect(_on_building_alignment_changed)
	tools.add_child(_action_button("Reset image alignment", _reset_building_alignment, false))
	tools.add_child(_settings_group_heading("4. Manage entrances", "Add up to eight entrances. Each door snaps to its chosen wall and every green arrow must be on verified clear ground."))
	building_entrance_option = OptionButton.new()
	building_entrance_option.custom_minimum_size.y = 38
	building_entrance_option.item_selected.connect(_on_building_entrance_selected)
	tools.add_child(building_entrance_option)
	building_door_button = _action_button("Add another entrance", _begin_building_door_placement, true)
	tools.add_child(building_door_button)
	building_move_entrance_button = _action_button("Move selected entrance", _begin_move_building_entrance, false)
	tools.add_child(building_move_entrance_button)
	building_remove_entrance_button = _action_button("Remove selected entrance", _remove_selected_building_entrance, false)
	tools.add_child(building_remove_entrance_button)
	var future_note := _label("The entrance is saved now for the upcoming Interior Designer. This stage does not create an interior room yet.", 11, MUTED)
	future_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(future_note)
	tools.add_child(_settings_group_heading("5. Save", "Review the footprint preview, then save the design as a stable-ID town override."))
	building_save_button = _action_button("Save building design", _save_building_designs, true)
	tools.add_child(building_save_button)
	building_remove_button = _action_button("Remove selected custom design", _remove_selected_building_design, false)
	tools.add_child(building_remove_button)
	building_summary_label = _label("", 12, MUTED)
	building_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(building_summary_label)

	var map_panel := _panel_container(PANEL, 12)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.clip_contents = true
	split.add_child(map_panel)
	var map_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		map_margin.add_theme_constant_override("margin_%s" % side, 10)
	map_panel.add_child(map_margin)
	var map_group := VBoxContainer.new()
	map_group.add_theme_constant_override("separation", 8)
	map_margin.add_child(map_group)
	var zoom_row := HBoxContainer.new()
	map_group.add_child(zoom_row)
	zoom_row.add_child(_label("Building preview", 14, TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(spacer)
	zoom_row.add_child(_action_button("−", func(): building_map_canvas.zoom_out(), false))
	zoom_row.add_child(_action_button("Reset", func(): building_map_canvas.reset_view(), false))
	zoom_row.add_child(_action_button("+", func(): building_map_canvas.zoom_in(), false))
	building_zoom_label = _label("100%", 12, MUTED)
	building_zoom_label.custom_minimum_size.x = 58
	zoom_row.add_child(building_zoom_label)
	var help := _label("Click a building to select it. Mouse wheel zooms; hold the middle mouse button and drag to pan.", 11, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_group.add_child(help)
	var clip := PanelContainer.new()
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.clip_contents = true
	map_group.add_child(clip)
	building_map_canvas = TownMapCanvasScript.new()
	building_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	building_map_canvas.set_map_data(imported_town)
	building_map_canvas.set_override_data(override_load.data)
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	building_map_canvas.building_selected.connect(_on_building_creator_selected)
	building_map_canvas.building_door_requested.connect(_on_building_door_requested)
	building_map_canvas.view_changed.connect(func(zoom: float): building_zoom_label.text = "%d%%" % roundi(zoom * 100.0))
	clip.add_child(building_map_canvas)
	_refresh_building_creator_controls()


func _choose_project_for_building_creator() -> void:
	project_dialog_action = "building_creator"
	_prepare_existing_project_dialog()


func _on_building_creator_selected(feature: Dictionary) -> void:
	var feature_id := str(feature.get("id", ""))
	if feature_id in building_map_canvas.override_data.get("hidden_feature_ids", []):
		building_selected_feature = {}
		building_map_canvas.selected_building_id = ""
		building_selection_label.text = "That building is hidden. Restore it in Advanced map editor before designing it."
		_refresh_building_creator_controls()
		return
	building_selected_feature = feature.duplicate(true)
	var record := BuildingInformationScript.describe_feature(feature)
	var design: Dictionary = building_exterior_data.get("buildings", {}).get(feature_id, {})
	var design_parts: Array[String] = []
	if design.has("exterior"):
		design_parts.append("exterior image")
	var entrance_count: int = design.get("doors", []).size()
	if entrance_count > 0:
		design_parts.append("%d entrance%s" % [entrance_count, "" if entrance_count == 1 else "s"])
	var design_text := "No custom design yet" if design_parts.is_empty() else "Has %s" % " and ".join(design_parts)
	building_selection_label.text = "%s\n%s · %s\nSource: %s" % [str(record.name), str(record.category), design_text, str(record.source_reference)]
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	_refresh_building_creator_controls()


func _choose_building_exterior_image() -> void:
	if building_selected_feature.is_empty():
		return
	building_image_dialog.popup_centered_ratio(0.72)


func _choose_building_footprint_export_path() -> void:
	if building_selected_feature.is_empty() or loaded_project_directory.is_empty():
		return
	var default_directory := loaded_project_directory.path_join("exports").path_join("building_footprints")
	DirAccess.make_dir_recursive_absolute(default_directory)
	building_footprint_dialog.current_dir = default_directory
	building_footprint_dialog.current_file = building_footprint_exporter.suggested_file_name(building_selected_feature)
	building_footprint_dialog.popup_centered_ratio(0.72)


func _on_building_footprint_path_selected(path_value: String) -> void:
	if building_selected_feature.is_empty():
		_show_message("Select a building first", "Select an active building footprint before exporting a Paint template.")
		return
	var result := building_footprint_exporter.export_png(building_selected_feature, path_value)
	if not result.ok:
		_show_message("Could not export footprint", result.message)
		return
	_set_status("Footprint template exported: %s" % str(result.path))
	_show_message(
		"Footprint template exported",
		"Saved a %d × %d transparent PNG at:\n%s\n\nOpen it in Microsoft Paint, keep the canvas size unchanged, paint over the grey footprint and save as PNG. Back in Building Creator, choose that PNG with Choose exterior image. Anything outside the footprint is clipped automatically."
		% [int(result.width), int(result.height), str(result.path)]
	)


func _on_building_exterior_image_selected(path_value: String) -> void:
	if building_selected_feature.is_empty() or loaded_project_directory.is_empty():
		_show_message("Select a building first", "Open Building Creator and select an active footprint before choosing artwork.")
		return
	var result := building_exterior_store.import_exterior(
		loaded_project_directory, building_exterior_data,
		str(building_selected_feature.get("id", "")), path_value
	)
	if not result.ok:
		_show_message("Could not import exterior artwork", result.message)
		return
	building_exterior_data = result.data
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_on_building_creator_selected(building_selected_feature)
	_set_status(result.message)


func _begin_building_door_placement() -> void:
	if building_selected_feature.is_empty():
		return
	building_pending_door_index = -1
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.PLACE_BUILDING_DOOR)
	_set_status("Building Creator: click near the preferred wall for the new entrance.")


func _begin_move_building_entrance() -> void:
	if building_selected_feature.is_empty() or building_entrance_option.item_count == 0:
		return
	building_pending_door_index = building_entrance_option.selected
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.PLACE_BUILDING_DOOR)
	_set_status("Building Creator: click near the new wall position for the selected entrance.")


func _on_building_door_requested(location: Dictionary) -> void:
	if building_selected_feature.is_empty():
		return
	var navigation := _read_optional_json(loaded_project_directory.path_join("data").path_join("navigation_graphs.json"))
	var result := building_exterior_store.set_door(
		building_exterior_data, building_selected_feature, location,
		building_effective_features, imported_town.bounds, navigation, building_pending_door_index
	)
	if not result.ok:
		_show_message("Choose another entrance wall", result.message)
		return
	building_exterior_data = result.data
	building_pending_door_index = -1
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	_on_building_creator_selected(building_selected_feature)
	_set_status(result.message)


func _remove_selected_building_entrance() -> void:
	if building_selected_feature.is_empty() or building_entrance_option.item_count == 0:
		return
	var result := building_exterior_store.remove_door(
		building_exterior_data, str(building_selected_feature.get("id", "")), building_entrance_option.selected
	)
	if not result.ok:
		_show_message("Could not remove entrance", result.message)
		return
	building_exterior_data = result.data
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_on_building_creator_selected(building_selected_feature)
	_set_status(result.message)


func _on_building_entrance_selected(_index: int) -> void:
	_set_status("Selected entrance %d for move/remove actions." % (_index + 1))


func _on_building_alignment_changed(_value: float = 0.0) -> void:
	if building_updating_controls or building_selected_feature.is_empty():
		return
	var result := building_exterior_store.set_exterior_transform(
		building_exterior_data, str(building_selected_feature.get("id", "")),
		building_scale_control.value, building_rotation_control.value,
		building_offset_x_control.value, building_offset_y_control.value
	)
	if not result.ok:
		return
	building_exterior_data = result.data
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_refresh_building_creator_controls()
	_set_status("Exterior alignment changed. Save the building design when ready.")


func _reset_building_alignment() -> void:
	if building_selected_feature.is_empty():
		return
	building_updating_controls = true
	building_scale_control.value = 100.0
	building_rotation_control.value = 0.0
	building_offset_x_control.value = 0.0
	building_offset_y_control.value = 0.0
	building_updating_controls = false
	_on_building_alignment_changed()


func _remove_selected_building_design() -> void:
	if building_selected_feature.is_empty():
		return
	building_exterior_data = building_exterior_store.remove_record(building_exterior_data, str(building_selected_feature.get("id", "")))
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_on_building_creator_selected(building_selected_feature)
	_set_status("Removed this building's custom exterior and entrance from the unsaved design.")


func _save_building_designs() -> void:
	if loaded_project_directory.is_empty():
		return
	var result := building_exterior_store.save_to_town(loaded_project_directory, building_exterior_data)
	if not result.ok:
		_show_message("Could not save building design", result.message)
		return
	building_exterior_data = result.data
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_refresh_building_creator_controls()
	_set_status("Building designs saved for %s." % current_town_name)
	_show_message("Building design saved", "The exterior artwork, footprint clipping and entrance were saved inside this town project. The mapped collision shape was not changed.")


func _refresh_building_creator_controls() -> void:
	if building_summary_label == null:
		return
	var selected := not building_selected_feature.is_empty()
	building_export_button.disabled = not selected
	building_import_button.disabled = not selected
	building_save_button.disabled = building_exterior_data.is_empty()
	var selected_id := str(building_selected_feature.get("id", ""))
	var record: Dictionary = building_exterior_data.get("buildings", {}).get(selected_id, {}) if selected else {}
	var has_exterior := record.has("exterior")
	var doors: Array = record.get("doors", [])
	building_door_button.disabled = not selected or doors.size() >= BuildingExteriorStoreScript.MAX_ENTRANCES_PER_BUILDING
	building_move_entrance_button.disabled = doors.is_empty()
	building_remove_entrance_button.disabled = doors.is_empty()
	building_remove_button.disabled = not selected or record.is_empty()
	building_updating_controls = true
	for control in [building_scale_control, building_rotation_control, building_offset_x_control, building_offset_y_control]:
		control.editable = has_exterior
	building_scale_control.value = float(record.get("exterior", {}).get("scale_percent", 100.0))
	building_rotation_control.value = float(record.get("exterior", {}).get("rotation_degrees", 0.0))
	building_offset_x_control.value = float(record.get("exterior", {}).get("offset_x_percent", 0.0))
	building_offset_y_control.value = float(record.get("exterior", {}).get("offset_y_percent", 0.0))
	var previous_selection := building_entrance_option.selected
	building_entrance_option.clear()
	for index in doors.size():
		var door: Dictionary = doors[index]
		var route_note := " · linked to path" if door.has("pedestrian_node_id") else " · path link pending"
		building_entrance_option.add_item("Entrance %d%s" % [index + 1, route_note])
		building_entrance_option.set_item_metadata(index, str(door.get("id", "entrance_%d" % (index + 1))))
	if building_entrance_option.item_count > 0:
		building_entrance_option.select(clampi(previous_selection, 0, building_entrance_option.item_count - 1))
	building_entrance_option.disabled = doors.is_empty()
	building_updating_controls = false
	var design_count: int = building_exterior_data.get("buildings", {}).size()
	building_summary_label.text = "%d building design(s) in this town · %d entrance(s) on the selected building. Original OSM geometry and generated collision footprints remain unchanged." % [design_count, doors.size()]


func _building_alignment_field(label_text: String, minimum: float, maximum: float, step: float, suffix: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 38
	var label := _label(label_text, 12, TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.suffix = suffix
	control.custom_minimum_size.x = 130
	control.allow_greater = false
	control.allow_lesser = false
	row.add_child(control)
	return {"row": row, "control": control}


func _read_optional_json(path_value: String) -> Dictionary:
	if not FileAccess.file_exists(path_value):
		return {}
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _show_interior_designer_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Interior Designer", "Start a building interior and connect its ground-floor entry—without writing Godot code."))
	if loaded_project_directory.is_empty() or not imported_town.get("ok", false):
		content_area.add_child(_notice_panel(
			"Open a saved town first",
			"Open the town that contains the building you want to design. Interior layouts are saved inside that town project.",
			WARNING
		))
		content_area.add_child(_action_button("Open town project…", _choose_project_to_load, true))
		return
	var exterior_load := building_exterior_store.load_from_town(loaded_project_directory)
	var interior_load := building_interior_store.load_from_town(loaded_project_directory)
	if not exterior_load.ok or not interior_load.ok:
		content_area.add_child(_notice_panel(
			"Could not read building design data",
			str(exterior_load.get("message", interior_load.get("message", "The saved building data could not be opened."))),
			WARNING
		))
		return
	interior_exterior_data = exterior_load.data
	interior_data = interior_load.data
	interior_eligible_features.clear()
	for feature_value in imported_town.features:
		if not feature_value is Dictionary or str(feature_value.get("kind", "")) != "building":
			continue
		var feature: Dictionary = feature_value
		var exterior: Dictionary = interior_exterior_data.get("buildings", {}).get(str(feature.get("id", "")), {})
		if not exterior.get("doors", []).is_empty():
			interior_eligible_features.append(feature)
	if interior_eligible_features.is_empty():
		content_area.add_child(_notice_panel(
			"Add an exterior entrance first",
			"Interior Designer needs at least one Building Creator entrance so the outside door can be connected to a safe point inside.",
			WARNING
		))
		content_area.add_child(_action_button("Open Building Creator", _show_building_creator_page, true))
		return

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(split)
	var tools_scroll := ScrollContainer.new()
	tools_scroll.custom_minimum_size.x = 380
	split.add_child(tools_scroll)
	var tools_margin := MarginContainer.new()
	tools_margin.add_theme_constant_override("margin_right", 18)
	tools_scroll.add_child(tools_margin)
	var tools := VBoxContainer.new()
	tools.custom_minimum_size.x = 350
	tools.add_theme_constant_override("separation", 10)
	tools_margin.add_child(tools)
	tools.add_child(_settings_group_heading("1. Choose a building", "Only buildings with at least one saved exterior entrance are listed."))
	interior_building_option = OptionButton.new()
	interior_building_option.custom_minimum_size.y = 40
	for feature in interior_eligible_features:
		var feature_name := str(feature.get("tags", {}).get("name", "Unnamed building"))
		interior_building_option.add_item("%s · OSM %s" % [feature_name, str(feature.get("id", ""))])
		interior_building_option.set_item_metadata(interior_building_option.item_count - 1, str(feature.get("id", "")))
	interior_building_option.item_selected.connect(_on_interior_building_selected)
	tools.add_child(interior_building_option)
	tools.add_child(_settings_group_heading("2. Create the floor", "Start with an empty ground floor shaped from the OSM footprint. This is an editable game layout, not a surveyed floor plan."))
	interior_create_button = _action_button("Create blank ground floor", _create_blank_interior_floor, true)
	tools.add_child(interior_create_button)
	interior_add_floor_button = _action_button("Add upper floor", _add_interior_floor, true)
	tools.add_child(interior_add_floor_button)
	interior_floor_option = OptionButton.new()
	interior_floor_option.custom_minimum_size.y = 40
	interior_floor_option.item_selected.connect(_on_interior_floor_selected)
	tools.add_child(interior_floor_option)
	var size_row := HBoxContainer.new()
	var size_label := _label("Selected floor size", 12, TEXT)
	size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(size_label)
	interior_size_control = SpinBox.new()
	interior_size_control.min_value = 100.0
	interior_size_control.max_value = 300.0
	interior_size_control.step = 5.0
	interior_size_control.suffix = "%"
	interior_size_control.custom_minimum_size.x = 120
	size_row.add_child(interior_size_control)
	tools.add_child(size_row)
	interior_resize_button = _action_button("Apply floor size", _resize_interior_floor, false)
	tools.add_child(interior_resize_button)
	tools.add_child(_settings_group_heading("3. Connect an entrance", "Choose an exterior entrance, then click a clear point inside the ground floor where the player will arrive later."))
	interior_entrance_option = OptionButton.new()
	interior_entrance_option.custom_minimum_size.y = 40
	tools.add_child(interior_entrance_option)
	interior_place_entry_button = _action_button("Place selected entry point", _begin_interior_entry_placement, true)
	tools.add_child(interior_place_entry_button)
	tools.add_child(_settings_group_heading("4. Storyline NPC location", "Select a clear point inside this floor. Creator Studio copies its stable building, floor and metre coordinates for the Storyline NPC creator."))
	interior_storyline_location_button = _action_button("Select and copy interior location", _begin_interior_storyline_location, true)
	tools.add_child(interior_storyline_location_button)
	interior_storyline_location_label = _label("No interior storyline location selected.", 11, MUTED)
	interior_storyline_location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(interior_storyline_location_label)
	tools.add_child(_settings_group_heading("5. Save", "Save the blank floor and its entrance links inside this town."))
	interior_save_button = _action_button("Save interior layout", _save_interior_layouts, true)
	tools.add_child(interior_save_button)
	var limit_note := _label("Floors keep the building footprint shape. A size above 100% is clearly stored as a creator adjustment, not surveyed OSM geometry. Saved ground-floor entrances work in Play test. Wall drawing, stairs, rooms and furniture remain later stages.", 11, MUTED)
	limit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(limit_note)
	interior_summary_label = _label("", 12, MUTED)
	interior_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(interior_summary_label)

	var preview_panel := _panel_container(PANEL, 12)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.clip_contents = true
	split.add_child(preview_panel)
	var preview_group := VBoxContainer.new()
	preview_group.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_group)
	preview_group.add_child(_label("Selected-floor preview · 1 metre grid", 14, TEXT))
	var help := _label("Green markers are interior arrival points linked to the selected exterior entrances.", 11, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_group.add_child(help)
	interior_floor_canvas = InteriorFloorCanvasScript.new()
	interior_floor_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior_floor_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	interior_floor_canvas.entry_spawn_requested.connect(_on_interior_spawn_requested)
	interior_floor_canvas.storyline_location_requested.connect(_on_interior_storyline_location_requested)
	preview_group.add_child(interior_floor_canvas)
	_on_interior_building_selected(0)


func _on_interior_building_selected(index: int) -> void:
	if index < 0 or index >= interior_eligible_features.size():
		interior_selected_feature = {}
		return
	interior_selected_feature = interior_eligible_features[index].duplicate(true)
	_refresh_interior_designer_controls()


func _create_blank_interior_floor() -> void:
	if interior_selected_feature.is_empty():
		return
	var result := building_interior_store.create_blank_ground_floor(interior_data, interior_selected_feature)
	if not result.ok:
		_show_message("Could not create ground floor", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls()
	_set_status(result.message)


func _add_interior_floor() -> void:
	if interior_selected_feature.is_empty():
		return
	var result := building_interior_store.add_upper_floor(interior_data, str(interior_selected_feature.get("id", "")))
	if not result.ok:
		_show_message("Could not add floor", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls(str(result.floor_id))
	_set_status(result.message)


func _on_interior_floor_selected(_index: int) -> void:
	_refresh_interior_designer_controls(_selected_interior_floor_id())


func _resize_interior_floor() -> void:
	if interior_selected_feature.is_empty() or interior_floor_option.item_count == 0:
		return
	var result := building_interior_store.resize_floor(
		interior_data,
		str(interior_selected_feature.get("id", "")),
		_selected_interior_floor_id(),
		interior_size_control.value / 100.0
	)
	if not result.ok:
		_show_message("Could not resize floor", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_set_status(result.message)


func _begin_interior_entry_placement() -> void:
	if interior_selected_feature.is_empty() or interior_entrance_option.item_count == 0:
		return
	# Exterior doors always enter at street level, so make the ground floor
	# visible before asking the creator to place its arrival point.
	if interior_floor_option.item_count > 0:
		interior_floor_option.select(0)
		_refresh_interior_designer_controls("ground_floor")
	interior_floor_canvas.begin_entry_placement()
	_set_status("Interior Designer: click inside the floor to place the selected entrance arrival point.")


func _on_interior_spawn_requested(position_metres: Vector2) -> void:
	if interior_selected_feature.is_empty() or interior_entrance_option.item_count == 0:
		return
	var entrance_id := str(interior_entrance_option.get_item_metadata(interior_entrance_option.selected))
	var result := building_interior_store.set_entry_spawn(
		interior_data, str(interior_selected_feature.get("id", "")), entrance_id, position_metres
	)
	if not result.ok:
		_show_message("Choose a point inside the floor", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls()
	_set_status(result.message)


func _begin_interior_storyline_location() -> void:
	if interior_selected_feature.is_empty() or interior_floor_option.item_count == 0:
		return
	interior_floor_canvas.begin_storyline_location_placement()
	_set_status("Interior Designer: click a clear point inside the selected floor.")


func _on_interior_storyline_location_requested(position_metres: Vector2) -> void:
	var location := {
		"space": "interior",
		"building_id": str(interior_selected_feature.get("id", "")),
		"floor_id": _selected_interior_floor_id(),
		"x_metres": position_metres.x,
		"y_metres": position_metres.y
	}
	var validation := building_interior_store.validate_location(interior_data, location)
	if not validation.ok:
		_show_message("Choose a point inside the floor", validation.message)
		return
	var copied_text := StorylineNpcStoreScript.format_interior_location(str(location.building_id), str(location.floor_id), Vector2(location.x_metres, location.y_metres))
	DisplayServer.clipboard_set(copied_text)
	interior_storyline_location_label.text = "%s\nCopied. Paste this into NPCs and personas → Storyline NPCs." % copied_text
	_set_status("Interior storyline location copied to the clipboard.")


func _save_interior_layouts() -> void:
	if loaded_project_directory.is_empty():
		return
	# Do not save a resized floor that strands an existing storyline character
	# outside its playable boundary. Validate against the edited layout first.
	var persona_load := persona_store.load_from_town(loaded_project_directory)
	var effective_result := _storyline_effective_features()
	var saved_interior_load := building_interior_store.load_from_town(loaded_project_directory)
	if persona_load.ok and effective_result.ok and saved_interior_load.ok:
		var storyline_load := storyline_npc_store.load_from_town(loaded_project_directory, imported_town.get("bounds", {}), effective_result.features, persona_load.data, saved_interior_load.data)
		if storyline_load.ok:
			var storyline_validation := StorylineNpcStoreScript.validate(storyline_load.data, imported_town.get("bounds", {}), effective_result.features, persona_load.data, false, interior_data)
			if not storyline_validation.passed:
				_show_message("Move the storyline NPC first", "%s The interior was not saved." % storyline_validation.errors[0])
				return
	var result := building_interior_store.save_to_town(loaded_project_directory, interior_data)
	if not result.ok:
		_show_message("Could not save interior", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls()
	_show_message("Interior layout saved", "The floor shapes and interior entry links were saved inside this town. In Play test, walk to the green exterior arrow and press E to enter the ground floor; return to the green interior marker and press E to exit.")
	_set_status("Interior layouts saved for %s." % current_town_name)


func _refresh_interior_designer_controls(preferred_floor_id := "") -> void:
	if interior_summary_label == null or interior_selected_feature.is_empty():
		return
	var feature_id := str(interior_selected_feature.get("id", ""))
	var exterior: Dictionary = interior_exterior_data.get("buildings", {}).get(feature_id, {})
	var doors: Array = exterior.get("doors", [])
	var previous_entrance_id := ""
	if interior_entrance_option.item_count > 0 and interior_entrance_option.selected >= 0:
		previous_entrance_id = str(interior_entrance_option.get_item_metadata(interior_entrance_option.selected))
	interior_entrance_option.clear()
	for door_value in doors:
		var door: Dictionary = door_value
		var entrance_id := str(door.get("id", ""))
		interior_entrance_option.add_item("%s · exterior door" % entrance_id.replace("_", " ").capitalize())
		interior_entrance_option.set_item_metadata(interior_entrance_option.item_count - 1, entrance_id)
		if entrance_id == previous_entrance_id:
			interior_entrance_option.select(interior_entrance_option.item_count - 1)
	var interior: Dictionary = interior_data.get("buildings", {}).get(feature_id, {})
	var floors: Array = interior.get("floors", [])
	var has_floor: bool = not floors.is_empty()
	var previous_floor_id := preferred_floor_id
	if previous_floor_id.is_empty():
		previous_floor_id = _selected_interior_floor_id()
	interior_floor_option.clear()
	for floor_index in floors.size():
		var floor_value: Dictionary = floors[floor_index]
		interior_floor_option.add_item(str(floor_value.get("name", "Floor %d" % (floor_index + 1))))
		interior_floor_option.set_item_metadata(floor_index, str(floor_value.get("id", "floor_%d" % floor_index)))
		if str(floor_value.get("id", "")) == previous_floor_id:
			interior_floor_option.select(floor_index)
	var selected_floor_index := interior_floor_option.selected if has_floor else -1
	var floor: Dictionary = floors[selected_floor_index] if selected_floor_index >= 0 else {}
	interior_create_button.disabled = has_floor
	interior_add_floor_button.disabled = not has_floor or floors.size() >= BuildingInteriorStoreScript.MAX_FLOORS
	interior_floor_option.disabled = not has_floor
	interior_size_control.editable = has_floor
	interior_resize_button.disabled = not has_floor
	interior_size_control.set_value_no_signal(float(floor.get("footprint_scale", 1.0)) * 100.0)
	interior_place_entry_button.disabled = not has_floor or doors.is_empty()
	interior_storyline_location_button.disabled = not has_floor
	interior_save_button.disabled = interior_data.get("buildings", {}).is_empty()
	interior_floor_canvas.set_floor(floor)
	if interior_storyline_location_label != null:
		interior_storyline_location_label.text = "No interior storyline location selected on this floor."
	var links: Array = floors[0].get("entry_links", []) if has_floor else []
	interior_summary_label.text = "%s · %s\n%d floor(s) · %d exterior entrance(s) · %d ground-floor entry link(s)%s" % [
		str(interior_selected_feature.get("tags", {}).get("name", "Unnamed building")),
		"ground floor ready" if has_floor else "no interior yet",
		floors.size(), doors.size(), links.size(),
		"\nApproximate footprint-based floor: %.1f m × %.1f m." % [float(floor.get("width_metres", 0.0)), float(floor.get("height_metres", 0.0))] if has_floor else ""
	]


func _selected_interior_floor_id() -> String:
	if interior_floor_option == null or interior_floor_option.item_count == 0 or interior_floor_option.selected < 0:
		return ""
	return str(interior_floor_option.get_item_metadata(interior_floor_option.selected))


func _show_game_settings_page() -> void:
	_clear_content()
	settings_controls.clear()
	content_area.add_child(_page_heading("Game settings", "Choose town populations, camera views and vehicle handling. No code is required."))

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
	form.add_child(_settings_field("skin_tone_distribution", "light_percent", "Light", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	form.add_child(_settings_field("skin_tone_distribution", "medium_percent", "Medium", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	form.add_child(_settings_field("skin_tone_distribution", "dark_percent", "Dark", "Visual skin pigmentation tone.", 0, 100, 0.01, "%"))
	skin_tone_total_label = _label("Total: 100%", 13, ACCENT)
	form.add_child(skin_tone_total_label)

	form.add_child(_settings_group_heading("Camera view", "Set the view separately for walking and driving. 1× is the ordinary scale; larger values bring the camera closer."))
	form.add_child(_settings_field("camera", "character_zoom", "On-foot character zoom", "Higher values enlarge the player and nearby town while walking.", 0.2, 3, 0.05, "×"))
	form.add_child(_settings_field("driving", "camera_zoom_multiplier", "In-car camera zoom", "Independent of on-foot zoom. Higher values bring the road closer while driving.", 0.2, 3, 0.05, "×"))

	form.add_child(_settings_group_heading("Player vehicle", "Set an understandable road speed. The game converts km/h to the correct movement speed for each generated map."))
	form.add_child(_settings_field("driving", "max_speed_kmh", "Maximum driving speed", "In Drive, Up raises the selected cruise speed by 1 km/h and Down lowers it by 1 km/h.", 1, 400, 1, " km/h"))
	form.add_child(_settings_field("driving", "zero_to_hundred_seconds", "0–100 km/h acceleration time", "The default 7.2 seconds is within the requested 2005 Holden VZ range. The game adjusts the movement rate automatically for each town's map scale.", 3, 20, 0.1, " seconds"))
	form.add_child(_settings_field("driving", "reverse_max_speed_kmh", "Maximum reverse speed", "Stop first, then press Shift to select Reverse. Up/Down set reverse cruise speed.", 5, 40, 5, " km/h"))
	form.add_child(_settings_field("driving", "reverse_acceleration", "Reverse acceleration", "How quickly the wagon gains speed in reverse.", 1, 400, 1, ""))
	form.add_child(_settings_field("driving", "coast_deceleration", "Coasting slowdown", "How quickly the wagon slows when no pedal is pressed.", 1, 400, 1, ""))
	form.add_child(_settings_field("driving", "brake_deceleration", "Brake strength", "Higher values stop the wagon more sharply.", 1, 800, 1, ""))
	form.add_child(_settings_field("driving", "steering_rate", "Steering speed", "How quickly the wagon turns.", 0.1, 8, 0.1, ""))

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


func _show_personas_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("NPCs and personas", "Create characters for short, natural conversations using your local Ollama model."))
	content_area.add_child(_notice_panel(
		"Dialogue only",
		"Ollama only writes NPC and NPR replies. It cannot create the town, change the game, run commands or alter saved progress.",
		ACCENT_BLUE
	))
	if loaded_project_directory.is_empty():
		content_area.add_child(_notice_panel("Open a town project", "Create a town or open a previous project before editing its personas.", WARNING))
		var open_button := _action_button("Open previous project", _prepare_existing_project_dialog, true)
		content_area.add_child(open_button)
		return
	var load_result := persona_store.load_from_town(loaded_project_directory)
	if not load_result.ok:
		content_area.add_child(_notice_panel("Persona file needs attention", load_result.message, WARNING))
		return
	persona_data = load_result.data
	var knowledge_result := town_knowledge_store.load_from_town(loaded_project_directory)
	if not knowledge_result.ok:
		content_area.add_child(_notice_panel("Town information needs attention", knowledge_result.message, WARNING))
		return
	town_knowledge_data = knowledge_result.data
	town_custom_text = str(knowledge_result.custom_text)
	var effective_result := _storyline_effective_features()
	if not effective_result.ok:
		content_area.add_child(_notice_panel("Map corrections need attention", effective_result.message, WARNING))
		return
	var interior_load := building_interior_store.load_from_town(loaded_project_directory)
	if not interior_load.ok:
		content_area.add_child(_notice_panel("Interior data needs attention", interior_load.message, WARNING))
		return
	interior_data = interior_load.data
	var storyline_result := storyline_npc_store.load_from_town(
		loaded_project_directory, imported_town.get("bounds", {}), effective_result.features, persona_data, interior_data
	)
	if not storyline_result.ok:
		content_area.add_child(_notice_panel("Storyline NPC file needs attention", storyline_result.message, WARNING))
		return
	storyline_npc_data = storyline_result.data
	persona_page_scroll = ScrollContainer.new()
	persona_page_scroll.name = "PersonaPageScroll"
	persona_page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	persona_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	persona_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(persona_page_scroll)
	var persona_page := VBoxContainer.new()
	persona_page.name = "PersonaPageContents"
	persona_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	persona_page.add_theme_constant_override("separation", 14)
	persona_page_scroll.add_child(persona_page)
	var model_row := HBoxContainer.new()
	model_row.add_theme_constant_override("separation", 10)
	var project_label := _label("Project: %s" % loaded_project_directory.get_file(), 13, MUTED)
	project_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_row.add_child(project_label)
	model_row.add_child(_label("Ollama model", 13, TEXT))
	persona_model_option = OptionButton.new()
	persona_model_option.custom_minimum_size.x = 190
	var saved_model := str(persona_data.get("provider", {}).get("model", PersonaStoreScript.DEFAULT_MODEL))
	persona_model_option.add_item(saved_model)
	model_row.add_child(persona_model_option)
	model_row.add_child(_action_button("Check models", _check_local_models, false))
	persona_page.add_child(model_row)

	var knowledge_panel := _panel_container(Color("#14231e"), 8)
	persona_page.add_child(knowledge_panel)
	var knowledge_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		knowledge_margin.add_theme_constant_override("margin_%s" % side, 10)
	knowledge_panel.add_child(knowledge_margin)
	var knowledge_contents := VBoxContainer.new()
	knowledge_contents.add_theme_constant_override("separation", 6)
	knowledge_margin.add_child(knowledge_contents)
	knowledge_contents.add_child(_label("Optional town knowledge", 14, TEXT))
	var knowledge_help := _label("Leave both sources empty if you prefer. Wikipedia and creator notes only provide background for conversations.", 11, MUTED)
	knowledge_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	knowledge_contents.add_child(knowledge_help)
	var wikipedia_row := HBoxContainer.new()
	wikipedia_row.add_theme_constant_override("separation", 8)
	wikipedia_row.add_child(_label("Wikipedia URL (optional)", 11, MUTED))
	wikipedia_url_edit = LineEdit.new()
	wikipedia_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wikipedia_url_edit.placeholder_text = "https://en.wikipedia.org/wiki/Your_town"
	wikipedia_url_edit.max_length = 500
	wikipedia_url_edit.text = str(town_knowledge_data.get("wikipedia", {}).get("url", ""))
	wikipedia_url_edit.text_submitted.connect(_on_wikipedia_url_submitted)
	wikipedia_row.add_child(wikipedia_url_edit)
	knowledge_contents.add_child(wikipedia_row)
	town_wikipedia_status_label = _label("", 10, MUTED)
	town_wikipedia_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var wikipedia_status_row := HBoxContainer.new()
	wikipedia_status_row.add_theme_constant_override("separation", 8)
	town_wikipedia_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wikipedia_status_row.add_child(town_wikipedia_status_label)
	wikipedia_status_row.add_child(_action_button("Save town information", _save_town_knowledge_and_report, true))
	knowledge_contents.add_child(wikipedia_status_row)
	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 8)
	town_text_status_label = _label("", 11, MUTED)
	town_text_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_row.add_child(town_text_status_label)
	custom_row.add_child(_action_button("Import or replace .txt", _choose_town_text_file, false))
	custom_row.add_child(_action_button("Remove text", _remove_town_text_file, false))
	knowledge_contents.add_child(custom_row)
	town_text_preview_label = _label("", 10, MUTED)
	town_text_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	knowledge_contents.add_child(town_text_preview_label)
	_refresh_town_knowledge_controls()

	var editor_panel := _panel_container(PANEL, 10)
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	persona_page.add_child(editor_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 14)
	editor_panel.add_child(margin)
	var editor := VBoxContainer.new()
	editor.add_theme_constant_override("separation", 8)
	margin.add_child(editor)
	var selector_row := HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 8)
	persona_option = OptionButton.new()
	persona_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	persona_option.item_selected.connect(_on_persona_selected)
	selector_row.add_child(persona_option)
	selector_row.add_child(_action_button("New NPC persona", _new_npc_persona, false))
	selector_row.add_child(_action_button("New robot persona", _new_npr_persona, false))
	persona_delete_button = _action_button("Delete custom", _delete_selected_persona, false)
	selector_row.add_child(persona_delete_button)
	editor.add_child(selector_row)
	persona_actor_label = _label("", 12, ACCENT)
	editor.add_child(persona_actor_label)
	persona_name_edit = LineEdit.new()
	persona_name_edit.max_length = 80
	editor.add_child(_persona_editor_row("Name", persona_name_edit))
	persona_background_edit = TextEdit.new()
	persona_background_edit.custom_minimum_size = Vector2(420, 48)
	persona_background_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.add_child(_persona_editor_row("Background", persona_background_edit))
	persona_personality_edit = LineEdit.new()
	persona_personality_edit.max_length = 240
	editor.add_child(_persona_editor_row("Personality", persona_personality_edit))
	persona_style_edit = LineEdit.new()
	persona_style_edit.max_length = 240
	editor.add_child(_persona_editor_row("Speaking style", persona_style_edit))
	persona_greeting_edit = LineEdit.new()
	persona_greeting_edit.max_length = 180
	editor.add_child(_persona_editor_row("Greeting", persona_greeting_edit))
	var save_row := HBoxContainer.new()
	persona_status_label = _label("Ordinary roaming NPCs receive random compatible personas. Outdoor and interior storyline NPCs are placed in the section below.", 12, MUTED)
	persona_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	persona_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_row.add_child(persona_status_label)
	save_row.add_child(_action_button("Save personas and town info", _save_persona_library, true))
	editor.add_child(save_row)
	_build_storyline_npc_section(persona_page)
	_refresh_persona_options()
	_check_local_models()


func _show_inventory_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Inventory items", "Add and configure the items available in this town without writing code."))
	if loaded_project_directory.is_empty():
		content_area.add_child(_notice_panel("Open a town project", "Create a town or open a previous project before editing its inventory catalogue.", WARNING))
		content_area.add_child(_action_button("Open previous project", _prepare_existing_project_dialog, true))
		return
	var editor = ItemCatalogEditorScript.new()
	content_area.add_child(editor)
	var setup_result: Dictionary = editor.setup(loaded_project_directory)
	if not setup_result.ok:
		editor.queue_free()
		content_area.add_child(_notice_panel("Item catalogue needs attention", setup_result.message, WARNING))
		return
	editor.status_changed.connect(func(message: String) -> void: _set_status(message))
	_set_status("Inventory catalogue loaded for %s." % loaded_project_directory.get_file())


func _build_storyline_npc_section(parent: VBoxContainer) -> void:
	var panel := _panel_container(Color("#14231e"), 10)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	margin.add_child(contents)
	contents.add_child(_label("Storyline NPCs", 15, TEXT))
	var help := _label("For an outdoor character, copy latitude/longitude from Advanced map editor. For an indoor character, use Interior Designer → Select and copy interior location. Paste either location here, then choose a name and human NPC persona or retain the random defaults.", 11, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(help)
	var coordinate_row := HBoxContainer.new()
	coordinate_row.add_theme_constant_override("separation", 8)
	coordinate_row.add_child(_label("Outdoor or interior location", 11, MUTED))
	storyline_coordinate_edit = LineEdit.new()
	storyline_coordinate_edit.name = "StorylineCoordinates"
	storyline_coordinate_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storyline_coordinate_edit.placeholder_text = "Latitude, longitude or copied Interior: location"
	coordinate_row.add_child(storyline_coordinate_edit)
	coordinate_row.add_child(_action_button("Paste copied location", _paste_storyline_coordinates, false))
	contents.add_child(coordinate_row)
	storyline_name_edit = LineEdit.new()
	storyline_name_edit.name = "StorylineName"
	storyline_name_edit.max_length = 80
	storyline_name_edit.placeholder_text = "Leave blank for a random name"
	contents.add_child(_persona_editor_row("Character name", storyline_name_edit))
	storyline_persona_option = OptionButton.new()
	storyline_persona_option.name = "StorylinePersona"
	contents.add_child(_persona_editor_row("Persona", storyline_persona_option))
	_refresh_storyline_persona_choices()
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	storyline_npc_option = OptionButton.new()
	storyline_npc_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(storyline_npc_option)
	action_row.add_child(_action_button("Place storyline NPC", _place_storyline_npc, true))
	storyline_remove_button = _action_button("Remove selected", _remove_storyline_npc, false)
	action_row.add_child(storyline_remove_button)
	contents.add_child(action_row)
	storyline_npc_status_label = _label("", 11, MUTED)
	storyline_npc_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(storyline_npc_status_label)
	_refresh_storyline_npc_controls()


func _paste_storyline_coordinates() -> void:
	if storyline_coordinate_edit != null:
		storyline_coordinate_edit.text = DisplayServer.clipboard_get().strip_edges()


func _place_storyline_npc() -> void:
	var parsed := StorylineNpcStoreScript.parse_location_text(storyline_coordinate_edit.text)
	if not parsed.ok:
		_show_message("Could not place the storyline NPC", parsed.message)
		return
	var effective_result := _storyline_effective_features()
	if not effective_result.ok:
		_show_message("Could not check the location", effective_result.message)
		return
	var location_space := str(parsed.location.get("space", "outdoors"))
	if location_space == "outdoors":
		var location_validation := SpawnSafetyScript.validate_outdoor_actor_location(parsed.location, effective_result.features, imported_town.get("bounds", {}))
		if not location_validation.ok:
			_show_message("Choose another outdoor location", location_validation.message)
			return
		var navigation_path := loaded_project_directory.path_join("data").path_join("navigation_graphs.json")
		if not FileAccess.file_exists(navigation_path):
			_show_message("Rebuild the town first", "Outdoor storyline placement needs this town's generated pedestrian routes. Select Rebuild project, then try again.")
			return
		var navigation_data = JSON.parse_string(FileAccess.get_file_as_string(navigation_path))
		if not navigation_data is Dictionary:
			_show_message("Rebuild the town first", "The generated pedestrian routes could not be read.")
			return
		var reachability := StorylineNpcStoreScript.validate_pedestrian_reachability(parsed.location, navigation_data)
		if not reachability.ok:
			_show_message("Choose a location near a walking route", reachability.message)
			return
	else:
		var interior_validation := building_interior_store.validate_location(interior_data, parsed.location)
		if not interior_validation.ok:
			_show_message("Choose another interior location", interior_validation.message)
			return
	_save_persona_form()
	var persona_save_result := persona_store.save_to_town(loaded_project_directory, persona_data)
	if not persona_save_result.ok:
		_show_message("Could not save the selected persona", persona_save_result.message)
		return
	var requested_persona_id := ""
	if storyline_persona_option != null and storyline_persona_option.item_count > 0:
		requested_persona_id = str(storyline_persona_option.get_item_metadata(storyline_persona_option.selected))
	var requested_name := storyline_name_edit.text if storyline_name_edit != null else ""
	var add_result := storyline_npc_store.add_interior_npc(storyline_npc_data, parsed.location, _current_town_id(), persona_data, requested_name, requested_persona_id) if location_space == "interior" else storyline_npc_store.add_outdoor_npc(storyline_npc_data, parsed.location, _current_town_id(), persona_data, requested_name, requested_persona_id)
	if not add_result.ok:
		_show_message("Could not place the storyline NPC", add_result.message)
		return
	var save_result := storyline_npc_store.save_to_town(loaded_project_directory, add_result.data, imported_town.get("bounds", {}), effective_result.features, persona_data, interior_data)
	if not save_result.ok:
		_show_message("Could not save the storyline NPC", save_result.message)
		return
	storyline_npc_data = save_result.data
	_refresh_storyline_npc_controls(str(add_result.npc.id))
	var chosen_persona := persona_store.find_persona(persona_data, str(add_result.npc.persona_id))
	var persona_name := str(chosen_persona.get("name", add_result.npc.persona_id))
	if location_space == "interior":
		storyline_npc_status_label.text = "%s Their persona is %s.\nSaved in %s / %s at X %.2f m, Y %.2f m." % [add_result.message, persona_name, str(parsed.location.building_id), str(parsed.location.floor_id), float(parsed.location.x_metres), float(parsed.location.y_metres)]
	else:
		storyline_npc_status_label.text = "%s Their persona is %s.\nSaved at latitude %.8f, longitude %.8f." % [add_result.message, persona_name, float(parsed.location.latitude), float(parsed.location.longitude)]
	if storyline_name_edit != null:
		storyline_name_edit.clear()
	if storyline_persona_option != null and storyline_persona_option.item_count > 0:
		storyline_persona_option.select(0)
	_set_status(add_result.message)


func _remove_storyline_npc() -> void:
	if storyline_npc_option == null or storyline_npc_option.item_count == 0:
		return
	var npc_id := str(storyline_npc_option.get_item_metadata(storyline_npc_option.selected))
	var remaining: Array = []
	for value in storyline_npc_data.get("npcs", []):
		if not value is Dictionary or str(value.get("id", "")) != npc_id:
			remaining.append(value)
	var updated := storyline_npc_data.duplicate(true)
	updated["npcs"] = remaining
	var effective_result := _storyline_effective_features()
	if not effective_result.ok:
		_show_message("Could not remove the storyline NPC", effective_result.message)
		return
	var save_result := storyline_npc_store.save_to_town(loaded_project_directory, updated, imported_town.get("bounds", {}), effective_result.features, persona_data, interior_data)
	if not save_result.ok:
		_show_message("Could not remove the storyline NPC", save_result.message)
		return
	storyline_npc_data = save_result.data
	_refresh_storyline_npc_controls()
	storyline_npc_status_label.text = "The selected storyline NPC was removed."


func _refresh_storyline_npc_controls(selected_id := "") -> void:
	if storyline_npc_option == null:
		return
	storyline_npc_option.clear()
	var selected_index := 0
	for value in storyline_npc_data.get("npcs", []):
		if not value is Dictionary:
			continue
		var npc: Dictionary = value
		var location: Dictionary = npc.get("location", {})
		var index := storyline_npc_option.item_count
		if str(location.get("space", "outdoors")) == "interior":
			storyline_npc_option.add_item("%s · %s / %s · X %.1f Y %.1f" % [str(npc.get("display_name", "Storyline NPC")), str(location.get("building_id", "")), str(location.get("floor_id", "")), float(location.get("x_metres", 0.0)), float(location.get("y_metres", 0.0))])
		else:
			storyline_npc_option.add_item("%s · %.6f, %.6f" % [str(npc.get("display_name", "Storyline NPC")), float(location.get("latitude", 0.0)), float(location.get("longitude", 0.0))])
		storyline_npc_option.set_item_metadata(index, str(npc.get("id", "")))
		if str(npc.get("id", "")) == selected_id:
			selected_index = index
	if storyline_npc_option.item_count > 0:
		storyline_npc_option.select(selected_index)
	if storyline_remove_button != null:
		storyline_remove_button.disabled = storyline_npc_option.item_count == 0
	if storyline_npc_status_label != null:
		storyline_npc_status_label.text = "%d storyline NPC(s) saved in this town." % storyline_npc_option.item_count


func _refresh_storyline_persona_choices(selected_id := "") -> void:
	if storyline_persona_option == null:
		return
	if selected_id.is_empty() and storyline_persona_option.item_count > 0:
		selected_id = str(storyline_persona_option.get_item_metadata(storyline_persona_option.selected))
	storyline_persona_option.clear()
	storyline_persona_option.add_item("Random compatible NPC persona")
	storyline_persona_option.set_item_metadata(0, "")
	var selected_index := 0
	for value in persona_data.get("personas", []):
		if not value is Dictionary or str(value.get("actor_kind", "")) != "npc":
			continue
		var persona: Dictionary = value
		var index := storyline_persona_option.item_count
		var source_label := "Built-in" if bool(persona.get("built_in", false)) else "Custom"
		storyline_persona_option.add_item("%s · %s" % [str(persona.get("name", "Unnamed")), source_label])
		storyline_persona_option.set_item_metadata(index, str(persona.get("id", "")))
		if str(persona.get("id", "")) == selected_id:
			selected_index = index
	storyline_persona_option.select(selected_index)


func _storyline_effective_features() -> Dictionary:
	var source_features: Array = imported_town.get("features", [])
	var bounds: Dictionary = imported_town.get("bounds", {})
	var override_result := map_override_store.load_from_town(loaded_project_directory, source_features, bounds)
	if not override_result.ok:
		return override_result
	return map_override_store.apply(source_features, override_result.data)


func _current_town_id() -> String:
	var town_path := loaded_project_directory.path_join("town.json")
	if FileAccess.file_exists(town_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(town_path))
		if parsed is Dictionary and not str(parsed.get("id", "")).is_empty():
			return str(parsed.id)
	return loaded_project_directory.get_file().to_lower().replace(" ", "_")


func _persona_editor_row(title: String, input: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var title_label := _label(title, 12, MUTED)
	title_label.custom_minimum_size.x = 105
	row.add_child(title_label)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	return row


func _refresh_persona_options(selected_id := "") -> void:
	if persona_option == null:
		return
	persona_form_index = -1
	persona_option.clear()
	var selected_index := 0
	for index in persona_data.get("personas", []).size():
		var persona: Dictionary = persona_data.personas[index]
		persona_option.add_item("%s · %s" % [str(persona.get("name", "Unnamed")), "NPR" if str(persona.get("actor_kind", "")) == "npr" else "NPC"])
		persona_option.set_item_metadata(index, str(persona.get("id", "")))
		if str(persona.get("id", "")) == selected_id:
			selected_index = index
	if persona_option.item_count > 0:
		persona_option.select(selected_index)
		_load_persona_form(selected_index)
	_refresh_storyline_persona_choices()


func _on_persona_selected(index: int) -> void:
	_save_persona_form()
	_load_persona_form(index)


func _load_persona_form(index: int) -> void:
	var personas: Array = persona_data.get("personas", [])
	if index < 0 or index >= personas.size():
		return
	var persona: Dictionary = personas[index]
	persona_form_index = index
	persona_actor_label.text = "Used by %s · ID: %s" % ["NPR robots" if str(persona.get("actor_kind", "")) == "npr" else "NPC people", str(persona.get("id", ""))]
	persona_name_edit.text = str(persona.get("name", ""))
	persona_background_edit.text = str(persona.get("background", ""))
	persona_personality_edit.text = str(persona.get("personality", ""))
	persona_style_edit.text = str(persona.get("speaking_style", ""))
	persona_greeting_edit.text = str(persona.get("greeting", ""))
	persona_delete_button.disabled = bool(persona.get("built_in", false))


func _new_npc_persona() -> void:
	_add_custom_persona("npc")


func _new_npr_persona() -> void:
	_add_custom_persona("npr")


func _add_custom_persona(actor_kind: String) -> void:
	_save_persona_form()
	var base_id := "custom_robot" if actor_kind == "npr" else "custom_npc"
	var next_number := 1
	var ids: Dictionary = {}
	for value in persona_data.get("personas", []):
		ids[str(value.get("id", ""))] = true
	while ids.has("%s_%d" % [base_id, next_number]):
		next_number += 1
	var id_value := "%s_%d" % [base_id, next_number]
	var persona := {
		"schema_version": 1, "id": id_value, "name": "New Robot" if actor_kind == "npr" else "New Character",
		"actor_kind": actor_kind, "background": "A character who lives or works in this town.",
		"personality": "Friendly and approachable.", "speaking_style": "Uses one or two short, natural sentences.",
		"knowledge": [], "boundaries": ["Cannot change the game world."],
		"greeting": "Greetings." if actor_kind == "npr" else "Hello.", "built_in": false, "robotic": actor_kind == "npr"
	}
	persona_data.get_or_add("personas", []).append(persona)
	_refresh_persona_options(id_value)
	persona_name_edit.grab_focus()
	persona_status_label.text = "Custom persona added. Edit it, then select Save personas and town info."


func _save_persona_form() -> void:
	if persona_option == null or persona_form_index < 0:
		return
	var personas: Array = persona_data.get("personas", [])
	if persona_form_index >= personas.size():
		return
	var persona: Dictionary = personas[persona_form_index]
	persona["name"] = persona_name_edit.text.strip_edges()
	persona["background"] = persona_background_edit.text.strip_edges()
	persona["personality"] = persona_personality_edit.text.strip_edges()
	persona["speaking_style"] = persona_style_edit.text.strip_edges()
	persona["greeting"] = persona_greeting_edit.text.strip_edges()


func _save_persona_library() -> void:
	_save_persona_form()
	var knowledge_result := _save_town_knowledge_form()
	if not knowledge_result.ok:
		persona_status_label.text = knowledge_result.message
		persona_status_label.add_theme_color_override("font_color", WARNING)
		_set_status("Could not save optional town knowledge: %s" % knowledge_result.message)
		return
	if persona_model_option != null and persona_model_option.selected >= 0:
		persona_data.provider["model"] = persona_model_option.get_item_text(persona_model_option.selected)
	var result := persona_store.save_to_town(loaded_project_directory, persona_data)
	if not result.ok:
		persona_status_label.text = result.message
		persona_status_label.add_theme_color_override("font_color", WARNING)
		_set_status("Could not save personas: %s" % result.message)
		return
	persona_status_label.text = "Personas and optional town knowledge saved. Reopen Play test to use the changes."
	persona_status_label.add_theme_color_override("font_color", ACCENT)
	_refresh_storyline_persona_choices()
	_set_status("Personas saved for %s." % loaded_project_directory.get_file())


func _delete_selected_persona() -> void:
	if persona_option == null or persona_option.selected < 0:
		return
	var personas: Array = persona_data.get("personas", [])
	if persona_option.selected >= personas.size() or bool(personas[persona_option.selected].get("built_in", false)):
		return
	var selected_id := str(personas[persona_option.selected].get("id", ""))
	for value in storyline_npc_data.get("npcs", []):
		if value is Dictionary and str(value.get("persona_id", "")) == selected_id:
			_show_message("Persona is in use", "A saved storyline NPC uses this persona. Remove that storyline NPC first, or keep the persona.")
			return
	personas.remove_at(persona_option.selected)
	_refresh_persona_options()
	persona_status_label.text = "Custom persona removed from the editor. Select Save personas and town info to confirm."


func _save_town_knowledge_form() -> Dictionary:
	if wikipedia_url_edit != null:
		var old_url := str(town_knowledge_data.get("wikipedia", {}).get("url", ""))
		var new_url := wikipedia_url_edit.text.strip_edges()
		if old_url != new_url:
			town_knowledge_data.wikipedia = TownKnowledgeStoreScript.empty_data().wikipedia
			town_knowledge_data.wikipedia["url"] = new_url
	var result := town_knowledge_store.save_to_town(loaded_project_directory, town_knowledge_data)
	if result.ok:
		town_knowledge_data = result.data
		_refresh_town_knowledge_controls()
	return result


func _save_town_knowledge_and_report() -> void:
	var result := _save_town_knowledge_form()
	if not result.ok:
		town_wikipedia_status_label.text = result.message
		town_wikipedia_status_label.add_theme_color_override("font_color", WARNING)
		_set_status("Could not save optional town information: %s" % result.message)
		return
	town_wikipedia_status_label.add_theme_color_override("font_color", ACCENT)
	_set_status("Town information saved. Reopen Play test to refresh the Wikipedia summary for NPC conversations.")


func _on_wikipedia_url_submitted(_value: String) -> void:
	_save_town_knowledge_and_report()


func _choose_town_text_file() -> void:
	if town_text_dialog != null:
		town_text_dialog.popup_centered_ratio(0.70)


func _on_town_text_file_selected(path_value: String) -> void:
	var result := town_knowledge_store.import_custom_text(loaded_project_directory, path_value, town_knowledge_data)
	if not result.ok:
		persona_status_label.text = result.message
		persona_status_label.add_theme_color_override("font_color", WARNING)
		return
	town_knowledge_data = result.data
	town_custom_text = str(result.custom_text)
	_refresh_town_knowledge_controls()
	persona_status_label.text = "Extra town information imported."
	persona_status_label.add_theme_color_override("font_color", ACCENT)


func _remove_town_text_file() -> void:
	var result := town_knowledge_store.remove_custom_text(loaded_project_directory, town_knowledge_data)
	if not result.ok:
		persona_status_label.text = result.message
		persona_status_label.add_theme_color_override("font_color", WARNING)
		return
	town_knowledge_data = result.data
	town_custom_text = ""
	_refresh_town_knowledge_controls()
	persona_status_label.text = "Optional town-information text removed."


func _refresh_town_knowledge_controls() -> void:
	if town_wikipedia_status_label == null or town_text_status_label == null or town_text_preview_label == null:
		return
	var wikipedia: Dictionary = town_knowledge_data.get("wikipedia", {})
	var wikipedia_url := str(wikipedia.get("url", ""))
	var wikipedia_title := str(wikipedia.get("title", ""))
	if wikipedia_url.is_empty():
		town_wikipedia_status_label.text = "No Wikipedia article selected. NPC conversations still work normally."
	elif wikipedia_title.is_empty():
		town_wikipedia_status_label.text = "The article will be checked and cached when the map next starts."
	else:
		town_wikipedia_status_label.text = "Cached: %s · Source: Wikipedia contributors" % wikipedia_title
	var original_name := str(town_knowledge_data.get("custom_text", {}).get("original_filename", ""))
	if original_name.is_empty() or town_custom_text.is_empty():
		town_text_status_label.text = "Extra town-information file (optional): none"
		town_text_preview_label.text = ""
	else:
		town_text_status_label.text = "Extra town information: %s" % original_name
		town_text_preview_label.text = "Preview: %s" % TownKnowledgeStoreScript._bounded_excerpt(town_custom_text).left(220)


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
	# Every generated town receives a canonical catalogue immediately. Older towns
	# keep their existing definitions; a damaged catalogue is never overwritten.
	var item_catalog_store = ItemCatalogStoreScript.new()
	var catalogue_load: Dictionary = item_catalog_store.load_from_town(str(result.town_directory))
	if not catalogue_load.ok:
		_set_status("The town was saved, but its item catalogue needs attention: %s" % catalogue_load.message)
		_show_message("Item catalogue needs attention", "%s The saved town and its existing catalogue were not overwritten." % catalogue_load.message)
		return false
	var catalogue_save: Dictionary = item_catalog_store.save_to_town(str(result.town_directory), catalogue_load.data)
	if not catalogue_save.ok:
		_set_status("The town was saved, but Creator Studio could not save its item catalogue: %s" % catalogue_save.message)
		_show_message("Could not save the item catalogue", "%s The generated town is still safe." % catalogue_save.message)
		return false
	last_created_directory = result.town_directory
	loaded_project_directory = result.town_directory
	current_town_name = town_name_edit.text.strip_edges()
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
	var crossing_count := int(navigation_summary.get("mapped_pedestrian_crossing_edges", 0))
	var crossing_message := " %d mapped pedestrian crossing route(s) now make NPCs and robots wait for a traffic gap; NPC cars yield after they commit." % crossing_count if crossing_count > 0 else " No mapped pedestrian crossing routes were found; Creator Studio has not invented crossings."
	var rebuild_note := " Rebuild source: %s." % source_note if rebuilding and not source_note.is_empty() else ""
	selection_instructions.text = "%s successfully. Building information, collisions, pathfinding and traffic rules were generated automatically from the OSM map.%s%s%s%s%s Hover or click a building during Play test to read its mapped details. Your source files remain unchanged." % ["Town project rebuilt" if rebuilding else "Town project created", control_message, geometry_message, transport_message, crossing_message, rebuild_note]
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
	# Reapply saved creator corrections before checking starts and water safety.
	# The original OSM import remains untouched and is still what we persist.
	var override_load := map_override_store.load_from_town(loaded_project_directory, refreshed.features, refreshed.bounds)
	if not override_load.ok:
		_show_message("Could not rebuild the project", "%s The existing generated project has not been changed." % override_load.message)
		_set_status("Rebuild stopped because the saved map corrections need attention.")
		return
	var override_apply := map_override_store.apply(refreshed.features, override_load.data)
	if not override_apply.ok:
		_show_message("Could not rebuild the project", "%s The existing generated project has not been changed." % override_apply.message)
		_set_status("Rebuild stopped because the saved map corrections need attention.")
		return
	var effective_refresh: Dictionary = refreshed.duplicate(true)
	effective_refresh["features"] = override_apply.features
	var validation: Dictionary = content_pack_writer.validate_town(town_name_edit.text, effective_refresh, selected_cbd, selected_start)
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
		_load_existing_project(path_value, project_dialog_action)


func _load_existing_project(path_value: String, destination_page: Variant = "load") -> void:
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
	# Boolean support preserves compatibility with the earlier map-editor helper
	# and focused UI checks while named destinations keep later tools readable.
	var destination := "map_editor" if destination_page is bool and destination_page else str(destination_page)
	if destination == "map_editor":
		_show_advanced_map_editor_page()
	elif destination == "building_creator":
		_show_building_creator_page()
	else:
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
	_set_status("Checking local model services for NPC dialogue…")
	llm_probe.check_all()


func _on_provider_checked(provider_id: String, available: bool, detail: String) -> void:
	if not provider_status_labels.has(provider_id):
		return
	var label: Label = provider_status_labels[provider_id]
	label.text = detail
	label.add_theme_color_override("font_color", ACCENT if available else MUTED)


func _on_provider_models(provider_id: String, models: PackedStringArray) -> void:
	if provider_id != "ollama" or persona_model_option == null or not is_instance_valid(persona_model_option):
		return
	var selected_model := str(persona_data.get("provider", {}).get("model", PersonaStoreScript.DEFAULT_MODEL))
	persona_model_option.clear()
	for model in models:
		persona_model_option.add_item(model)
		if model == selected_model:
			persona_model_option.select(persona_model_option.item_count - 1)
	if persona_model_option.item_count == 0:
		persona_model_option.add_item(selected_model)
	if persona_status_label != null and is_instance_valid(persona_status_label):
		persona_status_label.text = "%d installed Ollama model(s) found. Select one, then save personas." % models.size()


func _on_provider_checks_finished() -> void:
	_set_status("Local model check finished. Ollama is used only for NPC and NPR dialogue.")


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
