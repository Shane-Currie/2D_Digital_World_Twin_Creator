extends Control

const OsmImporterScript = preload("res://scripts/towns/osm_importer.gd")
const TownMapCanvasScript = preload("res://scripts/towns/map_canvas.gd")
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const ContentPackWriterScript = preload("res://scripts/content/content_pack.gd")
const LocalLlmProbeScript = preload("res://scripts/npcs/local_llm_probe.gd")
const PersonaStoreScript = preload("res://scripts/npcs/persona_store.gd")
const TownKnowledgeStoreScript = preload("res://scripts/npcs/town_knowledge_store.gd")
const StorylineNpcStoreScript = preload("res://scripts/npcs/storyline_npc_store.gd")
const NpcCreations = preload("res://scripts/npcs/creation/npc_creation_store.gd")
const NpcCreationEditor = preload("res://scripts/npcs/creation/npc_creation_editor.gd")
const NpcAppearancePicker = preload("res://scripts/npcs/creation/npc_appearance_picker.gd")
const SeatOrientation = preload("res://scripts/npcs/creation/seat_orientation.gd")
var npc_creation_editor
var npc_appearance_picker
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")
const GameLoreEditorScript = preload("res://scripts/npcs/lore/game_lore_editor.gd")
const TreeSettingsEditorScript = preload("res://scripts/environment/tree_settings_editor.gd")
const ProjectLoaderScript = preload("res://scripts/content/project_loader.gd")
const BuildingInformationScript = preload("res://scripts/places/osm_building_information.gd")
const MapOverrideStoreScript = preload("res://scripts/editor/map_override_store.gd")
const BuildingExteriorStoreScript = preload("res://scripts/buildings/building_exterior_store.gd")
const BuildingFootprintExporterScript = preload("res://scripts/buildings/building_footprint_exporter.gd")
const BuildingInteriorStoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const InteriorFloorCanvasScript = preload("res://scripts/interiors/interior_floor_canvas.gd")
const InteriorFurnitureCatalogScript = preload("res://scripts/interiors/interior_furniture_catalog.gd")
const InteriorFurnitureLibraryScript = preload("res://scripts/interiors/interior_furniture_library.gd")
const InteriorFloorMaterialCatalogScript = preload("res://scripts/interiors/interior_floor_material_catalog.gd")
const InteriorFloorMaterialLibraryScript = preload("res://scripts/interiors/interior_floor_material_library.gd")
const ItemCatalogEditorScript = preload("res://scripts/inventory/item_catalog_editor.gd")
const ItemCatalogStoreScript = preload("res://scripts/inventory/item_catalog_store.gd")
const TraderStoreScript = preload("res://scripts/npcs/traders/trader_store.gd")
const ToolTileMenuScript = preload("res://scripts/app/navigation/tool_tile_menu.gd")
const SectionSaveTransaction = preload("res://scripts/app/navigation/section_save_transaction.gd")
const EditorItemDeletion = preload("res://scripts/app/navigation/editor_item_deletion.gd")
const BuildingHeightProfile = preload("res://scripts/buildings/building_height_profile.gd")
const BuildingArtworkSettings = preload("res://scripts/buildings/building_artwork_settings.gd")
const BuildingArtworkPreview = preload("res://scripts/buildings/building_artwork_preview.gd")
const LocationNotesScript = preload("res://scripts/npcs/locations/location_notes_store.gd")
var location_notes_data: Dictionary = {"schema_version": 1, "locations": {}}
var location_note_texts: Dictionary = {}
var location_notes_ready := false
var location_text_dialog: FileDialog
var interior_location_notes_label: Label
var interior_location_notes_preview: TextEdit

const BACKGROUND := Color("#0f1715")
const PANEL := Color("#18241f")
const PANEL_LIGHT := Color("#21332b")
const ACCENT := Color("#4bc7a1")
const ACCENT_BLUE := Color("#72a7ff")
const TEXT := Color("#edf6f1")
const MUTED := Color("#a8bbb2")
const WARNING := Color("#efc56c")
const ERROR_COLOUR := Color("#ef7777")

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
var trader_editor
var interior_tools_navigation
const InteriorStairsScript = preload("res://scripts/interiors/stairs/interior_stairs.gd")
const BuildingConnections = preload("res://scripts/interiors/connections/building_connections.gd")
const FootprintEditor = preload("res://scripts/editor/building_footprint_editor.gd")
const SectionHistory = preload("res://scripts/app/navigation/section_edit_history.gd")
var section_history = SectionHistory.new()
var section_history_kind := ""
var section_history_busy := false
var section_history_queued := false
var section_saved_snapshot: Dictionary = {}
var section_save_callback: Callable
var section_save_succeeded := false
var top_delete_button: Button
var editor_delete_selection: Dictionary = {}
var section_state_label: Label
var section_leave_dialog: ConfirmationDialog
var section_pending_navigation: Callable
var top_undo_button: Button
var top_cancel_button: Button
var custom_footprint_name: LineEdit
var interior_connection_target: OptionButton
var interior_connection_list: OptionButton
var interior_connection_hint: Label
var interior_connection_add: Button
var interior_connection_create: Button
var interior_connection_remove: Button
var interior_connection_lock: Button
var interior_connection_neighbours: Array = []
var interior_connection_features: Array = []
var interior_connection_cache: Dictionary = {}
var interior_stair_target: OptionButton
var interior_stair_list: OptionButton
var interior_stair_hint: Label
var interior_stair_add: Button
var interior_stair_remove: Button
var interior_stair_rotation: SpinBox
var interior_stair_auto: CheckBox
var interior_tools_panel: Control
var interior_building_map: Control
var interior_map_button: Button
var interior_stair_pending: Dictionary = {}
# Only floor-count changes are merged into the latest saved exterior design.
var interior_stair_floor_counts: Dictionary = {}
var npc_tools_navigation
var settings_tools_navigation
var game_lore_editor
var tree_settings_editor
var npc_persona_panel: Control
var npc_placement_panel: Control
var npc_placement_heading: Label
var npc_place_button: Button
var persona_new_npc_button: Button
var persona_new_npr_button: Button
var placed_npc_role := "storyline"
var persona_actor_filter := "npc"
var persona_visible_indices: Array[int] = []
var npc_role_drafts: Dictionary = {}
var interior_trader_data: Dictionary = {"schema_version": 1, "traders": {}}
var interior_npc_place_active := false
var interior_npc_name_edit: LineEdit
var interior_npc_persona_option: OptionButton
var interior_npc_role_option: OptionButton
var interior_storyline_ready := false
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
var interior_furniture_image_dialog: FileDialog
var interior_floor_material_image_dialog: FileDialog
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
var vehicle_start_button: Button
var vehicle_rotation_control: SpinBox
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
var import_tools_navigation
var pending_osm_files := PackedStringArray()
var sidebar_navigation_buttons: Dictionary = {}
var inventory_editor: Control
var save_floppy_icon: Texture2D
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
var editor_tools_navigation: Control
var editor_floor_control: SpinBox
var editor_height_status: Label
var editor_height_restore := false
var building_floor_control: SpinBox
var building_floor_status: Label
var building_style_option: OptionButton
var importing_wall := false
var building_wall_import_target := "walls"
var building_artwork_target := "roof"
var building_artwork_preview
var building_artwork_buttons: Dictionary = {}
var building_artwork_material: OptionButton
var building_artwork_upload: Button
var building_artwork_status: Label
var building_artwork_help: Label
var building_tools_scroll: ScrollContainer
var building_tools_navigation
var building_map_workspace: Control
var building_artwork_workspace: Control
var building_entry_workspace: Control
var building_entry_canvas
var building_link_status: Label
var building_create_interior_button: Button
var building_link_button: Button
var building_link_data: Dictionary = {}
var building_link_dirty := false
var building_link_ready := false
var building_door_view_target := "front"
var building_alignment_heading: Control
var building_exterior_store = BuildingExteriorStoreScript.new()
var building_footprint_exporter = BuildingFootprintExporterScript.new()
var building_map_canvas: Control
var building_exterior_data: Dictionary = {}
var building_effective_features: Array = []
var building_selected_feature: Dictionary = {}
var building_selection_label: Label
var custom_building_option: OptionButton
var building_custom_name_edit: LineEdit
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
var interior_furniture_library = InteriorFurnitureLibraryScript.new()
var interior_floor_material_library = InteriorFloorMaterialLibraryScript.new()
var interior_data: Dictionary = {}
var interior_custom_catalog_data: Dictionary = {}
var interior_floor_material_data: Dictionary = {}
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
var interior_draw_wall_button: Button
var interior_wall_option: OptionButton
var interior_remove_wall_button: Button
var interior_door_width_control: SpinBox
var interior_add_door_button: Button
var interior_door_option: OptionButton
var interior_lock_door_button: Button
var interior_remove_door_button: Button
var interior_room_name_edit: LineEdit
var interior_add_room_button: Button
var interior_room_option: OptionButton
var interior_remove_room_button: Button
var interior_floor_material_option: OptionButton
var interior_paint_floor_button: Button
var interior_floor_material_name_edit: LineEdit
var interior_import_floor_material_button: Button
var interior_furniture_category_option: OptionButton
var interior_furniture_search_edit: LineEdit
var interior_furniture_results_label: Label
var interior_furniture_catalog_option: OptionButton
var interior_furniture_rotation_control: SpinBox
var interior_place_furniture_button: Button
var interior_placed_furniture_option: OptionButton
var interior_remove_furniture_button: Button
var interior_custom_name_edit: LineEdit
var interior_custom_type_edit: LineEdit
var interior_custom_category_option: OptionButton
var interior_custom_category_edit: LineEdit
var interior_custom_width_control: SpinBox
var interior_custom_depth_control: SpinBox
var interior_import_furniture_button: Button
var interior_zoom_label: Label
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
	title_group.add_child(_label("v1.7 · Completed release", 13, MUTED))
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
	var import_navigation := _navigation_button("Import a town", _show_town_import_page, true)
	sidebar_navigation_buttons["import"] = import_navigation
	sidebar.add_child(import_navigation)
	play_test_button = _navigation_button("Play test project", _show_play_test_page)
	sidebar_navigation_buttons["play"] = play_test_button
	sidebar.add_child(play_test_button)
	var settings_navigation := _navigation_button("Game settings", _show_game_settings_page)
	sidebar_navigation_buttons["settings"] = settings_navigation
	sidebar.add_child(settings_navigation)
	sidebar.add_child(_navigation_button("Advanced map editor", _show_advanced_map_editor_page))
	sidebar.add_child(_navigation_button("Building Creator", _show_building_creator_page))
	sidebar.add_child(_navigation_button("Interior designer", _show_interior_designer_page))
	sidebar.add_child(_navigation_button("NPCs and personas", _show_personas_page))
	sidebar.add_child(_navigation_button("Inventory items", _show_inventory_page))
	var system_navigation := _navigation_button("System setup", _show_system_page)
	sidebar_navigation_buttons["system"] = system_navigation
	sidebar.add_child(system_navigation)
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
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_margin.add_child(status_label)
	_refresh_sidebar_readiness()


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

	interior_furniture_image_dialog = FileDialog.new()
	interior_furniture_image_dialog.title = "Choose your furniture artwork"
	interior_furniture_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	interior_furniture_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	interior_furniture_image_dialog.filters = PackedStringArray([
		"*.png ; PNG images", "*.jpg,*.jpeg ; JPEG images", "*.webp ; WebP images"
	])
	interior_furniture_image_dialog.file_selected.connect(_on_interior_furniture_image_selected)
	add_child(interior_furniture_image_dialog)

	interior_floor_material_image_dialog = FileDialog.new()
	interior_floor_material_image_dialog.title = "Choose your floor texture"
	interior_floor_material_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	interior_floor_material_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	interior_floor_material_image_dialog.filters = PackedStringArray([
		"*.png ; PNG images", "*.jpg,*.jpeg ; JPEG images", "*.webp ; WebP images"
	])
	interior_floor_material_image_dialog.file_selected.connect(_on_interior_floor_material_image_selected)
	add_child(interior_floor_material_image_dialog)

	town_text_dialog = FileDialog.new()
	town_text_dialog.title = "Choose optional town-information text"
	town_text_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	town_text_dialog.access = FileDialog.ACCESS_FILESYSTEM
	town_text_dialog.filters = PackedStringArray(["*.txt ; UTF-8 plain-text files"])
	town_text_dialog.file_selected.connect(_on_town_text_file_selected)
	add_child(town_text_dialog)
	location_text_dialog = FileDialog.new()
	location_text_dialog.title = "Choose location reference text"
	location_text_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	location_text_dialog.access = FileDialog.ACCESS_FILESYSTEM
	location_text_dialog.filters = PackedStringArray(["*.txt ; UTF-8 plain-text files"])
	location_text_dialog.file_selected.connect(_on_location_text_selected)
	add_child(location_text_dialog)

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
	var note := _notice_panel(
		"v1.7 complete",
		"New-town import and Play test fixes are included. Previous releases remain preserved; next development is v1.8.",
		ACCENT
	)
	content_area.add_child(note)
	content_area.add_child(_action_button("Play test project", _show_play_test_page, true))


func _show_play_test_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Play test project", "Launch your current town or choose a saved project."))
	var project_name := current_town_name if not current_town_name.is_empty() else "No current town"
	content_area.add_child(_label(project_name, 18, TEXT))
	content_area.add_child(_action_button("Play current project", _play_current_project, true))
	content_area.add_child(_action_button("Choose saved project…", _choose_project_to_play, false))
	content_area.add_child(_action_button("Back to town setup", _show_town_import_page, false))


func _show_town_import_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Import a town", "Choose one setup tool at a time. Your map stays visible."))
	create_town_button = _add_top_save_bar("Save town project", _create_town_project)
	create_town_button.text = "Create town project" if loaded_project_directory.is_empty() else "Save project changes"

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(split)

	import_tools_navigation = ToolTileMenuScript.new()
	import_tools_navigation.custom_minimum_size.x = 350
	split.add_child(import_tools_navigation)
	import_tools_navigation.setup("Town setup")
	var form: VBoxContainer = import_tools_navigation.add_page("name", "Town name", "Name the project")
	town_name_edit = LineEdit.new()
	town_name_edit.placeholder_text = "Example: Benalla"
	town_name_edit.text = current_town_name
	town_name_edit.text_changed.connect(_on_town_name_changed)
	form.add_child(town_name_edit)

	form = import_tools_navigation.add_page("files", "Map files", "Choose and read OSM")
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

	form = import_tools_navigation.add_page("cbd", "CBD area", "Draw on the map")
	var cbd_help := _label("Select Draw CBD, then drag a box around the central business district on the map.", 12, MUTED)
	cbd_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(cbd_help)
	cbd_button = _action_button("Draw CBD on map", func(): _set_map_mode(TownMapCanvasScript.EditMode.DRAW_CBD), false)
	cbd_button.disabled = true
	form.add_child(cbd_button)

	form = import_tools_navigation.add_page("player", "Player start", "Choose safe ground")
	selection_instructions = _label("Read the OSM files and draw the CBD first.", 12, MUTED)
	selection_instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(selection_instructions)
	start_button = _action_button("Choose start on map", _activate_start_tool, true)
	start_button.disabled = true
	form.add_child(start_button)
	var start_help := _label("After selecting the button, click an open position on the map. Creator Studio places the vehicle separately on a nearby clear road.", 11, MUTED)
	start_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(start_help)
	form = import_tools_navigation.add_page("car", "Car start", "Place and rotate")
	vehicle_start_button = _action_button("Place player's car on map", func(): _set_map_mode(TownMapCanvasScript.EditMode.SET_VEHICLE_START), true)
	vehicle_start_button.disabled = selected_start.is_empty()
	form.add_child(vehicle_start_button)
	var car_rotation_row := HBoxContainer.new()
	car_rotation_row.add_child(_label("Car starting direction", 12, TEXT))
	vehicle_rotation_control = SpinBox.new()
	vehicle_rotation_control.min_value = 0
	vehicle_rotation_control.max_value = 360
	vehicle_rotation_control.step = 1
	vehicle_rotation_control.suffix = "°"
	vehicle_rotation_control.value = float(selected_start.get("vehicle", {}).get("rotation_degrees", 0.0))
	vehicle_rotation_control.value_changed.connect(func(degrees: float): map_canvas.set_vehicle_rotation(degrees))
	car_rotation_row.add_child(vehicle_rotation_control)
	form.add_child(car_rotation_row)
	var car_rotation_help := _label("The white arrow shows the car's front. 0° north, 90° east. Use the direction box, or right-click to turn 15° / hold right mouse and drag while Place car is active. Keep the car 8–250 metres from the player.", 11, MUTED)
	car_rotation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(car_rotation_help)

	form = import_tools_navigation.add_page("inspect", "Inspect building", "Read OSM details")
	var inspect_row := HBoxContainer.new()
	form.add_child(inspect_row)
	var inspect_button := _action_button("Inspect", func(): _set_map_mode(TownMapCanvasScript.EditMode.INSPECT), false)
	inspect_row.add_child(inspect_button)
	inspect_row.add_child(_label("Optional: inspect an imported building footprint.", 11, MUTED))
	building_information = _label("", 12, MUTED)
	building_information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(building_information)

	form = import_tools_navigation.add_page("rules", "Driving side", "Left or right")
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

	form = import_tools_navigation.add_page("folder", "Save folder", "Choose game directory")
	workspace_edit = LineEdit.new()
	workspace_edit.text = current_workspace if not current_workspace.is_empty() else _load_workspace_preference()
	current_workspace = workspace_edit.text.strip_edges()
	workspace_edit.placeholder_text = "Choose a folder for your game files"
	workspace_edit.text_changed.connect(_on_workspace_text_changed)
	form.add_child(workspace_edit)
	form.add_child(_action_button("Choose save directory…", _choose_workspace, false))
	var save_note := _label("Creator Studio will make a new town folder inside this directory. Your original OSM files will be copied, not moved.", 11, MUTED)
	save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(save_note)
	form = import_tools_navigation.add_page("rebuild", "Rebuild project", "Refresh saved OSM")

	creation_readiness_label = _label("", 11, MUTED)
	creation_readiness_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Requirements stay visible when a tool page is closed.
	content_area.add_child(creation_readiness_label)
	rebuild_project_button = _action_button("Rebuild project", _rebuild_loaded_project, false)
	rebuild_project_button.disabled = loaded_project_directory.is_empty()
	form.add_child(rebuild_project_button)
	open_folder_button = _action_button("Open created folder", _open_created_folder, false)
	open_folder_button.disabled = last_created_directory.is_empty()
	form.add_child(open_folder_button)
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
	map_canvas.vehicle_start_rejected.connect(func(message: String): _show_message("Choose a clear car starting point", message))
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
	var zoom_help := _label("Wheel zooms. Hold left mouse and drag to move the map; click to select. CBD drawing uses left-drag while that tool is active. Middle-drag also pans.", 11, MUTED)
	zoom_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_group.add_child(zoom_help)
	var map_clip := PanelContainer.new()
	map_clip.name = "MapCanvasClip"
	map_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_clip.clip_contents = true
	map_group.add_child(map_clip)
	map_clip.add_child(map_canvas)
	import_tools_navigation.page_changed.connect(_on_import_tool_changed)

	# Restore an import preview if the user briefly visited another page.
	if imported_town.get("ok", false):
		map_canvas.set_map_data(imported_town)
		_load_map_building_names(map_canvas)
		cbd_button.disabled = false
		import_summary_label.text = _statistics_text(imported_town.statistics)
		if not selected_cbd.is_empty():
			map_canvas.cbd_bounds = selected_cbd
			start_button.disabled = false
		if not selected_start.is_empty():
			map_canvas.start_location = selected_start
			start_button.text = "Change starting locations"
			selection_instructions.text = "Safe player and vehicle starting locations selected."
	if not pending_osm_files.is_empty():
		osm_files_label.text = "New map selected — read it before saving or playing: %s" % ", ".join(pending_osm_files)
		scan_button.disabled = false
	elif not selected_osm_files.is_empty():
		osm_files_label.text = _file_selection_text()
		scan_button.disabled = false
	_refresh_create_button()


func _on_import_tool_changed(page: String) -> void:
	if not is_instance_valid(map_canvas): return
	# A hidden drawing tool must not keep consuming left-drag map navigation.
	map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	if page == "cbd" and imported_town.get("ok", false):
		_set_map_mode(TownMapCanvasScript.EditMode.DRAW_CBD)
	elif page == "player" and not selected_cbd.is_empty():
		_activate_start_tool()
	elif page == "car" and not selected_start.is_empty():
		_set_map_mode(TownMapCanvasScript.EditMode.SET_VEHICLE_START)


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
	var exterior_load := building_exterior_store.load_from_town(loaded_project_directory)
	if not exterior_load.ok:
		content_area.add_child(_notice_panel("Could not load building designs", exterior_load.message, WARNING))
		return
	building_exterior_data = exterior_load.data
	editor_undo_stack.clear()
	editor_redo_stack.clear()
	editor_selected_building_id = ""
	_add_top_save_bar("Save corrections and rebuild", _save_map_editor_changes)

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
	editor_tools_navigation = ToolTileMenuScript.new()
	editor_tools_navigation.custom_minimum_size.y = 360
	tools_column.add_child(editor_tools_navigation)
	editor_tools_navigation.setup("Map tools")
	editor_tools_navigation.page_changed.connect(func(page: String):
		editor_tools_navigation.custom_minimum_size.y = 500 if page == "trees" else 360
		if editor_map_canvas != null:
			editor_map_canvas.show_floor_counts = page == "heights"
			_set_editor_mode(TownMapCanvasScript.EditMode.INSPECT))
	tools_column = editor_tools_navigation.add_page("buildings", "Hide buildings", "Select a footprint")
	tools_column.add_child(_settings_group_heading("Building footprints", "Select an imported building, then hide it if OSM placed it incorrectly. Select a hidden red footprint to restore it."))
	tools_column.add_child(_action_button("Select building", func(): _set_editor_mode(TownMapCanvasScript.EditMode.HIDE_BUILDING), false))
	editor_toggle_building_button = _action_button("Hide selected building", _toggle_editor_building, true)
	editor_toggle_building_button.disabled = true
	tools_column.add_child(editor_toggle_building_button)
	editor_selection_label = _label("No building selected.", 12, MUTED)
	editor_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(editor_selection_label)
	tools_column = editor_tools_navigation.add_page("new_building", "New building", "Draw a footprint")
	custom_footprint_name = LineEdit.new()
	custom_footprint_name.placeholder_text = "Building name (optional)"
	custom_footprint_name.max_length = 80
	tools_column.add_child(custom_footprint_name)
	tools_column.add_child(_action_button("Draw building footprint", func():
		_set_editor_mode(TownMapCanvasScript.EditMode.DRAW_BUILDING)
		_set_status("Drag a rectangle on clear land. Minimum 2 × 2 metres. Save/rebuild before designing its interior."), true))
	tools_column = editor_tools_navigation.add_page("heights", "Building height", "Set floor count")
	tools_column.add_child(_label("Total floors (ground floor included)", 13, TEXT))
	editor_floor_control = SpinBox.new()
	editor_floor_control.min_value = 1
	editor_floor_control.max_value = BuildingHeightProfile.MAX_FLOORS
	editor_floor_control.step = 1
	editor_floor_control.value = 1
	editor_floor_control.custom_minimum_size = Vector2(160, 42)
	tools_column.add_child(editor_floor_control)
	tools_column.add_child(_action_button("Apply floors — click buildings", func():
		editor_height_restore = false
		_set_status("Click each active footprint to apply %d floors. Drag to pan; Save when finished." % int(editor_floor_control.value)), true))
	tools_column.add_child(_action_button("Restore OSM/default — click buildings", func():
		editor_height_restore = true
		_set_status("Click buildings to remove their height override; roof/wall designs remain."), false))
	editor_height_status = _label("Click a building to set its total floors. Missing OSM counts use 1. Raised-roof perspective is visually capped at 10 floors. Undo/Redo is in Review.", 12, MUTED)
	editor_height_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(editor_height_status)
	tools_column = editor_tools_navigation.add_page("water", "Add water", "Draw a water area")
	tools_column.add_child(_settings_group_heading("Water correction", "Draw a rectangle over missing water to block all ground actors, or over incorrectly mapped water to make that area passable. NPD drones remain aerial."))
	tools_column.add_child(_action_button("Draw blocked water", func(): _set_editor_mode(TownMapCanvasScript.EditMode.DRAW_BLOCKED_WATER), false))
	tools_column = editor_tools_navigation.add_page("ground", "Restore land", "Correct mapped water")
	tools_column.add_child(_action_button("Draw passable ground", func(): _set_editor_mode(TownMapCanvasScript.EditMode.DRAW_ALLOWED_GROUND), false))
	editor_remove_zone_button = _action_button("Remove newest water correction", _remove_latest_editor_zone, false)
	tools_column.add_child(editor_remove_zone_button)
	var water_note := _label("Passable ground corrects water only; it does not erase a building. Hide an incorrect building separately.", 11, MUTED)
	water_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(water_note)
	tools_column = editor_tools_navigation.add_page("trees", "Tree type", "Choose town tree artwork")
	editor_tools_navigation.add_page("tree_upload", "Upload tree", "Add your own tree image")
	tree_settings_editor = TreeSettingsEditorScript.new()
	tools_column.add_child(tree_settings_editor)
	tree_settings_editor.configure(loaded_project_directory)
	tree_settings_editor.show_tool("style")
	editor_tools_navigation.page_changed.connect(func(page):
		if page in ["trees", "tree_upload"]:
			tree_settings_editor.reparent(editor_tools_navigation.pages[page])
			tree_settings_editor.show_tool("upload" if page == "tree_upload" else "style"))
	tools_column = editor_tools_navigation.add_page("coordinates", "Coordinates", "Select / copy")
	tools_column.add_child(_settings_group_heading("Storyline NPC coordinates", "Select this tool, click an outdoor location, then paste the copied latitude and longitude into the Storyline NPC creator."))
	tools_column.add_child(_action_button("Select location and copy coordinates", func(): _set_editor_mode(TownMapCanvasScript.EditMode.COPY_COORDINATES), true))
	editor_coordinate_status_label = _label("No location copied yet. Coordinate order is latitude, longitude.", 11, MUTED)
	editor_coordinate_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_column.add_child(editor_coordinate_status_label)
	tools_column = editor_tools_navigation.add_page("review", "Review", "Correction summary")
	tools_column.add_child(_settings_group_heading("Review corrections", "Use the Undo button in the top bar. Save rebuilds collisions, navigation and destinations. Original OSM files stay unchanged."))
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
	var map_help := _label("Hover for OSM details. Wheel zooms; left-drag moves the map, click selects. Water/ground drawing tools use left-drag to draw instead. Middle-drag also pans. Hidden buildings are red.", 11, MUTED)
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
	_load_map_building_names(editor_map_canvas)
	editor_map_canvas.set_override_data(editor_overrides)
	editor_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	editor_height_restore = false
	editor_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.HIDE_BUILDING)
	editor_map_canvas.building_selected.connect(_on_editor_building_selected)
	editor_map_canvas.override_zone_drawn.connect(_on_editor_zone_drawn)
	editor_map_canvas.building_footprint_drawn.connect(_on_custom_footprint_drawn)
	editor_map_canvas.coordinates_picked.connect(_on_editor_coordinates_picked)
	editor_map_canvas.view_changed.connect(func(zoom: float): editor_zoom_label.text = "%d%%" % roundi(zoom * 100.0))
	map_clip.add_child(editor_map_canvas)
	editor_map_canvas.custom_minimum_size = Vector2(280, 180)
	_refresh_editor_map_features()
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
	if editor_tools_navigation != null and editor_tools_navigation.current_page == "heights":
		if hidden:
			_set_status("Restore this hidden footprint before setting its height.")
			return
		_editor_record_change()
		if editor_height_restore: building_exterior_data = BuildingHeightProfile.restore(building_exterior_data, editor_selected_building_id)
		else: building_exterior_data = BuildingHeightProfile.set_floors(building_exterior_data, editor_selected_building_id, int(editor_floor_control.value)).data
		editor_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
		var resolved := BuildingHeightProfile.resolve(building.get("tags", {}), building_exterior_data.buildings.get(editor_selected_building_id, {}))
		editor_height_status.text = "Building %s: %d floors\n%s. Save to keep changes." % [editor_selected_building_id, resolved.total_floors, resolved.source]
		_refresh_editor_controls()
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
	editor_undo_stack.append(_editor_snapshot())
	if editor_undo_stack.size() > 50:
		editor_undo_stack.pop_front()
	editor_redo_stack.clear()


