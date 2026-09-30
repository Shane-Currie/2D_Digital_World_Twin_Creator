extends SceneTree

const Population = preload("res://scripts/runtime/runtime_population.gd")
const ConversationLayer = preload("res://scripts/npcs/runtime_conversation_layer.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var population = Population.new()
	var eastbound := _walker(1, Vector2(-5, 0), Vector2(30, 0), false)
	var westbound := _walker(2, Vector2(5, 0), Vector2(-30, 0), false)
	population.agents.clear()
	population.agents.append(eastbound)
	population.agents.append(westbound)
	population._rebuild_walker_cells()
	var east_direction: Vector2 = population._walker_avoidance_direction(eastbound, Vector2.RIGHT)
	var west_direction: Vector2 = population._walker_avoidance_direction(westbound, Vector2.LEFT)
	assert(absf(east_direction.y) > 0.1 and absf(west_direction.y) > 0.1, "Head-on walkers did not attempt to step around each other.")
	assert(signf(east_direction.y) != signf(west_direction.y), "Head-on walkers chose the same world-space passing side.")
	var minimum_gap := INF
	for _step in 30:
		population._rebuild_walker_cells()
		east_direction = population._walker_avoidance_direction(eastbound, Vector2(eastbound.position).direction_to(Vector2(eastbound.target)))
		west_direction = population._walker_avoidance_direction(westbound, Vector2(westbound.position).direction_to(Vector2(westbound.target)))
		eastbound.position = Vector2(eastbound.position) + east_direction
		westbound.position = Vector2(westbound.position) + west_direction
		minimum_gap = minf(minimum_gap, Vector2(eastbound.position).distance_to(Vector2(westbound.position)))
	assert(Vector2(eastbound.position).x > Vector2(westbound.position).x, "Head-on walkers failed to pass one another.")
	assert(minimum_gap >= 3.0, "Head-on walkers still overlapped while passing.")
	var overlapping_a := _walker(10, Vector2.ZERO, Vector2(30, 0), false)
	var overlapping_b := _walker(11, Vector2.ZERO, Vector2(30, 0), false)
	population.agents.clear()
	population.agents.append(overlapping_a)
	population.agents.append(overlapping_b)
	population._rebuild_walker_cells()
	var escape_a: Vector2 = population._walker_avoidance_direction(overlapping_a, Vector2.RIGHT)
	var escape_b: Vector2 = population._walker_avoidance_direction(overlapping_b, Vector2.RIGHT)
	assert(signf(escape_a.y) != signf(escape_b.y), "Exactly overlapping walkers did not choose separate escape directions.")

	var crossing_walker := _walker(3, Vector2(-5, 0), Vector2(30, 0), true)
	westbound.position = Vector2(3, 0)
	population.agents.clear()
	population.agents.append(crossing_walker)
	population.agents.append(westbound)
	population._rebuild_walker_cells()
	var crossing_direction: Vector2 = population._walker_avoidance_direction(crossing_walker, Vector2.RIGHT)
	assert(is_zero_approx(crossing_direction.y), "Avoidance incorrectly pushed a pedestrian sideways out of a road crossing.")
	assert(crossing_direction.x > 0.0 and crossing_direction.x < 1.0, "A crossing pedestrian did not slow to retain a safe gap.")
	var robot_height_agent := _walker(4, Vector2.ZERO, Vector2.RIGHT, false)
	robot_height_agent.kind = "robot"
	population.agents.append(robot_height_agent)
	assert(population.conversation_target_height(0) > 0.0, "The conversation bubble lost the NPC rendered height.")
	assert(population.conversation_target_height(2) > population.conversation_target_height(0), "The NPR reply bubble did not account for the NPR's taller rendered artwork.")

	var layer = ConversationLayer.new()
	assert(ConversationLayer.BUBBLE_FONT_SIZE >= 13 and ConversationLayer.BUBBLE_MINIMUM_SIZE.y >= 24.0, "Conversation text presentation is still too small.")
	var ordinary_head := Vector2(320, 150)
	var ordinary_centre: Vector2 = layer.target_bubble_centre(ordinary_head, Vector2(640, 360))
	var ordinary_bubble := Rect2(ordinary_centre - ConversationLayer.BUBBLE_MINIMUM_SIZE * 0.5, ConversationLayer.BUBBLE_MINIMUM_SIZE)
	assert(ordinary_bubble.end.y < ordinary_head.y, "The NPC/NPR speech bubble is not floating above the character's head.")
	var top_centre: Vector2 = layer.target_bubble_centre(Vector2(4, 4), Vector2(640, 360))
	var safe_rect: Rect2 = layer._safe_screen_rect(Vector2(640, 360))
	var bubble_rect := Rect2(top_centre - ConversationLayer.BUBBLE_MINIMUM_SIZE * 0.5, ConversationLayer.BUBBLE_MINIMUM_SIZE)
	assert(safe_rect.encloses(bubble_rect), "The NPC/NPR conversation bubble was not clamped clear of the screen HUD.")
	var complete_sentence := "I'm doing well, thanks for asking; I was just heading toward the riverside shops before going home for dinner this evening."
	var sentence_layout: Dictionary = layer._bubble_layout(complete_sentence)
	var sentence_centre: Vector2 = layer._bubble_centre_for_size(Vector2(320, 150), Vector2(640, 360), sentence_layout.size)
	var sentence_bubble := Rect2(sentence_centre - Vector2(sentence_layout.size) * 0.5, Vector2(sentence_layout.size))
	assert(sentence_layout.lines.size() > 1 and safe_rect.encloses(sentence_bubble), "A complete short sentence did not wrap inside the HUD-safe speech bubble area.")

	population.free()
	layer.free()
	print("WALKER AVOIDANCE AND BUBBLE PASSED: walkers pass safely, and complete NPC/NPR sentences wrap above the rendered head inside the HUD-safe screen area.")
	quit()


func _walker(walker_id: int, position: Vector2, target: Vector2, crossing: bool) -> Dictionary:
	return {
		"kind": "person",
		"walker_id": walker_id,
		"position": position,
		"target": target,
		"route_layer": 0,
		"route_crossing": crossing,
		"route_bridge": false,
		"route_tunnel": false
	}
