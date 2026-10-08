extends VBoxContainer
signal changed

const Store = preload("res://scripts/npcs/traders/trader_store.gd")
const Catalog = preload("res://scripts/inventory/item_catalog_store.gd")
var data := Store.empty_data()
var npcs: Dictionary = {}
var catalog: Dictionary = {}
var library: Dictionary = {}
var directory := ""
var selected_id := ""
var selected_offer_id := ""
var load_ok := false
var npc_choice: OptionButton
var enabled_choice: CheckBox
var role_edit: LineEdit
var persona_choice: OptionButton
var item_choice: OptionButton
var stock_spin: SpinBox
var price_spin: SpinBox
var offers_list: ItemList
var status: Label
var location_label: Callable
var stock_rows: VBoxContainer

func setup(town_directory: String, placements: Dictionary, personas: Dictionary, friendly_location: Callable) -> void:
	directory = town_directory
	npcs = placements
	library = personas
	location_label = friendly_location
	var loaded := Store.new().load_from_town(directory)
	var items := Catalog.new().load_from_town(directory)
	load_ok = loaded.ok and items.ok
	if loaded.ok: data = loaded.data
	if items.ok: catalog = items.data
	var heading := Label.new()
	heading.text = "Trader stock and prices"
	add_child(heading)
	var help := Label.new()
	help.text = "Create a Trader NPC in the placement tool above, then set its stock here. Traders use the same human personas as storyline NPCs. Every purchase requires player confirmation."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	npc_choice = OptionButton.new()
	npc_choice.item_selected.connect(_select_npc)
	add_child(npc_choice)
	enabled_choice = CheckBox.new()
	enabled_choice.text = "Trading is open (uncheck to close the shop)"
	add_child(enabled_choice)
	role_edit = LineEdit.new()
	role_edit.placeholder_text = "Trade type, for example Barkeep"
	role_edit.max_length = 80
	add_child(role_edit)
	persona_choice = OptionButton.new()
	add_child(persona_choice)
	refresh_personas(personas)
	var row := HBoxContainer.new()
	add_child(row)
	item_choice = OptionButton.new()
	item_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_choice.get_popup().max_size = Vector2i(0, 400)
	for item in catalog.get("items", []):
		if str(item.id) == "keks": continue
		item_choice.add_icon_item(Catalog.load_icon(item, directory), str(item.display_name))
		item_choice.set_item_metadata(item_choice.item_count - 1, str(item.id))
	row.add_child(item_choice)
	stock_spin = _number(row, "Stock")
	price_spin = _number(row, "Price (Keks)")
	var buttons := HBoxContainer.new()
	add_child(buttons)
	_button(buttons, "Add / update item", _save_offer)
	offers_list = ItemList.new()
	offers_list.custom_minimum_size.y = 150
	offers_list.item_selected.connect(_select_offer)
	add_child(offers_list)
	offers_list.hide()
	var stock_heading:=Label.new(); stock_heading.text="Current stock · edit quantity and price below"; add_child(stock_heading)
	stock_rows=VBoxContainer.new(); stock_rows.name="TraderStockRows"; add_child(stock_rows)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	set_npcs(placements)
	if not load_ok: status.text = str(loaded.get("message", "")) + " " + str(items.get("message", ""))

func _number(parent: HBoxContainer, caption: String) -> SpinBox:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var label := Label.new()
	label.text = caption
	column.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 1000000
	spin.step = 1
	spin.custom_minimum_size.x = 120
	column.add_child(spin)
	return spin

func _button(parent: Control, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)

func refresh_personas(personas: Dictionary) -> void:
	var previous := str(persona_choice.get_item_metadata(persona_choice.selected)) if persona_choice.selected >= 0 else ""
	library = personas
	persona_choice.clear()
	persona_choice.add_item("Use this NPC's assigned persona")
	persona_choice.set_item_metadata(0, "")
	for entry in Store.shared_personas(library).get("personas", []):
		if str(entry.get("actor_kind", "")) != "npc": continue
		persona_choice.add_item(str(entry.name))
		var index := persona_choice.item_count - 1
		persona_choice.set_item_metadata(index, str(entry.id))
		if str(entry.id) == previous: persona_choice.select(index)

func set_npcs(placements: Dictionary, flush_form := true) -> void:
	if flush_form and placements.get("npcs", []).any(func(npc): return str(npc.id) == selected_id): _flush_profile()
	npcs = placements
	npc_choice.clear()
	for npc in npcs.get("npcs", []):
		if Store.npc_role(npc, data) != "trader": continue
		var location: Dictionary = npc.get("location", {})
		var place := str(location_label.call(location)) if str(location.get("space", "")) == "interior" else "Outdoors"
		npc_choice.add_item("%s — %s" % [npc.get("display_name", npc.id), place])
		npc_choice.set_item_metadata(npc_choice.item_count - 1, str(npc.id))
		if str(npc.id) == selected_id: npc_choice.select(npc_choice.item_count - 1)
	selected_id = ""
	if npc_choice.item_count > 0: _select_npc(maxi(0, npc_choice.selected))
	else:
		selected_offer_id=""
		_refresh_offers()
		status.text = "Place a Trader NPC first, then choose it here to set stock."

func set_assigned_persona(npc_id: String, persona_id: String) -> void:
	# The placement form and stock form edit the same assignment, not two personas.
	var profile: Dictionary = data.traders.get_or_add(npc_id, {"enabled": true, "trade_role": "Trader", "offers": []})
	profile.persona_id = persona_id
	if selected_id == npc_id: persona_choice.select(0)