func _editor_undo() -> void:
	if editor_undo_stack.is_empty():
		return
	editor_redo_stack.append(_editor_snapshot())
	_restore_editor_snapshot(editor_undo_stack.pop_back())
	editor_selected_building_id = ""
	editor_map_canvas.selected_building_id = ""
	editor_map_canvas.set_override_data(editor_overrides)
	_refresh_editor_controls()


func _editor_redo() -> void:
	if editor_redo_stack.is_empty():
		return
	editor_undo_stack.append(_editor_snapshot())
	_restore_editor_snapshot(editor_redo_stack.pop_back())
	editor_selected_building_id = ""
	editor_map_canvas.selected_building_id = ""
	editor_map_canvas.set_override_data(editor_overrides)
	_refresh_editor_controls()


func _editor_snapshot() -> Dictionary:
	return {"corrections": editor_overrides.duplicate(true), "exteriors": building_exterior_data.duplicate(true)}

func _restore_editor_snapshot(snapshot: Dictionary) -> void:
	editor_overrides = snapshot.corrections
	_refresh_editor_map_features()
	building_exterior_data = snapshot.exteriors
	editor_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	if editor_height_status != null: editor_height_status.text = "Edit restored. Floor labels show current counts; Save to keep changes."

func _refresh_editor_map_features() -> void:
	# Keep hidden source shapes selectable for restore, and show new footprints.
	var display := imported_town.duplicate(false)
	var no_hidden := editor_overrides.duplicate(true)
	no_hidden["hidden_feature_ids"] = []
	var result := map_override_store.apply(imported_town.features, no_hidden)
	if result.ok:
		display["features"] = result.features
		editor_map_canvas.set_map_data(display)
		editor_map_canvas.set_override_data(editor_overrides)

func _on_custom_footprint_drawn(points: Array) -> void:
	var effective := map_override_store.apply(imported_town.features, editor_overrides)
	if not effective.ok: _set_status(effective.message); return
	var result := FootprintEditor.propose(editor_overrides, points, custom_footprint_name.text, effective.features, imported_town.bounds, selected_start)
	if not result.ok: _set_status(result.message); return
	_editor_record_change()
	editor_overrides = result.data
	_refresh_editor_map_features()
	editor_selected_building_id = str(result.feature.id)
	editor_map_canvas.selected_building_id = editor_selected_building_id
	_refresh_editor_controls()
	_set_status(result.message)

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
	if is_instance_valid(editor_undo_button): editor_undo_button.disabled = editor_undo_stack.is_empty()
	if is_instance_valid(editor_redo_button): editor_redo_button.disabled = editor_redo_stack.is_empty()
	editor_remove_zone_button.disabled = editor_overrides.get("zones", []).is_empty()
	if editor_toggle_building_button != null and editor_selected_building_id.is_empty():
		editor_toggle_building_button.disabled = true
	if editor_selection_label != null and editor_selected_building_id.is_empty():
		editor_selection_label.text = "No building selected."


func _save_map_editor_changes() -> void:
	if loaded_project_directory.is_empty():
		return
	var design_save := building_exterior_store.save_to_town(loaded_project_directory, building_exterior_data)
	if not design_save.ok:
		_show_message("Could not save building heights", design_save.message)
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
	_mark_section_saved()
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
	building_artwork_target = "roof"
	building_artwork_buttons.clear()
	var interior_load := building_interior_store.load_from_town(loaded_project_directory)
	building_link_ready = interior_load.ok
	building_link_data = interior_load.get("data", {}).duplicate(true)
	building_link_dirty = false
	building_save_button = _add_top_save_bar("Save building design", _save_building_designs)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(split)
	var tools_scroll := VBoxContainer.new()
	tools_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_scroll.custom_minimum_size.x = 370
	split.add_child(tools_scroll)
	var tools_margin := MarginContainer.new()
	tools_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_margin.add_theme_constant_override("margin_right", 18)
	tools_scroll.add_child(tools_margin)
	var tools := VBoxContainer.new()
	tools.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools.custom_minimum_size.x = 340
	tools.add_theme_constant_override("separation", 10)
	tools_margin.add_child(tools)
	tools.add_child(_label("Designing: %s" % current_town_name, 17, TEXT))
	# Selection stays available while only the active tool's form is displayed.
	custom_building_option = OptionButton.new()
	custom_building_option.custom_minimum_size.y = 40
	custom_building_option.item_selected.connect(_on_custom_building_selected)
	tools.add_child(_label("Open saved custom building", 12, TEXT))
	tools.add_child(custom_building_option)
	building_selection_label = _label("No building selected.", 12, MUTED)
	building_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(building_selection_label)
	building_custom_name_edit = LineEdit.new()
	building_custom_name_edit.placeholder_text = "Custom building name (optional)"
	building_custom_name_edit.max_length = 80
	building_custom_name_edit.text_changed.connect(_on_custom_building_name_changed)
	building_tools_navigation = ToolTileMenuScript.new()
	tools.add_child(building_tools_navigation)
	building_tools_navigation.setup("Building tools")
	building_tools_scroll = building_tools_navigation.page_scroll
	tools = building_tools_navigation.add_page("building", "Building name", "Name this footprint")
	tools.add_child(building_custom_name_edit)
	tools = building_tools_navigation.add_page("height", "Building height", "Set total floors")
	tools.add_child(_settings_group_heading("Height and building design", "OSM floor counts load automatically; otherwise one floor. Changing exterior height does not alter furnished interiors."))
	var floor_field := _building_alignment_field("Total floors", 1, BuildingHeightProfile.MAX_FLOORS, 1, "floors")
	building_floor_control = floor_field.control
	tools.add_child(floor_field.row)
	building_floor_control.value_changed.connect(_on_building_floors_changed)
	building_floor_status = _label("Select a building", 12, MUTED)
	building_floor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(building_floor_status)
	tools.add_child(_action_button("Restore OSM/default floors", _restore_building_floors, false))
	tools = building_tools_navigation.add_page("style", "Building style", "Choose wall design")
	building_style_option = OptionButton.new()
	for style in BuildingHeightProfile.STYLES:
		building_style_option.add_item(BuildingHeightProfile.STYLES[style])
		building_style_option.set_item_metadata(building_style_option.item_count - 1, style)
	building_style_option.item_selected.connect(_on_building_style_selected)
	tools.add_child(building_style_option)
	tools.add_child(_action_button("Upload wall artwork…", func():
		if not building_selected_feature.is_empty():
			importing_wall = true
			building_wall_import_target = "walls"
			building_image_dialog.title = "Choose a repeatable wall image (one floor)"
			building_image_dialog.popup_centered_ratio(0.72), false))
	tools = building_tools_navigation.add_page("export", "Export footprint", "Create a Paint template")
	tools.add_child(_settings_group_heading("Export a footprint template", "Export the exact footprint as a transparent PNG for painting your own roof artwork."))
	building_export_button = _action_button("Export footprint for Paint…", _choose_building_footprint_export_path, true)
	tools.add_child(building_export_button)
	var paint_note := _label("In Paint, keep the exported canvas size unchanged and paint over the grey footprint. Save as PNG, then choose that PNG as the exterior image.", 11, MUTED)
	paint_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(paint_note)
	tools = building_tools_navigation.add_page("upload", "Upload artwork", "Add a roof or wall image")
	tools.add_child(_settings_group_heading("Upload building artwork", "Choose Roof, Default walls, Front or Left in the preview, then upload its image. Your original picture is copied, not moved."))
	building_import_button = _action_button("Choose exterior roof image…", _choose_building_exterior_image, true)
	tools.add_child(building_import_button)
	building_artwork_upload = _action_button("Upload for selected surface…",_upload_selected_building_surface,false)
	tools.add_child(building_artwork_upload)
	tools = building_tools_navigation.add_page("artwork", "Align artwork", "Move, scale or turn the image")
	building_alignment_heading = _settings_group_heading("Align selected surface", "Choose Roof, Default walls, Front or Left in the live preview. Drag to align; wheel resizes the texture. Geometry and doors stay fixed.")
	tools.add_child(building_alignment_heading)
	building_artwork_status = _label("Select a building.",12,MUTED)
	building_artwork_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(building_artwork_status)
	building_artwork_material = OptionButton.new()
	for material in BuildingArtworkSettings.MATERIALS:
		if material=="automatic": building_artwork_material.add_item("Default / uploaded artwork")
		else: building_artwork_material.add_icon_item(load("res://assets/buildings/styles/%s_wall.svg" % material),material.capitalize())
	building_artwork_material.item_selected.connect(_on_building_artwork_material)
	tools.add_child(building_artwork_material)
	tools.add_child(_action_button("Use default for this surface",_restore_building_artwork_surface,false))
	var scale_field := _building_alignment_field("Image scale", 50.0, 300.0, 5.0, "%")
	building_scale_control = scale_field.control
	tools.add_child(scale_field.row)
	var rotation_field := _building_alignment_field("Rotation", -180.0, 180.0, 1.0, "°")
	building_rotation_control = rotation_field.control
	tools.add_child(rotation_field.row)
	var horizontal_field := _building_alignment_field("Move left/right", -100.0, 100.0, 0.5, "%")
	building_offset_x_control = horizontal_field.control
	tools.add_child(horizontal_field.row)
	var vertical_field := _building_alignment_field("Move up/down", -100.0, 100.0, 0.5, "%")
	building_offset_y_control = vertical_field.control
	tools.add_child(vertical_field.row)
	for control in [building_scale_control, building_rotation_control, building_offset_x_control, building_offset_y_control]:
		control.value_changed.connect(_on_building_alignment_changed)
	tools.add_child(_action_button("Reset image alignment", _reset_building_alignment, false))
	tools = building_tools_navigation.add_page("entrances", "Doors", "Place or drag outside doors")
	tools.add_child(_settings_group_heading("Place outside doorways", "Drag a numbered doorway to move it. Use Entry link afterwards to connect it to an interior."))
	building_entrance_option = OptionButton.new()
	building_entrance_option.custom_minimum_size.y = 38
	building_entrance_option.item_selected.connect(_on_building_entrance_selected)
	tools.add_child(building_entrance_option)
	# Primary workflows first, visible without scrolling on normal windows.
	tools.add_child(_action_button("Town map / drag doorway", func(): _show_building_workspace("map"), false))
	tools.add_child(_action_button("Facade / drag doorway artwork", func(): _show_building_workspace("door_art"), false))
	var door_tools := tools
	tools = building_tools_navigation.add_page("entry_link", "Entry link", "Connect a door to its interior")
	tools.add_child(_settings_group_heading("Link an outside doorway", "Choose a doorway, then place its arrival inside the ground floor. Create a blank ground floor only if this building has no interior yet."))
	building_link_button = _action_button("Link / drag interior arrival", _begin_building_interior_link, true)
	tools.add_child(building_link_button)
	building_link_status = _label("",12,MUTED)
	building_link_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(building_link_status)
	building_create_interior_button = _action_button("Create blank ground floor", _create_building_link_floor, false)
	tools.add_child(building_create_interior_button)
	tools = door_tools
	building_door_button = _action_button("Add another entrance", _begin_building_door_placement, true)
	tools.add_child(building_door_button)
	building_move_entrance_button = _action_button("Move selected entrance", _begin_move_building_entrance, false)
	tools.add_child(building_move_entrance_button)
	building_move_entrance_button.hide() # Retained for compatibility; direct drag replaces this extra step.
	building_remove_entrance_button = _action_button("Remove selected entrance", _remove_selected_building_entrance, false)
	tools.add_child(building_remove_entrance_button)
	tools = building_tools_navigation.add_page("review", "Review", "Check • remove design")
	tools.add_child(_settings_group_heading("Review", "Save at the top when ready. Linked doors become usable in Play test; decorative doors alone do not create an interior."))
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
	map_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_margin.add_child(map_group)
	building_artwork_workspace=VBoxContainer.new()
	building_artwork_workspace.size_flags_vertical=Control.SIZE_EXPAND_FILL
	map_group.add_child(building_artwork_workspace)
	var artwork_row := HBoxContainer.new()
	building_artwork_workspace.add_child(artwork_row)
	for target in BuildingArtworkSettings.TARGETS:
		var button := _action_button({"roof":"Roof","walls":"Default walls","front":"Front","left":"Left"}[target],func(): _select_building_artwork_target(target),false)
		button.toggle_mode=true
		building_artwork_buttons[target]=button
		artwork_row.add_child(button)
	artwork_row.add_child(_action_button("View −",func(): building_artwork_preview.zoom_view(0.8),false))
	artwork_row.add_child(_action_button("Fit",func(): building_artwork_preview.fit_view(),false))
	artwork_row.add_child(_action_button("View +",func(): building_artwork_preview.zoom_view(1.25),false))
	var artwork_help := _label("Live artwork preview: left-drag aligns · right-drag rotates · wheel changes texture size. View −/+ zoom the preview only. Map below still pans normally.",11,MUTED)
	building_artwork_help=artwork_help
	artwork_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	building_artwork_workspace.add_child(artwork_help)
	building_artwork_preview=BuildingArtworkPreview.new()
	building_artwork_preview.alignment_dragged.connect(_drag_building_artwork)
	building_artwork_preview.rotation_dragged.connect(func(change: float):
		if building_rotation_control.editable: building_rotation_control.value=wrapf(building_rotation_control.value+change,-180.0,180.0))
	building_artwork_preview.scale_requested.connect(func(change: float):
		if building_scale_control.editable: building_scale_control.value+=change)
	building_artwork_preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	building_artwork_preview.door_placement_requested.connect(_on_building_dragged_door)
	building_artwork_workspace.add_child(building_artwork_preview)
	building_map_workspace=VBoxContainer.new()
	building_map_workspace.size_flags_vertical=Control.SIZE_EXPAND_FILL
	map_group.add_child(building_map_workspace)
	var zoom_row := HBoxContainer.new()
	building_map_workspace.add_child(zoom_row)
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
	var help := _label("Click a building to select. Wheel zooms; drag empty space to pan. In Entrances, drag a doorway to move it. Use the tool buttons for artwork or interior linking.", 11, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	building_map_workspace.add_child(help)
	var clip := PanelContainer.new()
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip.clip_contents = true
	building_map_workspace.add_child(clip)
	building_map_canvas = TownMapCanvasScript.new()
	building_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	building_map_canvas.set_map_data(imported_town)
	building_map_canvas.set_override_data(override_load.data)
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	building_map_canvas.building_selected.connect(_on_building_creator_selected)
	building_map_canvas.building_door_requested.connect(_on_building_door_requested)
	building_map_canvas.building_door_drag_requested.connect(_on_building_dragged_door)
	building_map_canvas.placement_rotation_requested.connect(func(change: float):
		if building_rotation_control.editable: building_rotation_control.value = wrapf(building_rotation_control.value + change, -180.0, 180.0))
	building_map_canvas.view_changed.connect(func(zoom: float): building_zoom_label.text = "%d%%" % roundi(zoom * 100.0))
	clip.add_child(building_map_canvas)
	# Shared canvases' old minima forced a second preview off-screen. Only one
	# workspace is visible, and each can shrink to fit the available window.
	building_map_canvas.custom_minimum_size=Vector2(280,220)
	building_entry_workspace=VBoxContainer.new()
	building_entry_workspace.size_flags_vertical=Control.SIZE_EXPAND_FILL
	map_group.add_child(building_entry_workspace)
	var entry_bar := HBoxContainer.new()
	building_entry_workspace.add_child(entry_bar)
	entry_bar.add_child(_label("Ground-floor arrival",14,TEXT))
	entry_bar.add_child(_action_button("−",func(): building_entry_canvas.zoom_out(),false))
	entry_bar.add_child(_action_button("Fit",func(): building_entry_canvas.reset_view(),false))
	entry_bar.add_child(_action_button("+",func(): building_entry_canvas.zoom_in(),false))
	var entry_help := _label("Click or drag the green arrival marker. Keep it clear of walls and furniture; red X means blocked. Save building design saves both sides of the link.",11,MUTED)
	entry_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	building_entry_workspace.add_child(entry_help)
	building_entry_canvas=InteriorFloorCanvasScript.new()
	building_entry_canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
	building_entry_canvas.entry_spawn_requested.connect(_on_building_entry_spawn)
	building_entry_workspace.add_child(building_entry_canvas)
	building_entry_canvas.custom_minimum_size=Vector2(280,220)
	building_entry_canvas.entry_drag_enabled=true
	building_tools_navigation.page_changed.connect(_on_building_tool_page)
	_show_building_workspace("map")
	_refresh_building_creator_controls()


func _choose_project_for_building_creator() -> void:
	project_dialog_action = "building_creator"
	_prepare_existing_project_dialog()


func _show_building_workspace(workspace: String) -> void:
	building_map_workspace.visible=workspace=="map"
	building_artwork_workspace.visible=workspace in ["artwork","door_art"]
	building_entry_workspace.visible=workspace=="interior"
	building_artwork_preview.editing_doors=workspace=="door_art"
	building_artwork_preview.selected_target=building_door_view_target if workspace=="door_art" else building_artwork_target
	for target in building_artwork_buttons:
		building_artwork_buttons[target].visible=workspace!="door_art" or target!="roof"
		building_artwork_buttons[target].text="All sides" if workspace=="door_art" and target=="walls" else {"roof":"Roof","walls":"Default walls","front":"Front","left":"Left"}[target]
		building_artwork_buttons[target].button_pressed=target==(building_door_view_target if workspace=="door_art" else building_artwork_target)
	building_artwork_help.text="Click a visible wall to add a door, or drag a numbered doorway. Release to snap; blocked approaches show a red X. Wheel / View −/+ zoom. Link the interior arrival using the button on the left." if workspace=="door_art" else "Drag to align artwork · right-drag rotates · wheel changes texture size. View −/Fit/+ controls the view only. Back returns to the full-height town map."
	building_artwork_preview.queue_redraw()
	building_artwork_preview._fit()


func _on_building_tool_page(page: String) -> void:
	if page in ["entrances", "entry_link"]:
		building_entrance_option.reparent(building_tools_navigation.pages[page])
		building_tools_navigation.pages[page].move_child(building_entrance_option, 1)
	building_map_canvas.door_drag_enabled=page=="entrances"
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	building_pending_door_index=-1
	_show_building_workspace("artwork" if page in ["artwork", "upload"] else "map")


func _create_building_link_floor() -> void:
	if not building_link_ready or building_selected_feature.is_empty(): return
	var result := building_interior_store.create_blank_ground_floor(building_link_data,building_selected_feature)
	if not result.ok: _set_status(result.message); return
	building_link_data=result.data
	building_link_dirty=true
	_refresh_building_creator_controls()
	_begin_building_interior_link()


func _begin_building_interior_link() -> void:
	if building_link_button.disabled: return
	_refresh_building_entry_canvas()
	_show_building_workspace("interior")
	building_entry_canvas.begin_entry_placement()
	_set_status("Choose a clear ground-floor arrival point for the selected outside doorway. Click or drag, then Save building design.")


func _refresh_building_entry_canvas() -> void:
	var id := str(building_selected_feature.get("id",""))
	var floors: Array=building_link_data.get("buildings",{}).get(id,{}).get("floors",[])
	building_entry_canvas.set_floor(floors[0] if not floors.is_empty() else {},id+":ground_floor")
	building_entry_canvas.set_asset_root(loaded_project_directory)
	building_entry_canvas.entry_drag_id=str(building_entrance_option.get_item_metadata(building_entrance_option.selected)) if building_entrance_option.item_count>0 else ""


func _on_building_entry_spawn(position_metres: Vector2) -> void:
	if not building_link_ready or building_entrance_option.item_count==0: return
	var id := str(building_entrance_option.get_item_metadata(building_entrance_option.selected))
	var result := building_interior_store.set_entry_spawn(building_link_data,str(building_selected_feature.id),id,position_metres)
	if not result.ok:
		building_entry_canvas.invalid_position=position_metres
		building_entry_canvas.placing_entry=true
		building_entry_canvas.queue_redraw()
		_set_status(result.message)
		return
	building_link_data=result.data
	building_link_dirty=true
	building_entry_canvas.invalid_position=Vector2.INF
	_refresh_building_creator_controls()
	_set_status("Doorway linked to ground-floor arrival. Save building design when ready.")


func _on_building_dragged_door(index: int, location: Dictionary) -> void:
	building_pending_door_index=index
	_on_building_door_requested(location)


func _load_map_building_names(target: Control) -> void:
	if loaded_project_directory.is_empty(): return
	var result := building_exterior_store.load_from_town(loaded_project_directory)
	if result.ok: target.set_building_exterior_data(result.data, loaded_project_directory)


func _on_custom_building_selected(index: int) -> void:
	var feature_id := str(custom_building_option.get_item_metadata(index))
	for feature in building_effective_features:
		if str(feature.get("id", "")) != feature_id: continue
		building_map_canvas.selected_building_id = feature_id
		_on_building_creator_selected(feature)
		var points: PackedVector2Array = building_map_canvas._screen_polygon(feature.get("points", []))
		if points.size() >= 3:
			var centre: Vector2 = building_map_canvas._polygon_bounds(points).get_center()
			building_map_canvas._pan_by(building_map_canvas.size * 0.5 - centre)
		return


func _on_custom_building_name_changed(value: String) -> void:
	if building_updating_controls or building_selected_feature.is_empty(): return
	var result := building_exterior_store.set_custom_name(building_exterior_data, str(building_selected_feature.id), value)
	if not result.ok: return
	building_exterior_data = result.data
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_refresh_custom_building_options()


func _refresh_custom_building_options() -> void:
	if custom_building_option == null: return
	custom_building_option.clear()
	custom_building_option.add_item("Choose a saved custom building…")
	custom_building_option.set_item_metadata(0, "")
	var feature_ids: Array = building_exterior_data.get("buildings", {}).keys()
	feature_ids.sort()
	for feature_id in feature_ids:
		var record: Dictionary = building_exterior_data.buildings[feature_id]
		var name_value := str(record.get("custom_name", ""))
		if name_value.is_empty():
			for feature in building_effective_features:
				if str(feature.get("id", "")) == str(feature_id): name_value = str(BuildingInformationScript.describe_feature(feature).name)
		custom_building_option.add_item("%s · ID %s" % [name_value, str(feature_id)])
		var index := custom_building_option.item_count - 1
		custom_building_option.set_item_metadata(index, str(feature_id))
		if str(building_selected_feature.get("id", "")) == str(feature_id): custom_building_option.select(index)


func _on_building_creator_selected(feature: Dictionary) -> void:
	var feature_id := str(feature.get("id", ""))
	if feature_id in building_map_canvas.override_data.get("hidden_feature_ids", []):
		building_selected_feature = {}
		building_map_canvas.selected_building_id = ""
		building_selection_label.text = "That building is hidden. Restore it in Advanced map editor before designing it."
		_refresh_building_creator_controls()
		return
	building_selected_feature = feature.duplicate(true)
	building_map_canvas.selected_building_id=feature_id
	var record := BuildingInformationScript.describe_feature(feature)
	var design: Dictionary = building_exterior_data.get("buildings", {}).get(feature_id, {})
	var design_parts: Array[String] = []
	if design.has("exterior"):
		design_parts.append("exterior image")
	var entrance_count: int = design.get("doors", []).size()
	if entrance_count > 0:
		design_parts.append("%d entrance%s" % [entrance_count, "" if entrance_count == 1 else "s"])
	var design_text := "No custom design yet" if design_parts.is_empty() else "Has %s" % " and ".join(design_parts)
	building_selection_label.text = "%s\n%s · %s\nSource: %s" % [str(design.get("custom_name",record.name)), str(record.category), design_text, str(record.source_reference)]
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	_refresh_building_creator_controls()


func _choose_building_exterior_image() -> void:
	if building_selected_feature.is_empty():
		return
	importing_wall = false
	building_image_dialog.title = "Choose roof / existing exterior artwork"
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
	var result := building_exterior_store.import_wall(loaded_project_directory, building_exterior_data, str(building_selected_feature.id), path_value,building_wall_import_target) if importing_wall else building_exterior_store.import_exterior(
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
	_show_building_workspace("map")
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.PLACE_BUILDING_DOOR)
	_set_status("Click or drag near the preferred outside wall; release to place a doorway.")


func _begin_move_building_entrance() -> void:
	if building_selected_feature.is_empty() or building_entrance_option.item_count == 0:
		return
	building_pending_door_index = building_entrance_option.selected
	_show_building_workspace("map")
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
		building_map_canvas.rejected_door_location=location
		building_map_canvas.queue_redraw()
		building_artwork_preview.rejected_door_location=location
		building_artwork_preview.door_overlay.queue_redraw()
		_set_status(result.message)
		return
	building_exterior_data = result.data
	building_map_canvas.rejected_door_location={}
	building_artwork_preview.rejected_door_location={}
	building_pending_door_index = -1
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	building_map_canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	_on_building_creator_selected(building_selected_feature)
	building_entrance_option.select(int(result.door_index))
	_refresh_building_link_status()
	_set_status(result.message)


func _remove_selected_building_entrance() -> void:
	if building_selected_feature.is_empty() or building_entrance_option.item_count == 0:
		return
	var removed_id := str(building_entrance_option.get_item_metadata(building_entrance_option.selected))
	var result := building_exterior_store.remove_door(
		building_exterior_data, str(building_selected_feature.get("id", "")), building_entrance_option.selected
	)
	if not result.ok:
		_show_message("Could not remove entrance", result.message)
		return
	building_exterior_data = result.data
	# An intentional deletion is not a legacy ID mismatch. Remove its links so
	# save-time migration cannot silently attach that arrival to a different door.
	var id := str(building_selected_feature.id)
	if building_link_data.get("buildings",{}).has(id):
		for floor in building_link_data.buildings[id].floors:
			floor.entry_links=floor.get("entry_links",[]).filter(func(link): return str(link.exterior_entrance_id)!=removed_id)
		building_link_dirty=true
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_on_building_creator_selected(building_selected_feature)
	_set_status(result.message)


func _on_building_entrance_selected(_index: int) -> void:
	_refresh_building_link_status()
	if building_entry_workspace.visible: _refresh_building_entry_canvas()
	_set_status("Selected entrance %d for move/remove actions." % (_index + 1))


func _select_building_artwork_target(target: String) -> void:
	if building_artwork_preview.editing_doors:
		building_door_view_target=target
		_show_building_workspace("door_art")
		return
	if building_tools_navigation.current_page!="artwork": building_tools_navigation.open_page("artwork")
	building_artwork_target=target
	_refresh_building_creator_controls()
	building_tools_scroll.scroll_vertical=int(building_alignment_heading.position.y)

func _drag_building_artwork(delta: Vector2) -> void:
	if building_selected_feature.is_empty(): return
	building_updating_controls=true
	building_offset_x_control.value+=delta.x
	building_offset_y_control.value+=delta.y
	building_updating_controls=false
	_on_building_alignment_changed()

func _on_building_artwork_material(index: int) -> void:
	if building_updating_controls or building_selected_feature.is_empty(): return
	var result := BuildingArtworkSettings.set_material(building_exterior_data,str(building_selected_feature.id),building_artwork_target,BuildingArtworkSettings.MATERIALS[index])
	if not result.ok: return
	building_exterior_data=result.data
	_refresh_building_creator_controls()
	_set_status("Wall material changed. Save building design when ready.")

func _upload_selected_building_surface() -> void:
	if building_selected_feature.is_empty(): return
	importing_wall=building_artwork_target!="roof"
	building_wall_import_target=building_artwork_target
	building_image_dialog.title="Upload %s artwork" % building_artwork_target
	building_image_dialog.popup_centered_ratio(0.72)

func _restore_building_artwork_surface() -> void:
	if building_selected_feature.is_empty(): return
	building_exterior_data=BuildingArtworkSettings.remove_override(building_exterior_data,str(building_selected_feature.id),building_artwork_target)
	building_map_canvas.set_building_exterior_data(building_exterior_data,loaded_project_directory)
	_refresh_building_creator_controls()
	_set_status("Selected surface restored to its default. Doors, floors and other surfaces retained; save when ready.")

func _on_building_alignment_changed(_value: float = 0.0) -> void:
	if building_updating_controls or building_selected_feature.is_empty():
		return
	var result := BuildingArtworkSettings.set_alignment(building_exterior_data,str(building_selected_feature.id),building_artwork_target,{"scale_percent":building_scale_control.value,"rotation_degrees":building_rotation_control.value,"offset_x_percent":building_offset_x_control.value,"offset_y_percent":building_offset_y_control.value})
	if not result.ok:
		return
	building_exterior_data = result.data
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory, false)
	_refresh_building_creator_controls()
	_set_status("%s artwork alignment changed. Save the building design when ready." % building_artwork_target.capitalize())


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
	var id := str(building_selected_feature.id)
	if building_link_data.get("buildings",{}).has(id):
		for floor in building_link_data.buildings[id].floors: floor.entry_links=[]
		building_link_dirty=true
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_on_building_creator_selected(building_selected_feature)
	_set_status("Removed this building's custom exterior and entrance from the unsaved design.")


