class_name ItemCatalogEditor
extends VBoxContainer

signal status_changed(message: String)

const ItemCatalogStoreScript = preload("res://scripts/inventory/item_catalog_store.gd")
const TEXT := Color("#edf6f1")
const MUTED := Color("#a8bbb2")
const ACCENT := Color("#4bc7a1")
const WARNING := Color("#efc56c")

var store = ItemCatalogStoreScript.new()
var town_directory := ""
var catalog_data: Dictionary = {}
var form_index := -1
var item_option: OptionButton
var name_edit: LineEdit
var type_option: OptionButton
var starting_quantity: SpinBox
var nutrient_points: SpinBox
var hydration_points: SpinBox
var picture_preview: TextureRect
var picture_status: Label
var delete_button: Button
var save_button: Button
var image_dialog: FileDialog


func setup(directory: String) -> Dictionary:
	town_directory = directory
	var load_result := store.load_from_town(town_directory)
	if not load_result.ok:
		return load_result
	catalog_data = load_result.data
	_build()
	_refresh_items()
	return {"ok": true, "message": load_result.message}


func _build() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var help := _label("Keks, bananas and water bottles use the same catalogue as every custom item. Add a name, picture, starting quantity and type. Nutrient and hydration items also need restoration points from 1 to 100.", 12, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)
	item_option = OptionButton.new()
	item_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_option.item_selected.connect(_on_item_selected)
	toolbar.add_child(item_option)
	toolbar.add_child(_button("New item", _new_item))
	delete_button = _button("Delete item", _delete_item)
	toolbar.add_child(delete_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)

	var picture_row := HBoxContainer.new()
	picture_row.add_theme_constant_override("separation", 12)
	form.add_child(picture_row)
	picture_preview = TextureRect.new()
	picture_preview.custom_minimum_size = Vector2(84, 84)
	picture_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture_row.add_child(picture_preview)
	var picture_actions := VBoxContainer.new()
	picture_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture_row.add_child(picture_actions)
	picture_actions.add_child(_button("Choose item picture…", _choose_picture))
	picture_status = _label("", 11, MUTED)
	picture_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	picture_actions.add_child(picture_status)

	name_edit = LineEdit.new()
	name_edit.max_length = 60
	form.add_child(_field("Item name", name_edit))
	type_option = OptionButton.new()
	for entry in [["General item", "general"], ["Currency", "currency"], ["Nutrient consumable", "nutrient"], ["Hydration consumable", "hydration"]]:
		type_option.add_item(entry[0])
		type_option.set_item_metadata(type_option.item_count - 1, entry[1])
	type_option.item_selected.connect(func(_index: int): _update_point_controls())
	form.add_child(_field("Item type", type_option))
	starting_quantity = _spin(0, 1000000, 1)
	form.add_child(_field("Starting quantity", starting_quantity))
	nutrient_points = _spin(0, 100, 1)
	form.add_child(_field("Nutrient points", nutrient_points))
	hydration_points = _spin(0, 100, 1)
	form.add_child(_field("Hydration points", hydration_points))
	var note := _label("Starting quantity is used when this item is first added to a player's save. Existing quantities are never reset when the catalogue is edited.", 11, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(note)
	save_button = _button("Save item catalogue", _save_catalog, true)
	form.add_child(save_button)

	image_dialog = FileDialog.new()
	image_dialog.title = "Choose a picture for this item"
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.filters = PackedStringArray(["*.png ; PNG images", "*.jpg,*.jpeg ; JPEG images", "*.webp ; WebP images"])
	image_dialog.file_selected.connect(_on_picture_selected)
	add_child(image_dialog)


func _refresh_items(selected_id := "") -> void:
	if selected_id.is_empty() and item_option.item_count > 0:
		selected_id = str(item_option.get_item_metadata(item_option.selected))
	item_option.clear()
	var selected_index := 0
	for index in catalog_data.get("items", []).size():
		var item: Dictionary = catalog_data.items[index]
		item_option.add_item("%s · %s" % [str(item.display_name), _type_label(str(item.type))])
		item_option.set_item_metadata(index, str(item.id))
		if str(item.id) == selected_id:
			selected_index = index
	if item_option.item_count > 0:
		item_option.select(selected_index)
		_load_form(selected_index)


func _on_item_selected(index: int) -> void:
	_save_form()
	_load_form(index)


func _load_form(index: int) -> void:
	var items: Array = catalog_data.get("items", [])
	if index < 0 or index >= items.size():
		return
	form_index = index
	var item: Dictionary = items[index]
	name_edit.text = str(item.get("display_name", ""))
	starting_quantity.value = int(item.get("starting_quantity", 0))
	nutrient_points.value = int(item.get("nutrient_points", 0))
	hydration_points.value = int(item.get("hydration_points", 0))
	for option_index in type_option.item_count:
		if str(type_option.get_item_metadata(option_index)) == str(item.get("type", "general")):
			type_option.select(option_index)
			break
	picture_preview.texture = ItemCatalogStoreScript.load_icon(item, town_directory)
	picture_status.text = str(item.get("icon_path", "No picture selected"))
	picture_status.add_theme_color_override("font_color", MUTED if picture_preview.texture != null else WARNING)
	delete_button.disabled = bool(item.get("built_in", false))
	_update_point_controls()


func _save_form() -> void:
	var items: Array = catalog_data.get("items", [])
	if form_index < 0 or form_index >= items.size():
		return
	var item: Dictionary = items[form_index]
	item["display_name"] = name_edit.text.strip_edges()
	item["type"] = str(type_option.get_item_metadata(type_option.selected))
	item["starting_quantity"] = int(starting_quantity.value)
	item["nutrient_points"] = int(nutrient_points.value) if item.type == "nutrient" else 0
	item["hydration_points"] = int(hydration_points.value) if item.type == "hydration" else 0


func _new_item() -> void:
	_save_form()
	var result := store.add_custom_item(catalog_data)
	catalog_data = result.data
	_refresh_items(str(result.item.id))
	status_changed.emit("New item added. Choose its picture and complete the fields.")


func _delete_item() -> void:
	var items: Array = catalog_data.get("items", [])
	if form_index < 0 or form_index >= items.size() or bool(items[form_index].get("built_in", false)):
		return
	items.remove_at(form_index)
	form_index = -1
	_refresh_items()
	status_changed.emit("Custom item removed from the editor. Select Save item catalogue to confirm.")


func _choose_picture() -> void:
	if form_index < 0:
		return
	image_dialog.popup_centered_ratio(0.72)


func _on_picture_selected(path_value: String) -> void:
	var items: Array = catalog_data.get("items", [])
	if form_index < 0 or form_index >= items.size():
		return
	var item: Dictionary = items[form_index]
	var result := store.import_icon(town_directory, str(item.id), path_value)
	if not result.ok:
		status_changed.emit(str(result.message))
		return
	item["icon_path"] = str(result.icon_path)
	picture_preview.texture = ItemCatalogStoreScript.load_icon(item, town_directory)
	picture_status.text = str(result.icon_path)
	picture_status.add_theme_color_override("font_color", ACCENT)
	status_changed.emit(str(result.message))


func _save_catalog() -> bool:
	_save_form()
	var result := store.save_to_town(town_directory, catalog_data)
	if not result.ok:
		status_changed.emit("Could not save the item catalogue: %s" % result.message)
		return false
	_refresh_items(str(item_option.get_item_metadata(item_option.selected)))
	status_changed.emit("Item catalogue saved. Reopen Play test to use the changes.")
	return true


func _update_point_controls() -> void:
	if type_option == null or type_option.selected < 0:
		return
	var type_value := str(type_option.get_item_metadata(type_option.selected))
	nutrient_points.editable = type_value == "nutrient"
	hydration_points.editable = type_value == "hydration"


func _field(caption: String, input: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var caption_label := _label(caption, 12, MUTED)
	caption_label.custom_minimum_size.x = 145
	row.add_child(caption_label)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	return row


func _spin(minimum: float, maximum: float, step_value: float) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step_value
	control.allow_greater = false
	control.allow_lesser = false
	return control


func _button(caption: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	if primary:
		button.add_theme_color_override("font_color", ACCENT)
	return button


func _label(value: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


func _type_label(type_value: String) -> String:
	match type_value:
		"currency": return "Currency"
		"nutrient": return "Nutrient"
		"hydration": return "Hydration"
		_: return "General"
