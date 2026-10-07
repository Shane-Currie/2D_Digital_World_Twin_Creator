extends VBoxContainer

## Persistent tool pages: Back changes visibility, not the creator's edits.
signal page_changed(page_id: String)
var pages: Dictionary = {}
var current_page := ""
var back_button: Button
var heading: Label
var hub_scroll: ScrollContainer
var tiles: GridContainer
var page_scroll: ScrollContainer
var page_host: VBoxContainer
var home_title := "Tools"

func setup(title: String, columns := 2) -> void:
	home_title = title
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var bar := HBoxContainer.new()
	add_child(bar)
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(92, 36)
	back_button.pressed.connect(show_home)
	bar.add_child(back_button)
	heading = Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(heading)
	hub_scroll = ScrollContainer.new()
	hub_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(hub_scroll)
	tiles = GridContainer.new()
	tiles.columns = columns
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("h_separation", 10)
	tiles.add_theme_constant_override("v_separation", 10)
	hub_scroll.add_child(tiles)
	page_scroll = ScrollContainer.new()
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page_scroll)
	page_host = VBoxContainer.new()
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(page_host)
	show_home()

func add_page(id_value: String, title: String, hint: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = "ToolPage_" + id_value
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	page.set_meta("title", title)
	page.hide()
	page_host.add_child(page)
	pages[id_value] = page
	var tile := Button.new()
	tile.name = "ToolTile_" + id_value
	tile.text = title + "\n" + hint
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.custom_minimum_size = Vector2(145, 88)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203b32")
	style.border_color = Color("426b59")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	tile.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("2f5847")
	hover.border_color = Color("58d5ad")
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("focus", hover)
	tile.pressed.connect(open_page.bind(id_value))
	tiles.add_child(tile)
	return page

func open_page(id_value: String) -> void:
	if not pages.has(id_value): return
	_bound_form(pages[id_value])
	for page in pages.values(): page.hide()
	pages[id_value].show()
	current_page = id_value
	heading.text = str(pages[id_value].get_meta("title"))
	hub_scroll.hide()
	page_scroll.show()
	back_button.show()
	page_scroll.scroll_vertical = 0
	page_changed.emit(id_value)
	# Some tools reparent shared forms in page_changed; compact those too.
	_bound_form(pages[id_value])

func _bound_form(node: Node) -> void:
	preload("res://scripts/app/navigation/compact_form.gd").apply(node)

func show_home() -> void:
	for page in pages.values(): page.hide()
	current_page = ""
	if heading == null: return
	heading.text = home_title
	hub_scroll.show()
	page_scroll.hide()
	back_button.hide()
	page_changed.emit("")