func _save_building_designs() -> void:
	if loaded_project_directory.is_empty():
		return
	if building_link_dirty and not building_interior_store.validate(building_link_data).ok:
		_set_status("Interior link could not be validated; neither design was saved.")
		return
	var result := building_exterior_store.save_to_town(loaded_project_directory, building_exterior_data)
	if not result.ok:
		_show_message("Could not save building design", result.message)
		return
	building_exterior_data = result.data
	var interior_load := building_interior_store.load_from_town(loaded_project_directory)
	if building_link_dirty: interior_load={"ok":true,"data":building_link_data}
	var interior_message := ""
	var all_saved := false
	if interior_load.ok:
		var synchronized := building_interior_store.synchronize_with_exteriors(interior_load.data, building_exterior_data, imported_town.features)
		var interior_save := building_interior_store.save_to_town(loaded_project_directory, synchronized.data)
		if not interior_save.ok:
			interior_message = " The exterior was saved, but the matching interior name could not be updated: %s" % interior_save.message
		elif int(synchronized.unresolved_links) > 0:
			interior_message = " One or more interior entry links still need to be reselected in Interior Designer."
		elif int(synchronized.repaired_links) > 0:
			interior_message = " Creator Studio also repaired the building's unambiguous exterior-to-interior entrance link."
		if interior_save.ok:
			building_link_data=interior_save.data
			building_link_dirty=false
			all_saved=true
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_refresh_building_creator_controls()
	_set_status("Building designs saved for %s." % current_town_name)
	if all_saved: _mark_section_saved()
	_show_message("Building design saved", "The name, exterior artwork, footprint clipping and entrance were saved inside this town project. Existing interior records now use the same displayed name while retaining the stable OSM building ID.%s The mapped collision shape was not changed." % interior_message)


func _on_building_floors_changed(value: float) -> void:
	if building_updating_controls or building_selected_feature.is_empty(): return
	building_exterior_data = BuildingHeightProfile.set_floors(building_exterior_data, str(building_selected_feature.id), int(value)).data
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_refresh_building_creator_controls()

func _restore_building_floors() -> void:
	if building_selected_feature.is_empty(): return
	building_exterior_data = BuildingHeightProfile.restore(building_exterior_data, str(building_selected_feature.id))
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_refresh_building_creator_controls()

func _on_building_style_selected(index: int) -> void:
	if building_updating_controls or building_selected_feature.is_empty(): return
	building_exterior_data = BuildingHeightProfile.set_style(building_exterior_data, str(building_selected_feature.id), str(building_style_option.get_item_metadata(index)))
	building_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
	_set_status("Building style selected. Existing uploaded roof/wall art takes priority. Save when ready.")

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
	building_floor_control.editable = selected
	building_style_option.disabled = not selected
	var resolved := BuildingHeightProfile.resolve(building_selected_feature.get("tags", {}), record)
	building_floor_control.value = resolved.total_floors
	building_floor_status.text = "%d floors · %s%s%s" % [resolved.total_floors, resolved.source, " · source value needs review" if resolved.review else "", " · visual height capped at 10 floors" if resolved.total_floors > 10 else ""]
	for index in building_style_option.item_count:
		if str(building_style_option.get_item_metadata(index)) == str(record.get("building_style", "automatic")): building_style_option.select(index)
	building_custom_name_edit.editable = selected
	building_custom_name_edit.text = str(record.get("custom_name", ""))
	_refresh_custom_building_options()
	for control in [building_scale_control, building_rotation_control, building_offset_x_control, building_offset_y_control]:
		control.editable = selected
	var alignment := BuildingArtworkSettings.alignment(record,building_artwork_target)
	building_scale_control.value = float(alignment.get("scale_percent",100.0))
	building_rotation_control.value = float(alignment.get("rotation_degrees",0.0))
	building_offset_x_control.value = float(alignment.get("offset_x_percent",0.0))
	building_offset_y_control.value = float(alignment.get("offset_y_percent",0.0))
	building_artwork_upload.disabled=not selected
	building_artwork_material.disabled=not selected or building_artwork_target=="roof"
	var selected_material := str(record.get("wall_material","automatic")) if building_artwork_target=="walls" else str(record.get("facades",{}).get(building_artwork_target,{}).get("material","automatic"))
	building_artwork_material.select(maxi(0,BuildingArtworkSettings.MATERIALS.find(selected_material)))
	for target in building_artwork_buttons:
		building_artwork_buttons[target].button_pressed=target==(building_door_view_target if building_artwork_preview.editing_doors else building_artwork_target)
	building_artwork_status.text="Editing %s. Roof/door shapes and ground collision do not change." % building_artwork_target if selected else "Select a building."
	building_artwork_preview.selected_target=building_door_view_target if building_artwork_preview.editing_doors else building_artwork_target
	building_artwork_preview.set_design(building_selected_feature,building_exterior_data,imported_town.bounds,loaded_project_directory)
	var previous_selection := building_entrance_option.selected
	building_entrance_option.clear()
	for index in doors.size():
		var door: Dictionary = doors[index]
		var floor_links: Array=building_link_data.get("buildings",{}).get(selected_id,{}).get("floors",[])
		var linked: bool = not floor_links.is_empty() and floor_links[0].get("entry_links",[]).any(func(link): return str(link.exterior_entrance_id)==str(door.get("id","")))
		building_entrance_option.add_item("Entrance %d · %s" % [index + 1, "✓ Ground floor" if linked else "✗ Interior not linked"])
		building_entrance_option.set_item_metadata(index, str(door.get("id", "entrance_%d" % (index + 1))))
	if building_entrance_option.item_count > 0:
		building_entrance_option.select(clampi(previous_selection, 0, building_entrance_option.item_count - 1))
	building_entrance_option.disabled = doors.is_empty()
	building_updating_controls = false
	_refresh_building_link_status()
	if building_entry_workspace.visible: _refresh_building_entry_canvas()
	var design_count: int = building_exterior_data.get("buildings", {}).size()
	building_summary_label.text = "%d building design(s) in this town · %d entrance(s) on the selected building. Original OSM geometry and generated collision footprints remain unchanged." % [design_count, doors.size()]


func _refresh_building_link_status() -> void:
	var id := str(building_selected_feature.get("id",""))
	var floors: Array=building_link_data.get("buildings",{}).get(id,{}).get("floors",[])
	building_create_interior_button.disabled=not building_link_ready or id.is_empty() or not floors.is_empty()
	building_link_button.disabled=not building_link_ready or floors.is_empty() or building_entrance_option.item_count==0
	if not building_link_ready:
		building_link_status.text="Interior data could not be read. Repair it before linking; existing data will not be overwritten."
	elif floors.is_empty(): building_link_status.text="No interior yet. Create a blank ground floor, then link the selected door."
	elif building_entrance_option.item_count==0: building_link_status.text="Place an outside doorway first."
	else:
		var entrance_id := str(building_entrance_option.get_item_metadata(building_entrance_option.selected))
		var links: Array=floors[0].get("entry_links",[])
		var linked := links.any(func(link): return str(link.exterior_entrance_id)==entrance_id)
		building_link_status.text="✓ Selected doorway linked to Ground floor. Save when ready." if linked else "✗ Selected doorway has no interior arrival. Choose Link / drag interior arrival."


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
	var furniture_catalog_load := interior_furniture_library.load_from_town(loaded_project_directory)
	var floor_material_load := interior_floor_material_library.load_from_town(loaded_project_directory)
	if not exterior_load.ok or not interior_load.ok or not furniture_catalog_load.ok or not floor_material_load.ok:
		content_area.add_child(_notice_panel(
			"Could not read building design data",
			str(exterior_load.get("message", interior_load.get("message", furniture_catalog_load.get("message", floor_material_load.get("message", "The saved building data could not be opened."))))),
			WARNING
		))
		return
	interior_exterior_data = exterior_load.data
	interior_stair_floor_counts.clear()
	var synchronized := building_interior_store.synchronize_with_exteriors(interior_load.data, interior_exterior_data, imported_town.features)
	interior_data = synchronized.data
	interior_custom_catalog_data = furniture_catalog_load.data
	interior_floor_material_data = floor_material_load.data
	var notes_load := LocationNotesScript.new().load_from_town(loaded_project_directory)
	location_notes_ready = bool(notes_load.ok)
	if notes_load.ok:
		location_notes_data = notes_load.data
		location_note_texts = notes_load.texts
	else: _set_status(str(notes_load.message))
	var storyline_load := storyline_npc_store.load_from_town(loaded_project_directory, imported_town.get("bounds", {}), imported_town.features, {}, interior_load.data)
	interior_storyline_ready = bool(storyline_load.ok)
	if storyline_load.ok: storyline_npc_data = storyline_load.data
	else:
		storyline_npc_data = StorylineNpcStoreScript.empty_data()
		_set_status(str(storyline_load.message))
	var trader_load := TraderStoreScript.new().load_from_town(loaded_project_directory)
	interior_storyline_ready = interior_storyline_ready and bool(trader_load.ok)
	if trader_load.ok:
		interior_trader_data = trader_load.data
		storyline_npc_data = TraderStoreScript.classify_placements(storyline_npc_data, interior_trader_data)
	else: _set_status(str(trader_load.message))
	interior_eligible_features.clear()
	interior_connection_cache.clear()
	var connection_features := _storyline_effective_features()
	if not connection_features.ok:
		content_area.add_child(_notice_panel("Could not load map corrections", connection_features.message, WARNING))
		return
	interior_connection_features = BuildingConnections.with_source_precision(loaded_project_directory, connection_features.features)
	for feature_value in interior_connection_features:
		if not feature_value is Dictionary or str(feature_value.get("kind", "")) != "building":
			continue
		var feature: Dictionary = feature_value
		var exterior: Dictionary = interior_exterior_data.get("buildings", {}).get(str(feature.get("id", "")), {})
		interior_eligible_features.append(feature)
	if interior_eligible_features.is_empty():
		content_area.add_child(_notice_panel(
			"No active building footprints",
			"Use Advanced map editor → New building, or restore a hidden building.",
			WARNING
		))
		content_area.add_child(_action_button("Open Building Creator", _show_building_creator_page, true))
		return
	interior_save_button = _add_top_save_bar("Save interior layout", _save_interior_layouts)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(split)
	var tools_scroll := ScrollContainer.new()
	interior_tools_panel = tools_scroll
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools_scroll.custom_minimum_size.x = 310
	tools_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(tools_scroll)
	var tools_margin := MarginContainer.new()
	tools_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_margin.add_theme_constant_override("margin_right", 18)
	tools_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_scroll.add_child(tools_margin)
	var tools := VBoxContainer.new()
	tools.custom_minimum_size.x = 280
	tools.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools.add_theme_constant_override("separation", 10)
	tools_margin.add_child(tools)
	tools.add_child(_label("Choose a building footprint", 14, TEXT))
	var footprint_row := HBoxContainer.new()
	tools.add_child(footprint_row)
	interior_building_option = OptionButton.new()
	interior_building_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior_building_option.custom_minimum_size.y = 40
	interior_building_option.fit_to_longest_item = false
	interior_building_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for feature in interior_eligible_features:
		var feature_id := str(feature.get("id", ""))
		var exterior_record: Dictionary = interior_exterior_data.get("buildings", {}).get(feature_id, {})
		var feature_name := str(exterior_record.get("custom_name", feature.get("tags", {}).get("name", "Unnamed building")))
		interior_building_option.add_item("%s · ID %s" % [feature_name, str(feature.get("id", ""))])
		interior_building_option.set_item_metadata(interior_building_option.item_count - 1, str(feature.get("id", "")))
	interior_building_option.item_selected.connect(_on_interior_building_selected)
	footprint_row.add_child(interior_building_option)
	interior_map_button = _action_button("Map", _show_interior_building_map, false)
	interior_map_button.tooltip_text = "Choose a footprint on the town map"
	footprint_row.add_child(interior_map_button)
	interior_create_button = _action_button("Create interior from this footprint", _create_blank_interior_floor, true)
	tools.add_child(interior_create_button)
	# Floor choice stays visible across tools, including both stair endpoints.
	interior_floor_option = OptionButton.new()
	interior_floor_option.custom_minimum_size.y = 40
	interior_floor_option.item_selected.connect(_on_interior_floor_selected)
	tools.add_child(interior_floor_option)
	var tools_root := tools
	interior_tools_navigation = ToolTileMenuScript.new()
	tools_root.add_child(interior_tools_navigation)
	interior_tools_navigation.setup("Interior tools")
	var seat_page: VBoxContainer = interior_tools_navigation.add_page("seat_direction","Seat direction","Face chairs and toilets")
	seat_page.add_child(_settings_group_heading("Seating direction", "Click a chair or toilet on the map. Drag the arrow's round tip to set the sitting direction. Save keeps the angle. In Play test, use E to sit or stand. Front, back, left and right artwork follows the nearest direction; automatic NPC seating is a later feature."))
	tools = interior_tools_navigation.add_page("new_building", "New building", "Draw an outdoor footprint")
	tools.add_child(_settings_group_heading("Create an outdoor footprint", "Draw a rectangle in Advanced map editor, then save it. Return here to create an interior from that footprint."))
	tools.add_child(_action_button("Draw footprint on town map", func():
		_request_section_navigation(func():
			_show_advanced_map_editor_page()
			editor_tools_navigation.open_page("new_building")
			_set_editor_mode(TownMapCanvasScript.EditMode.DRAW_BUILDING)), true))
	tools = interior_tools_navigation.add_page("floors", "Add floor", "Create an upper floor")
	tools.add_child(_settings_group_heading("Add an upper floor", "Create another editable floor using this building's footprint. This is a game layout, not a surveyed floor plan."))
	tools.add_child(_label("Create the ground floor using the button above the tools.", 12, MUTED))
	interior_add_floor_button = _action_button("Add upper floor", _add_interior_floor, true)
	tools.add_child(interior_add_floor_button)
	tools = interior_tools_navigation.add_page("size", "Floor size", "Resize this floor")
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
	tools = interior_tools_navigation.add_page("stairs", "Stairs", "Connect • drag • explore floors")
	tools.add_child(_settings_group_heading("Connect two floors", "Choose an existing floor or New upper floor. A new floor also raises the exterior count when needed. Place both points, then Save. In play, use E."))
	interior_stair_target = OptionButton.new()
	interior_stair_target.custom_minimum_size.y = 40
	tools.add_child(interior_stair_target)
	interior_stair_auto = CheckBox.new()
	interior_stair_auto.text = "Auto-place matching stairs on destination floor"
	interior_stair_auto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(interior_stair_auto)
	interior_stair_rotation = SpinBox.new()
	interior_stair_rotation.min_value = 0
	interior_stair_rotation.max_value = 359.9
	interior_stair_rotation.step = 0.1
	interior_stair_rotation.suffix = "°"
	interior_stair_rotation.value_changed.connect(_set_interior_stair_rotation)
	tools.add_child(_label("Stair rotation (hold right mouse + drag)", 12, TEXT))
	tools.add_child(interior_stair_rotation)
	interior_stair_add = _action_button("Place paired stairs", _begin_interior_stairs, true)
	tools.add_child(interior_stair_add)
	tools.add_child(_action_button("Cancel placement", _cancel_interior_stairs, false))
	interior_stair_hint = _label("Choose a destination; New upper floor creates it automatically.", 12, MUTED)
	interior_stair_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(interior_stair_hint)
	interior_stair_list = OptionButton.new()
	interior_stair_list.custom_minimum_size.y = 40
	interior_stair_list.item_selected.connect(func(index):
		interior_floor_canvas.stair_selected_id = str(interior_stair_list.get_item_metadata(index))
		interior_floor_canvas.queue_redraw())
	tools.add_child(interior_stair_list)
	interior_stair_remove = _action_button("Remove selected stair pair", _remove_interior_stairs, false)
	tools.add_child(interior_stair_remove)
	tools = interior_tools_navigation.add_page("connections", "Next-door link", "Connect a shared wall")
	tools.add_child(_settings_group_heading("Connect neighbouring buildings", "Choose a neighbour, then click the shared wall. Drag doors to move both sides. No gaps or corner-only contacts. In play, press E."))
	interior_connection_target = OptionButton.new()
	interior_connection_target.custom_minimum_size.y = 40
	interior_connection_target.item_selected.connect(func(_index): _refresh_connection_actions())
	tools.add_child(interior_connection_target)
	interior_connection_create = _action_button("Create neighbour's ground floor", _create_connection_neighbour, false)
	tools.add_child(interior_connection_create)
	interior_connection_add = _action_button("Place connecting door", func():
		interior_floor_canvas.placing_connection = true
		interior_connection_hint.text = "Click the shared wall. Red X means this position is blocked. Esc cancels."
		interior_floor_canvas.grab_focus(), true)
	tools.add_child(interior_connection_add)
	interior_connection_hint = _label("Choose a directly connected neighbouring footprint.", 12, MUTED)
	interior_connection_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(interior_connection_hint)
	interior_connection_list = OptionButton.new()
	interior_connection_list.custom_minimum_size.y = 40
	interior_connection_list.item_selected.connect(func(index):
		interior_floor_canvas.connection_selected_id = str(interior_connection_list.get_item_metadata(index))
		_refresh_connection_actions()
		interior_floor_canvas.queue_redraw())
	tools.add_child(interior_connection_list)
	interior_connection_lock = _action_button("Lock selected door", _toggle_connection_lock, false)
	tools.add_child(interior_connection_lock)
	interior_connection_remove = _action_button("Remove paired door", _remove_connection, false)
	tools.add_child(interior_connection_remove)
	tools = interior_tools_navigation.add_page("entrances", "Outside entry", "Set indoor arrival")
	tools.add_child(_settings_group_heading("Connect an entrance", "Choose an exterior entrance, then click a clear point inside the ground floor where the player will arrive later."))
	interior_entrance_option = OptionButton.new()
	interior_entrance_option.custom_minimum_size.y = 40
	tools.add_child(interior_entrance_option)
	interior_place_entry_button = _action_button("Place selected entry point", _begin_interior_entry_placement, true)
	tools.add_child(interior_place_entry_button)
	tools = interior_tools_navigation.add_page("walls", "Walls", "Draw or move walls")
	tools.add_child(_settings_group_heading("Draw walls and name rooms", "Drag to draw a wall. Select/drag existing walls to move them or drag their end handles to connect them. A green ring shows a snapped joint."))
	interior_draw_wall_button = _action_button("Draw a new internal wall", _begin_interior_wall_placement, true)
	tools.add_child(interior_draw_wall_button)
	tools.add_child(_action_button("Select / drag existing walls", func(): interior_floor_canvas.begin_wall_editing(), false))
	interior_wall_option = OptionButton.new()
	interior_wall_option.custom_minimum_size.y = 40
	interior_wall_option.item_selected.connect(func(_index): _refresh_interior_wall_doors())
	interior_wall_option.item_selected.connect(func(index):
		interior_floor_canvas.begin_wall_editing()
		interior_floor_canvas.select_wall(str(interior_wall_option.get_item_metadata(index)))
	)
	tools.add_child(interior_wall_option)
	interior_remove_wall_button = _action_button("Remove selected wall", _remove_selected_interior_wall, false)
	tools.add_child(interior_remove_wall_button)
	tools = interior_tools_navigation.add_page("doors", "Doors", "Place or lock doorways")
	var door_width_row := HBoxContainer.new()
	var door_width_label := _label("Doorway width", 12, TEXT)
	door_width_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	door_width_row.add_child(door_width_label)
	interior_door_width_control = SpinBox.new()
	interior_door_width_control.min_value = 0.7
	interior_door_width_control.max_value = 3.0
	interior_door_width_control.step = 0.05
	interior_door_width_control.value = 0.9
	interior_door_width_control.suffix = " m"
	interior_door_width_control.custom_minimum_size.x = 120
	door_width_row.add_child(interior_door_width_control)
	tools.add_child(door_width_row)
	interior_add_door_button = _action_button("Add doorway — click any wall", _begin_interior_wall_door_placement, true)
	tools.add_child(interior_add_door_button)
	interior_door_option = OptionButton.new()
	interior_door_option.custom_minimum_size.y = 40
	interior_door_option.item_selected.connect(func(_index): _refresh_interior_door_lock_button())
	tools.add_child(interior_door_option)
	interior_lock_door_button = _action_button("Lock selected doorway", _toggle_selected_interior_wall_door_lock, false)
	tools.add_child(interior_lock_door_button)
	interior_remove_door_button = _action_button("Remove selected doorway", _remove_selected_interior_wall_door, false)
	tools.add_child(interior_remove_door_button)
	tools = interior_tools_navigation.add_page("rooms", "Room names", "Name rooms")
	interior_room_name_edit = LineEdit.new()
	interior_room_name_edit.placeholder_text = "Room name, for example Bedroom"
	interior_room_name_edit.max_length = 60
	tools.add_child(interior_room_name_edit)
	interior_add_room_button = _action_button("Place room name", _begin_interior_room_label_placement, true)
	tools.add_child(interior_add_room_button)
	interior_room_option = OptionButton.new()
	interior_room_option.custom_minimum_size.y = 40
	tools.add_child(interior_room_option)
	interior_remove_room_button = _action_button("Remove selected room name", _remove_selected_interior_room_label, false)
	tools.add_child(interior_remove_room_button)
	tools = interior_tools_navigation.add_page("flooring", "Floor paint", "Brush or room fill")
	tools.add_child(_settings_group_heading("Paint the floor", "Choose a floor texture. Hold the left mouse button and drag to paint, or hold Shift and click to fill the entire enclosed room."))
	interior_floor_material_option = OptionButton.new()
	interior_floor_material_option.add_theme_constant_override("icon_max_width", 48)
	interior_floor_material_option.custom_minimum_size.y = 52
	interior_floor_material_option.get_popup().add_theme_constant_override("icon_max_width", 64)
	tools.add_child(interior_floor_material_option)
	_populate_interior_floor_material_options()
	interior_paint_floor_button = _action_button("Paint selected floor texture", _begin_interior_floor_painting, true)
	tools.add_child(interior_paint_floor_button)
	var floor_paint_note := _label("Plain floor / eraser restores the original floor. Painting changes appearance only and never adds collision.", 11, MUTED)
	floor_paint_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(floor_paint_note)
	tools = interior_tools_navigation.add_page("floor_upload", "Upload floor", "Add your floor texture")
	interior_floor_material_name_edit = LineEdit.new()
	interior_floor_material_name_edit.placeholder_text = "Custom floor name, for example Honey pine"
	interior_floor_material_name_edit.max_length = 80
	tools.add_child(interior_floor_material_name_edit)
	interior_import_floor_material_button = _action_button("Upload my floor texture…", _choose_interior_floor_material_image, false)
	tools.add_child(interior_import_floor_material_button)
	tools = interior_tools_navigation.add_page("furniture", "Furniture", "Find • place • rotate")
	tools.add_child(_settings_group_heading("Place furniture", "Choose a building category or search by name, then select a metre-scaled item and click a clear point inside the floor."))
	interior_furniture_category_option = OptionButton.new()
	interior_furniture_category_option.custom_minimum_size.y = 40
	_refresh_interior_furniture_category_options()
	interior_furniture_category_option.item_selected.connect(func(_index): _populate_interior_furniture_options())
	tools.add_child(interior_furniture_category_option)
	interior_furniture_search_edit = LineEdit.new()
	interior_furniture_search_edit.placeholder_text = "Search furniture, for example sofa, bed or bar"
	interior_furniture_search_edit.clear_button_enabled = true
	interior_furniture_search_edit.max_length = 80
	interior_furniture_search_edit.text_changed.connect(func(_text): _populate_interior_furniture_options())
	tools.add_child(interior_furniture_search_edit)
	interior_furniture_results_label = _label("", 11, MUTED)
	tools.add_child(interior_furniture_results_label)
	interior_furniture_catalog_option = OptionButton.new()
	interior_furniture_catalog_option.add_theme_constant_override("icon_max_width", 48)
	interior_furniture_catalog_option.custom_minimum_size.y = 52
	interior_furniture_catalog_option.get_popup().add_theme_constant_override("icon_max_width", 64)
	tools.add_child(interior_furniture_catalog_option)
	_populate_interior_furniture_options()
	var furniture_rotation_row := HBoxContainer.new()
	var furniture_rotation_label := _label("Rotation", 12, TEXT)
	furniture_rotation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	furniture_rotation_row.add_child(furniture_rotation_label)
	interior_furniture_rotation_control = SpinBox.new()
	interior_furniture_rotation_control.min_value = 0.0
	interior_furniture_rotation_control.max_value = 359.0
	interior_furniture_rotation_control.step = 1.0
	interior_furniture_rotation_control.suffix = "°"
	interior_furniture_rotation_control.custom_minimum_size.x = 120
	furniture_rotation_row.add_child(interior_furniture_rotation_control)
	interior_furniture_rotation_control.value_changed.connect(func(_degrees: float):
		if is_instance_valid(interior_floor_canvas) and interior_floor_canvas.placing_furniture: _update_furniture_placement_preview())
	tools.add_child(furniture_rotation_row)
	interior_place_furniture_button = _action_button("Place selected furniture", _begin_interior_furniture_placement, true)
	tools.add_child(interior_place_furniture_button)
	interior_placed_furniture_option = OptionButton.new()
	interior_placed_furniture_option.custom_minimum_size.y = 40
	tools.add_child(interior_placed_furniture_option)
	interior_placed_furniture_option.item_selected.connect(func(index: int):
		interior_floor_canvas.selected_furniture_id = str(interior_placed_furniture_option.get_item_metadata(index))
		interior_floor_canvas.queue_redraw())
	var rotation_help := _label("Select a placed item here or click it on the map. Right-click turns it 45°; hold right mouse and drag for finer rotation. While placing an item, the same controls rotate its preview.", 11, MUTED)
	rotation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(rotation_help)
	interior_remove_furniture_button = _action_button("Remove selected furniture", _remove_selected_interior_furniture, false)
	tools.add_child(interior_remove_furniture_button)
	tools = interior_tools_navigation.add_page("uploads", "Upload furniture", "Add your object artwork")
	tools.add_child(_settings_group_heading("Add your own furniture", "Enter what the object is, choose its real size and upload your PNG, JPEG or WebP artwork. Creator Studio copies it into this town and automatically enables collision."))
	interior_custom_name_edit = LineEdit.new()
	interior_custom_name_edit.placeholder_text = "Furniture name, for example Blue armchair"
	interior_custom_name_edit.max_length = 80
	tools.add_child(interior_custom_name_edit)
	interior_custom_type_edit = LineEdit.new()
	interior_custom_type_edit.placeholder_text = "Object type shown in game, for example chair"
	interior_custom_type_edit.max_length = 48
	tools.add_child(interior_custom_type_edit)
	interior_custom_category_option = OptionButton.new()
	interior_custom_category_option.custom_minimum_size.y = 40
	_refresh_custom_furniture_category_options()
	tools.add_child(interior_custom_category_option)
	interior_custom_category_edit = LineEdit.new()
	interior_custom_category_edit.placeholder_text = "Or create a category, for example Medical clinic"
	interior_custom_category_edit.clear_button_enabled = true
	interior_custom_category_edit.max_length = 48
	tools.add_child(interior_custom_category_edit)
	var custom_size_row := HBoxContainer.new()
	custom_size_row.add_child(_label("Width", 11, TEXT))
	interior_custom_width_control = SpinBox.new()
	interior_custom_width_control.min_value = 0.1
	interior_custom_width_control.max_value = 20.0
	interior_custom_width_control.step = 0.05
	interior_custom_width_control.value = 1.0
	interior_custom_width_control.suffix = " m"
	interior_custom_width_control.custom_minimum_size.x = 105
	custom_size_row.add_child(interior_custom_width_control)
	custom_size_row.add_child(_label("Depth", 11, TEXT))
	interior_custom_depth_control = SpinBox.new()
	interior_custom_depth_control.min_value = 0.1
	interior_custom_depth_control.max_value = 20.0
	interior_custom_depth_control.step = 0.05
	interior_custom_depth_control.value = 1.0
	interior_custom_depth_control.suffix = " m"
	interior_custom_depth_control.custom_minimum_size.x = 105
	custom_size_row.add_child(interior_custom_depth_control)
	tools.add_child(custom_size_row)
	interior_import_furniture_button = _action_button("Upload my furniture artwork…", _choose_interior_furniture_image, true)
	tools.add_child(interior_import_furniture_button)
	var collision_note := _label("Collision is always enabled for uploaded furniture and uses the width and depth above.", 11, MUTED)
	collision_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(collision_note)
	tools = interior_tools_navigation.add_page("npcs", "NPC placement", "People • robots • traders")
	tools.add_child(_settings_group_heading("Place interior characters", "Place a generic NPC, NPR robot, storyline NPC or trader on this floor, then Save. Drag existing characters to move them. These placed characters stay at their assigned positions; configure trader stock in NPCs and personas → Trader NPCs."))
	interior_npc_role_option = OptionButton.new()
	interior_npc_role_option.add_item("Storyline NPC")
	interior_npc_role_option.add_item("Trader NPC")
	interior_npc_role_option.add_item("Generic NPC")
	interior_npc_role_option.add_item("NPR robot")
	interior_npc_role_option.item_selected.connect(func(_index): _refresh_interior_npc_personas())
	tools.add_child(interior_npc_role_option)
	interior_npc_name_edit = LineEdit.new()
	interior_npc_name_edit.placeholder_text = "Character name (blank = random)"
	interior_npc_name_edit.max_length = 80
	tools.add_child(interior_npc_name_edit)
	interior_npc_persona_option = OptionButton.new()
	interior_npc_persona_option.add_item("Random compatible NPC persona")
	interior_npc_persona_option.set_item_metadata(0, "")
	var interior_personas := persona_store.load_from_town(loaded_project_directory)
	if interior_personas.ok:
		for entry in interior_personas.data.personas:
			if str(entry.get("actor_kind", "")) != "npc": continue
			interior_npc_persona_option.add_item(str(entry.name))
			interior_npc_persona_option.set_item_metadata(interior_npc_persona_option.item_count - 1, str(entry.id))
	tools.add_child(interior_npc_persona_option)
	tools.add_child(_action_button("Place NPC — click a clear floor position", _begin_interior_npc_placement, true))
	tools = interior_tools_navigation.add_page("location", "Copy location", "Get floor coordinates")
	interior_storyline_location_button = _action_button("Select and copy interior location", _begin_interior_storyline_location, true)
	tools.add_child(interior_storyline_location_button)
	interior_storyline_location_label = _label("No interior storyline location selected.", 11, MUTED)
	interior_storyline_location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(interior_storyline_location_label)
	tools = interior_tools_navigation.add_page("notes", "Location notes", "Upload venue reference text")
	tools.add_child(_settings_group_heading("Location conversation notes", "Upload optional plain text about this building. All its NPCs/NPRs know their venue, and street characters can refer to these notes when asked. Files are loaded at map startup; no LLM is used by the editor."))
	tools.add_child(_action_button("Upload / replace location .txt…", func():
		if location_notes_ready: location_text_dialog.popup_centered_ratio(0.70)
		else: _set_status("Reopen the project after repairing its location notes file."), true))
	tools.add_child(_action_button("Remove this building's reference", _remove_location_notes, false))
	interior_location_notes_label = _label("", 12, MUTED)
	interior_location_notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(interior_location_notes_label)
	interior_location_notes_preview = TextEdit.new()
	interior_location_notes_preview.editable = false
	interior_location_notes_preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	interior_location_notes_preview.custom_minimum_size.y = 220
	tools.add_child(interior_location_notes_preview)
	interior_summary_label = _label("", 12, MUTED)
	interior_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interior_summary_label.max_lines_visible = 3
	tools_root.add_child(interior_summary_label)

	var preview_panel := _panel_container(PANEL, 12)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.clip_contents = true
	split.add_child(preview_panel)
	var preview_group := VBoxContainer.new()
	preview_group.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_group)
	var zoom_row := HBoxContainer.new()
	preview_group.add_child(zoom_row)
	zoom_row.add_child(_action_button("Tools", func(): interior_tools_panel.visible = not interior_tools_panel.visible, false))
	zoom_row.add_child(_action_button("Town / floor", _toggle_interior_map, false))
	var zoom_spacer := Control.new()
	zoom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom_spacer)
	zoom_row.add_child(_action_button("−", func(): _active_interior_canvas().zoom_out(), false))
	zoom_row.add_child(_action_button("Fit", func(): _active_interior_canvas().reset_view(), false))
	zoom_row.add_child(_action_button("+", func(): _active_interior_canvas().zoom_in(), false))
	interior_zoom_label = _label("100%", 12, MUTED)
	interior_zoom_label.custom_minimum_size.x = 58
	interior_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zoom_row.add_child(interior_zoom_label)
	var help := _label("Click and drag furniture or door markers to move them. Select an item, then hold Shift and click for copies. Red X means blocked. Wheel zooms; drag empty floor to pan. Right mouse rotates furniture; Esc finishes placement.", 11, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_group.add_child(help)
	interior_floor_canvas = InteriorFloorCanvasScript.new()
	interior_floor_canvas.set_asset_root(loaded_project_directory)
	interior_floor_canvas.set_floor_materials(interior_floor_material_library.all_definitions(interior_floor_material_data))
	interior_floor_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior_floor_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	interior_floor_canvas.entry_spawn_requested.connect(_on_interior_spawn_requested)
	interior_floor_canvas.stair_point_requested.connect(_on_interior_stair_point)
	interior_floor_canvas.stair_cancelled.connect(_cancel_interior_stairs)
	interior_floor_canvas.stair_move_requested.connect(_on_interior_stair_move)
	interior_floor_canvas.stair_rotation_requested.connect(_on_interior_stair_rotation)
	interior_floor_canvas.stair_validation = _interior_stair_point_valid
	interior_floor_canvas.connection_point_requested.connect(func(point): _place_connection(point))
	interior_floor_canvas.connection_move_requested.connect(func(id, point): _place_connection(point, id))
	interior_floor_canvas.connection_validation = _connection_point_valid
	interior_floor_canvas.connection_selected.connect(func(id):
		for index in interior_connection_list.item_count:
			if str(interior_connection_list.get_item_metadata(index)) == id: interior_connection_list.select(index)
		_refresh_connection_actions())
	interior_floor_canvas.stair_selected.connect(func(id):
		for index in interior_stair_list.item_count:
			if str(interior_stair_list.get_item_metadata(index)) == id: interior_stair_list.select(index)
		interior_stair_rotation.set_value_no_signal(interior_floor_canvas.stair_rotation_degrees))
	interior_floor_canvas.storyline_location_requested.connect(_on_interior_storyline_location_requested)
	interior_floor_canvas.furniture_position_requested.connect(_on_interior_furniture_position_requested)
	interior_floor_canvas.furniture_rotation_requested.connect(_on_interior_furniture_rotation_requested)
	interior_floor_canvas.preview_validation = _interior_object_preview_validation
	interior_floor_canvas.furniture_move_requested.connect(_on_interior_furniture_move_requested)
	interior_floor_canvas.furniture_resize_requested.connect(_on_interior_furniture_resize_requested)
	interior_floor_canvas.npc_move_requested.connect(_on_interior_npc_move_requested)
	interior_floor_canvas.wall_door_move_requested.connect(_on_interior_wall_door_move_requested)
	interior_floor_canvas.wall_door_selected.connect(func(wall_id: String, door_id: String):
		_select_interior_wall_by_id(wall_id)
		_refresh_interior_wall_doors()
		_select_interior_door_by_id(door_id)
		_refresh_interior_door_lock_button())
	interior_floor_canvas.furniture_selected.connect(func(item_id: String):
		for index in interior_placed_furniture_option.item_count:
			if str(interior_placed_furniture_option.get_item_metadata(index)) == item_id: interior_placed_furniture_option.select(index))
	interior_floor_canvas.seat_direction_requested.connect(_on_seat_direction_requested)
	interior_floor_canvas.wall_requested.connect(_on_interior_wall_requested)
	interior_floor_canvas.wall_move_requested.connect(_on_interior_wall_move_requested)
	interior_floor_canvas.wall_selected.connect(func(wall_id): _select_interior_wall_by_id(wall_id); _refresh_interior_wall_doors())
	interior_floor_canvas.wall_door_requested.connect(_on_interior_wall_door_requested)
	interior_floor_canvas.room_label_requested.connect(_on_interior_room_label_requested)
	interior_floor_canvas.floor_paint_requested.connect(_on_interior_floor_paint_requested)
	interior_floor_canvas.view_changed.connect(func(zoom: float): interior_zoom_label.text = "%d%%" % roundi(zoom * 100.0))
	preview_group.add_child(interior_floor_canvas)
	interior_building_map = TownMapCanvasScript.new()
	interior_building_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior_building_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var effective_map := imported_town.duplicate(false)
	effective_map["features"] = interior_connection_features
	interior_building_map.set_map_data(effective_map)
	interior_building_map.set_building_exterior_data(interior_exterior_data, loaded_project_directory)
	interior_building_map.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
	interior_building_map.building_selected.connect(func(feature):
		for index in interior_eligible_features.size():
			if str(interior_eligible_features[index].id) == str(feature.id):
				interior_building_option.select(index)
				_on_interior_building_selected(index)
				break)
	preview_group.add_child(interior_building_map)
	interior_building_map.custom_minimum_size = Vector2(280, 180)
	interior_building_map.hide()
	interior_tools_navigation.page_changed.connect(func(_page):
		interior_floor_canvas.seat_direction_edit_enabled=str(_page)=="seat_direction"
		interior_floor_canvas.seat_direction_gesture.clear()
		interior_floor_canvas.queue_redraw()
		help.text = {"flooring": "Choose a texture. Hold left mouse to paint; Shift-click fills the room. Wheel zooms; middle-drag pans.", "stairs": "Click stairs; hold right mouse and drag to rotate. Release applies; red X means blocked. Right-click turns 90°; E uses them in play.", "connections": "Select a neighbouring building, then click its shared wall. Drag a green/red connecting-door marker to move it.", "walls": "Click two points to draw a wall. Drag endpoints to snap them to other walls or the building boundary.", "doors": "Click a wall to add a doorway. Drag door markers to move them. Red means locked.", "furniture": "Select an object; drag green corners to resize. Drag its body to move; right-click turns; Shift copies."}.get(str(_page), "Wheel or +/− zooms. Drag empty floor to pan. Use Tools to hide the controls and enlarge the map.")
		interior_npc_place_active = false
		_cancel_interior_stairs()
		interior_floor_canvas.stair_edit_enabled = str(_page) == "stairs"
		interior_floor_canvas.set_connections(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), str(_page) == "connections")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		interior_floor_canvas._handle_object_input(escape))
	var initial_index := 0
	for index in interior_eligible_features.size():
		if interior_data.buildings.has(str(interior_eligible_features[index].id)):
			initial_index=index
			break
	interior_building_option.select(initial_index)
	_on_interior_building_selected(initial_index)
	interior_tools_navigation._bound_form(tools_root)

