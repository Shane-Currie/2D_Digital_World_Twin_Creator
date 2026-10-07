extends VBoxContainer

signal edited

const Store = preload("res://scripts/npcs/lore/game_lore_store.gd")
var town_directory := ""
var store := Store.new()
var data: Dictionary = Store.empty_data()
var data_ready := false
var status: Label
var preview: TextEdit
var upload_button: Button
var example_button: Button
var remove_button: Button
var dialog: FileDialog

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var help := Label.new()
	help.text = "Optional fictional background for all NPC/NPR conversations, indoors and outdoors. Upload saves immediately; reopen Play test to load the lore at startup. No LLM is needed to edit lore."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	var actions := HBoxContainer.new()
	add_child(actions)
	upload_button = _button("Upload / replace .txt",_choose_file)
	example_button = _button("Use example lore",func(): import_file(Store.EXAMPLE_PATH))
	remove_button = _button("Remove lore",_remove)
	for button in [upload_button,example_button,remove_button]: actions.add_child(button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	preview = TextEdit.new()
	preview.editable = false
	preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	preview.custom_minimum_size.y = 300
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(preview)
	dialog = FileDialog.new()
	dialog.title = "Choose game lore text"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.txt ; UTF-8 game lore"])
	dialog.file_selected.connect(import_file)
	add_child(dialog)
	configure(town_directory)

func _button(title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	return button

func configure(directory: String) -> void:
	town_directory = directory
	data_ready = false
	if status == null: return
	var usable := FileAccess.file_exists(directory.path_join("town.json"))
	upload_button.disabled = not usable
	example_button.disabled = not usable
	remove_button.disabled = true
	preview.text = ""
	if not usable:
		status.text = "Choose or create a town project above before adding lore. Lore is optional."
		return
	_refresh(store.load_from_town(directory))

func _refresh(result: Dictionary) -> void:
	data_ready = false
	status.modulate = Color("efc56c") if not result.ok or not result.get("warnings",[]).is_empty() else Color.WHITE
	if not result.ok:
		status.text = result.message
		return
	data = JSON.parse_string(JSON.stringify(result.data))
	data_ready = _has_active_town() and result.get("warnings", []).is_empty()
	preview.text = result.text
	remove_button.disabled = result.data.lore.is_empty()
	var warnings: Array = result.get("warnings",[])
	status.text = "\n".join(warnings) if not warnings.is_empty() else str(result.get("message","Loaded: " + str(result.data.lore.get("original_filename","No lore selected. Conversations still work normally."))))

func _choose_file() -> void:
	dialog.popup_centered_ratio(0.7)

func import_file(path: String) -> void:
	if upload_button.disabled: return
	var previous := data.duplicate(true)
	var result := store.import_text(town_directory,path)
	_refresh(result)
	if result.ok and previous != data: edited.emit()

func _remove() -> void:
	var previous := data.duplicate(true)
	var result := store.remove_from_town(town_directory)
	_refresh(result)
	if result.ok and previous != data: edited.emit()

func snapshot_state() -> Dictionary:
	if not data_ready or not _has_active_town(): return {}
	var loaded := store.load_from_town(town_directory)
	if not loaded.ok or not loaded.get("warnings", []).is_empty(): return {}
	return {"directory": town_directory, "data": JSON.parse_string(JSON.stringify(loaded.data))}

func restore_state(snapshot: Dictionary) -> Dictionary:
	if not is_instance_valid(status) or not is_instance_valid(preview):
		return {"ok": false, "message": "Open the lore editor before restoring its settings."}
	if not _has_active_town() or not _snapshot_matches_town(snapshot):
		return {"ok": false, "message": "Lore Undo belongs to a different or unavailable town."}
	if not snapshot.get("data") is Dictionary or not Store._valid(snapshot.data):
		return {"ok": false, "message": "Lore Undo data is invalid; current settings are preserved."}
	var current := store.load_from_town(town_directory)
	if not current.ok: return current
	# Removal/import keeps content-addressed copies. Repoint only the metadata,
	# after checking the original text still exists and has not been altered.
	if not snapshot.data.lore.is_empty():
		var text_check := Store._read_text(town_directory.path_join(snapshot.data.lore.relative_path))
		if not text_check.ok: return text_check
		if str(text_check.text).sha256_text() != snapshot.data.lore.sha256:
			return {"ok": false, "message": "The saved lore copy changed; Undo kept the current settings."}
	var restored := store._save(town_directory, snapshot.data)
	if not restored.ok: return restored
	_refresh(store.load_from_town(town_directory))
	status.text = "Game lore restored. Copied text files are kept; reopen Play test to apply."
	return {"ok": true, "message": status.text}

func _has_active_town() -> bool:
	return not town_directory.is_empty() and FileAccess.file_exists(town_directory.path_join("town.json"))

func _snapshot_matches_town(snapshot: Dictionary) -> bool:
	if not snapshot.get("directory") is String or str(snapshot.directory).is_empty(): return false
	var active := ProjectSettings.globalize_path(town_directory).simplify_path().replace("\\", "/").trim_suffix("/")
	var previous := ProjectSettings.globalize_path(str(snapshot.directory)).simplify_path().replace("\\", "/").trim_suffix("/")
	return active.nocasecmp_to(previous) == 0