func _flush_profile() -> void:
	if selected_id.is_empty() or not load_ok: return
	var profile: Dictionary = data.traders.get_or_add(selected_id, {"offers": []})
	profile.enabled = enabled_choice.button_pressed
	profile.trade_role = role_edit.text.strip_edges()
	var chosen := str(persona_choice.get_item_metadata(persona_choice.selected)) if persona_choice.selected >= 0 else ""
	for npc in npcs.get("npcs", []):
		if str(npc.id) != selected_id: continue
		if not chosen.is_empty(): npc.persona_id = chosen
		profile.persona_id = str(npc.get("persona_id", "friendly_local"))
	if item_choice != null and item_choice.selected >= 0 and str(item_choice.get_item_metadata(item_choice.selected)) == selected_offer_id:
		for offer in profile.offers:
			if str(offer.item_id) == selected_offer_id:
				offer.stock = int(stock_spin.value)
				offer.price_keks = int(price_spin.value)

func _select_npc(index: int) -> void:
	_flush_profile()
	selected_id = str(npc_choice.get_item_metadata(index))
	selected_offer_id = ""
	var profile: Dictionary = data.traders.get(selected_id, {})
	enabled_choice.button_pressed = bool(profile.get("enabled", false))
	role_edit.text = str(profile.get("trade_role", "Barkeep"))
	persona_choice.select(0)
	for i in persona_choice.item_count:
		if str(persona_choice.get_item_metadata(i)) == str(profile.get("persona_id", "")): persona_choice.select(i)
	_refresh_offers()
	status.text="Edit the stock below, then use the top Save."

func _refresh_offers() -> void:
	offers_list.clear()
	for child in stock_rows.get_children(): stock_rows.remove_child(child); child.queue_free()
	for offer in data.traders.get(selected_id, {}).get("offers", []):
		var item := Catalog.find_item(catalog, str(offer.get("item_id", "")))
		offers_list.add_item("%s — %d in stock — %d Keks each" % [item.get("display_name", offer.get("item_id", "Unknown item")), offer.get("stock", 0), offer.get("price_keks", 0)])
		offers_list.set_item_metadata(offers_list.item_count - 1, offer)
		var row:=HBoxContainer.new(); row.name="Stock_"+str(offer.item_id); stock_rows.add_child(row)
		var label:=Label.new(); label.text=str(item.get("display_name",offer.item_id)); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
		var stock:=_number(row,"Quantity"); stock.value=float(offer.stock)
		var price:=_number(row,"Keks each"); price.value=float(offer.price_keks)
		var owner_id:=selected_id; var item_id:=str(offer.item_id)
		stock.value_changed.connect(func(value): _edit_stock(owner_id,item_id,"stock",int(value)))
		price.value_changed.connect(func(value): _edit_stock(owner_id,item_id,"price_keks",int(value)))
		_button(row,"Remove",func(): _remove_stock(owner_id,item_id))
	if stock_rows.get_child_count()==0:
		var empty:=Label.new(); empty.text="No items added yet. Choose an item and select Add / update item."; empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; stock_rows.add_child(empty)
	preload("res://scripts/app/navigation/compact_form.gd").apply(stock_rows)

func _edit_stock(owner_id: String,item_id: String,field: String,value: int) -> void:
	if owner_id!=selected_id: return
	for offer in data.traders.get(owner_id,{}).get("offers",[]):
		if str(offer.item_id)!=item_id: continue
		offer[field]=value
		if selected_offer_id==item_id:
			if field=="stock": stock_spin.value=value
			else: price_spin.value=value
		status.text="Stock changed. Use the top Save to keep it."; changed.emit(); return

func _remove_stock(owner_id: String,item_id: String) -> void:
	if owner_id!=selected_id: return
	data.traders[owner_id].offers=data.traders[owner_id].offers.filter(func(offer):return str(offer.item_id)!=item_id)
	if selected_offer_id==item_id: selected_offer_id=""
	_refresh_offers()
	status.text="Item removed. Use the top Save to keep it."
	changed.emit()

func _save_offer() -> void:
	if selected_id.is_empty() or not load_ok or item_choice.selected < 0: return
	_flush_profile()
	var offers: Array = data.traders[selected_id].offers
	var item_id := str(item_choice.get_item_metadata(item_choice.selected))
	var replacement := {"item_id": item_id, "stock": int(stock_spin.value), "price_keks": int(price_spin.value)}
	var found := false
	for i in offers.size():
		if str(offers[i].item_id) == item_id:
			offers[i] = replacement
			found = true
	if not found: offers.append(replacement)
	selected_offer_id = item_id
	_refresh_offers()
	status.text = "Item staged. Select the top Save button to keep these settings."
	changed.emit()

func _select_offer(index: int) -> void:
	var offer: Dictionary = offers_list.get_item_metadata(index)
	selected_offer_id = str(offer.item_id)
	for i in item_choice.item_count:
		if str(item_choice.get_item_metadata(i)) == str(offer.item_id): item_choice.select(i)
	stock_spin.value = float(offer.get("stock", 0))
	price_spin.value = float(offer.get("price_keks", 0))

func _remove_offer() -> void:
	var selected := offers_list.get_selected_items()
	if selected.is_empty(): return
	data.traders[selected_id].offers.remove_at(selected[0])
	selected_offer_id = ""
	_refresh_offers()
	changed.emit()

func save(personas: Dictionary) -> Dictionary:
	if not load_ok: return {"ok": false, "message": "Unreadable trader settings were not overwritten."}
	_flush_profile()
	var result := Store.new().save_to_town(directory, data, npcs, catalog, personas)
	status.text = result.message
	return result