func _on_seat_direction_requested(item_id: String, degrees: float) -> void:
	var result := SeatOrientation.set_direction(interior_data,str(interior_selected_feature.get("id","")),_selected_interior_floor_id(),item_id,degrees)
	if not result.ok: _set_status(result.message); return
	interior_data=result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	interior_floor_canvas.selected_furniture_id=item_id
	_queue_section_history()
	_set_status("Seating direction set. Save, then E to sit/stand in Play test. Automatic NPC seating is later.")

func _active_interior_canvas() -> Control:
	return interior_building_map if interior_building_map.visible else interior_floor_canvas

func _show_interior_building_map() -> void:
	_cancel_interior_stairs()
	interior_floor_canvas.cancel_selection()
	interior_building_map.show()
	interior_floor_canvas.hide()
	_set_status("Click any active building footprint. Create interior is above the tool buttons.")

func _toggle_interior_map() -> void:
	if interior_building_map.visible and not _selected_interior_floor_id().is_empty():
		interior_building_map.hide()
		interior_floor_canvas.show()
	else: _show_interior_building_map()


func _on_interior_building_selected(index: int) -> void:
	_cancel_interior_stairs()
	if index < 0 or index >= interior_eligible_features.size():
		interior_selected_feature = {}
		return
	interior_selected_feature = interior_eligible_features[index].duplicate(true)
	_refresh_interior_designer_controls()
	_refresh_location_notes_controls()

func _refresh_interior_npc_personas() -> void:
	var actor_kind := "npr" if interior_npc_role_option.selected == 3 else "npc"
	interior_npc_persona_option.clear()
	interior_npc_persona_option.add_item("Random compatible %s persona" % actor_kind.to_upper())
	interior_npc_persona_option.set_item_metadata(0, "")
	var library := persona_store.load_from_town(loaded_project_directory)
	if not library.ok: return
	for entry in library.data.personas:
		if str(entry.get("actor_kind", "")) != actor_kind: continue
		interior_npc_persona_option.add_item(str(entry.name))
		interior_npc_persona_option.set_item_metadata(interior_npc_persona_option.item_count - 1, str(entry.id))

func _refresh_location_notes_controls() -> void:
	if not is_instance_valid(interior_location_notes_label) or interior_selected_feature.is_empty(): return
	var id := str(interior_selected_feature.id)
	var entry: Dictionary = location_notes_data.get("locations", {}).get(id, {})
	interior_location_notes_label.text = "Optional reference: " + str(entry.get("original_filename", "none")) + " · loaded at game startup"
	interior_location_notes_preview.text = str(location_note_texts.get(id, ""))

func _on_location_text_selected(path: String) -> void:
	if not location_notes_ready or interior_selected_feature.is_empty(): return
	var id := str(interior_selected_feature.id)
	var name := str(interior_data.get("buildings", {}).get(id, {}).get("name", "Building " + id))
	var result := LocationNotesScript.new().import_text(loaded_project_directory, path, id, name, location_notes_data)
	if not result.ok: _set_status(result.message); return
	location_notes_data = result.data
	location_note_texts[id] = result.text
	_refresh_location_notes_controls()
	_set_status(result.message)

func _remove_location_notes() -> void:
	if not location_notes_ready or interior_selected_feature.is_empty(): return
	var id := str(interior_selected_feature.id)
	var edited := location_notes_data.duplicate(true)
	edited.locations.erase(id)
	var result := LocationNotesScript.new().save_to_town(loaded_project_directory, edited)
	if not result.ok: _set_status(result.message); return
	location_notes_data = edited
	location_note_texts.erase(id)
	_refresh_location_notes_controls()
	_set_status("Reference detached. Its copied text stays recoverable in the town folder; reopen Play test.")


func _create_blank_interior_floor() -> void:
	if interior_selected_feature.is_empty():
		return
	var result := building_interior_store.create_blank_ground_floor(interior_data, interior_selected_feature)
	if not result.ok:
		_show_message("Could not create ground floor", result.message)
		return
	interior_data = result.data
	var id := str(interior_selected_feature.id)
	interior_data.buildings[id].name = str(interior_exterior_data.get("buildings", {}).get(id, {}).get("custom_name", result.record.name))
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
	var requested := _selected_interior_floor_id()
	_cancel_interior_stairs()
	_refresh_interior_designer_controls(requested)


func _interior_stair_point_valid(point: Vector2, ignored_id := "", degrees: Variant = null) -> bool:
	var record: Dictionary = interior_data.get("buildings", {}).get(str(interior_selected_feature.get("id", "")), {})
	var floor_id := _selected_interior_floor_id()
	var floor: Dictionary = BuildingInteriorStoreScript.floor_by_id(record, floor_id)
	var angle: float = float(degrees) if degrees != null else interior_floor_canvas.stair_rotation_degrees
	if not InteriorStairsScript.fits(floor, point, InteriorStairsScript.endpoints(record, floor_id), ignored_id, angle): return false
	for npc in storyline_npc_data.get("npcs", []):
		var location: Dictionary = npc.get("location", {})
		if str(location.get("space", "")) != "interior" or str(location.get("building_id", "")) != str(interior_selected_feature.id) or str(location.get("floor_id", "")) != floor_id: continue
		var npc_point := Vector2(float(location.get("x_metres", -INF)), float(location.get("y_metres", -INF)))
		if InteriorStairsScript.overlaps(InteriorStairsScript.rectangle(point, InteriorStairsScript.CLEAR_SIZE, angle), InteriorStairsScript.rectangle(npc_point, Vector2.ONE * 0.8)): return false
	for arrival in interior_floor_canvas.connection_endpoints:
		if InteriorStairsScript.overlaps(InteriorStairsScript.rectangle(point, InteriorStairsScript.CLEAR_SIZE, angle), InteriorStairsScript.rectangle(BuildingConnections.position(arrival), Vector2.ONE * 1.2)): return false
	return true


func _begin_interior_stairs() -> void:
	if interior_stair_target.item_count == 0: return
	var target := str(interior_stair_target.get_item_metadata(interior_stair_target.selected))
	_cancel_interior_stairs()
	interior_stair_pending = {"from_floor": _selected_interior_floor_id(), "to_floor": target}
	interior_floor_canvas.stair_rotation_degrees = interior_stair_rotation.value
	interior_floor_canvas.placing_stair = true
	interior_floor_canvas.stair_preview = Vector2.INF
	interior_floor_canvas.set_edit_feedback(true, Vector2.ZERO)
	_set_stair_instruction("1 / 2 — Click a clear stair point on %s." % interior_floor_option.get_item_text(interior_floor_option.selected))
	interior_floor_canvas.grab_focus()


func _cancel_interior_stairs() -> void:
	var original: Dictionary = interior_stair_pending.get("original_data", {})
	var source := str(interior_stair_pending.get("from_floor", ""))
	if not original.is_empty(): interior_data = original
	interior_stair_pending.clear()
	if is_instance_valid(interior_floor_canvas):
		interior_floor_canvas.placing_stair = false
		interior_floor_canvas.stair_preview = Vector2.INF
		interior_floor_canvas.stair_drag.clear()
		interior_floor_canvas.stair_rotation_gesture.clear()
		interior_floor_canvas.queue_redraw()
	if is_instance_valid(interior_stair_hint): interior_stair_hint.text = "Choose a destination and place both points. Drag stairs to move them."
	if not original.is_empty(): _refresh_interior_designer_controls(source)


func _set_stair_instruction(message: String) -> void:
	interior_stair_hint.text = message
	# The summary is outside the scrolling tool page, so placement feedback
	# stays visible even on smaller windows.
	interior_summary_label.text = message


func _on_interior_stair_point(point: Vector2) -> void:
	if interior_stair_pending.is_empty(): return
	if not _interior_stair_point_valid(point):
		interior_floor_canvas.set_edit_feedback(false, point)
		_set_stair_instruction("Blocked — keep the stair platform and landing clear. Try another point.")
		return
	if not interior_stair_pending.has("from_position"):
		if str(interior_stair_pending.to_floor) == "__new_upper_floor":
			var added: Dictionary = building_interior_store.add_upper_floor(interior_data, str(interior_selected_feature.id))
			if not added.ok:
				_set_stair_instruction(added.message)
				return
			# Preview the new floor, but retain the original until both points succeed.
			interior_stair_pending["original_data"] = interior_data.duplicate(true)
			interior_stair_pending["to_floor"] = str(added.floor_id)
			interior_data = added.data
		interior_stair_pending["from_position"] = point
		interior_stair_pending["from_rotation"] = interior_floor_canvas.stair_rotation_degrees
		_refresh_interior_designer_controls(str(interior_stair_pending.to_floor))
		interior_floor_canvas.placing_stair = true
		if interior_stair_auto.button_pressed:
			if _interior_stair_point_valid(point):
				_on_interior_stair_point(point)
				return
			_set_stair_instruction("Matching point is blocked on destination floor. Click a clear point here, or Cancel.")
			return
		_set_stair_instruction("2 / 2 — Now click the matching stair point on %s." % interior_floor_option.get_item_text(interior_floor_option.selected))
		return
	var result: Dictionary = building_interior_store.add_stair_pair(interior_data, str(interior_selected_feature.id), str(interior_stair_pending.from_floor), Vector2(interior_stair_pending.from_position), str(interior_stair_pending.to_floor), point, float(interior_stair_pending.get("from_rotation", 0)), interior_floor_canvas.stair_rotation_degrees)
	if not result.ok:
		interior_floor_canvas.set_edit_feedback(false, point)
		_set_stair_instruction(result.message)
		return
	interior_data = result.data
	if interior_stair_pending.has("original_data"):
		var id := str(interior_selected_feature.id)
		var count: int = interior_data.buildings[id].floors.size()
		interior_stair_floor_counts[id] = count
		interior_exterior_data = BuildingHeightProfile.ensure_minimum_floors(interior_exterior_data, interior_selected_feature, count).data
		result.message += " New upper floor created; exterior count raised if needed. Save to keep both."
	interior_stair_pending.clear()
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	interior_floor_canvas.set_edit_feedback(true, point)
	_set_stair_instruction(result.message)
	interior_floor_canvas.stair_selected_id = str(result.stair_id)
	_set_status(result.message)


func _on_interior_stair_move(id: String, side: String, point: Vector2) -> void:
	var angle := 0.0
	for endpoint in interior_floor_canvas.stair_endpoints:
		if str(endpoint.id) == id: angle = InteriorStairsScript.rotation(endpoint)
	if not _interior_stair_point_valid(point, id, angle):
		interior_floor_canvas.set_edit_feedback(false, point)
		_set_stair_instruction("Blocked — keep the stairs clear of walls, items, NPCs and entrances.")
		return
	var result: Dictionary = building_interior_store.move_stair_endpoint(interior_data, str(interior_selected_feature.id), id, side, point)
	if result.ok:
		interior_data = result.data
		_refresh_interior_designer_controls(_selected_interior_floor_id())
	interior_floor_canvas.set_edit_feedback(bool(result.ok), point)
	_set_stair_instruction(result.message)
	_set_status(result.message)

func _set_interior_stair_rotation(value: float) -> void:
	if not is_instance_valid(interior_floor_canvas): return
	var delta := wrapf(value - interior_floor_canvas.stair_rotation_degrees, -180, 180)
	var side := ""
	for endpoint in interior_floor_canvas.stair_endpoints:
		if str(endpoint.id) == interior_floor_canvas.stair_selected_id: side = str(endpoint.side)
	_on_interior_stair_rotation("" if interior_floor_canvas.placing_stair else interior_floor_canvas.stair_selected_id, side, delta)

func _on_interior_stair_rotation(id: String, side: String, change: float) -> void:
	if id.is_empty() or side.is_empty():
		interior_floor_canvas.stair_rotation_degrees = wrapf(interior_floor_canvas.stair_rotation_degrees + change, 0, 360)
	else:
		for endpoint in interior_floor_canvas.stair_endpoints:
			if str(endpoint.id) != id or str(endpoint.side) != side: continue
			var angle := wrapf(InteriorStairsScript.rotation(endpoint) + change, 0, 360)
			var point := InteriorStairsScript.position(endpoint)
			if not _interior_stair_point_valid(point, id, angle):
				interior_floor_canvas.set_edit_feedback(false, point)
				_set_stair_instruction("Rotation blocked; keep the full landing clear.")
				return
			var result: Dictionary = building_interior_store.move_stair_endpoint(interior_data, str(interior_selected_feature.id), id, side, point, angle)
			if result.ok:
				interior_data = result.data
				_refresh_interior_designer_controls()
				interior_floor_canvas.stair_rotation_degrees = angle
			else: _set_stair_instruction(result.message)
	interior_stair_rotation.set_value_no_signal(interior_floor_canvas.stair_rotation_degrees)
	interior_floor_canvas.queue_redraw()


func _remove_interior_stairs() -> void:
	if interior_stair_list.item_count == 0: return
	var result: Dictionary = building_interior_store.remove_stair_pair(interior_data, str(interior_selected_feature.id), str(interior_stair_list.get_item_metadata(interior_stair_list.selected)))
	if result.ok:
		interior_data = result.data
		_refresh_interior_designer_controls(_selected_interior_floor_id())
		_set_stair_instruction(result.message)


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


func _begin_interior_wall_placement() -> void:
	if interior_selected_feature.is_empty() or interior_floor_option.item_count == 0: return
	interior_floor_canvas.begin_wall_placement()
	_set_status("Interior Designer: drag to draw, or click both ends. Follow the green snap ring to connect walls; right-click cancels.")


func _on_interior_wall_requested(start_metres: Vector2, end_metres: Vector2) -> void:
	var result := building_interior_store.add_wall(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), start_metres, end_metres, interior_floor_canvas.wall_snap_distance(), true)
	if not result.ok:
		_show_message("Could not add internal wall", result.message)
		interior_floor_canvas.begin_wall_placement()
		return
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_select_interior_wall_by_id(str(result.wall_id))
	interior_floor_canvas.begin_wall_placement()
	_set_status(result.message)


func _on_interior_wall_move_requested(wall_id: String, start_metres: Vector2, end_metres: Vector2) -> void:
	var result := building_interior_store.move_wall(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), wall_id, start_metres, end_metres, interior_floor_canvas.wall_snap_distance(), true)
	if not result.ok:
		_show_message("Wall left in its original position", result.message)
		return
	# Refuse a move that would put a saved storyline character inside a wall.
	for npc in storyline_npc_data.get("npcs", []):
		var location: Dictionary = npc.get("location", {})
		if str(location.get("space", "")) != "interior": continue
		if str(location.get("building_id", "")) != str(interior_selected_feature.get("id", "")) or str(location.get("floor_id", "")) != _selected_interior_floor_id(): continue
		var validation := building_interior_store.validate_location(result.data, location)
		if not validation.ok:
			_show_message("Wall left in its original position", "This move would block a saved storyline NPC location. Move the character first.")
			return
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_select_interior_wall_by_id(wall_id)
	_refresh_interior_wall_doors()
	_set_status(result.message)


func _remove_selected_interior_wall() -> void:
	if interior_wall_option.item_count == 0 or interior_wall_option.selected < 0: return
	var result := building_interior_store.remove_wall(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), str(interior_wall_option.get_item_metadata(interior_wall_option.selected)))
	if not result.ok:
		_show_message("Could not remove internal wall", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_set_status(result.message)


func _begin_interior_wall_door_placement() -> void:
	if interior_wall_option.item_count == 0 or interior_wall_option.selected < 0: return
	var wall_id := str(interior_wall_option.get_item_metadata(interior_wall_option.selected))
	interior_floor_canvas.begin_wall_door_placement(wall_id)
	_set_status("Interior Designer: click any visible internal wall where the doorway should open.")


func _on_interior_wall_door_requested(wall_id: String, position_metres: Vector2) -> void:
	var result := building_interior_store.add_wall_door(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), wall_id, position_metres, interior_door_width_control.value)
	if not _finish_interior_object_edit(result, position_metres): return
	_select_interior_wall_by_id(str(result.get("wall_id", "")))
	_refresh_interior_wall_doors()
	_select_interior_door_by_id(str(result.get("door_id", "")))
	interior_floor_canvas.selected_door_id = str(result.get("door_id", ""))


