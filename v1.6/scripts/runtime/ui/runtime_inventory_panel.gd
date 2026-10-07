class_name RuntimeInventoryPanel
extends Control

signal inventory_toggled(open: bool)
signal consume_requested(item_id: String)
signal notice_requested(message: String)

const ItemCatalogStoreScript = preload("res://scripts/inventory/item_catalog_store.gd")
const VIEW_SIZE := Vector2(640, 360)
const BACKPACK_RECT := Rect2(582, 274, 50, 50)
const LIST_RECT := Rect2(430, 104, 202, 162)
const ITEM_ICON_SIZE := Vector2(24, 24)
const BACKPACK_TEXTURE := preload("res://assets/inventory/backpack_icon_runtime.png")

var inventory_source
var catalog_data: Dictionary = ItemCatalogStoreScript.default_data()
var town_directory := ""
var backpack_button: TextureButton
var item_panel: PanelContainer
var item_list: VBoxContainer
var quantity_labels: Dictionary = {}
var item_buttons: Dictionary = {}
var keks_quantity_label: Label
var bananas_quantity_label: Label
var water_quantity_label: Label
var confirmation_overlay: ColorRect
var confirmation_label: Label
var pending_item_id := ""


func _ready() -> void:
	name = "PlayerInventoryHud"
	size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_backpack_button()
	_build_item_list()
	_build_confirmation_prompt()
	_rebuild_item_rows()
	refresh()


func bind_inventory(source, item_catalog: Dictionary = {}, directory := "") -> void:
	inventory_source = source
	town_directory = directory
	if not item_catalog.is_empty(): catalog_data = item_catalog
	if item_list != null: _rebuild_item_rows()
	refresh()


func is_open() -> bool:
	return item_panel != null and item_panel.visible


func confirmation_is_open() -> bool:
	return confirmation_overlay != null and confirmation_overlay.visible


func set_open(open: bool) -> void:
	if item_panel == null: return
	item_panel.visible = open
	backpack_button.button_pressed = open
	if not open: _close_confirmation()
	else: refresh()
	inventory_toggled.emit(open)


func toggle() -> void:
	set_open(not is_open())


func close_topmost() -> bool:
	if confirmation_is_open():
		_close_confirmation()
		return true
	if is_open():
		set_open(false)
		return true
	return false


func refresh() -> void:
	for item_id in quantity_labels:
		var item := ItemCatalogStoreScript.find_item(catalog_data, str(item_id))
		var amount := int(inventory_source.quantity(str(item_id))) if inventory_source != null else int(item.get("starting_quantity", 0))
		quantity_labels[item_id].text = "%d" % amount
		if item_buttons.has(item_id): item_buttons[item_id].disabled = amount <= 0


func contains_screen_point(screen_position: Vector2) -> bool:
	if confirmation_is_open(): return true
	return BACKPACK_RECT.has_point(screen_position) or (is_open() and LIST_RECT.has_point(screen_position))


func request_item(item_id: String) -> void:
	var item := ItemCatalogStoreScript.find_item(catalog_data, item_id)
	if item.is_empty(): return
	if inventory_source != null and inventory_source.quantity(item_id) <= 0:
		notice_requested.emit("There are no %s left in the backpack." % str(item.get("display_name", "items")))
		return
	var type_value := str(item.get("type", "general"))
	if type_value not in ["nutrient", "hydration"]:
		notice_requested.emit("%s cannot be consumed." % str(item.get("display_name", "This item")))
		return
	pending_item_id = item_id
	var points := int(item.get("nutrient_points", 0)) if type_value == "nutrient" else int(item.get("hydration_points", 0))
	confirmation_label.text = "Consume 1 %s?\nRestores up to %d %s points." % [str(item.get("display_name", "item")).trim_suffix("s"), points, type_value]
	confirmation_overlay.visible = true


func _build_backpack_button() -> void:
	backpack_button = TextureButton.new()
	backpack_button.name = "BackpackButton"
	backpack_button.position = BACKPACK_RECT.position
	backpack_button.size = BACKPACK_RECT.size
	backpack_button.texture_normal = BACKPACK_TEXTURE
	backpack_button.ignore_texture_size = true
	backpack_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	backpack_button.toggle_mode = true
	backpack_button.focus_mode = Control.FOCUS_NONE
	backpack_button.tooltip_text = "Open backpack"
	backpack_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	backpack_button.pressed.connect(toggle)
	add_child(backpack_button)


