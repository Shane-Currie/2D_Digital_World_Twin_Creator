extends RefCounted

## Single-line controls must not grow to the height of a wrapped neighbour.
## Keep genuine multiline notes, tool tiles, thumbnails and map canvases intact.
static func apply(node: Node) -> void:
	if node is Window: return
	if node is OptionButton:
		node.fit_to_longest_item=false
		node.add_theme_constant_override("icon_max_width",24)
		node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		compact_height(node,38)
	elif node is Button and not str(node.name).begins_with("ToolTile_"):
		# Wrapping before HBox layout assigns a width can make one word hundreds
		# of pixels tall, stretching the adjacent dropdown/text field with it.
		node.autowrap_mode=TextServer.AUTOWRAP_OFF
		node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		node.tooltip_text=node.text if node.tooltip_text.is_empty() else node.tooltip_text
		# Ellipsis removes text from Godot's minimum-width calculation. Reserve
		# a readable button width so Save/Upload/Add do not collapse to a sliver.
		var label_width: float=node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x+24
		var minimum_width:=38 if node.text.strip_edges().length()<=3 else 76
		node.custom_minimum_size.x=maxf(node.custom_minimum_size.x,clampf(label_width,minimum_width,180))
		compact_height(node,38)
	elif node is LineEdit:
		node.expand_to_text_length=false
		compact_height(node,34)
	elif node is SpinBox:
		compact_height(node,36)
	for child in node.get_children(): apply(child)

static func compact_height(control: Control, minimum: float) -> void:
	control.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	# Explicit 52px image dropdowns remain usable; plain fields stay one line.
	control.custom_minimum_size.y=clampf(control.custom_minimum_size.y,minimum,56)
