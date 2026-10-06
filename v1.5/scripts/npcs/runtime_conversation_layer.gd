class_name RuntimeConversationLayer
extends Node2D

## Screen-safe NPC/NPR speech presentation. The Ollama adapter can provide text,
## but this layer only draws it and has no access to game state.

const BUBBLE_FILL := Color("#fff9e8")
const BUBBLE_EDGE := Color("#18241f")
const BUBBLE_TEXT := Color("#101916")
const BUBBLE_FONT_SIZE := 13
const BUBBLE_MINIMUM_SIZE := Vector2(40.0, 24.0)
const BUBBLE_MAXIMUM_WIDTH := 210.0
const BUBBLE_LINE_HEIGHT := 16.0
const SAFE_SCREEN_MARGIN := 8.0
const SAFE_SCREEN_TOP := 43.0
const SAFE_SCREEN_BOTTOM := 58.0

var population: Node2D
var target_index := -1
var target_text := ""


func _ready() -> void:
	z_index = 15
	visible = false


func start(_player_node: Node2D, population_node: Node2D, agent_index: int) -> void:
	population = population_node
	target_index = agent_index
	target_text = ""
	visible = true
	queue_redraw()


func say_hi() -> void:
	show_reply("Hi")


func show_reply(text_value: String) -> void:
	if target_index < 0:
		return
	target_text = text_value.strip_edges()
	queue_redraw()


func finish() -> void:
	visible = false
	target_index = -1
	target_text = ""
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible or population == null:
		return
	var target_position: Vector2 = population.conversation_target_position(target_index)
	if target_position == Vector2.INF:
		return
	# Speech is interface information, so keep it a stable screen size instead
	# of letting the close conversation camera enlarge and crop it like scenery.
	var world_to_screen := get_viewport().get_canvas_transform()
	var target_screen: Vector2 = world_to_screen * target_position
	var camera_scale := world_to_screen.x.length()
	var target_height := float(population.conversation_target_height(target_index)) * camera_scale
	var target_head := target_screen + Vector2(0, -target_height)
	var viewport_size := get_viewport().get_visible_rect().size
	var layout := _bubble_layout(target_text)
	var bubble_centre := _bubble_centre_for_size(target_head, viewport_size, layout.size)
	draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())
	if not target_text.is_empty():
		_draw_bubble(target_head, bubble_centre, layout)


func target_bubble_centre(target_head: Vector2, viewport_size: Vector2 = Vector2(640, 360)) -> Vector2:
	return _bubble_centre_for_size(target_head, viewport_size, BUBBLE_MINIMUM_SIZE)


func _bubble_centre_for_size(target_head: Vector2, viewport_size: Vector2, bubble_size: Vector2) -> Vector2:
	var target_centre := target_head + Vector2(0, -bubble_size.y * 0.5 - 5.0)
	var safe_rect := _safe_screen_rect(viewport_size)
	return _clamp_bubble_centre(target_centre, safe_rect, bubble_size)


func _safe_screen_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(
		Vector2(SAFE_SCREEN_MARGIN, SAFE_SCREEN_TOP),
		Vector2(maxf(1.0, viewport_size.x - SAFE_SCREEN_MARGIN * 2.0), maxf(1.0, viewport_size.y - SAFE_SCREEN_TOP - SAFE_SCREEN_BOTTOM))
	)


func _clamp_bubble_centre(centre: Vector2, safe_rect: Rect2, bubble_size: Vector2 = BUBBLE_MINIMUM_SIZE) -> Vector2:
	var half_size := bubble_size * 0.5
	return Vector2(
		clampf(centre.x, safe_rect.position.x + half_size.x, safe_rect.end.x - half_size.x),
		clampf(centre.y, safe_rect.position.y + half_size.y, safe_rect.end.y - half_size.y)
	)


func _bubble_layout(text_value: String) -> Dictionary:
	var font := ThemeDB.fallback_font
	var lines: Array[String] = []
	var current := ""
	for word in text_value.split(" ", false):
		var candidate := str(word) if current.is_empty() else "%s %s" % [current, word]
		if not current.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FONT_SIZE).x > BUBBLE_MAXIMUM_WIDTH - 18.0:
			lines.append(current)
			current = str(word)
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	if lines.is_empty():
		lines.append("…")
	var text_width := 0.0
	for line in lines:
		text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FONT_SIZE).x)
	var bubble_size := Vector2(clampf(text_width + 18.0, BUBBLE_MINIMUM_SIZE.x, BUBBLE_MAXIMUM_WIDTH), maxf(BUBBLE_MINIMUM_SIZE.y, lines.size() * BUBBLE_LINE_HEIGHT + 9.0))
	return {"lines": lines, "size": bubble_size}


func _draw_bubble(speaker_anchor: Vector2, bubble_centre: Vector2, layout: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var bubble_size: Vector2 = layout.size
	var bubble := Rect2(bubble_centre - bubble_size * 0.5, bubble_size)
	draw_rect(bubble.grow(1.5), Color(0.02, 0.05, 0.04, 0.32), true)
	draw_rect(bubble, BUBBLE_FILL, true)
	draw_rect(bubble, BUBBLE_EDGE, false, 2.0)
	var tail_start_x := clampf(speaker_anchor.x, bubble.position.x + 6.0, bubble.end.x - 6.0)
	var tail := PackedVector2Array([
		Vector2(tail_start_x - 4.0, bubble.end.y), Vector2(tail_start_x + 4.0, bubble.end.y), speaker_anchor
	])
	draw_colored_polygon(tail, BUBBLE_FILL)
	draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), BUBBLE_EDGE, 2.0)
	var lines: Array = layout.lines
	for index in lines.size():
		var line := str(lines[index])
		var text_width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FONT_SIZE).x
		var text_position := Vector2(bubble.position.x + (bubble_size.x - text_width) * 0.5, bubble.position.y + 16.0 + index * BUBBLE_LINE_HEIGHT)
		draw_string(font, text_position, line, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FONT_SIZE, BUBBLE_TEXT)