func _toggle_selected_interior_wall_door_lock() -> void:
	if interior_wall_option.item_count == 0 or interior_door_option.item_count == 0: return
	var wall_id := str(interior_wall_option.get_item_metadata(interior_wall_option.selected))
	var door_id := str(interior_door_option.get_item_metadata(interior_door_option.selected))
	var currently_locked := _selected_interior_door_locked(wall_id, door_id)
	var result := building_interior_store.set_wall_door_locked(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), wall_id, door_id, not currently_locked)
	if not result.ok:
		_show_message("Could not change doorway lock", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_select_interior_wall_by_id(wall_id)
	_refresh_interior_wall_doors()
	_select_interior_door_by_id(door_id)
	_refresh_interior_door_lock_button()
	_set_status(result.message)


func _remove_selected_interior_wall_door() -> void:
	if interior_wall_option.item_count == 0 or interior_door_option.item_count == 0: return
	var result := building_interior_store.remove_wall_door(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), str(interior_wall_option.get_item_metadata(interior_wall_option.selected)), str(interior_door_option.get_item_metadata(interior_door_option.selected)))
	if not result.ok:
		_show_message("Could not remove doorway", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_set_status(result.message)


func _begin_interior_room_label_placement() -> void:
	if interior_room_name_edit.text.strip_edges().is_empty():
		_show_message("Name the room first", "Enter a room name such as Bedroom, Kitchen or Office, then select Place room name.")
		return
	interior_floor_canvas.begin_room_label_placement()
	_set_status("Interior Designer: click inside the room to place its name.")


func _on_interior_room_label_requested(position_metres: Vector2) -> void:
	var result := building_interior_store.add_room_label(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), interior_room_name_edit.text, position_metres)
	if not result.ok:
		_show_message("Could not name room", result.message)
		return
	interior_data = result.data
	interior_room_name_edit.clear()
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_set_status(result.message)


func _remove_selected_interior_room_label() -> void:
	if interior_room_option.item_count == 0 or interior_room_option.selected < 0: return
	var result := building_interior_store.remove_room_label(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), str(interior_room_option.get_item_metadata(interior_room_option.selected)))
	if not result.ok:
		_show_message("Could not remove room name", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_set_status(result.message)


func _populate_interior_floor_material_options(preferred_id := "") -> void:
	if interior_floor_material_option == null: return
	if preferred_id.is_empty() and interior_floor_material_option.item_count > 0 and interior_floor_material_option.selected >= 0:
		preferred_id = str(interior_floor_material_option.get_item_metadata(interior_floor_material_option.selected))
	interior_floor_material_option.clear()
	var definitions := interior_floor_material_library.all_definitions(interior_floor_material_data)
	for definition_value in definitions:
		if not definition_value is Dictionary: continue
		var definition: Dictionary = definition_value
		var icon := _interior_floor_material_option_icon(definition)
		interior_floor_material_option.add_icon_item(icon, "%s · %s" % [str(definition.get("category", "Floor")), str(definition.get("name", "Floor texture"))])
		var index := interior_floor_material_option.item_count - 1
		interior_floor_material_option.set_item_metadata(index, str(definition.get("id", "")))
		if str(definition.get("id", "")) == preferred_id: interior_floor_material_option.select(index)
	interior_floor_material_option.disabled = interior_floor_material_option.item_count == 0


func _interior_floor_material_option_icon(definition: Dictionary) -> Texture2D:
	var relative_path := str(definition.get("image_path", "")).replace("\\", "/")
	if not relative_path.is_empty() and not relative_path.begins_with("res://") and not relative_path.contains("..") and not relative_path.is_absolute_path():
		var image := Image.new()
		if image.load(loaded_project_directory.path_join(relative_path)) == OK and not image.is_empty():
			image.resize(64, 40, Image.INTERPOLATE_LANCZOS)
			return ImageTexture.create_from_image(image)
	return InteriorFloorMaterialCatalogScript.thumbnail_texture(definition)


func _begin_interior_floor_painting() -> void:
	if interior_selected_feature.is_empty() or interior_floor_option.item_count == 0 or interior_floor_material_option.item_count == 0: return
	interior_floor_canvas.begin_floor_painting()
	_set_status("Interior Designer: hold left mouse and drag to paint, or Shift-click to fill the enclosed room.")


func _on_interior_floor_paint_requested(points_metres: Array, fill_room: bool) -> void:
	if interior_floor_material_option.item_count == 0 or interior_floor_material_option.selected < 0: return
	var material_id := str(interior_floor_material_option.get_item_metadata(interior_floor_material_option.selected))
	var result := building_interior_store.paint_flooring(
		interior_data,
		str(interior_selected_feature.get("id", "")),
		_selected_interior_floor_id(),
		material_id,
		points_metres,
		fill_room
	)
	if not result.ok:
		_show_message("Could not paint the floor", result.message)
		return
	interior_data = result.data
	interior_floor_canvas.update_floor_data(result.floor)
	_set_status(result.message)


func _choose_interior_floor_material_image() -> void:
	if interior_floor_material_name_edit.text.strip_edges().is_empty():
		_show_message("Name the floor texture first", "Enter a simple name such as Honey pine before choosing the picture.")
		return
	interior_floor_material_image_dialog.popup_centered_ratio(0.72)


func _on_interior_floor_material_image_selected(path_value: String) -> void:
	var result := interior_floor_material_library.import_creation(
		loaded_project_directory,
		interior_floor_material_data,
		path_value,
		interior_floor_material_name_edit.text
	)
	if not result.ok:
		_show_message("Could not add floor texture", result.message)
		return
	interior_floor_material_data = result.data
	var new_id := str(result.definition.get("id", ""))
	_populate_interior_floor_material_options(new_id)
	interior_floor_material_name_edit.clear()
	interior_floor_canvas.set_asset_root(loaded_project_directory)
	interior_floor_canvas.set_floor_materials(interior_floor_material_library.all_definitions(interior_floor_material_data))
	_show_message("Floor texture added", "%s It is now selected and ready to paint." % result.message)
	_set_status(result.message)


func _begin_interior_furniture_placement() -> void:
	if interior_selected_feature.is_empty() or interior_floor_option.item_count == 0 or interior_furniture_catalog_option.item_count == 0:
		return
	interior_floor_canvas.begin_furniture_placement()
	_update_furniture_placement_preview()
	_set_status("Interior Designer: click a clear point to place the selected furniture.")


func _populate_interior_furniture_options(preferred_id := "") -> void:
	if interior_furniture_catalog_option == null: return
	if preferred_id.is_empty() and interior_furniture_catalog_option.item_count > 0 and interior_furniture_catalog_option.selected >= 0:
		preferred_id = str(interior_furniture_catalog_option.get_item_metadata(interior_furniture_catalog_option.selected))
	interior_furniture_catalog_option.clear()
	var definitions: Array = interior_furniture_library.all_definitions(interior_custom_catalog_data)
	definitions.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_categories := InteriorFurnitureCatalogScript.usage_categories(first)
		var second_categories := InteriorFurnitureCatalogScript.usage_categories(second)
		var first_primary := str(first_categories[0]) if not first_categories.is_empty() else "Generic business"
		var second_primary := str(second_categories[0]) if not second_categories.is_empty() else "Generic business"
		var category_order := InteriorFurnitureCatalogScript.USAGE_CATEGORIES
		var first_order := category_order.find(first_primary)
		var second_order := category_order.find(second_primary)
		if first_order != second_order: return first_order < second_order
		return str(first.get("name", "")).naturalnocasecmp_to(str(second.get("name", ""))) < 0
	)
	var selected_category := "All items"
	if interior_furniture_category_option != null and interior_furniture_category_option.item_count > 0:
		selected_category = str(interior_furniture_category_option.get_item_metadata(interior_furniture_category_option.selected))
	var search_text := interior_furniture_search_edit.text.strip_edges().to_lower() if interior_furniture_search_edit != null else ""
	for definition_value in definitions:
		var definition: Dictionary = definition_value
		var usage_categories := InteriorFurnitureCatalogScript.usage_categories(definition)
		if selected_category != "All items" and selected_category not in usage_categories:
			continue
		var searchable := "%s %s %s %s %s" % [
			str(definition.get("name", "")), str(definition.get("object_type", "")),
			str(definition.get("category", "")), " ".join(usage_categories), str(definition.get("id", ""))
		]
		if not search_text.is_empty() and not searchable.to_lower().contains(search_text):
			continue
		var size_value: Array = definition.get("size_metres", [1.0, 1.0])
		var primary_usage := str(usage_categories[0]) if not usage_categories.is_empty() else str(definition.get("category", "Furniture"))
		var label := "%s · %s (%.2f × %.2f m)" % [primary_usage, str(definition.get("name", "Furniture")), float(size_value[0]), float(size_value[1])]
		var icon := _interior_furniture_option_icon(definition)
		interior_furniture_catalog_option.add_icon_item(icon, label)
		var item_index := interior_furniture_catalog_option.item_count - 1
		interior_furniture_catalog_option.set_item_metadata(item_index, str(definition.get("id", "")))
		if str(definition.get("id", "")) == preferred_id: interior_furniture_catalog_option.select(item_index)
	interior_furniture_catalog_option.disabled = interior_furniture_catalog_option.item_count == 0
	if interior_furniture_results_label != null:
		interior_furniture_results_label.text = "Showing %d of %d furniture items" % [interior_furniture_catalog_option.item_count, definitions.size()]
	if interior_place_furniture_button != null:
		interior_place_furniture_button.disabled = interior_furniture_catalog_option.item_count == 0 or interior_floor_option == null or interior_floor_option.item_count == 0


func _available_interior_furniture_categories(include_all := true) -> Array[String]:
	var categories: Array[String] = []
	if include_all: categories.append("All items")
	for category_value in InteriorFurnitureCatalogScript.USAGE_CATEGORIES:
		var category := str(category_value)
		if category in ["All items", "My creations"] or category in categories: continue
		categories.append(category)
	var custom_categories: Array[String] = []
	for definition_value in interior_custom_catalog_data.get("items", []):
		if not definition_value is Dictionary: continue
		for category_value in InteriorFurnitureCatalogScript.usage_categories(definition_value):
			var category := str(category_value).strip_edges()
			if category.is_empty() or category in categories or category in custom_categories or category == "My creations": continue
			custom_categories.append(category)
	custom_categories.sort_custom(func(first: String, second: String): return first.naturalnocasecmp_to(second) < 0)
	categories.append_array(custom_categories)
	categories.append("My creations")
	return categories


func _refresh_interior_furniture_category_options(preferred_category := "") -> void:
	if interior_furniture_category_option == null: return
	if preferred_category.is_empty() and interior_furniture_category_option.item_count > 0:
		preferred_category = str(interior_furniture_category_option.get_item_metadata(interior_furniture_category_option.selected))
	interior_furniture_category_option.clear()
	var selected_index := 0
	for category in _available_interior_furniture_categories(true):
		interior_furniture_category_option.add_item(category)
		var index := interior_furniture_category_option.item_count - 1
		interior_furniture_category_option.set_item_metadata(index, category)
		if category == preferred_category: selected_index = index
	interior_furniture_category_option.select(selected_index)


func _refresh_custom_furniture_category_options(preferred_category := "") -> void:
	if interior_custom_category_option == null: return
	if preferred_category.is_empty() and interior_custom_category_option.item_count > 0:
		preferred_category = str(interior_custom_category_option.get_item_metadata(interior_custom_category_option.selected))
	interior_custom_category_option.clear()
	var selected_index := 0
	for category in _available_interior_furniture_categories(false):
		interior_custom_category_option.add_item(category)
		var index := interior_custom_category_option.item_count - 1
		interior_custom_category_option.set_item_metadata(index, category)
		if category == preferred_category: selected_index = index
	interior_custom_category_option.select(selected_index)


func _selected_custom_furniture_category() -> String:
	if interior_custom_category_edit != null and not interior_custom_category_edit.text.strip_edges().is_empty():
		return interior_custom_category_edit.text.strip_edges()
	if interior_custom_category_option != null and interior_custom_category_option.item_count > 0:
		return str(interior_custom_category_option.get_item_metadata(interior_custom_category_option.selected))
	return "My creations"


func _interior_furniture_option_icon(definition: Dictionary) -> Texture2D:
	var relative_path := str(definition.get("image_path", "")).replace("\\", "/")
	if not relative_path.is_empty() and not relative_path.contains("..") and not relative_path.is_absolute_path():
		var image := Image.new()
		if image.load(loaded_project_directory.path_join(relative_path)) == OK and not image.is_empty():
			image.resize(64, 40, Image.INTERPOLATE_LANCZOS)
			return ImageTexture.create_from_image(image)
	return InteriorFurnitureCatalogScript.thumbnail_texture(definition)


func _choose_interior_furniture_image() -> void:
	if interior_custom_name_edit.text.strip_edges().is_empty() or interior_custom_type_edit.text.strip_edges().is_empty():
		_show_message("Describe your furniture first", "Enter a furniture name and an object type before choosing the picture. The object type is what the player will identify in game, such as bed, sofa or chair.")
		return
	interior_furniture_image_dialog.popup_centered_ratio(0.72)


func _on_interior_furniture_image_selected(path_value: String) -> void:
	var result := interior_furniture_library.import_creation(
		loaded_project_directory,
		interior_custom_catalog_data,
		path_value,
		interior_custom_name_edit.text,
		interior_custom_type_edit.text,
		interior_custom_width_control.value,
		interior_custom_depth_control.value,
		_selected_custom_furniture_category()
	)
	if not result.ok:
		_show_message("Could not add furniture", result.message)
		return
	interior_custom_catalog_data = result.data
	var new_id := str(result.definition.get("id", ""))
	var selected_category := str(InteriorFurnitureCatalogScript.usage_categories(result.definition)[0])
	# Make the newly imported item immediately visible even if the creator was
	# previously looking at a different category or a narrow search result.
	_refresh_interior_furniture_category_options(selected_category)
	_refresh_custom_furniture_category_options(selected_category)
	if interior_furniture_search_edit != null: interior_furniture_search_edit.clear()
	_populate_interior_furniture_options(new_id)
	interior_custom_name_edit.clear()
	interior_custom_type_edit.clear()
	interior_custom_category_edit.clear()
	interior_floor_canvas.set_asset_root(loaded_project_directory)
	_show_message("Furniture added", "%s It is now selected in the illustrated furniture list and will automatically block the player when placed." % result.message)
	_set_status(result.message)


func _update_furniture_placement_preview() -> void:
	if interior_furniture_catalog_option.item_count == 0: return
	var catalog_id := str(interior_furniture_catalog_option.get_item_metadata(interior_furniture_catalog_option.selected))
	var definition := interior_furniture_library.definition(interior_custom_catalog_data, catalog_id)
	interior_floor_canvas.furniture_preview = {
		"catalog_id": catalog_id, "width_metres": float(definition.size_metres[0]), "depth_metres": float(definition.size_metres[1]),
		"rotation_degrees": interior_furniture_rotation_control.value, "fill": definition.get("fill", "#8a735d"),
		"outline": definition.get("outline", "#41362d"), "image_path": definition.get("image_path", ""), "name": definition.get("name", "Furniture"), "collision": definition.get("collision", true)}
	if interior_floor_canvas.placing_furniture: interior_floor_canvas._update_object_preview()
	interior_floor_canvas.queue_redraw()


func _on_interior_furniture_rotation_requested(item_id: String, change: float) -> void:
	if item_id.is_empty():
		interior_furniture_rotation_control.value = fposmod(interior_furniture_rotation_control.value + change, 360.0)
		_update_furniture_placement_preview()
		return
	var result := building_interior_store.rotate_furniture(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), item_id, change)
	var item_position := Vector2.ZERO
	for item in interior_floor_canvas.floor_data.get("furniture", []):
		if str(item.id) == item_id: item_position = Vector2(float(item.x_metres), float(item.y_metres))
	if result.ok:
		for npc in interior_floor_canvas.interior_npcs:
			if not building_interior_store.validate_location(result.data, npc.location).ok:
				result = {"ok": false, "message": "That rotation would block a saved NPC."}
				break
	interior_floor_canvas.set_edit_feedback(bool(result.ok), item_position)
	if not result.ok:
		_set_status(result.message)
		return
	interior_data = result.data
	var record: Dictionary = interior_data.buildings[str(interior_selected_feature.id)]
	for floor in record.floors:
		if str(floor.id) == _selected_interior_floor_id(): interior_floor_canvas.update_floor_data(floor)
	for index in interior_placed_furniture_option.item_count:
		if str(interior_placed_furniture_option.get_item_metadata(index)) == item_id:
			for item in interior_floor_canvas.floor_data.get("furniture", []):
				if str(item.id) == item_id: interior_placed_furniture_option.set_item_text(index, "%s · %.1f°" % [str(item.name), float(item.rotation_degrees)])
	_set_status("Item rotated. Save interior layout when ready.")


func _on_interior_furniture_position_requested(position_metres: Vector2) -> void:
	var catalog_id := str(interior_furniture_catalog_option.get_item_metadata(interior_furniture_catalog_option.selected))
	var selected_definition := interior_furniture_library.definition(interior_custom_catalog_data, catalog_id)
	var result := building_interior_store.place_furniture(
		interior_data,
		str(interior_selected_feature.get("id", "")),
		_selected_interior_floor_id(),
		catalog_id,
		position_metres,
		interior_furniture_rotation_control.value,
		selected_definition
	)
	if not _finish_interior_object_edit(result, position_metres): return
	interior_floor_canvas.selected_furniture_id = str(result.furniture_id)
	_select_editor_item("furniture",str(result.furniture_id))
	interior_floor_canvas.object_preview.clear()


func _interior_object_preview_validation(kind: String, position_metres: Vector2, candidate: Dictionary, wall_id: String, door_id: String, ignored_id: String) -> Dictionary:
	var floor: Dictionary = interior_floor_canvas.floor_data
	if kind == "npc":
		var building_id := str(candidate.location.building_id)
		var local_interiors := {"buildings": {building_id: {"feature_id": building_id, "floors": [floor]}}}
		return storyline_npc_store.move_interior_npc({"npcs": interior_floor_canvas.interior_npcs}, str(candidate.id), position_metres, local_interiors)
	if kind == "furniture":
		if float(candidate.get("width_metres",0))<0.11 or float(candidate.get("depth_metres",0))<0.11 or float(candidate.get("width_metres",0))>20 or float(candidate.get("depth_metres",0))>20: return {"ok":false}
		if not building_interior_store._furniture_fits_floor(candidate, floor, ignored_id): return {"ok": false}
		for npc in interior_floor_canvas.interior_npcs:
			var location: Dictionary = npc.location
			if bool(candidate.get("collision", true)) and building_interior_store._point_inside_furniture(Vector2(float(location.x_metres), float(location.y_metres)), candidate, 0.35): return {"ok": false}
		return {"ok": true}
	# Preview only this floor, not an entire town's interiors on every pointer
	# event. Use exactly the same doorway snapping and validation as commit.
	var local_data := {"buildings": {"preview": {"feature_id": "preview", "floors": [floor]}}}
	var floor_id := str(floor.get("id", ""))
	var result: Dictionary = building_interior_store.add_wall_door(local_data, "preview", floor_id, wall_id, position_metres, interior_door_width_control.value) if door_id.is_empty() else building_interior_store.move_wall_door(local_data, "preview", floor_id, wall_id, door_id, position_metres)
	if not result.ok: return {"ok": false, "preview": {"position": position_metres}}
	var edited_floor: Dictionary = result.data.buildings.preview.floors[0]
	for npc in interior_floor_canvas.interior_npcs:
		var location: Dictionary = npc.location.duplicate(true)
		location.building_id = "preview"
		if not building_interior_store.validate_location(result.data, location).ok: return {"ok": false, "preview": {"position": position_metres}}
	for wall in edited_floor.walls:
		if str(wall.id) != str(result.wall_id): continue
		var start := Vector2(float(wall.start_x_metres), float(wall.start_y_metres))
		var finish := Vector2(float(wall.end_x_metres), float(wall.end_y_metres))
		for door in wall.doors:
			if str(door.id) == str(result.door_id): return {"ok": true, "preview": {"position": start + start.direction_to(finish) * float(door.offset_metres), "direction": start.direction_to(finish), "width_metres": float(door.width_metres)}}
	return {"ok": false}


func _finish_interior_object_edit(result: Dictionary, position_metres: Vector2) -> bool:
	if result.ok:
		for npc in interior_floor_canvas.interior_npcs:
			if not building_interior_store.validate_location(result.data, npc.location).ok:
				result = {"ok": false, "message": "This position would block a saved NPC. Choose a clear position."}
				break
	interior_floor_canvas.set_edit_feedback(bool(result.ok), position_metres)
	_set_status(str(result.get("message", "Choose a clear position.")))
	if not result.ok: return false
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	return true


func _on_interior_npc_move_requested(npc_id: String, position_metres: Vector2) -> void:
	var result := storyline_npc_store.move_interior_npc(storyline_npc_data, npc_id, position_metres, interior_data)
	interior_floor_canvas.set_edit_feedback(bool(result.ok), position_metres)
	_set_status(str(result.message))
	if not result.ok: return
	storyline_npc_data = result.data
	interior_floor_canvas.set_interior_npcs(storyline_npc_data.npcs, str(interior_selected_feature.id), _selected_interior_floor_id())


func _on_interior_furniture_move_requested(item_id: String, position_metres: Vector2, duplicate: bool) -> void:
	var rotation_value: float = float(interior_floor_canvas.furniture_preview.get("rotation_degrees", NAN)) if duplicate and interior_floor_canvas.placing_furniture else NAN
	var result := building_interior_store.move_furniture(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), item_id, position_metres, duplicate, rotation_value)
	if not _finish_interior_object_edit(result, position_metres): return
	interior_floor_canvas.selected_furniture_id = str(result.furniture_id)


func _on_interior_furniture_resize_requested(item_id: String, position_metres: Vector2, dimensions: Vector2) -> void:
	var result := building_interior_store.resize_furniture(interior_data,str(interior_selected_feature.id),_selected_interior_floor_id(),item_id,position_metres,dimensions)
	if _finish_interior_object_edit(result,position_metres):
		interior_floor_canvas.selected_furniture_id=item_id
		_queue_section_history()


func _on_interior_wall_door_move_requested(wall_id: String, door_id: String, position_metres: Vector2) -> void:
	var result := building_interior_store.move_wall_door(interior_data, str(interior_selected_feature.get("id", "")), _selected_interior_floor_id(), wall_id, door_id, position_metres)
	if not _finish_interior_object_edit(result, position_metres): return
	_select_interior_wall_by_id(str(result.wall_id))
	_refresh_interior_wall_doors()
	_select_interior_door_by_id(str(result.door_id))
	interior_floor_canvas.selected_wall_id = str(result.wall_id)
	interior_floor_canvas.selected_door_id = str(result.door_id)
	_refresh_interior_door_lock_button()


func _remove_selected_interior_furniture() -> void:
	if interior_placed_furniture_option.item_count == 0 or interior_placed_furniture_option.selected < 0:
		return
	var result := building_interior_store.remove_furniture(
		interior_data,
		str(interior_selected_feature.get("id", "")),
		_selected_interior_floor_id(),
		str(interior_placed_furniture_option.get_item_metadata(interior_placed_furniture_option.selected))
	)
	if not result.ok:
		_show_message("Could not remove furniture", result.message)
		return
	interior_data = result.data
	_refresh_interior_designer_controls(_selected_interior_floor_id())
	_set_status(result.message)


func _begin_interior_storyline_location() -> void:
	interior_npc_place_active = false
	if interior_selected_feature.is_empty() or interior_floor_option.item_count == 0:
		return
	interior_floor_canvas.begin_storyline_location_placement()
	_set_status("Interior Designer: click a clear point inside the selected floor.")


func _begin_interior_npc_placement() -> void:
	if interior_selected_feature.is_empty() or interior_floor_option.item_count == 0: return
	interior_npc_place_active = true
	interior_floor_canvas.begin_storyline_location_placement()
	_set_status("Click a clear point on this floor to place the selected NPC type, then Save.")


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
		interior_floor_canvas.set_edit_feedback(false, position_metres)
		_set_status(validation.message)
		return
	if interior_npc_place_active:
		for npc in storyline_npc_data.get("npcs", []):
			var other: Dictionary = npc.get("location", {})
			if str(other.get("building_id", "")) == str(location.building_id) and str(other.get("floor_id", "")) == str(location.floor_id):
				if Vector2(float(other.get("x_metres", 0)), float(other.get("y_metres", 0))).distance_to(position_metres) < 0.7:
					interior_floor_canvas.set_edit_feedback(false, position_metres)
					_set_status("Leave room between characters.")
					return
		var library := persona_store.load_from_town(loaded_project_directory)
		if not library.ok: _set_status(library.message); return
		var role: String = ["storyline", "trader", "generic", "npr"][interior_npc_role_option.selected]
		var selected_persona := str(interior_npc_persona_option.get_item_metadata(interior_npc_persona_option.selected))
		var added := storyline_npc_store.add_interior_npc(storyline_npc_data, location, _current_town_id(), library.data, interior_npc_name_edit.text, selected_persona, role)
		if not added.ok: _set_status(added.message); return
		storyline_npc_data = added.data
		if role == "trader": interior_trader_data.traders[str(added.npc.id)] = {"enabled": true, "trade_role": "Trader", "persona_id": str(added.npc.persona_id), "offers": []}
		interior_npc_place_active = false
		interior_floor_canvas.placing_storyline_location = false
		interior_floor_canvas.set_interior_npcs(storyline_npc_data.npcs, str(location.building_id), str(location.floor_id))
		interior_floor_canvas.set_edit_feedback(true, position_metres)
		_set_status("%s placed as a %s NPC. Save the interior to keep this character." % [added.npc.display_name, role])
		return
	var copied_text := StorylineNpcStoreScript.format_interior_location(str(location.building_id), str(location.floor_id), Vector2(location.x_metres, location.y_metres))
	DisplayServer.clipboard_set(copied_text)
	interior_storyline_location_label.text = "%s\nCopied. Paste into NPCs and personas → Storyline NPCs or Trader NPCs." % copied_text
	_set_status("Interior storyline location copied to the clipboard.")


func _save_interior_layouts() -> void:
	_run_section_save_transaction("interior", _save_interior_layout_data)


