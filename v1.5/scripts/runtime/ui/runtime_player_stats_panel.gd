class_name RuntimePlayerStatsPanel
extends Control

signal stats_toggled(open: bool)

const VIEW_SIZE := Vector2(640, 360)
const BUTTON_RECT := Rect2(526, 39, 106, 23)
const PANEL_RECT := Rect2(452, 68, 180, 86)

var stats_source
var stats_button: Button
var stats_panel: PanelContainer
var nutrient_bar: ProgressBar
var hydration_bar: ProgressBar


func _ready() -> void:
	name = "PlayerStatsHud"
	size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_button = Button.new()
	stats_button.name = "PlayerStatsButton"
	stats_button.text = "PLAYER STATS"
	stats_button.position = BUTTON_RECT.position
	stats_button.size = BUTTON_RECT.size
	stats_button.toggle_mode = true
	stats_button.focus_mode = Control.FOCUS_NONE
	stats_button.add_theme_font_size_override("font_size", 8)
	stats_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stats_button.pressed.connect(toggle)
	add_child(stats_button)

	stats_panel = PanelContainer.new()
	stats_panel.name = "PlayerStatsPanel"
	stats_panel.position = PANEL_RECT.position
	stats_panel.size = PANEL_RECT.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17231ff5")
	style.border_color = Color("#72a7ff")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	stats_panel.add_theme_stylebox_override("panel", style)
	add_child(stats_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 7)
	stats_panel.add_child(margin)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 5)
	margin.add_child(contents)
	var title := Label.new()
	title.text = "HEALTH STATS"
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color("#edf6f1"))
	contents.add_child(title)
	nutrient_bar = _bar(Color("#e2b84f"))
	contents.add_child(nutrient_bar)
	hydration_bar = _bar(Color("#58aee8"))
	contents.add_child(hydration_bar)
	stats_panel.visible = false
	refresh()


func bind_stats(source) -> void:
	stats_source = source
	refresh()


func is_open() -> bool:
	return stats_panel != null and stats_panel.visible


func set_open(open: bool) -> void:
	if stats_panel == null:
		return
	stats_panel.visible = open
	stats_button.button_pressed = open
	if open:
		refresh()
	stats_toggled.emit(open)


func toggle() -> void:
	set_open(not is_open())


func refresh() -> void:
	if nutrient_bar == null or hydration_bar == null:
		return
	var nutrient := 50
	var hydration := 50
	if stats_source != null:
		nutrient = int(stats_source.nutrient)
		hydration = int(stats_source.hydration)
	nutrient_bar.value = nutrient
	hydration_bar.value = hydration
	nutrient_bar.tooltip_text = "Nutrients %d/100" % nutrient
	hydration_bar.tooltip_text = "Hydration %d/100" % hydration
	var nutrient_label := nutrient_bar.get_node("Value") as Label
	var hydration_label := hydration_bar.get_node("Value") as Label
	nutrient_label.text = "NUTRIENTS  %d/100" % nutrient
	hydration_label.text = "HYDRATION  %d/100" % hydration


func contains_screen_point(screen_position: Vector2) -> bool:
	return BUTTON_RECT.has_point(screen_position) or (is_open() and PANEL_RECT.has_point(screen_position))


func _bar(fill_colour: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "StatBar"
	bar.custom_minimum_size = Vector2(164, 20)
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#26332f")
	background.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_colour
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	var label := Label.new()
	label.name = "Value"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", Color("#fff8de"))
	label.add_theme_color_override("font_outline_color", Color("#18211e"))
	label.add_theme_constant_override("outline_size", 2)
	bar.add_child(label)
	return bar

