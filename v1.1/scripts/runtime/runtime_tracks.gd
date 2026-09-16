class_name RuntimeTracks
extends Node2D

var marks: Array[Dictionary] = []
var timer := 0.0
var alternate_foot := false


func update_tracks(delta: float, actor: Node2D, moving: bool, driving: bool, grass_test: Callable) -> void:
	timer -= delta
	for mark in marks:
		mark.age += delta
	while not marks.is_empty() and float(marks[0].age) > 180.0:
		marks.pop_front()
	if moving and timer <= 0.0 and grass_test.call(actor.position):
		timer = 0.13 if driving else 0.25
		if driving:
			var side := Vector2.DOWN.rotated(actor.rotation) * 6.0
			_add(actor.position + side, "tire")
			_add(actor.position - side, "tire")
		else:
			alternate_foot = not alternate_foot
			_add(actor.position + Vector2(3 if alternate_foot else -3, 0), "foot")
	queue_redraw()


func _add(position: Vector2, kind: String) -> void:
	marks.append({"position": position, "kind": kind, "age": 0.0})
	if marks.size() > 1200:
		marks.pop_front()


func _draw() -> void:
	for mark in marks:
		var alpha := clampf(1.0 - float(mark.age) / 180.0, 0.0, 0.55)
		if mark.kind == "tire":
			draw_circle(mark.position, 2.0, Color(0.18, 0.13, 0.09, alpha))
		else:
			draw_circle(mark.position, 1.5, Color(0.22, 0.15, 0.1, alpha))