func _save_interior_layout_data() -> void:
	if loaded_project_directory.is_empty():
		return
	# Saving during half-placement cancels the temporary floor, not a full pair.
	_cancel_interior_stairs()
	var exterior_load := building_exterior_store.load_from_town(loaded_project_directory)
	if not exterior_load.ok:
		_show_message("Could not save the interior", exterior_load.message)
		return
	var exterior_to_save: Dictionary = exterior_load.data
	var effective_result := _storyline_effective_features()
	if not effective_result.ok: _set_status(effective_result.message); return
	for feature in effective_result.features:
		var id := str(feature.get("id", ""))
		if not interior_stair_floor_counts.has(id): continue
		var raised: Dictionary = BuildingHeightProfile.ensure_minimum_floors(exterior_to_save, feature, int(interior_stair_floor_counts[id]))
		if not raised.ok:
			_show_message("Could not update exterior height", raised.message)
			return
		exterior_to_save = raised.data
	if not building_exterior_store.validate(exterior_to_save).ok or not building_interior_store.validate(interior_data).ok:
		_show_message("Could not save the interior", "Check the floor and building design data before saving. Neither layout nor height was saved.")
		return
	interior_exterior_data = exterior_to_save
	var connection_features := _storyline_effective_features()
	if not connection_features.ok: _set_status(connection_features.message); return
	var connection_check := BuildingConnections.validate(interior_data, BuildingConnections.with_source_precision(loaded_project_directory, connection_features.features), storyline_npc_data.get("npcs", []))
	if not connection_check.ok:
		_set_status(connection_check.message)
		return
	# Do not save a resized floor that strands an existing storyline character
	# outside its playable boundary. Validate against the edited layout first.
	var persona_load := persona_store.load_from_town(loaded_project_directory)
	if not interior_storyline_ready or not persona_load.ok or not effective_result.ok:
		_show_message("Could not save the interior", "The storyline NPC or persona data could not be loaded safely. Reopen the project and check NPCs and personas before saving.")
		return
	var storyline_validation := StorylineNpcStoreScript.validate(storyline_npc_data, imported_town.get("bounds", {}), effective_result.features, persona_load.data, false, interior_data)
	if not storyline_validation.passed:
		_show_message("Move the storyline NPC first", "%s The interior was not saved." % storyline_validation.errors[0])
		return
	var catalog_result := interior_furniture_library.save_to_town(loaded_project_directory, interior_custom_catalog_data)
	if not catalog_result.ok:
		_show_message("Could not save custom furniture", catalog_result.message)
		return
	interior_custom_catalog_data = catalog_result.data
	var floor_material_result := interior_floor_material_library.save_to_town(loaded_project_directory, interior_floor_material_data)
	if not floor_material_result.ok:
		_show_message("Could not save custom floor textures", floor_material_result.message)
		return
	interior_floor_material_data = floor_material_result.data
	var synchronized := building_interior_store.synchronize_with_exteriors(interior_data, interior_exterior_data, effective_result.features)
	interior_data = synchronized.data
	var result := building_interior_store.save_to_town(loaded_project_directory, interior_data)
	if not result.ok:
		_show_message("Could not save interior", result.message)
		return
	interior_data = result.data
	if not interior_stair_floor_counts.is_empty():
		var exterior_save := building_exterior_store.save_to_town(loaded_project_directory, exterior_to_save)
		if not exterior_save.ok:
			_show_message("Exterior height was not saved", "%s The interior was saved. Keep this section open and retry Save to update the exterior height." % exterior_save.message)
			return
		interior_exterior_data = exterior_save.data
		interior_stair_floor_counts.clear()
	var npc_save := storyline_npc_store.save_to_town(loaded_project_directory, storyline_npc_data, imported_town.get("bounds", {}), effective_result.features, persona_load.data, interior_data)
	if not npc_save.ok:
		_show_message("NPC positions were not saved", "%s The interior layout was saved; keep this section open and retry Save to keep the NPC moves." % str(npc_save.message))
		return
	storyline_npc_data = npc_save.data
	var trader_catalog := ItemCatalogStoreScript.new().load_from_town(loaded_project_directory)
	var trader_save: Dictionary = TraderStoreScript.new().save_to_town(loaded_project_directory, interior_trader_data, storyline_npc_data, trader_catalog.get("data", {}), persona_load.data)
	if not trader_save.ok:
		_set_status("Interior saved, but trader settings need attention: " + str(trader_save.message))
		return
	var notes_save := LocationNotesScript.new().restore_references(loaded_project_directory, location_notes_data, location_note_texts)
	if not notes_save.ok: _set_status(notes_save.message); return
	_refresh_interior_designer_controls()
	var link_note := " One or more older entry links refer to a removed exterior door; select a current entrance and place its arrival point before Play test." if int(synchronized.unresolved_links) > 0 else ""
	_show_message("Interior layout saved", "The floor shapes and textures, internal walls, doorways, room names, furniture and entry links were saved inside this town.%s In Play test, walls and furniture block walking. Stand at a green internal door and press E to enter its room; entering reveals the greyed-out room." % link_note)
	_set_status("Interior layouts and storyline NPC positions saved for %s." % current_town_name)
	_mark_section_saved()


func _connection_destination(id := "") -> Dictionary:
	if not id.is_empty():
		for endpoint in BuildingConnections.endpoints(interior_data, str(interior_selected_feature.id), _selected_interior_floor_id()):
			if str(endpoint.id) == id: return endpoint.destination
	if not is_instance_valid(interior_connection_target) or interior_connection_target.item_count == 0: return {}
	return interior_connection_target.get_item_metadata(interior_connection_target.selected)


func _connection_point_valid(point: Vector2, id := "") -> bool:
	var destination := _connection_destination(id)
	if destination.is_empty() or str(destination.get("floor_id", "")).is_empty(): return false
	return bool(BuildingConnections.propose(interior_data, interior_connection_features, str(interior_selected_feature.id), _selected_interior_floor_id(), str(destination.building_id), str(destination.floor_id), point, id, storyline_npc_data.get("npcs", []), 1.25).ok)


func _place_connection(point: Vector2, id := "") -> void:
	var destination := _connection_destination(id)
	if destination.is_empty(): return
	var result := BuildingConnections.set_door(interior_data, interior_connection_features, str(interior_selected_feature.id), _selected_interior_floor_id(), str(destination.building_id), str(destination.floor_id), point, id, storyline_npc_data.get("npcs", []), 1.25)
	if result.ok:
		interior_data = result.data
		interior_floor_canvas.connection_selected_id = str(result.id)
		_refresh_interior_designer_controls()
	interior_floor_canvas.set_edit_feedback(bool(result.ok), point)
	interior_connection_hint.text = str(result.message)
	_set_status(str(result.message))


func _refresh_interior_connections() -> void:
	var building_id := str(interior_selected_feature.id)
	if not interior_connection_cache.has(building_id):
		var neighbours: Array = []
		for feature in interior_connection_features:
			if str(feature.get("kind", "")) == "building" and not BuildingConnections.shared_segments(interior_selected_feature, feature).is_empty(): neighbours.append(feature)
		interior_connection_cache[building_id] = neighbours
	interior_connection_neighbours = interior_connection_cache[building_id]
	var previous: Dictionary = _connection_destination()
	interior_connection_target.clear()
	var source := BuildingConnections.floor_for(interior_data, building_id, _selected_interior_floor_id())
	for feature in interior_connection_neighbours:
		var id := str(feature.id)
		var record: Dictionary = interior_data.get("buildings", {}).get(id, {})
		var floor_id := ""
		for floor in record.get("floors", []):
			if int(floor.level) == int(source.get("level", -1)): floor_id = str(floor.id); break
		var name := str(interior_exterior_data.get("buildings", {}).get(id, {}).get("custom_name", record.get("name", feature.get("tags", {}).get("name", "Building " + id))))
		# Lead with the stable ID so a narrow control cannot hide the neighbour
		# identifier creators use to distinguish unnamed adjacent buildings.
		interior_connection_target.add_item("ID %s · %s%s" % [id, name, " · create ground floor first" if record.is_empty() else " · matching floor needed" if floor_id.is_empty() else ""])
		interior_connection_target.set_item_metadata(interior_connection_target.item_count - 1, {"building_id": id, "floor_id": floor_id})
		if str(previous.get("building_id", "")) == id: interior_connection_target.select(interior_connection_target.item_count - 1)
	interior_connection_list.clear()
	for endpoint in BuildingConnections.endpoints(interior_data, building_id, _selected_interior_floor_id()):
		interior_connection_list.add_item("To: " + str(endpoint.destination_name) + (" · locked" if bool(endpoint.locked) else ""))
		interior_connection_list.set_item_metadata(interior_connection_list.item_count - 1, str(endpoint.id))
		if str(endpoint.id) == interior_floor_canvas.connection_selected_id: interior_connection_list.select(interior_connection_list.item_count - 1)
	interior_floor_canvas.set_connections(interior_data, building_id, _selected_interior_floor_id(), interior_tools_navigation.current_page == "connections")
	_refresh_connection_actions()
	if interior_connection_neighbours.is_empty():
		interior_connection_hint.text = "No verified shared wall. Only directly touching footprints qualify; hidden buildings are excluded."


func _refresh_connection_actions() -> void:
	var target := _connection_destination()
	interior_connection_add.disabled = target.is_empty() or str(target.get("floor_id", "")).is_empty() or _selected_interior_floor_id().is_empty()
	interior_connection_create.disabled = target.is_empty() or interior_data.get("buildings", {}).has(str(target.get("building_id", "")))
	interior_connection_create.visible = not interior_connection_create.disabled
	interior_connection_remove.disabled = interior_connection_list.item_count == 0
	interior_connection_lock.disabled = interior_connection_list.item_count == 0
	interior_connection_lock.text = "Lock / unlock selected door"


func _create_connection_neighbour() -> void:
	var target := _connection_destination()
	if target.is_empty(): return
	var feature := BuildingConnections.feature_for(interior_connection_features, str(target.building_id))
	var created: Dictionary = building_interior_store.create_blank_ground_floor(interior_data, feature)
	if not created.ok: _set_status(created.message); return
	interior_data = created.data
	interior_data.buildings[str(feature.id)].name = str(interior_exterior_data.get("buildings", {}).get(str(feature.id), {}).get("custom_name", created.record.name))
	if not interior_eligible_features.any(func(value): return str(value.id) == str(feature.id)):
		interior_eligible_features.append(feature)
		interior_building_option.add_item("%s · ID %s" % [interior_data.buildings[str(feature.id)].name, str(feature.id)])
		interior_building_option.set_item_metadata(interior_building_option.item_count - 1, str(feature.id))
	_refresh_interior_designer_controls()
	interior_connection_hint.text = "Neighbour's blank ground floor created. Choose Place connecting door. Save to keep it."


func _remove_connection() -> void:
	if interior_connection_list.item_count == 0: return
	var id := str(interior_connection_list.get_item_metadata(interior_connection_list.selected))
	var pairs: Array = interior_data.get("building_connections", [])
	for index in range(pairs.size() - 1, -1, -1):
		if str(pairs[index].id) == id: pairs.remove_at(index)
	_refresh_interior_designer_controls()
	_set_status("Both connecting door sides removed; Save to keep the change.")


func _toggle_connection_lock() -> void:
	if interior_connection_list.item_count == 0: return
	var id := str(interior_connection_list.get_item_metadata(interior_connection_list.selected))
	for pair in interior_data.get("building_connections", []):
		if str(pair.id) == id: pair.locked = not bool(pair.locked)
	_refresh_interior_designer_controls()
	interior_connection_hint.text = "Door lock changed on both sides. Green is unlocked; red is locked. Save to keep the change."
	_set_status("Connecting door lock changed on both sides; Save before Play test.")


func _refresh_interior_stair_controls(record: Dictionary) -> void:
	var previous := ""
	if interior_stair_list.item_count > 0 and interior_stair_list.selected >= 0:
		previous = str(interior_stair_list.get_item_metadata(interior_stair_list.selected))
	interior_stair_list.clear()
	interior_stair_target.clear()
	var floor_id := _selected_interior_floor_id()
	for floor in record.get("floors", []):
		if str(floor.get("id", "")) == floor_id: continue
		interior_stair_target.add_item("To: %s" % str(floor.get("name", "Floor")))
		interior_stair_target.set_item_metadata(interior_stair_target.item_count - 1, str(floor.id))
	if not record.get("floors", []).is_empty() and record.floors.size() < BuildingInteriorStoreScript.MAX_FLOORS:
		interior_stair_target.add_item("New upper floor (create automatically)")
		interior_stair_target.set_item_metadata(interior_stair_target.item_count - 1, "__new_upper_floor")
	for endpoint in InteriorStairsScript.endpoints(record, floor_id):
		interior_stair_list.add_item("%s → %s" % [str(endpoint.id).replace("_", " ").capitalize(), str(endpoint.get("destination_name", "Floor"))])
		interior_stair_list.set_item_metadata(interior_stair_list.item_count - 1, str(endpoint.id))
		if str(endpoint.id) == previous: interior_stair_list.select(interior_stair_list.item_count - 1)
	interior_stair_add.disabled = interior_stair_target.item_count == 0
	interior_stair_target.disabled = interior_stair_target.item_count == 0
	interior_stair_list.disabled = interior_stair_list.item_count == 0
	interior_stair_remove.disabled = interior_stair_list.item_count == 0
	interior_floor_canvas.set_stairs(record, floor_id, interior_tools_navigation.current_page == "stairs")


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
	interior_create_button.visible = not has_floor
	interior_add_floor_button.disabled = not has_floor or floors.size() >= BuildingInteriorStoreScript.MAX_FLOORS
	interior_floor_option.disabled = not has_floor
	interior_size_control.editable = has_floor
	interior_resize_button.disabled = not has_floor
	interior_size_control.set_value_no_signal(float(floor.get("footprint_scale", 1.0)) * 100.0)
	interior_place_entry_button.disabled = not has_floor or doors.is_empty()
	interior_draw_wall_button.disabled = not has_floor
	interior_paint_floor_button.disabled = not has_floor or interior_floor_material_option.item_count == 0
	interior_place_furniture_button.disabled = not has_floor or interior_furniture_catalog_option.item_count == 0
	interior_add_room_button.disabled = not has_floor
	interior_storyline_location_button.disabled = not has_floor
	interior_save_button.disabled = interior_data.get("buildings", {}).is_empty()
	interior_floor_canvas.set_floor_materials(interior_floor_material_library.all_definitions(interior_floor_material_data))
	interior_floor_canvas.set_floor(floor, "%s/%s" % [feature_id, str(floor.get("id", ""))])
	if is_instance_valid(interior_building_map):
		interior_building_map.selected_building_id = feature_id
		interior_building_map.visible = not has_floor
		interior_floor_canvas.visible = has_floor
		interior_building_map.queue_redraw()
	interior_floor_canvas.set_interior_npcs(storyline_npc_data.get("npcs", []), feature_id, str(floor.get("id", "")))
	var npc_art_load := NpcCreations.load_from_town(loaded_project_directory)
	if npc_art_load.ok: interior_floor_canvas.npc_creation_data=npc_art_load.data
	interior_floor_canvas.npc_artwork_directory=loaded_project_directory
	_refresh_interior_stair_controls(interior)
	_refresh_interior_connections()
	var previous_wall_id := ""
	if interior_wall_option.item_count > 0 and interior_wall_option.selected >= 0:
		previous_wall_id = str(interior_wall_option.get_item_metadata(interior_wall_option.selected))
	interior_wall_option.clear()
	for wall_index in floor.get("walls", []).size():
		var wall: Dictionary = floor.get("walls", [])[wall_index]
		var start := Vector2(float(wall.get("start_x_metres", 0.0)), float(wall.get("start_y_metres", 0.0)))
		var finish := Vector2(float(wall.get("end_x_metres", 0.0)), float(wall.get("end_y_metres", 0.0)))
		interior_wall_option.add_item("Wall %d · %.1f m · %d doorway(s)" % [wall_index + 1, start.distance_to(finish), wall.get("doors", []).size()])
		interior_wall_option.set_item_metadata(interior_wall_option.item_count - 1, str(wall.get("id", "")))
		if str(wall.get("id", "")) == previous_wall_id: interior_wall_option.select(interior_wall_option.item_count - 1)
	interior_wall_option.disabled = interior_wall_option.item_count == 0
	interior_remove_wall_button.disabled = interior_wall_option.item_count == 0
	interior_add_door_button.disabled = interior_wall_option.item_count == 0
	_refresh_interior_wall_doors(floor)
	var previous_room_id := ""
	if interior_room_option.item_count > 0 and interior_room_option.selected >= 0:
		previous_room_id = str(interior_room_option.get_item_metadata(interior_room_option.selected))
	interior_room_option.clear()
	for room_value in floor.get("rooms", []):
		var room: Dictionary = room_value
		interior_room_option.add_item(str(room.get("name", "Room")))
		interior_room_option.set_item_metadata(interior_room_option.item_count - 1, str(room.get("id", "")))
		if str(room.get("id", "")) == previous_room_id: interior_room_option.select(interior_room_option.item_count - 1)
	interior_room_option.disabled = interior_room_option.item_count == 0
	interior_remove_room_button.disabled = interior_room_option.item_count == 0
	var previous_furniture_id := ""
	if interior_placed_furniture_option.item_count > 0 and interior_placed_furniture_option.selected >= 0:
		previous_furniture_id = str(interior_placed_furniture_option.get_item_metadata(interior_placed_furniture_option.selected))
	interior_placed_furniture_option.clear()
	for furniture_value in floor.get("furniture", []):
		var furniture: Dictionary = furniture_value
		interior_placed_furniture_option.add_item("%s · %.1f°" % [str(furniture.get("name", "Furniture")), float(furniture.get("rotation_degrees", 0.0))])
		interior_placed_furniture_option.set_item_metadata(interior_placed_furniture_option.item_count - 1, str(furniture.get("id", "")))
		if str(furniture.get("id", "")) == previous_furniture_id:
			interior_placed_furniture_option.select(interior_placed_furniture_option.item_count - 1)
	interior_placed_furniture_option.disabled = interior_placed_furniture_option.item_count == 0
	interior_remove_furniture_button.disabled = interior_placed_furniture_option.item_count == 0
	if interior_storyline_location_label != null:
		interior_storyline_location_label.text = "No interior storyline location selected on this floor."
	var links: Array = floors[0].get("entry_links", []) if has_floor else []
	var painted_cells: int = floor.get("flooring", {}).get("cells", {}).size()
	var interior_display_name := str(exterior.get("custom_name", interior.get("name", interior_selected_feature.get("tags", {}).get("name", "Unnamed building"))))
	interior_summary_label.text = "%s · %s\n%d floor(s) · %d exterior entrance(s) · %d entry link(s) · %d wall(s) · %d room name(s) · %d furniture item(s) · %d painted floor tile(s)%s" % [
		interior_display_name,
		"ground floor ready" if has_floor else "no interior yet",
		floors.size(), doors.size(), links.size(), floor.get("walls", []).size(), floor.get("rooms", []).size(), floor.get("furniture", []).size(), painted_cells,
		"\nApproximate footprint-based floor: %.1f m × %.1f m." % [float(floor.get("width_metres", 0.0)), float(floor.get("height_metres", 0.0))] if has_floor else ""
	]
	_refresh_editor_delete_button()


func _refresh_interior_wall_doors(floor_override: Dictionary = {}) -> void:
	if interior_door_option == null: return
	var floor := floor_override
	if floor.is_empty() and not interior_selected_feature.is_empty():
		var record: Dictionary = interior_data.get("buildings", {}).get(str(interior_selected_feature.get("id", "")), {})
		floor = BuildingInteriorStoreScript.floor_by_id(record, _selected_interior_floor_id())
	var wall_id := ""
	if interior_wall_option.item_count > 0 and interior_wall_option.selected >= 0:
		wall_id = str(interior_wall_option.get_item_metadata(interior_wall_option.selected))
	interior_door_option.clear()
	for wall_value in floor.get("walls", []):
		if str(wall_value.get("id", "")) != wall_id: continue
		for door_value in wall_value.get("doors", []):
			var door: Dictionary = door_value
			interior_door_option.add_item("%s doorway · %.2f m" % ["Locked" if bool(door.get("locked", false)) else "Unlocked", float(door.get("width_metres", 0.9))])
			interior_door_option.set_item_metadata(interior_door_option.item_count - 1, str(door.get("id", "")))
		break
	interior_door_option.disabled = interior_door_option.item_count == 0
	interior_remove_door_button.disabled = interior_door_option.item_count == 0
	_refresh_interior_door_lock_button()


func _refresh_interior_door_lock_button() -> void:
	if interior_lock_door_button == null: return
	var has_door := interior_wall_option != null and interior_wall_option.item_count > 0 and interior_wall_option.selected >= 0 and interior_door_option != null and interior_door_option.item_count > 0 and interior_door_option.selected >= 0
	interior_lock_door_button.disabled = not has_door
	if not has_door:
		interior_lock_door_button.text = "Lock selected doorway"
		return
	var wall_id := str(interior_wall_option.get_item_metadata(interior_wall_option.selected))
	var door_id := str(interior_door_option.get_item_metadata(interior_door_option.selected))
	interior_lock_door_button.text = "Unlock selected doorway" if _selected_interior_door_locked(wall_id, door_id) else "Lock selected doorway"


func _selected_interior_door_locked(wall_id: String, door_id: String) -> bool:
	var record: Dictionary = interior_data.get("buildings", {}).get(str(interior_selected_feature.get("id", "")), {})
	var floor := BuildingInteriorStoreScript.floor_by_id(record, _selected_interior_floor_id())
	for wall_value in floor.get("walls", []):
		if str(wall_value.get("id", "")) != wall_id: continue
		for door_value in wall_value.get("doors", []):
			if str(door_value.get("id", "")) == door_id: return bool(door_value.get("locked", false))
	return false


func _select_interior_wall_by_id(wall_id: String) -> void:
	for index in interior_wall_option.item_count:
		if str(interior_wall_option.get_item_metadata(index)) == wall_id:
			interior_wall_option.select(index)
			interior_floor_canvas.select_wall(wall_id)
			return


func _select_interior_door_by_id(door_id: String) -> void:
	for index in interior_door_option.item_count:
		if str(interior_door_option.get_item_metadata(index)) == door_id:
			interior_door_option.select(index)
			return


func _selected_interior_floor_id() -> String:
	if interior_floor_option == null or interior_floor_option.item_count == 0 or interior_floor_option.selected < 0:
		return ""
	return str(interior_floor_option.get_item_metadata(interior_floor_option.selected))


func _show_game_settings_page() -> void:
	_clear_content()
	settings_controls.clear()
	content_area.add_child(_page_heading("Game settings", "Choose town populations, camera views and vehicle handling. No code is required."))
	_add_top_save_bar("Save settings", _save_game_settings)

	var town_row := HBoxContainer.new()
	content_area.add_child(town_row)
	settings_town_edit = LineEdit.new()
	settings_town_edit.placeholder_text = "Choose an existing town project folder"
	settings_town_edit.text = last_created_directory
	settings_town_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	town_row.add_child(settings_town_edit)
	town_row.add_child(_action_button("Choose town…", _choose_settings_town, false))
	town_row.add_child(_action_button("Load", _load_game_settings, false))

	settings_tools_navigation = ToolTileMenuScript.new()
	content_area.add_child(settings_tools_navigation)
	settings_tools_navigation.setup("Choose a game settings tool",3)
	var form: VBoxContainer = settings_tools_navigation.add_page("population","Town population","NPCs • robots • drones • traffic")
	form.add_child(_settings_group_heading("Town population", "Counts are totals across the town. CBD percentages decide how many should be in, or travelling toward, the CBD."))
	form.add_child(_settings_field("population", "traffic_car_count", "Traffic cars", "NPC vehicles; excludes the player's wagon.", 0, 1000, 1, " cars"))
	form.add_child(_settings_field("population", "pedestrian_count", "Walking NPCs", "Set this to zero for an empty pedestrian population.", 0, 2000, 1, " NPCs"))
	form.add_child(_settings_field("population", "cbd_car_percent", "Traffic in the CBD", "Target share in or heading toward the CBD.", 0, 100, 1, "%"))
	form.add_child(_settings_field("population", "cbd_pedestrian_percent", "Pedestrians in the CBD", "Target share in or heading toward the CBD.", 0, 100, 1, "%"))
	form.add_child(_settings_field("population", "robot_count", "Walking robots (NPR)", "Not Playable Robots use the pedestrian route network.", 0, 1000, 1, " NPRs"))
	form.add_child(_settings_field("population", "cbd_robot_percent", "NPRs in the CBD", "Target share of walking robots in, or travelling toward, the CBD.", 0, 100, 1, "%"))
	form.add_child(_settings_field("population", "drone_count", "Flying drones (NPD)", "Non-Playable Drones use the more lenient aerial route network.", 0, 1000, 1, " NPDs"))
	form.add_child(_settings_field("population", "cbd_drone_percent", "NPDs in the CBD", "Target share of flying drones in, or travelling toward, the CBD.", 0, 100, 1, "%"))

	form = settings_tools_navigation.add_page("roads","Road rules","Left / right driving")
	form.add_child(_settings_group_heading("Road rules", "This saves which side moving traffic will use when playable lanes and turn paths are generated."))
	driving_side_option = OptionButton.new()
	driving_side_option.add_item("Drive on the left")
	driving_side_option.set_item_metadata(0, "left")
	driving_side_option.add_item("Drive on the right")
	driving_side_option.set_item_metadata(1, "right")
	form.add_child(driving_side_option)

	form = settings_tools_navigation.add_page("appearance","Skin pigmentation tones","Light • medium • dark")
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

	form = settings_tools_navigation.add_page("camera","Camera view","Walking / driving zoom")
	var character_form: VBoxContainer=settings_tools_navigation.add_page("characters","Character artwork","Animated NPCs • player artwork")
	character_form.add_child(_settings_group_heading("Character artwork","The main character and human NPCs all animate when walking, at the current scale. Choose NPC appearances in NPCs and personas."))
	character_form.add_child(_label("NPCs: Animated NPC",13,ACCENT))
	character_form.add_child(_label("Main character: Animated",13,ACCENT))
	form.add_child(_settings_group_heading("Camera view", "Set the view separately for walking and driving. 1× is the ordinary scale; larger values bring the camera closer."))
	form.add_child(_settings_field("camera", "character_zoom", "On-foot character zoom", "Higher values enlarge the player and nearby town while walking.", 0.2, 3, 0.05, "×"))
	form.add_child(_settings_field("driving", "camera_zoom_multiplier", "In-car camera zoom", "Independent of on-foot zoom. Higher values bring the road closer while driving.", 0.2, 3, 0.05, "×"))

	form = settings_tools_navigation.add_page("vehicle","Player vehicle","Speed • braking • steering")
	form.add_child(_settings_group_heading("Player vehicle", "Set an understandable road speed. The game converts km/h to the correct movement speed for each generated map."))
	form.add_child(_settings_field("driving", "max_speed_kmh", "Maximum driving speed", "In Drive, Up raises the selected cruise speed by 1 km/h and Down lowers it by 1 km/h.", 1, 400, 1, " km/h"))
	form.add_child(_settings_field("driving", "zero_to_hundred_seconds", "0–100 km/h acceleration time", "The default 7.2 seconds is within the requested 2005 Holden VZ range. The game adjusts the movement rate automatically for each town's map scale.", 3, 20, 0.1, " seconds"))
	form.add_child(_settings_field("driving", "reverse_max_speed_kmh", "Maximum reverse speed", "Stop first, then press Shift to select Reverse. Up/Down set reverse cruise speed.", 5, 40, 5, " km/h"))
	form.add_child(_settings_field("driving", "reverse_acceleration", "Reverse acceleration", "How quickly the wagon gains speed in reverse.", 1, 400, 1, ""))
	form.add_child(_settings_field("driving", "coast_deceleration", "Coasting slowdown", "How quickly the wagon slows when no pedal is pressed.", 1, 400, 1, ""))
	form.add_child(_settings_field("driving", "brake_deceleration", "Brake strength", "Higher values stop the wagon more sharply.", 1, 800, 1, ""))
	form.add_child(_settings_field("driving", "steering_rate", "Steering speed", "How quickly the wagon turns.", 0.1, 8, 0.1, ""))

	form = settings_tools_navigation.add_page("recovery","Traffic jam recovery","Safe relocation settings")
	form.add_child(_settings_group_heading("Traffic jam recovery", "NPC cars that cannot make progress can be safely moved to another clear lane."))
	jam_recovery_check = CheckBox.new()
	jam_recovery_check.text = "Automatically relocate jammed NPC traffic"
	form.add_child(jam_recovery_check)
	form.add_child(_settings_field("traffic_recovery", "jam_timeout_seconds", "Wait before recovery", "Red and amber traffic-light waits do not count.", 5, 300, 1, " seconds"))
	form.add_child(_settings_field("traffic_recovery", "recovery_spacing_seconds", "Space out recoveries", "Prevents many cars moving at the same instant.", 0.25, 30, 0.25, " seconds"))
	form.add_child(_settings_field("traffic_recovery", "respawn_distance_pixels", "Minimum relocation distance", "Keeps the replacement away from the jam and player.", 100, 10000, 50, " pixels"))
	form.add_child(_settings_field("traffic_recovery", "respawn_attempts", "Safe-lane attempts", "How many legal, clear positions are tried.", 1, 200, 1, " tries"))

	form = settings_tools_navigation.add_page("lore","Game lore","Upload fictional world background")
	game_lore_editor = GameLoreEditorScript.new()
	form.add_child(game_lore_editor)
	game_lore_editor.configure(last_created_directory)
	form = settings_tools_navigation.add_page("defaults","Recommended settings","Restore defaults")
	var actions := HBoxContainer.new()
	form.add_child(actions)
	actions.add_child(_action_button("Restore recommended settings", _restore_recommended_settings, false))
	_apply_settings_to_controls(GameSettingsStoreScript.recommended_settings())
	if not last_created_directory.is_empty():
		_load_game_settings()


func _choose_settings_town() -> void:
	if settings_town_edit != null and not settings_town_edit.text.strip_edges().is_empty():
		settings_town_dialog.current_dir = settings_town_edit.text.strip_edges()
	settings_town_dialog.popup_centered_ratio(0.72)


