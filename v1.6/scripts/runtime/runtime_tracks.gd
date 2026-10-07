class_name RuntimeTracks
extends Node2D

var marks: Array[Dictionary] = []
var timer := 0.0


func update_tracks(delta: float, actor: Node2D, moving: bool, driving: bool, grass_test: Callable) -> void:
	timer -= delta
	for mark in marks:
		mark.age += delta
	while not marks.is_empty() and float(marks[0].age) > 180.0:
		marks.pop_front()
	# The user requested clean walking surfaces. Only the occupied wagon leaves
	# temporary tyre marks on grass; walking never creates footprint marks.
	if driving and moving and timer <= 0.0 and grass_test.call(actor.position):
		timer = 0.13
		var side := Vector2.DOWN.rotated(actor.rotation) * 6.0
		_add(actor.position + side, "tire")
		_add(actor.position - side, "tire")
	queue_redraw()


func _add(position: Vector2, kind: String) -> void:
	marks.append({"position": position, "kind": kind, "age": 0.0})
	if marks.size() > 1200:
		marks.pop_front()


func _draw() -> void:
	for mark in marks:
		var alpha := clampf(1.0 - float(mark.age) / 180.0, 0.0, 0.55)
		draw_circle(mark.position, 2.0, Color(0.18, 0.13, 0.09, alpha))
