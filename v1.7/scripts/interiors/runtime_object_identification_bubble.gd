class_name RuntimeObjectIdentificationBubble
extends Node2D

## Temporary, non-LLM object identification shown after clicking furniture.
## It is screen-sized and anchored above the player's rendered head.

const PLAYER_RENDERED_HEIGHT_WORLD := 13.75
const BUBBLE_FILL := Color("#fff9e8")
const BUBBLE_EDGE := Color("#18241f")
const BUBBLE_TEXT := Color("#101916")
const SAFE_TOP := 43.0
const SAFE_BOTTOM := 58.0
const SAFE_MARGIN := 8.0

var player_node: Node2D
var message := ""
var seconds_remaining := 0.0


func _ready() -> void:
	z_index = 17
	visible = false


func show_object(player_value: Node2D, text_value: String, duration := 2.6) -> void:
	player_node = player_value
	message = text_value.strip_edges()
	seconds_remaining = maxf(duration, 0.1)
	visible = not message.is_empty()
	queue_redraw()


func hide_bubble() -> void:
	visible = false
	seconds_remaining = 0.0
	message = ""
	queue_redraw()


func _process(delta: float) -> void:
	if not visible: return
	seconds_remaining -= delta
	if seconds_remaining <= 0.0 or not is_instance_valid(player_node):
		hide_bubble()
		return
	queue_redraw()


func _draw() -> void:
	if not visible or not is_instance_valid(player_node): return
	var world_to_screen := get_viewport().get_canvas_transform()
	var player_screen: Vector2 = world_to_screen * player_node.global_position
	var camera_scale := world_to_screen.x.length()
	var player_head := player_screen + Vector2(0, -PLAYER_RENDERED_HEIGHT_WORLD * camera_scale)
	var font := ThemeDB.fallback_font
	var text_width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var bubble_size := Vector2(clampf(text_width + 18.0, 54.0, 240.0), 29.0)
	var viewport_size := get_viewport().get_visible_rect().size
	var centre := player_head + Vector2(0, -bubble_size.y * 0.5 - 5.0)
	centre.x = clampf(centre.x, SAFE_MARGIN + bubble_size.x * 0.5, viewport_size.x - SAFE_MARGIN - bubble_size.x * 0.5)
	centre.y = clampf(centre.y, SAFE_TOP + bubble_size.y * 0.5, viewport_size.y - SAFE_BOTTOM - bubble_size.y * 0.5)
	draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())
	var bubble := Rect2(centre - bubble_size * 0.5, bubble_size)
	draw_rect(bubble.grow(1.5), Color(0.02, 0.05, 0.04, 0.32), true)
	draw_rect(bubble, BUBBLE_FILL, true)
	draw_rect(bubble, BUBBLE_EDGE, false, 2.0)
	var tail_x := clampf(player_head.x, bubble.position.x + 7.0, bubble.end.x - 7.0)
	var tail := PackedVector2Array([Vector2(tail_x - 4.0, bubble.end.y), Vector2(tail_x + 4.0, bubble.end.y), player_head])
	draw_colored_polygon(tail, BUBBLE_FILL)
	draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), BUBBLE_EDGE, 2.0)
	var displayed := message
	if text_width > 220.0:
		displayed = message.left(34).strip_edges() + "…"
		text_width = font.get_string_size(displayed, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var text_position := Vector2(bubble.position.x + (bubble_size.x - text_width) * 0.5, bubble.position.y + 19.0)
	draw_string(font, text_position, displayed, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BUBBLE_TEXT)
