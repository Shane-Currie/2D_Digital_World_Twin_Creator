class_name RuntimeSpeedometerGauge
extends Control

## Compact car-style instrument: needle/large digits show actual speed;
## the selected cruise speed sits in the centre of the dial.
var actual_kmh := 0
var cruise_kmh := 0
var maximum_kmh := 200
var gear := "D"

const PANEL := Color("#172923ef")
const BORDER := Color("#86aa9b")
const DIAL := Color("#5b776e")
const ACTIVE := Color("#68d7b5")
const NEEDLE := Color("#f3bc75")
const TEXT := Color("#f8f2dc")


func _ready() -> void:
	custom_minimum_size = Vector2(212, 98)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func update_readings(actual: float, selected: float, maximum: float, selected_gear: String) -> void:
	var next_actual := roundi(actual)
	var next_cruise := roundi(selected)
	var next_maximum := maxi(1, roundi(maximum))
	if actual_kmh == next_actual and cruise_kmh == next_cruise and maximum_kmh == next_maximum and gear == selected_gear:
		return
	actual_kmh = next_actual
	cruise_kmh = next_cruise
	maximum_kmh = next_maximum
	gear = selected_gear
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)
	var centre := Vector2(55, 53)
	var radius := 39.0
	var start_angle := deg_to_rad(150.0)
	var sweep := deg_to_rad(240.0)
	draw_arc(centre, radius, start_angle, start_angle + sweep, 32, DIAL, 5.0, true)
	var fraction := clampf(float(actual_kmh) / float(maximum_kmh), 0.0, 1.0)
	if fraction > 0.0:
		draw_arc(centre, radius, start_angle, start_angle + sweep * fraction, 32, ACTIVE, 5.0, true)
	for index in range(11):
		var angle := start_angle + sweep * float(index) / 10.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(centre + direction * 30.0, centre + direction * 34.0, TEXT, 1.0, true)
	var font := ThemeDB.fallback_font
	for index in range(5):
		var angle := start_angle + sweep * float(index) / 4.0
		var label_position := centre + Vector2(cos(angle), sin(angle)) * 47.0
		var caption := str(roundi(float(maximum_kmh) * float(index) / 4.0))
		draw_string(font, label_position + Vector2(-float(caption.length()) * 2.5, 3.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, TEXT)
	var needle_angle := start_angle + sweep * fraction
	draw_line(centre, centre + Vector2(cos(needle_angle), sin(needle_angle)) * 28.0, NEEDLE, 2.0, true)
	draw_circle(centre, 3.0, NEEDLE)
	draw_rect(Rect2(29, 34, 54, 42), Color("#12231d"))
	draw_rect(Rect2(29, 34, 54, 42), BORDER, false, 1.0)
	draw_string(font, Vector2(35, 47), "CRUISE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, ACTIVE)
	draw_string(font, Vector2(35, 68), "%03d" % cruise_kmh, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, TEXT)
	draw_string(font, Vector2(111, 23), "ACTUAL SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, ACTIVE)
	draw_string(font, Vector2(110, 57), "%03d" % actual_kmh, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, TEXT)
	draw_string(font, Vector2(112, 73), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, TEXT)
	draw_string(font, Vector2(150, 73), "of %d" % maximum_kmh, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, BORDER)
	draw_rect(Rect2(184, 8, 20, 16), Color("#305449"))
	draw_string(font, Vector2(190, 21), gear, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, NEEDLE)
