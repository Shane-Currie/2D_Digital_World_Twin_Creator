extends VBoxContainer

signal edited

const Store = preload("res://scripts/environment/tree_settings_store.gd")
var store := Store.new()
var town_directory := ""
var data: Dictionary = Store.defaults()
var data_ready := false
var style_group: VBoxContainer
var upload_group: VBoxContainer
var style_option: OptionButton
var name_edit: LineEdit
var preview: TextureRect
var status: Label
var upload_button: Button
var file_dialog: FileDialog

func _ready() -> void:
	style_group = VBoxContainer.new()
	style_group.name = "TreeStyleControls"
	add_child(style_group)
	var help := Label.new()
	help.text="Choose tree artwork for this town. Bushland has denser trees; grass and clear grassy verges have sparse decorative trees. Roads, paths, buildings, water and playing fields stay clear."
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size",13)
	style_group.add_child(help)
	style_option=OptionButton.new()
	style_option.custom_minimum_size.y=42
	style_option.item_selected.connect(_select_style)
	style_group.add_child(style_option)
	preview=TextureRect.new()
	preview.custom_minimum_size=Vector2(128,128)
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	style_group.add_child(preview)
	upload_group = VBoxContainer.new()
	upload_group.name = "TreeUploadControls"
	add_child(upload_group)
	name_edit=LineEdit.new()
	name_edit.placeholder_text="Custom tree name (optional)"
	name_edit.max_length=80
	upload_group.add_child(name_edit)
	upload_button=Button.new()
	upload_button.text="Upload custom tree PNG…"
	upload_button.pressed.connect(func(): file_dialog.popup_centered_ratio(0.72))
	upload_group.add_child(upload_button)
	var hint := Label.new()
	hint.text="Transparent PNG • up to 2048 × 2048 pixels / 8 MB. Source artwork is copied, not moved. Selection and uploads save immediately; reopen Play test to apply. Fine trees hide in the zoomed-out map view."
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size",12)
	upload_group.add_child(hint)
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",13)
	add_child(status)
	file_dialog=FileDialog.new()
	file_dialog.access=FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters=PackedStringArray(["*.png ; Transparent tree artwork"])
	file_dialog.file_selected.connect(import_image)
	add_child(file_dialog)
	configure(town_directory)

func configure(directory: String) -> void:
	town_directory=directory
	data_ready=false
	if not is_instance_valid(status): return
	var loaded := store.load_from_town(directory)
	data=JSON.parse_string(JSON.stringify(loaded.data))
	var available: bool = loaded.ok and FileAccess.file_exists(directory.path_join("town.json"))
	data_ready = available
	style_option.disabled=not available
	upload_button.disabled=not available
	status.text=loaded.message if available else "Choose a saved town project. " + (str(loaded.message) if not loaded.ok else "")
	_refresh()

func show_tool(tool: String) -> void:
	# The parent hub can offer separate Choose trees and Upload tree buttons.
	if not is_instance_valid(style_group): return
	style_group.visible = tool != "upload"
	upload_group.visible = tool != "style"

func snapshot_state() -> Dictionary:
	if not data_ready or not _has_active_town(): return {}
	var loaded := store.load_from_town(town_directory)
	if not loaded.ok or not Store.valid(loaded.data): return {}
	# Normalize JSON number types, including optional-file defaults, so saving
	# schema_version 1 cannot manufacture a new Undo step by itself.
	return {"directory": town_directory, "data": JSON.parse_string(JSON.stringify(loaded.data))}

func restore_state(snapshot: Dictionary) -> Dictionary:
	if not is_instance_valid(style_option) or not is_instance_valid(status):
		return {"ok": false, "message": "Open the tree editor before restoring its settings."}
	if not _has_active_town() or not _snapshot_matches_town(snapshot):
		return {"ok": false, "message": "Tree Undo belongs to a different or unavailable town."}
	if not snapshot.get("data") is Dictionary or not Store.valid(snapshot.data):
		return {"ok": false, "message": "Tree Undo data is invalid; current settings are preserved."}
	var current := store.load_from_town(town_directory)
	if not current.ok: return current
	# Restore metadata, never delete or rewrite copied artwork. Validate the
	# selected copy before making it active again, preserving corrupt sources.
	for item in snapshot.data.custom_trees:
		if item.id == snapshot.data.tree_style:
			var image_check := Store.read_image(town_directory.path_join(item.relative_path), item.sha256)
			if not image_check.ok: return image_check
	var restored := store.save(town_directory, snapshot.data)
	if not restored.ok: return restored
	data = snapshot.data.duplicate(true)
	data_ready = true
	_refresh()
	status.text = "Tree settings restored. Copied artwork is kept; reopen Play test to apply."
	return {"ok": true, "message": status.text}

func _has_active_town() -> bool:
	return not town_directory.is_empty() and FileAccess.file_exists(town_directory.path_join("town.json"))

func _snapshot_matches_town(snapshot: Dictionary) -> bool:
	if not snapshot.get("directory") is String or str(snapshot.directory).is_empty(): return false
	var active := ProjectSettings.globalize_path(town_directory).simplify_path().replace("\\", "/").trim_suffix("/")
	var previous := ProjectSettings.globalize_path(str(snapshot.directory)).simplify_path().replace("\\", "/").trim_suffix("/")
	return active.nocasecmp_to(previous) == 0

func _refresh() -> void:
	style_option.clear()
	for id in Store.BUILT_INS:
		style_option.add_item(Store.BUILT_INS[id])
		style_option.set_item_metadata(style_option.item_count-1,id)
	for item in data.custom_trees:
		style_option.add_item(item.name+" (custom)")
		style_option.set_item_metadata(style_option.item_count-1,item.id)
	for index in style_option.item_count:
		if style_option.get_item_metadata(index)==data.tree_style: style_option.select(index)
	var custom := store.selected_texture(town_directory,data)
	var built_in := str(data.tree_style) if Store.BUILT_INS.has(data.tree_style) and data.tree_style!="mapped" else "broadleaf"
	preview.texture=custom if custom!=null else load("res://assets/environment/trees/%s.svg" % built_in)

func _select_style(index: int) -> void:
	var next := data.duplicate(true)
	next.tree_style=style_option.get_item_metadata(index)
	var changed := next != data
	var result := store.save(town_directory,next)
	if result.ok: data=next
	_refresh()
	status.text=result.message
	if result.ok and changed: edited.emit()

func import_image(path: String) -> void:
	var previous := data.duplicate(true)
	var result := store.import_image(town_directory,path,name_edit.text)
	if result.ok: configure(town_directory)
	status.text=result.message
	if result.ok and previous != data: edited.emit()
