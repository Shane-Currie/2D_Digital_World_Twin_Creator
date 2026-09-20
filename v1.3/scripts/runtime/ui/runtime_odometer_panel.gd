class_name RuntimeOdometerPanel
extends Control

signal trip_reset_requested()

var total_metres := 0.0
var trip_metres := 0.0
const RESET_RECT := Rect2(157, 14, 48, 25)

const PANEL := Color("#172923ef")
const BORDER := Color("#86aa9b")
const TEXT := Color("#f8f2dc")
const ACCENT := Color("#68d7b5")


func _ready() -> void:
	# Godot's native Button keeps a larger minimum hit target than its text.
	# Give that target its own room so it cannot hang over the panel border.
	custom_minimum_size = Vector2(212, 54)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if RESET_RECT.has_point(event.position) else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and RESET_RECT.has_point(event.position):
		trip_reset_requested.emit()
		accept_event()


func update_readings(total: float, trip: float) -> void:
	if roundi(total) == roundi(total_metres) and roundi(trip) == roundi(trip_metres):
		return
	total_metres = total
	trip_metres = trip
	queue_redraw()


func set_display_state(in_vehicle: bool, map_open: bool) -> void:
	# The car's instrument is not part of the on-foot HUD. Keep it accessible
	# while driving or using the map from inside the car.
	visible = in_vehicle
	position.y = 40.0 if map_open else 140.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)
	draw_rect(RESET_RECT, Color("#305449"))
	draw_rect(RESET_RECT, BORDER, false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, RESET_RECT.position + Vector2(7, 16), "RESET", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, TEXT)
	draw_string(font, Vector2(7, 20), "ODO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, ACCENT)
	draw_string(font, Vector2(46, 20), "%.1f km" % (total_metres / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, TEXT)
	draw_string(font, Vector2(7, 41), "TRIP A", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, ACCENT)
	var trip_text := "%d m" % roundi(trip_metres) if trip_metres < 1000.0 else "%.1f km" % (trip_metres / 1000.0)
	draw_string(font, Vector2(46, 41), trip_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, TEXT)
