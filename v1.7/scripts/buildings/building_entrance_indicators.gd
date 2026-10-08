extends Node2D

## Small independent overlay: animating entrances must not redraw the town.
var pointing_time := 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	pointing_time = fmod(pointing_time+delta,1000.0)
	queue_redraw()

func _draw() -> void:
	get_parent()._draw_custom_building_entrances(self,pointing_time)