func _on_settings_town_selected(path_value: String) -> void:
	_request_section_navigation(_load_selected_settings.bind(path_value))


func _load_selected_settings(path_value: String) -> void:
	settings_town_edit.text = path_value
	_load_game_settings_data()
	if section_history_kind == "settings": _start_section_history("settings")


func _load_game_settings() -> void:
	if section_history_kind == "settings" and not section_saved_snapshot.is_empty():
		_request_section_navigation(_load_selected_settings.bind(settings_town_edit.text.strip_edges()))
	else:
		_load_game_settings_data()


func _load_game_settings_data() -> void:
	if settings_town_edit == null or settings_town_edit.text.strip_edges().is_empty():
		_set_status("Choose a town project before loading settings.")
		return
	var result: Dictionary = GameSettingsStoreScript.load_from_town(settings_town_edit.text.strip_edges())
	_apply_settings_to_controls(result.settings)
	if is_instance_valid(game_lore_editor): game_lore_editor.configure(settings_town_edit.text.strip_edges())
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
	_mark_section_saved()


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
	settings.character_art.npc_type="animated"
	settings.character_art.player_type="animated"
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
		"Ollama writes NPC/NPR replies and can suggest purchases. Only the game's validated confirmation can change inventory; Ollama cannot create towns or run commands.",
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
	var roles_load := TraderStoreScript.new().load_from_town(loaded_project_directory)
	if roles_load.ok: storyline_npc_data = TraderStoreScript.classify_placements(storyline_npc_data, roles_load.data)
	placed_npc_role = "storyline"
	npc_role_drafts.clear()
	_add_top_save_bar("Save personas, traders and town info", _save_persona_library)
	npc_tools_navigation = ToolTileMenuScript.new()
	content_area.add_child(npc_tools_navigation)
	npc_tools_navigation.setup("Choose a character tool", 3)
	var creation_load := NpcCreations.load_from_town(loaded_project_directory)
	if not creation_load.ok: _set_status(creation_load.message); return
	var creation_page: VBoxContainer = npc_tools_navigation.add_page("creation", "NPC creator", "Artwork • age • appearance")
	npc_creation_editor=NpcCreationEditor.new()
	creation_page.add_child(npc_creation_editor)
	npc_creation_editor.setup(loaded_project_directory,creation_load.data)
	npc_creation_editor.creation_in_use=func(id): return storyline_npc_data.get("npcs",[]).any(func(npc): return str(npc.get("appearance",{}).get("template_id",""))==str(id))
	npc_creation_editor.changed.connect(_queue_section_history)
	npc_tools_navigation.add_page("generic", "Generic NPCs", "Place a human")
	npc_tools_navigation.add_page("npr", "NPR", "Place a robot")
	var generic_page: VBoxContainer = npc_tools_navigation.add_page("human_personas", "Human personas", "Edit conversation profiles")
	npc_tools_navigation.add_page("robot_personas", "Robot personas", "Edit robot profiles")
	var storyline_page: VBoxContainer = npc_tools_navigation.add_page("storyline", "Storyline NPCs", "Name • persona • place")
	npc_tools_navigation.add_page("trader", "Trader NPCs", "Place a trader")
	var trader_page: VBoxContainer = npc_tools_navigation.add_page("stock", "Trader stock", "Items and prices")
	var persona_page: VBoxContainer = npc_tools_navigation.add_page("model", "Local LLM", "Model • connection")
	var knowledge_page: VBoxContainer = npc_tools_navigation.add_page("knowledge", "Town information", "Wikipedia • extra notes")
	persona_page_scroll = npc_tools_navigation.page_scroll
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
	knowledge_page.add_child(knowledge_panel)
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
	knowledge_contents.add_child(_label("Custom town notes (.txt)",13,TEXT))
	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 8)
	town_text_status_label = _label("", 11, MUTED)
	town_text_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	knowledge_contents.add_child(town_text_status_label)
	var text_upload:=_action_button("Upload text file…", _choose_town_text_file, false)
	text_upload.name="TownTextUpload"
	custom_row.add_child(text_upload)
	custom_row.add_child(_action_button("Remove text", _remove_town_text_file, false))
	knowledge_contents.add_child(custom_row)
	town_text_preview_label = _label("", 10, MUTED)
	town_text_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	knowledge_contents.add_child(town_text_preview_label)
	_refresh_town_knowledge_controls()

	var editor_panel := _panel_container(PANEL, 10)
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	generic_page.add_child(editor_panel)
	npc_persona_panel = editor_panel
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
	persona_new_npc_button = _action_button("New NPC persona", _new_npc_persona, false)
	persona_new_npr_button = _action_button("New robot persona", _new_npr_persona, false)
	selector_row.add_child(persona_new_npc_button)
	selector_row.add_child(persona_new_npr_button)
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
	persona_status_label = _label("Edit human or robot personas here. Place named characters using the separate Storyline NPCs and Trader NPCs tiles. Save with the top floppy disk.", 12, MUTED)
	persona_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	persona_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_row.add_child(persona_status_label)
	editor.add_child(save_row)
	_build_storyline_npc_section(storyline_page)
	trader_editor = preload("res://scripts/npcs/traders/trader_editor.gd").new()
	trader_page.add_child(trader_editor)
	trader_editor.setup(loaded_project_directory, storyline_npc_data, persona_data, _storyline_interior_label)
	trader_editor.changed.connect(_queue_section_history)
	persona_actor_filter = "npc"
	_refresh_persona_options()
	npc_tools_navigation.page_changed.connect(_on_npc_tool_page_changed)
	_check_local_models()


func _show_inventory_page() -> void:
	_clear_content()
	content_area.add_child(_page_heading("Inventory items", "Add and configure the items available in this town without writing code."))
	if loaded_project_directory.is_empty():
		content_area.add_child(_notice_panel("Open a town project", "Create a town or open a previous project before editing its inventory catalogue.", WARNING))
		content_area.add_child(_action_button("Open previous project", _prepare_existing_project_dialog, true))
		return
	inventory_editor = ItemCatalogEditorScript.new()
	var setup_result: Dictionary = inventory_editor.setup(loaded_project_directory)
	if not setup_result.ok:
		inventory_editor.queue_free()
		content_area.add_child(_notice_panel("Item catalogue needs attention", setup_result.message, WARNING))
		return
	_add_top_save_bar("Save item catalogue", _save_inventory_catalogue)
	inventory_editor.save_button.hide()
	content_area.add_child(inventory_editor)
	inventory_editor.status_changed.connect(func(message: String) -> void: _set_status(message))
	_set_status("Inventory catalogue loaded for %s." % loaded_project_directory.get_file())

func _save_inventory_catalogue() -> void:
	if inventory_editor._save_catalog(): _mark_section_saved()


func _build_storyline_npc_section(parent: VBoxContainer) -> void:
	var panel := _panel_container(Color("#14231e"), 10)
	npc_placement_panel = panel
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	margin.add_child(contents)
	npc_placement_heading = _label("Storyline NPCs", 15, TEXT)
	contents.add_child(npc_placement_heading)
	var help := _label("Copy outdoor coordinates from Advanced map editor, or an interior location from Interior Designer → NPC placement. Paste here, then choose a name and compatible persona, or keep random defaults. NPR uses robot personas; the other categories use human personas.", 11, MUTED)
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
	npc_appearance_picker=NpcAppearancePicker.new()
	npc_appearance_picker.directory=loaded_project_directory
	contents.add_child(npc_appearance_picker)
	npc_appearance_picker.refresh(npc_creation_editor.data)
	_refresh_storyline_persona_choices()
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	storyline_npc_option = OptionButton.new()
	storyline_npc_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storyline_npc_option.item_selected.connect(_select_placed_npc_for_edit)
	action_row.add_child(storyline_npc_option)
	npc_place_button = _action_button("Place storyline NPC", _place_storyline_npc, true)
	action_row.add_child(npc_place_button)
	storyline_remove_button = _action_button("Remove selected", _remove_storyline_npc, false)
	action_row.add_child(storyline_remove_button)
	contents.add_child(action_row)
	var edit_row := HBoxContainer.new()
	edit_row.add_child(_action_button("New / clear fields", _clear_placed_npc_form, false))
	edit_row.add_child(_action_button("Apply character changes", _update_placed_npc_identity, false))
	edit_row.add_child(_action_button("Edit personas", func(): npc_tools_navigation.open_page("robot_personas" if placed_npc_role == "npr" else "human_personas"), false))
	contents.add_child(edit_row)
	storyline_npc_status_label = _label("", 11, MUTED)
	storyline_npc_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(storyline_npc_status_label)
	_refresh_storyline_npc_controls()


func _paste_storyline_coordinates() -> void:
	if storyline_coordinate_edit != null:
		storyline_coordinate_edit.text = DisplayServer.clipboard_get().strip_edges()


func _on_npc_tool_page_changed(page_id: String) -> void:
	_save_persona_form()
	if is_instance_valid(npc_creation_editor): npc_creation_editor._flush()
	if is_instance_valid(trader_editor): trader_editor._flush_profile()
	if page_id in ["human_personas", "robot_personas"]:
		npc_persona_panel.reparent(npc_tools_navigation.pages[page_id])
		persona_actor_filter = "npr" if page_id == "robot_personas" else "npc"
		persona_new_npc_button.visible = persona_actor_filter == "npc"
		persona_new_npr_button.visible = persona_actor_filter == "npr"
		_refresh_persona_options()
	if page_id in ["generic", "npr", "storyline", "trader"]:
		npc_role_drafts[placed_npc_role] = {"name": storyline_name_edit.text, "location": storyline_coordinate_edit.text, "appearance": npc_appearance_picker.selected_appearance(), "persona": str(storyline_persona_option.get_item_metadata(storyline_persona_option.selected)) if storyline_persona_option.selected >= 0 else ""}
		placed_npc_role = page_id
		npc_placement_panel.reparent(npc_tools_navigation.pages[page_id])
		npc_tools_navigation.pages[page_id].move_child(npc_placement_panel, 0)
		var category_name: String = {"generic": "Generic NPC", "npr": "NPR", "storyline": "Storyline NPC", "trader": "Trader NPC"}[page_id]
		npc_placement_heading.text = category_name + " placement"
		npc_place_button.text = "Place " + category_name
		var draft: Dictionary = npc_role_drafts.get(page_id, {})
		storyline_name_edit.text = str(draft.get("name", ""))
		storyline_coordinate_edit.text = str(draft.get("location", ""))
		_refresh_storyline_persona_choices(str(draft.get("persona", "")))
		_refresh_storyline_npc_controls()
		npc_appearance_picker.visible=page_id!="npr"
		npc_appearance_picker.refresh(npc_creation_editor.data)
		npc_appearance_picker.set_appearance(draft.get("appearance",{}))


func _clear_placed_npc_form() -> void:
	storyline_name_edit.clear()
	storyline_coordinate_edit.clear()
	storyline_persona_option.select(0)
	if is_instance_valid(npc_appearance_picker): npc_appearance_picker.set_appearance({})


func _select_placed_npc_for_edit(index: int) -> void:
	var npc_id := str(storyline_npc_option.get_item_metadata(index))
	for npc in storyline_npc_data.get("npcs", []):
		if str(npc.id) != npc_id: continue
		storyline_name_edit.text = str(npc.display_name)
		if is_instance_valid(npc_appearance_picker): npc_appearance_picker.set_appearance(npc.appearance)
		_refresh_storyline_persona_choices(str(npc.persona_id))
		var location: Dictionary = npc.location
		storyline_coordinate_edit.text = StorylineNpcStoreScript.format_interior_location(str(location.building_id), str(location.floor_id), Vector2(float(location.x_metres), float(location.y_metres))) if str(location.get("space", "")) == "interior" else "%.8f, %.8f" % [location.latitude, location.longitude]
		if placed_npc_role == "trader" and is_instance_valid(trader_editor):
			for i in trader_editor.npc_choice.item_count:
				if str(trader_editor.npc_choice.get_item_metadata(i)) == npc_id:
					trader_editor.npc_choice.select(i)
					trader_editor._select_npc(i)
		return


func _update_placed_npc_identity() -> void:
	if storyline_npc_option.selected < 0: return
	var npc_id := str(storyline_npc_option.get_item_metadata(storyline_npc_option.selected))
	var new_name := storyline_name_edit.text.strip_edges()
	for other in storyline_npc_data.get("npcs", []):
		if str(other.id) != npc_id and not new_name.is_empty() and str(other.display_name) == new_name:
			_set_status("Another character already uses that name.")
			return
	for npc in storyline_npc_data.get("npcs", []):
		if str(npc.id) != npc_id: continue
		if not new_name.is_empty(): npc.display_name = new_name
		if placed_npc_role!="npr": npc.appearance=npc_appearance_picker.selected_appearance(npc.appearance)
		var chosen := str(storyline_persona_option.get_item_metadata(storyline_persona_option.selected))
		if not chosen.is_empty(): npc.persona_id = chosen
		if placed_npc_role == "trader" and is_instance_valid(trader_editor):
			trader_editor._flush_profile()
			if not chosen.is_empty(): npc.persona_id = chosen
			trader_editor.set_assigned_persona(npc_id, str(npc.persona_id))
		_refresh_storyline_npc_controls(npc_id)
		_set_status("Character updated. Select the top Save button to keep the name and persona.")
		return


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
	var requested_persona_id := ""
	if storyline_persona_option != null and storyline_persona_option.item_count > 0:
		requested_persona_id = str(storyline_persona_option.get_item_metadata(storyline_persona_option.selected))
	var requested_name := storyline_name_edit.text if storyline_name_edit != null else ""
	var add_result := storyline_npc_store.add_interior_npc(storyline_npc_data, parsed.location, _current_town_id(), persona_data, requested_name, requested_persona_id, placed_npc_role) if location_space == "interior" else storyline_npc_store.add_outdoor_npc(storyline_npc_data, parsed.location, _current_town_id(), persona_data, requested_name, requested_persona_id, placed_npc_role)
	if not add_result.ok:
		_show_message("Could not place the storyline NPC", add_result.message)
		return
	if placed_npc_role!="npr": add_result.npc.appearance=npc_appearance_picker.selected_appearance(add_result.npc.appearance)
	var checked := storyline_npc_store.validate(add_result.data, imported_town.get("bounds", {}), effective_result.features, persona_data, false, interior_data)
	if not checked.passed:
		_set_status(str(checked.errors[0]))
		return
	storyline_npc_data = add_result.data
	if placed_npc_role == "trader" and is_instance_valid(trader_editor):
		trader_editor.data.traders[str(add_result.npc.id)] = {"enabled": true, "trade_role": "Trader", "persona_id": str(add_result.npc.persona_id), "offers": []}
	_refresh_storyline_npc_controls(str(add_result.npc.id))
	var chosen_persona := persona_store.find_persona(persona_data, str(add_result.npc.persona_id))
	var persona_name := str(chosen_persona.get("name", add_result.npc.persona_id))
	if location_space == "interior":
		storyline_npc_status_label.text = "%s Their persona is %s.\nPlaced in %s / %s at X %.2f m, Y %.2f m. Use top Save." % [add_result.message, persona_name, str(parsed.location.building_id), str(parsed.location.floor_id), float(parsed.location.x_metres), float(parsed.location.y_metres)]
	else:
		storyline_npc_status_label.text = "%s Their persona is %s.\nPlaced at latitude %.8f, longitude %.8f. Use top Save." % [add_result.message, persona_name, float(parsed.location.latitude), float(parsed.location.longitude)]
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
	storyline_npc_data = updated
	if is_instance_valid(trader_editor): trader_editor.data.traders.erase(npc_id)
	_refresh_storyline_npc_controls()
	storyline_npc_status_label.text = "Character removed from the editor. Use top Save to keep the change."


func _refresh_storyline_npc_controls(selected_id := "") -> void:
	if is_instance_valid(trader_editor) and not trader_editor.is_queued_for_deletion():
		trader_editor.set_npcs(storyline_npc_data, not section_history_busy)
	if storyline_npc_option == null:
		return
	storyline_npc_option.clear()
	var selected_index := 0
	for value in storyline_npc_data.get("npcs", []):
		if not value is Dictionary:
			continue
		var npc: Dictionary = value
		if TraderStoreScript.npc_role(npc, trader_editor.data if is_instance_valid(trader_editor) else {}) != placed_npc_role: continue
		var location: Dictionary = npc.get("location", {})
		var index := storyline_npc_option.item_count
		if str(location.get("space", "outdoors")) == "interior":
			storyline_npc_option.add_item("%s · %s · X %.1f Y %.1f" % [str(npc.get("display_name", "Storyline NPC")), _storyline_interior_label(location), float(location.get("x_metres", 0.0)), float(location.get("y_metres", 0.0))])
		else:
			storyline_npc_option.add_item("%s · %.6f, %.6f" % [str(npc.get("display_name", "Storyline NPC")), float(location.get("latitude", 0.0)), float(location.get("longitude", 0.0))])
		storyline_npc_option.set_item_metadata(index, str(npc.get("id", "")))
		if str(npc.get("id", "")) == selected_id:
			selected_index = index
	if storyline_npc_option.item_count > 0:
		storyline_npc_option.select(selected_index)
		if placed_npc_role == "trader" and is_instance_valid(trader_editor):
			var selected_npc_id := str(storyline_npc_option.get_item_metadata(selected_index))
			for i in trader_editor.npc_choice.item_count:
				if str(trader_editor.npc_choice.get_item_metadata(i)) == selected_npc_id:
					trader_editor.npc_choice.select(i)
					trader_editor._select_npc(i)
	if storyline_remove_button != null:
		storyline_remove_button.disabled = storyline_npc_option.item_count == 0
	if storyline_npc_status_label != null:
		storyline_npc_status_label.text = "%d %s NPC(s) saved in this town." % [storyline_npc_option.item_count, placed_npc_role]


func _storyline_interior_label(location: Dictionary) -> String:
	var building_id := str(location.get("building_id", ""))
	var building: Dictionary = interior_data.get("buildings", {}).get(building_id, {})
	var building_name := str(building.get("name", "")).strip_edges()
	if building_name.is_empty(): building_name = "Building %s" % building_id
	var floor_name := str(location.get("floor_id", "")).replace("_", " ").capitalize()
	for floor in building.get("floors", []):
		if str(floor.id) == str(location.get("floor_id", "")): floor_name = str(floor.get("name", floor_name))
	return "%s / %s" % [building_name, floor_name]


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
		if not value is Dictionary or str(value.get("actor_kind", "")) != ("npr" if placed_npc_role == "npr" else "npc"):
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
	if is_instance_valid(trader_editor) and not trader_editor.is_queued_for_deletion(): trader_editor.refresh_personas(persona_data)
	if persona_option == null:
		return
	persona_form_index = -1
	persona_option.clear()
	persona_visible_indices.clear()
	var selected_index := 0
	for index in persona_data.get("personas", []).size():
		var persona: Dictionary = persona_data.personas[index]
		if str(persona.get("actor_kind", "")) != persona_actor_filter: continue
		var visible_index := persona_option.item_count
		persona_option.add_item("%s · %s" % [str(persona.get("name", "Unnamed")), "NPR" if str(persona.get("actor_kind", "")) == "npr" else "NPC"])
		persona_option.set_item_metadata(visible_index, str(persona.get("id", "")))
		persona_visible_indices.append(index)
		if str(persona.get("id", "")) == selected_id:
			selected_index = visible_index
	if persona_option.item_count > 0:
		persona_option.select(selected_index)
		_load_persona_form(persona_visible_indices[selected_index])
	_refresh_storyline_persona_choices()


func _on_persona_selected(index: int) -> void:
	_save_persona_form()
	if index >= 0 and index < persona_visible_indices.size(): _load_persona_form(persona_visible_indices[index])


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
	_run_section_save_transaction("npcs", _save_persona_library_data)


func _save_persona_library_data() -> void:
	if is_instance_valid(npc_creation_editor):
		npc_creation_editor._flush()
		var creations_check := NpcCreations.references_valid(storyline_npc_data,npc_creation_editor.data)
		if not creations_check.ok: _set_status(creations_check.message); return
		var creations_save := NpcCreations.save_to_town(loaded_project_directory,npc_creation_editor.data)
		if not creations_save.ok: _set_status(creations_save.message); return
	_save_persona_form()
	if is_instance_valid(trader_editor): trader_editor._flush_profile()
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
	if is_instance_valid(trader_editor) and not trader_editor.is_queued_for_deletion():
		var trader_save: Dictionary = trader_editor.save(persona_data)
		if not trader_save.ok:
			persona_status_label.text = "Personas saved, but traders were not: " + str(trader_save.message)
			_set_status(persona_status_label.text)
			return
		trader_editor.refresh_personas(persona_data)
	var effective := _storyline_effective_features()
	if not effective.ok: _set_status(effective.message); return
	var placement_save := storyline_npc_store.save_to_town(loaded_project_directory, storyline_npc_data, imported_town.get("bounds", {}), effective.features, persona_data, interior_data)
	if not placement_save.ok:
		_set_status("Personas saved, but character edits were not: " + str(placement_save.message))
		return
	storyline_npc_data = placement_save.data
	persona_status_label.add_theme_color_override("font_color", ACCENT)
	_refresh_storyline_persona_choices()
	_set_status("Personas saved for %s." % loaded_project_directory.get_file())
	_mark_section_saved()


func _delete_selected_persona() -> void:
	if persona_option == null or persona_option.selected < 0:
		return
	var personas: Array = persona_data.get("personas", [])
	if persona_form_index < 0 or persona_form_index >= personas.size() or bool(personas[persona_form_index].get("built_in", false)):
		return
	var selected_id := str(personas[persona_form_index].get("id", ""))
	if is_instance_valid(trader_editor) and not trader_editor.is_queued_for_deletion():
		trader_editor._flush_profile()
		for profile in trader_editor.data.traders.values():
			if str(profile.get("persona_id", "")) == selected_id:
				_show_message("Trader persona is in use", "Choose another persona for this trader before deleting the current one.")
				return
	for value in storyline_npc_data.get("npcs", []):
		if value is Dictionary and str(value.get("persona_id", "")) == selected_id:
			_show_message("Persona is in use", "A saved storyline NPC uses this persona. Remove that storyline NPC first, or keep the persona.")
			return
	personas.remove_at(persona_form_index)
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
		town_text_status_label.text = result.message
		_set_status(result.message)
		return
	town_knowledge_data = result.data
	town_custom_text = str(result.custom_text)
	_refresh_town_knowledge_controls()
	_set_status("Extra town information imported.")
	_queue_section_history()


func _remove_town_text_file() -> void:
	town_knowledge_data["custom_text"] = TownKnowledgeStoreScript.empty_data().custom_text
	town_custom_text = ""
	_refresh_town_knowledge_controls()
	_set_status("Optional town text detached in the editor. Use top Save; copied text is kept.")
	_queue_section_history()


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
	# Keep the current saved project intact until the replacement parses.
	pending_osm_files = paths.duplicate()
	osm_files_label.text = "Selected: %s. Select Read files and show preview." % ", ".join(paths)
	scan_button.disabled = paths.is_empty()
	_refresh_create_button()


func _on_workspace_selected(path_value: String) -> void:
	workspace_edit.text = path_value
	current_workspace = path_value
	_save_workspace_preference(path_value)
	_set_status("Game files will be saved inside %s" % path_value)
	_refresh_create_button()


func _on_workspace_text_changed(value: String) -> void:
	current_workspace = value.strip_edges()
	_refresh_create_button()


func _on_town_name_changed(value: String) -> void:
	current_town_name = value
	_refresh_create_button()


func _scan_osm_files() -> void:
	_set_status("Reading OpenStreetMap files…")
	var sources := pending_osm_files if not pending_osm_files.is_empty() else selected_osm_files
	var parsed: Dictionary = importer.parse_files(sources)
	if not parsed.get("ok", false):
		import_summary_label.text = parsed.message
		import_summary_label.add_theme_color_override("font_color", WARNING)
		_set_status("The OSM files need attention. The previous project has not been changed.")
		return
	if not pending_osm_files.is_empty():
		if not loaded_project_directory.is_empty():
			current_town_name = sources[0].get_file().get_basename().replace("_", " ").capitalize()
			town_name_edit.text = current_town_name
		loaded_project_directory = ""
		last_created_directory = ""
		selected_osm_files = sources.duplicate()
		original_osm_files = sources.duplicate()
		pending_osm_files.clear()
		create_town_button.text = "Create town project"
		rebuild_project_button.disabled = true
		open_folder_button.disabled = true
	osm_files_label.text = _file_selection_text()
	imported_town = parsed
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
	vehicle_start_button.disabled = true
	selection_instructions.text = "Click Draw CBD and drag a rectangle. Then click Set start and choose a location."
	_set_map_mode(TownMapCanvasScript.EditMode.DRAW_CBD)
	_set_status("Town preview ready. Draw the CBD area." if imported_town.get("warnings", []).is_empty() else "Town preview ready with an OSM water warning shown above.")
	_refresh_create_button()
	if is_instance_valid(import_tools_navigation): import_tools_navigation.open_page("cbd")
	# New source selection is a new setup/history boundary, not an undoable
	# replacement of a saved town's map and content.
	_mark_section_saved()


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
		TownMapCanvasScript.EditMode.SET_VEHICLE_START:
			selection_instructions.text = "Car placement active. Click clear ground for the car. The white arrow marks its front; use Car starting direction, right-click or right-drag to rotate. Save project changes when ready."
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
	selection_instructions.text = "CBD selected. Open Player start and choose safe ground."
	_set_status("CBD area selected.")
	_refresh_create_button()


func _on_start_changed(location: Dictionary) -> void:
	selected_start = location.duplicate(true)
	vehicle_start_button.disabled = false
	vehicle_rotation_control.set_value_no_signal(float(selected_start.get("vehicle", {}).get("rotation_degrees", 0.0)))
	selection_instructions.remove_theme_color_override("font_color")
	start_button.text = "Change starting locations"
	selection_instructions.text = "Safe player and car starting positions selected. Place player's car lets you choose a different clear point; the white arrow shows its starting direction."
	_set_status("Starting location selected.")
	_refresh_create_button()


func _on_start_rejected(message: String) -> void:
	selected_start = {}
	vehicle_start_button.disabled = true
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
	if not is_instance_valid(create_town_button):
		return
	var missing := _creation_missing_requirements()
	# Keep the button clickable so a non-technical creator can ask the program what
	# is missing instead of being left with an unexplained grey button.
	create_town_button.disabled = false
	if not is_instance_valid(creation_readiness_label):
		return
	if missing.is_empty():
		creation_readiness_label.text = "Ready. Select %s, then Play test project." % ("Save project changes" if not loaded_project_directory.is_empty() else "Create town project")
		creation_readiness_label.add_theme_color_override("font_color", ACCENT)
	else:
		creation_readiness_label.text = "Still needed: %s." % ", ".join(missing)
		creation_readiness_label.add_theme_color_override("font_color", WARNING)
	_refresh_sidebar_readiness()


