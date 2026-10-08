extends Control

signal trade_accepted(quote: Dictionary)
signal notice_requested(message: String)
const Service = preload("res://scripts/npcs/traders/trade_service.gd")
const Catalog = preload("res://scripts/inventory/item_catalog_store.gd")
var inventory
var catalog: Dictionary = {}
var profile: Dictionary = {}
var npc_id := ""
var directory := ""
var trader_name := ""
var pending: Dictionary = {}
var panel: PanelContainer
var rows: VBoxContainer
var confirmation: VBoxContainer
var confirmation_text: Label
var title: Label
var status: Label

func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = 10
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	panel.position = Vector2(100, 64)
	panel.size = Vector2(440, 225)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("25382e")
	style.set_content_margin_all(10)
	style.set_border_width_all(1)
	style.border_color = Color("a1bb89")
	panel.add_theme_stylebox_override("panel", style)
	panel.add_theme_font_size_override("font_size", 10)
	add_child(panel)
	var contents := VBoxContainer.new()
	panel.add_child(contents)
	title = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 115
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	confirmation = VBoxContainer.new()
	contents.add_child(confirmation)
	confirmation_text = Label.new()
	confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation.add_child(confirmation_text)
	var buttons := HBoxContainer.new()
	confirmation.add_child(buttons)
	_button(buttons, "Accept purchase", _accept)
	_button(buttons, "Cancel", cancel_quote)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(status)
	_button(contents, "Close shop", close)
	close()

func _button(parent: Control, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	parent.add_child(button)

func bind_trader(player_inventory, items: Dictionary, town_directory: String, id_value: String, settings: Dictionary, name_value: String) -> void:
	close()
	inventory = player_inventory
	catalog = items
	directory = town_directory
	npc_id = id_value
	profile = settings
	trader_name = name_value

func open() -> void:
	if inventory == null: return
	visible = true
	refresh()

func refresh() -> void:
	title.text = "%s · %s · %d Keks" % [trader_name, profile.get("trade_role", "Trader"), inventory.quantity("keks")]
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for offer in profile.get("offers", []):
		var item := Catalog.find_item(catalog, str(offer.get("item_id", "")))
		if item.is_empty(): continue
		var row := HBoxContainer.new()
		rows.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Catalog.load_icon(item, directory)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s · %d Keks · stock %d" % [item.display_name, offer.get("price_keks", 0), Service.remaining(inventory, npc_id, offer)]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var count := SpinBox.new()
		count.min_value = 1
		count.max_value = 99
		count.value = 1
		count.custom_minimum_size.x = 58
		row.add_child(count)
		_button(row, "Buy", func(): propose(str(item.id), int(count.value)))
	if profile.get("offers", []).is_empty(): status.text = "No items listed for sale."

func propose(item_id: String, count: Variant) -> void:
	open()
	var quoted := Service.quote(inventory, npc_id, profile, catalog, item_id, count)
	if not quoted.ok:
		cancel_quote()
		status.text = quoted.message
		return
	pending = quoted
	confirmation_text.text = "Buy %d %s for %d Keks? You have %d Keks." % [quoted.quantity, quoted.item_name, quoted.total, inventory.quantity("keks")]
	confirmation.show()
	status.text = "Nothing changes until you accept."

func cancel_quote() -> void:
	pending = {}
	confirmation.hide()
	status.text = "Purchase cancelled."

func _accept() -> void:
	if pending.is_empty(): return
	var accepted := pending.duplicate(true)
	# Clear before notifying: double clicks cannot accept the same quote twice.
	cancel_quote()
	trade_accepted.emit(accepted)

func close() -> void:
	visible = false
	pending = {}
	if confirmation != null: confirmation.hide()
