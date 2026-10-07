class_name LocalLlmLoadingScreen
extends Control

## Full-screen startup presentation. Ollama does not expose incremental model-
## load percentages, so the ProgressBar uses its honest indeterminate mode.

signal retry_requested
signal continue_requested

var elapsed := 0.0
var model_name := ""
var title_label: Label
var detail_label: Label
var elapsed_label: Label
var progress_bar: ProgressBar
var retry_button: Button
var continue_button: Button


func _ready() -> void:
	name = "LocalLlmLoadingScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	_build_interface()
	visible = false
	set_process(false)


func begin(model: String) -> void:
	model_name = model
	elapsed = 0.0
	title_label.text = "Loading local conversation model"
	detail_label.text = "Preparing %s for NPC and NPR conversations…" % model_name
	elapsed_label.text = "Starting Ollama…"
	progress_bar.visible = true
	progress_bar.indeterminate = true
	progress_bar.value = 0.0
	retry_button.visible = false
	continue_button.visible = false
	visible = true
	set_process(true)


func show_stage(message: String) -> void:
	detail_label.text = message


func show_ready(load_seconds: float) -> void:
	title_label.text = "Local conversation model ready"
	detail_label.text = "%s is ready. Opening the town…" % model_name
	elapsed_label.text = "Model load: %.1f seconds" % load_seconds if load_seconds > 0.05 else "Model was already available in memory."
	progress_bar.indeterminate = false
	progress_bar.value = 100.0
	set_process(false)


func show_error(message: String) -> void:
	title_label.text = "Local conversation model needs attention"
	detail_label.text = message
	elapsed_label.text = "Start Ollama and check that %s is installed, then retry." % model_name
	progress_bar.visible = false
	retry_button.visible = true
	continue_button.visible = true
	set_process(false)


func finish() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	elapsed += delta
	elapsed_label.text = "Waiting for Ollama… %d seconds" % floori(elapsed)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#0b1411")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210, -88)
	panel.size = Vector2(420, 176)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18241f")
	style.border_color = Color("#4bc7a1")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	margin.add_child(contents)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color("#edf6f1"))
	contents.add_child(title_label)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 11)
	detail_label.add_theme_color_override("font_color", Color("#a8bbb2"))
	contents.add_child(detail_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 18
	progress_bar.show_percentage = false
	contents.add_child(progress_bar)
	elapsed_label = Label.new()
	elapsed_label.add_theme_font_size_override("font_size", 10)
	elapsed_label.add_theme_color_override("font_color", Color("#efc56c"))
	contents.add_child(elapsed_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	contents.add_child(actions)
	retry_button = Button.new()
	retry_button.text = "Retry"
	retry_button.visible = false
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	actions.add_child(retry_button)
	continue_button = Button.new()
	continue_button.text = "Continue without conversations"
	continue_button.visible = false
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	actions.add_child(continue_button)