func _creation_missing_requirements() -> PackedStringArray:
	var missing := PackedStringArray()
	if not pending_osm_files.is_empty(): missing.append("read the newly selected map in Map files")
	var town_name := current_town_name
	if is_instance_valid(town_name_edit) and town_name_edit.is_inside_tree():
		town_name = town_name_edit.text.strip_edges()
	if town_name.is_empty():
		missing.append("enter a town name in Town name")
	if not imported_town.get("ok", false):
		missing.append("read the OSM map in Map files")
	if selected_cbd.is_empty():
		missing.append("draw the CBD in CBD area")
	elif imported_town.get("ok", false) and not content_pack_writer._bounds_contains_bounds(imported_town.bounds, selected_cbd):
		missing.append("redraw the CBD inside this map in CBD area")
	if selected_start.is_empty():
		missing.append("choose a location in Player start")
	var workspace := current_workspace
	if is_instance_valid(workspace_edit) and workspace_edit.is_inside_tree():
		workspace = workspace_edit.text.strip_edges()
	if workspace.is_empty():
		missing.append("choose a save directory in Save folder")
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
	var town_name := current_town_name.strip_edges()
	if is_instance_valid(town_name_edit) and town_name_edit.is_inside_tree():
		town_name = town_name_edit.text.strip_edges()
	var workspace := current_workspace
	if is_instance_valid(workspace_edit) and workspace_edit.is_inside_tree():
		workspace = workspace_edit.text.strip_edges()
	var result: Dictionary
	if not loaded_project_directory.is_empty():
		result = content_pack_writer.update_town(
			loaded_project_directory,
			town_name,
			imported_town,
			selected_cbd,
			selected_start,
			project_settings
		)
	else:
		result = content_pack_writer.save_town(
			workspace,
			town_name,
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
	current_town_name = town_name
	current_workspace = result.town_directory.get_base_dir()
	if is_instance_valid(open_folder_button): open_folder_button.disabled = false
	play_test_button.disabled = false
	if is_instance_valid(rebuild_project_button): rebuild_project_button.disabled = false
	if is_instance_valid(create_town_button): create_town_button.text = "Save project changes"
	_save_workspace_preference(workspace)
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
	if is_instance_valid(selection_instructions):
		selection_instructions.text = "%s successfully. Building information, collisions, pathfinding and traffic rules were generated automatically from the OSM map.%s%s%s%s%s Hover or click a building during Play test to read its mapped details. Your source files remain unchanged." % ["Town project rebuilt" if rebuilding else "Town project created", control_message, geometry_message, transport_message, crossing_message, rebuild_note]
	_mark_section_saved()
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
	existing_project_dialog.title = "Open previous project"
	_prepare_existing_project_dialog()


func _choose_project_to_play() -> void:
	project_dialog_action = "play"
	existing_project_dialog.title = "Play test project"
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
	pending_osm_files.clear()
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
	if not pending_osm_files.is_empty():
		_show_message("Read the new map first", "Return to Import a town → Map files and read the selected OSM. The previous town will not be launched instead.")
		return
	if last_created_directory.is_empty():
		var missing := _creation_missing_requirements()
		if not missing.is_empty():
			_show_message(
				"Finish setup before Play test",
				"This test game cannot be built yet. Please %s. Your current map and completed selections are still safe in this window."
				% ", then ".join(missing)
			)
			_set_status("Play test is waiting for: %s." % ", ".join(missing))
			return
		if not _create_town_project(): return
	_play_project(last_created_directory)


func _play_project(path_value: String) -> void:
	var result: Dictionary = project_loader.load_project(path_value)
	if not result.ok:
		_show_message("Could not open project", result.message)
		return
	_save_recent_project(result.town_directory)
	var interiors := building_interior_store.load_from_town(result.town_directory)
	if not interiors.ok: _show_message("Could not open interiors", interiors.message); return
	if not interiors.data.get("building_connections", []).is_empty():
		var feature_path: String = result.town_directory.path_join("data/map_features.json")
		var mapped = JSON.parse_string(FileAccess.get_file_as_string(feature_path))
		var source_features: Array = mapped.get("features", []) if mapped is Dictionary else []
		var overrides := map_override_store.load_from_town(result.town_directory, source_features, result.town.get("map_bounds", {}))
		if not overrides.ok: _show_message("Map corrections need attention", overrides.message); return
		var effective := map_override_store.apply(source_features, overrides.data)
		if not effective.ok: _show_message("Map corrections need attention", effective.message); return
		var checked := BuildingConnections.validate(interiors.data, BuildingConnections.with_source_precision(result.town_directory, effective.features))
		if not checked.ok: _show_message("Connecting doors need attention", checked.message); return
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
		if not is_instance_valid(label_value): continue
		var label: Label = label_value
		label.text = label.text.get_slice(" · ", 0) + " · Checking…"
		label.add_theme_color_override("font_color", MUTED)
	_set_status("Checking local model services for NPC dialogue…")
	llm_probe.check_all()


func _on_provider_checked(provider_id: String, available: bool, detail: String) -> void:
	if not provider_status_labels.has(provider_id) or not is_instance_valid(provider_status_labels[provider_id]):
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
	call_deferred("_compact_editor_fields")
	provider_status_labels.clear()
	editor_delete_selection.clear()
	section_history_kind = ""
	section_history_queued = false
	section_history.reset({})
	section_saved_snapshot = {}
	section_save_callback = Callable()
	if not interior_stair_pending.is_empty(): _cancel_interior_stairs()
	trader_editor = null
	npc_tools_navigation = null
	import_tools_navigation = null
	interior_tools_navigation = null
	settings_tools_navigation = null
	building_tools_navigation = null
	game_lore_editor = null
	tree_settings_editor = null
	for child in content_area.get_children():
		content_area.remove_child(child)
		child.queue_free()

func _compact_editor_fields() -> void:
	if is_instance_valid(content_area): preload("res://scripts/app/navigation/compact_form.gd").apply(content_area)


func _set_status(message: String) -> void:
	status_label.text = message
	_refresh_sidebar_readiness()


func _add_top_save_bar(text_value: String, callback: Callable) -> Button:
	var panel := _panel_container(Color("#14231e"), 8)
	panel.custom_minimum_size.y = 48
	content_area.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var note := _label("Saved / no changes", 12, MUTED)
	section_state_label = note
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(note)
	section_history_kind = {"_create_town_project": "import", "_save_map_editor_changes": "map", "_save_building_designs": "building", "_save_interior_layouts": "interior", "_save_game_settings": "settings", "_save_persona_library": "npcs"}.get(callback.get_method(), "inventory")
	top_undo_button = _action_button("Undo", _undo_section_edit, false)
	top_undo_button.name = "TopUndoButton"
	top_undo_button.disabled = true
	row.add_child(top_undo_button)
	top_cancel_button = _action_button("Cancel", _cancel_section_selection, false)
	top_cancel_button.name = "TopCancelButton"
	top_cancel_button.tooltip_text = "Cancel the active placement/selection without deleting completed edits"
	row.add_child(top_cancel_button)
	top_delete_button = _action_button("Delete item", _delete_editor_item, false)
	top_delete_button.name = "TopDeleteButton"
	top_delete_button.tooltip_text = "Delete the selected item (Delete key). Undo restores it; Save keeps the deletion."
	top_delete_button.add_theme_color_override("font_color",ERROR_COLOUR)
	top_delete_button.hide()
	row.add_child(top_delete_button)
	section_save_callback = callback
	var button := _action_button("Save", _save_active_section, true)
	button.name = "TopSaveButton"
	button.icon = _save_icon_texture()
	button.add_theme_constant_override("icon_max_width", 22)
	button.tooltip_text = text_value
	row.add_child(button)
	call_deferred("_start_section_history", section_history_kind)
	return button

func _section_fields() -> Array:
	return {"import": ["selected_cbd", "selected_start", "selected_driving_side"], "map": ["editor_overrides", "building_exterior_data"], "building": ["building_exterior_data", "building_link_data", "building_link_dirty"], "interior": ["interior_data", "interior_exterior_data", "interior_stair_floor_counts", "storyline_npc_data", "interior_trader_data", "location_notes_data", "location_note_texts", "interior_custom_catalog_data", "interior_floor_material_data"], "npcs": ["persona_data", "storyline_npc_data", "town_knowledge_data", "town_custom_text", "npc_role_drafts", "persona_actor_filter", "placed_npc_role"]}.get(section_history_kind, [])

func _section_snapshot() -> Dictionary:
	# Flush widgets before capturing canonical drafts. Save must not add a fake
	# history step merely by moving the same text from a widget into its record.
	var previous_busy := section_history_busy
	section_history_busy = true
	if section_history_kind == "inventory" and is_instance_valid(inventory_editor): inventory_editor._save_form()
	if section_history_kind == "npcs":
		_save_persona_form()
		if is_instance_valid(trader_editor): trader_editor._flush_profile()
		if is_instance_valid(persona_model_option) and persona_model_option.selected >= 0:
			persona_data.provider["model"] = persona_model_option.get_item_text(persona_model_option.selected)
		if is_instance_valid(wikipedia_url_edit):
			var url := wikipedia_url_edit.text.strip_edges()
			if url != str(town_knowledge_data.wikipedia.get("url", "")):
				town_knowledge_data.wikipedia = TownKnowledgeStoreScript.empty_data().wikipedia
				town_knowledge_data.wikipedia.url = url
	var result := {"fields": {}, "forms": SectionHistory.form_values(content_area) if section_history_kind in ["import", "settings", "npcs", "inventory"] else {}}
	for field in _section_fields(): result.fields[field] = get(field)
	if section_history_kind == "inventory" and is_instance_valid(inventory_editor): result["catalog"] = inventory_editor.catalog_data
	if section_history_kind == "npcs" and is_instance_valid(trader_editor): result["traders"] = trader_editor.data
	if section_history_kind == "npcs" and is_instance_valid(npc_creation_editor): result["creations"]=npc_creation_editor.snapshot_state()
	if section_history_kind == "npcs" and is_instance_valid(npc_appearance_picker): result["appearance_draft"]=npc_appearance_picker.selected_appearance()
	if section_history_kind == "npcs":
		result["persona_id"] = _option_id(persona_option)
		result["npc_id"] = _option_id(storyline_npc_option)
		result["trader_id"] = trader_editor.selected_id
		result["offer_id"] = trader_editor.selected_offer_id
		result["placement_draft"] = _current_placement_draft()
	if section_history_kind == "inventory": result["item_id"] = _option_id(inventory_editor.item_option)
	if is_instance_valid(tree_settings_editor): result["trees"] = tree_settings_editor.snapshot_state()
	if is_instance_valid(game_lore_editor): result["lore"] = game_lore_editor.snapshot_state()
	section_history_busy = previous_busy
	return result.duplicate(true)

func _option_id(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if is_instance_valid(option) and option.selected >= 0 else ""

func _current_placement_draft() -> Dictionary:
	var draft := {"name": storyline_name_edit.text.strip_edges(), "coordinates": storyline_coordinate_edit.text.strip_edges(), "persona": _option_id(storyline_persona_option),"appearance":npc_appearance_picker.selected_appearance() if is_instance_valid(npc_appearance_picker) and placed_npc_role!="npr" else {}}
	if draft.name.is_empty() and draft.coordinates.is_empty() and draft.appearance.is_empty(): return {}
	for npc in storyline_npc_data.get("npcs", []):
		if str(npc.id) != _option_id(storyline_npc_option): continue
		var location: Dictionary = npc.location
		var coordinates := StorylineNpcStoreScript.format_interior_location(str(location.building_id), str(location.floor_id), Vector2(location.x_metres, location.y_metres)) if location.get("space", "") == "interior" else "%.8f, %.8f" % [location.latitude, location.longitude]
		var effective: Dictionary = npc_appearance_picker.selected_appearance(npc.appearance) if placed_npc_role!="npr" else npc.appearance
		draft.appearance=effective
		if draft.name == npc.display_name and draft.persona == npc.persona_id and draft.coordinates == coordinates and effective==npc.appearance: return {}
	return draft

func _start_section_history(kind: String) -> void:
	if kind != section_history_kind or kind.is_empty(): return
	_watch_section_controls(content_area)
	section_history.reset(_section_snapshot())
	section_saved_snapshot = section_history.current.duplicate(true)
	_connect_editor_delete_actions()
	for dialog in [osm_file_dialog, building_image_dialog, interior_furniture_image_dialog, interior_floor_material_image_dialog, town_text_dialog, location_text_dialog]:
		if is_instance_valid(dialog) and not dialog.file_selected.is_connected(_queue_section_history.unbind(1)): dialog.file_selected.connect(_queue_section_history.unbind(1))

func _watch_section_controls(node: Node) -> void:
	if node.name in ["TopUndoButton", "TopCancelButton", "TopDeleteButton", "TopSaveButton"]: return
	for info in node.get_signal_list():
		var name := str(info.name)
		if name not in ["edited", "pressed", "value_changed", "text_changed", "item_selected", "toggled", "entry_spawn_requested", "furniture_position_requested", "furniture_rotation_requested", "furniture_move_requested", "npc_move_requested", "wall_door_move_requested", "wall_requested", "wall_move_requested", "wall_door_requested", "room_label_requested", "floor_paint_requested", "stair_point_requested", "stair_move_requested", "stair_rotation_requested", "connection_point_requested", "connection_move_requested", "building_door_requested", "building_door_drag_requested", "override_zone_drawn", "building_footprint_drawn", "cbd_changed", "start_changed", "alignment_dragged", "rotation_dragged", "scale_requested", "status_changed"]: continue
		var callback := _queue_section_history.unbind(info.args.size()) if info.args.size() > 0 else _queue_section_history
		if not node.is_connected(name, callback): node.connect(name, callback)
	for child in node.get_children(): _watch_section_controls(child)

func _queue_section_history() -> void:
	if section_history_busy or section_history_queued or section_history_kind.is_empty(): return
	section_history_queued = true
	call_deferred("_record_section_edit")

func _record_section_edit() -> void:
	section_history_queued = false
	if section_history_kind.is_empty() or section_history_busy: return
	# A preview floor is not an edit until the stair pair is complete.
	if section_history_kind == "interior" and not interior_stair_pending.is_empty(): return
	section_history.record(_section_snapshot())
	if is_instance_valid(top_undo_button): top_undo_button.disabled = section_history.previous.is_empty()
	_refresh_section_save_state()

func _undo_section_edit() -> void:
	_cancel_section_selection()
	_record_section_edit()
	var before: Dictionary = section_history.current.duplicate(true)
	var snapshot: Dictionary = section_history.undo()
	if snapshot.is_empty(): return
	if not _restore_section_snapshot(snapshot):
		section_history.previous.append(snapshot)
		section_history.current=before
		return
	section_history.current = _section_snapshot()
	top_undo_button.disabled = section_history.previous.is_empty()
	_refresh_section_save_state()
	_set_status("Undone. Save to keep the restored edits. Imported source files and rebuilds are not undone.")

func _restore_section_snapshot(snapshot: Dictionary) -> bool:
	section_history_busy = true
	# Validate immediately saved references before changing any editor draft.
	for entry in [["trees", tree_settings_editor], ["lore", game_lore_editor]]:
		if snapshot.get(entry[0], {}).is_empty() or not is_instance_valid(entry[1]): continue
		if entry[1].snapshot_state() != snapshot[entry[0]]:
			var restored: Dictionary = entry[1].restore_state(snapshot[entry[0]])
			if not restored.ok:
				section_history_busy=false
				_set_status(restored.message)
				return false
	if section_history_kind == "npcs":
		var result := town_knowledge_store.restore_reference(loaded_project_directory, snapshot.fields.town_knowledge_data, snapshot.fields.town_custom_text)
		if not result.ok: section_history_busy=false; _set_status(result.message); return false
	if section_history_kind == "interior":
		var result := LocationNotesScript.new().restore_references(loaded_project_directory, snapshot.fields.location_notes_data, snapshot.fields.location_note_texts)
		if not result.ok: section_history_busy=false; _set_status(result.message); return false
	if section_history_kind == "npcs":
		persona_form_index = -1
		trader_editor.selected_id = ""
		trader_editor.selected_offer_id = ""
	for field in snapshot.fields:
		var value = snapshot.fields[field]
		set(field, value.duplicate(true) if value is Dictionary or value is Array else value)
	match section_history_kind:
		"interior":
			_refresh_interior_designer_controls(_selected_interior_floor_id())
			_refresh_location_notes_controls()
		"building": _refresh_building_creator_controls()
		"map":
			_refresh_editor_map_features()
			editor_map_canvas.set_building_exterior_data(building_exterior_data, loaded_project_directory)
			_refresh_editor_controls()
		"import":
			map_canvas.cbd_bounds = selected_cbd
			map_canvas.start_location = selected_start
			map_canvas.queue_redraw()
		"inventory":
			inventory_editor.catalog_data = snapshot.catalog
			inventory_editor.form_index = -1
			inventory_editor._refresh_items(str(snapshot.get("item_id", "")))
		"npcs":
			if snapshot.has("creations") and is_instance_valid(npc_creation_editor):
				npc_creation_editor.restore_state(snapshot.creations)
				npc_appearance_picker.refresh(npc_creation_editor.data)
			if snapshot.has("traders"):
				trader_editor.data = snapshot.traders
			_refresh_persona_options(str(snapshot.get("persona_id", "")))
			_refresh_storyline_npc_controls(str(snapshot.get("npc_id", "")))
			_refresh_town_knowledge_controls()
			for i in trader_editor.npc_choice.item_count:
				if str(trader_editor.npc_choice.get_item_metadata(i)) == str(snapshot.get("trader_id", "")): trader_editor._select_npc(i); break
			for i in trader_editor.offers_list.item_count:
				if str(trader_editor.offers_list.get_item_metadata(i).item_id) == str(snapshot.get("offer_id", "")): trader_editor._select_offer(i); break
	SectionHistory.restore_form(content_area, snapshot.forms)
	if section_history_kind == "npcs" and is_instance_valid(npc_appearance_picker): npc_appearance_picker.set_appearance(snapshot.get("appearance_draft",{}))
	section_history_busy = false
	return true

func _save_active_section() -> void:
	_record_section_edit()
	if section_save_callback.is_valid(): section_save_callback.call()

func _run_section_save_transaction(kind: String, callback: Callable) -> void:
	section_save_succeeded = false
	var transaction := SectionSaveTransaction.new()
	var prepared := transaction.begin(loaded_project_directory, kind)
	if not prepared.ok: _set_status(prepared.message); return
	var pending_heights := interior_stair_floor_counts.duplicate(true)
	callback.call()
	if section_save_succeeded: return
	if kind == "interior": interior_stair_floor_counts = pending_heights
	var restored := transaction.rollback()
	_set_status(restored.message)
	if is_instance_valid(message_dialog) and message_dialog.visible:
		message_dialog.dialog_text += "\n\n" + str(restored.message)


func _mark_section_saved() -> void:
	section_save_succeeded = true
	if section_history_kind.is_empty(): return
	section_history.current = _section_snapshot()
	section_saved_snapshot = section_history.current.duplicate(true)
	_refresh_section_save_state()

func _section_is_dirty() -> bool:
	if section_history_kind.is_empty() or section_saved_snapshot.is_empty(): return false
	var now := _section_snapshot()
	var saved := section_saved_snapshot.duplicate(true)
	# Selecting an existing item/NPC or switching a tool is not a content edit.
	if section_history_kind not in ["settings", "import"]:
		for value in [now, saved]:
			for key in ["forms", "persona_id", "npc_id", "trader_id", "offer_id", "item_id"]: value.erase(key)
			if section_history_kind == "npcs":
				for key in ["persona_actor_filter", "placed_npc_role", "npc_role_drafts"]: value.fields.erase(key)
	return now != saved

func _refresh_section_save_state() -> void:
	_refresh_editor_delete_button()
	if not is_instance_valid(section_state_label): return
	var dirty := _section_is_dirty()
	section_state_label.text = "Unsaved changes" if dirty else "Saved / no changes"
	section_state_label.modulate = WARNING if dirty else MUTED

func _request_section_navigation(callback: Callable) -> void:
	_record_section_edit()
	if not _section_is_dirty(): callback.call(); return
	section_pending_navigation = callback
	if not is_instance_valid(section_leave_dialog):
		section_leave_dialog = ConfirmationDialog.new()
		section_leave_dialog.title = "Keep your edits?"
		section_leave_dialog.dialog_text = "This section has unsaved changes. Save them before leaving?"
		section_leave_dialog.ok_button_text = "Save"
		section_leave_dialog.cancel_button_text = "Stay"
		section_leave_dialog.add_button("Discard", true, "discard")
		section_leave_dialog.confirmed.connect(_save_before_leaving)
		section_leave_dialog.custom_action.connect(func(action):
			if action == "discard": _discard_before_leaving())
		add_child(section_leave_dialog)
	section_leave_dialog.popup_centered(Vector2i(440, 180))

func _save_before_leaving() -> void:
	_save_active_section()
	if not _section_is_dirty() and section_pending_navigation.is_valid(): section_pending_navigation.call()
	else: _set_status("Save needs attention. Your edits are still open; correct the issue or choose Stay.")

func _discard_before_leaving() -> void:
	# Immediate imports keep their copied files. Restore only the references;
	# do not delete source artwork/text or undo a generated map rebuild.
	if not _restore_section_snapshot(section_saved_snapshot): return
	section_leave_dialog.hide()
	if section_pending_navigation.is_valid(): section_pending_navigation.call()

func _connect_editor_delete_actions() -> void:
	if not is_instance_valid(top_delete_button) or top_delete_button.has_meta("connected"): return
	top_delete_button.set_meta("connected",true)
	if section_history_kind != "interior": return
	for choice in [[interior_placed_furniture_option,"furniture"],[interior_wall_option,"wall"],[interior_door_option,"door"],[interior_room_option,"room"],[interior_stair_list,"stairs"],[interior_connection_list,"connection"]]:
		choice[0].item_selected.connect(_select_editor_list_item.bind(choice[0],choice[1]))
	for choice in [["furniture_selected","furniture"],["wall_selected","wall"],["stair_selected","stairs"],["connection_selected","connection"],["npc_selected","npc"]]:
		interior_floor_canvas.connect(choice[0],_select_editor_signal_item.bind(choice[1]))
	interior_floor_canvas.wall_door_selected.connect(_select_editor_door)
	interior_tools_navigation.page_changed.connect(func(_page): _clear_editor_delete_selection())
	interior_floor_option.item_selected.connect(func(_index): _clear_editor_delete_selection())
	interior_building_option.item_selected.connect(func(_index): _clear_editor_delete_selection())


func _select_editor_list_item(index: int, option: OptionButton, kind: String) -> void:
	if index < 0 or index >= option.item_count: return
	_select_editor_item(kind,str(option.get_item_metadata(index)),_option_id(interior_wall_option) if kind=="door" else "")


func _select_editor_signal_item(id: String, kind: String) -> void:
	_select_editor_item(kind,id)


func _select_editor_door(wall_id: String, door_id: String) -> void:
	_select_editor_item("door",door_id,wall_id)


func _select_editor_item(kind: String, id: String, owner_id := "") -> void:
	if section_history_kind != "interior": return
	editor_delete_selection = {"section":"interior","kind":kind,"id":id,"owner_id":owner_id,"building_id":str(interior_selected_feature.get("id","")),"floor_id":_selected_interior_floor_id()} if not id.is_empty() else {}
	_refresh_editor_delete_button()


func _clear_editor_delete_selection() -> void:
	editor_delete_selection.clear()
	_refresh_editor_delete_button()


func _current_editor_delete_selection() -> Dictionary:
	var selection := editor_delete_selection
	if selection.is_empty() or str(selection.section)!=section_history_kind: return {}
	if selection.building_id!=str(interior_selected_feature.get("id","")) or selection.floor_id!=_selected_interior_floor_id(): return {}
	var record: Dictionary = interior_data.get("buildings",{}).get(str(selection.building_id),{})
	var floor := BuildingInteriorStoreScript.floor_by_id(record,str(selection.floor_id))
	var candidates: Array = []
	match str(selection.kind):
		"furniture": candidates=floor.get("furniture",[])
		"wall": candidates=floor.get("walls",[])
		"room": candidates=floor.get("rooms",[])
		"stairs": candidates=record.get("stairs",[])
		"connection": candidates=interior_data.get("building_connections",[])
		"door":
			for wall in floor.get("walls",[]):
				if str(wall.id)==str(selection.owner_id): candidates=wall.get("doors",[])
		"npc":
			for npc in storyline_npc_data.get("npcs",[]):
				var location: Dictionary=npc.get("location",{})
				if str(location.get("building_id",""))==str(selection.building_id) and str(location.get("floor_id",""))==str(selection.floor_id): candidates.append(npc)
	for item in candidates:
		if str(item.get("id",""))==str(selection.id): return selection
	return {}


func _refresh_editor_delete_button() -> void:
	if is_instance_valid(top_delete_button): top_delete_button.visible=not _current_editor_delete_selection().is_empty()


func _delete_editor_item() -> bool:
	var selection := _current_editor_delete_selection().duplicate(true)
	if selection.is_empty(): _clear_editor_delete_selection(); return false
	_record_section_edit()
	# Cancel unfinished gestures before deleting the canonical placed item.
	_cancel_section_selection()
	var result := EditorItemDeletion.remove(interior_data,storyline_npc_data,interior_trader_data,selection)
	if not result.ok: _set_status(result.message); return false
	interior_data=result.data
	storyline_npc_data=result.npcs
	interior_trader_data=result.traders
	_refresh_interior_designer_controls(str(selection.floor_id))
	_record_section_edit()
	_set_status(str(result.get("message","Item deleted."))+" Undo restores it; Save keeps the deletion.")
	return true


func _cancel_section_selection() -> void:
	editor_delete_selection.clear()
	if section_history_kind == "npcs" and is_instance_valid(npc_creation_editor):
		npc_creation_editor.rig_editor.canvas.cancel_drag()
	_refresh_editor_delete_button()
	if section_history_kind == "interior":
		_cancel_interior_stairs()
		interior_npc_place_active = false
		if is_instance_valid(interior_floor_canvas): interior_floor_canvas.cancel_selection()
	var canvases: Array = []
	match section_history_kind:
		"import": canvases = [map_canvas]
		"map": canvases = [editor_map_canvas]
		"building":
			canvases = [building_map_canvas]
			building_pending_door_index = -1
			if is_instance_valid(building_entry_canvas): building_entry_canvas.cancel_selection()
			if is_instance_valid(building_artwork_preview):
				building_artwork_preview.dragging = false
				building_artwork_preview.door_dragging = false
	for canvas in canvases:
		if not is_instance_valid(canvas): continue
		canvas.set_edit_mode(TownMapCanvasScript.EditMode.INSPECT)
		canvas.selected_building_id = ""
		canvas.dragging = false
		canvas.left_pointer_down = false
		canvas.panning = false
		canvas.queue_redraw()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()
	_set_status("Selection/placement cancelled. Completed edits are kept; Undo reverses an edit.")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or section_history_kind.is_empty(): return
	if event.keycode == KEY_DELETE:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit: return
		if _delete_editor_item(): get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		_cancel_section_selection()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Z and event.ctrl_pressed:
		_undo_section_edit()
		get_viewport().set_input_as_handled()


func _save_icon_texture() -> Texture2D:
	if save_floppy_icon != null:
		return save_floppy_icon
	var image := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var teal := ACCENT
	var dark := BACKGROUND
	# A deliberately simple pixel floppy disk remains crisp in Godot and in the
	# exported Windows application without an editor-side asset import.
	for y in range(2, 18):
		for x in range(2, 18):
			if x <= 15 or y >= 5:
				image.set_pixel(x, y, teal)
	for y in range(3, 9):
		for x in range(6, 15):
			image.set_pixel(x, y, dark)
	for y in range(12, 17):
		for x in range(6, 15):
			image.set_pixel(x, y, dark)
	save_floppy_icon = ImageTexture.create_from_image(image)
	return save_floppy_icon


func _refresh_sidebar_readiness() -> void:
	if sidebar_navigation_buttons.is_empty():
		return
	var setup_ready := _creation_missing_requirements().is_empty()
	var project_path := loaded_project_directory if not loaded_project_directory.is_empty() else last_created_directory
	var settings_ready := bool(GameSettingsStoreScript.validate(GameSettingsStoreScript.recommended_settings()).get("passed", false))
	var runtime_ready := false
	if not project_path.is_empty():
		settings_ready = GameSettingsStoreScript.load_from_town(project_path).ok
		var profile := _read_optional_json(project_path.path_join("runtime_profile.json"))
		runtime_ready = str(profile.get("template_status", "")) in ["preview_ready", "ready"]
	var version := Engine.get_version_info()
	var system_ready := int(version.get("major", 0)) == 4 and int(version.get("minor", 0)) >= 7
	_set_sidebar_completion("import", "Import a town", setup_ready)
	_set_sidebar_completion("settings", "Game settings", settings_ready)
	_set_sidebar_completion("system", "System setup", system_ready)
	_set_sidebar_completion("play", "Play test project", runtime_ready)


func _set_sidebar_completion(key: String, label_text: String, complete: bool) -> void:
	var button: Button = sidebar_navigation_buttons.get(key)
	if button == null:
		return
	button.text = "%s %s" % ["✓" if complete else "✗", label_text]
	button.add_theme_color_override("font_color", ACCENT if complete else ERROR_COLOUR)


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
		button.pressed.connect(func(): _request_section_navigation(callback))
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