func _build_item_list() -> void:
	item_panel = PanelContainer.new()
	item_panel.name = "BackpackItemList"
	item_panel.position = LIST_RECT.position
	item_panel.size = LIST_RECT.size
	item_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#17231ff5")
	panel_style.border_color = Color("#d1ac55")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	item_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(item_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 6)
	item_panel.add_child(margin)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 3)
	margin.add_child(contents)
	var heading_row := HBoxContainer.new()
	var heading := Label.new()
	heading.text = "BACKPACK"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", Color("#f6e7bc"))
	heading_row.add_child(heading)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(24, 20)
	close_button.pressed.connect(set_open.bind(false))
	heading_row.add_child(close_button)
	contents.add_child(heading_row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	contents.add_child(scroll)
	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 2)
	scroll.add_child(item_list)
	item_panel.visible = false


func _rebuild_item_rows() -> void:
	for child in item_list.get_children(): child.queue_free()
	quantity_labels.clear(); item_buttons.clear()
	keks_quantity_label = null; bananas_quantity_label = null; water_quantity_label = null
	for value in catalog_data.get("items", []):
		if not value is Dictionary: continue
		var item: Dictionary = value
		var item_id := str(item.get("id", ""))
		var quantity_label := _add_item_row(item)
		quantity_labels[item_id] = quantity_label
		if item_id == "keks": keks_quantity_label = quantity_label
		elif item_id == "bananas": bananas_quantity_label = quantity_label
		elif item_id == "water_bottles": water_quantity_label = quantity_label


func _add_item_row(item: Dictionary) -> Label:
	var item_id := str(item.get("id", ""))
	var button := Button.new()
	button.name = "Item_%s" % item_id
	button.custom_minimum_size.y = 29
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Click to consume" if str(item.get("type", "")) in ["nutrient", "hydration"] else "Not consumable"
	button.pressed.connect(request_item.bind(item_id))
	item_list.add_child(button)
	item_buttons[item_id] = button
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = ITEM_ICON_SIZE
	icon.texture = ItemCatalogStoreScript.load_icon(item, town_directory)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var wording := VBoxContainer.new()
	wording.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wording.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wording)
	var title_label := Label.new()
	title_label.text = str(item.get("display_name", "Unnamed item"))
	title_label.add_theme_font_size_override("font_size", 8)
	title_label.add_theme_color_override("font_color", Color("#f8f2dc"))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wording.add_child(title_label)
	var category_label := Label.new()
	category_label.text = _item_detail(item)
	category_label.add_theme_font_size_override("font_size", 6)
	category_label.add_theme_color_override("font_color", Color("#9db6a9"))
	category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wording.add_child(category_label)
	var quantity_label := Label.new()
	quantity_label.custom_minimum_size.x = 30
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_font_size_override("font_size", 10)
	quantity_label.add_theme_color_override("font_color", Color("#f3cf64"))
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(quantity_label)
	return quantity_label


func _build_confirmation_prompt() -> void:
	confirmation_overlay = ColorRect.new()
	confirmation_overlay.name = "ConsumeConfirmation"
	confirmation_overlay.color = Color("#07100dcc")
	confirmation_overlay.size = VIEW_SIZE
	confirmation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirmation_overlay)
	var prompt := PanelContainer.new()
	prompt.position = Vector2(175, 126)
	prompt.size = Vector2(290, 108)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#21332b")
	style.border_color = Color("#d1ac55")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	prompt.add_theme_stylebox_override("panel", style)
	confirmation_overlay.add_child(prompt)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 10)
	prompt.add_child(margin)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	margin.add_child(contents)
	confirmation_label = Label.new()
	confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_label.add_theme_font_size_override("font_size", 9)
	confirmation_label.add_theme_color_override("font_color", Color("#f8f2dc"))
	contents.add_child(confirmation_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	contents.add_child(actions)
	var cancel := Button.new(); cancel.text = "Cancel"; cancel.pressed.connect(_close_confirmation); actions.add_child(cancel)
	var consume := Button.new(); consume.text = "Consume"; consume.add_theme_color_override("font_color", Color("#4bc7a1")); consume.pressed.connect(_confirm_consumption); actions.add_child(consume)
	confirmation_overlay.visible = false


func _confirm_consumption() -> void:
	var item_id := pending_item_id
	_close_confirmation()
	if not item_id.is_empty(): consume_requested.emit(item_id)


func _close_confirmation() -> void:
	pending_item_id = ""
	if confirmation_overlay != null: confirmation_overlay.visible = false


func _item_detail(item: Dictionary) -> String:
	match str(item.get("type", "general")):
		"currency": return "Currency"
		"nutrient": return "Nutrient · +%d" % int(item.get("nutrient_points", 0))
		"hydration": return "Hydration · +%d" % int(item.get("hydration_points", 0))
		_: return "General item"

