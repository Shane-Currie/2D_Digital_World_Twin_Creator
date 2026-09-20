class_name RuntimePopulation
extends Node2D

const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const TrafficFlowScript = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
const CrossingSafetyScript = preload("res://scripts/runtime/pedestrians/runtime_crossing_safety.gd")
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")
const RoadDimensionsScript = preload("res://scripts/roads/road_dimensions.gd")

var agents: Array[Dictionary] = []
var graphs: Dictionary = {}
var rng := RandomNumberGenerator.new()
var driving_side := "left"
var skin_tone_distribution: Dictionary = {}
var traffic_flow = TrafficFlowScript.new()
var crossing_safety = CrossingSafetyScript.new()
var owned_wagon: Node2D
var traffic_obstacles: Array[Node2D] = []
var bridge_corridors: Array[Dictionary] = []
var water_bridge_ids: Dictionary = {}
var active_land_bridge_id := ""
var active_bridge_source_ids: Dictionary = {}
var elapsed := 0.0
var pixels_per_metre := 2.0
var road_tags_by_id: Dictionary = {}
var road_forward_lookup: Dictionary = {}
var ground_check: Callable
var building_segment_check: Callable
var vehicle_road_segments: Array = []
var vehicle_road_cells: Dictionary = {}
var simulation_focus := Vector2.ZERO
var draw_view_bounds := Rect2()
var draw_full_overview := true
var benchmark_agent_updates := false
var benchmark_update_usec: Dictionary = {}
const DISTANT_TRAFFIC_RADIUS := 900.0
const DISTANT_TRAFFIC_INTERVAL := 0.20

const SKIN_TONE_KEYS := ["light_percent", "medium_percent", "dark_percent"]
const SKIN_TONE_COLORS := [
	Color("#e8bd99"), Color("#bd8159"), Color("#70442d")
]
const AGE_GROUPS := ["young", "adult", "older"]
const CAR_VARIANTS := [
	"car_sedan_blue", "car_sedan_red", "car_sedan_silver", "car_sedan_green",
	"car_wagon_white", "car_wagon_blue", "car_wagon_bronze", "car_wagon_grey",
	"car_ute_red", "car_ute_blue", "car_ute_white", "car_ute_green"
]


func setup(navigation: Dictionary, settings: Dictionary, projection: Dictionary, scale: float, cbd_bounds: Dictionary, town_seed: String, map_bounds: Dictionary = {}, features: Array = []) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixels_per_metre = scale
	road_tags_by_id.clear()
	road_forward_lookup.clear()
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) == "road":
			var way_id := str(feature.get("id", ""))
			road_tags_by_id[way_id] = feature.get("tags", {})
			var way_points: Array = feature.get("points", [])
			for point_index in range(way_points.size() - 1):
				var first := ProjectionScript.value_to_location(way_points[point_index])
				var second := ProjectionScript.value_to_location(way_points[point_index + 1])
				road_forward_lookup[_way_segment_key(way_id, first, second)] = true
				road_forward_lookup[_way_segment_key(way_id, second, first)] = false
	rng.seed = hash(town_seed)
	agents.clear()
	driving_side = str(settings.get("road_rules", {}).get("driving_side", "left"))
	skin_tone_distribution = GameSettingsStoreScript.migrate_skin_tones(settings.get("skin_tone_distribution", {}))
	traffic_flow.configure(settings)
	crossing_safety.reset()
	graphs = {
		"traffic": _prepare_graph(navigation.vehicle, projection, scale, cbd_bounds, map_bounds, true),
		"person": _prepare_graph(navigation.pedestrian, projection, scale, cbd_bounds, map_bounds),
		"drone": _prepare_graph(navigation.aerial, projection, scale, cbd_bounds, map_bounds)
	}
	var population: Dictionary = settings.get("population", {})
	_add_population("traffic", int(population.get("traffic_car_count", 0)), int(population.get("cbd_car_percent", 0)), 75.0)
	_add_population("person", int(population.get("pedestrian_count", 0)), int(population.get("cbd_pedestrian_percent", 0)), 30.0)
	_add_population("robot", int(population.get("robot_count", 0)), int(population.get("cbd_robot_percent", 0)), 27.0)
	_add_population("drone", int(population.get("drone_count", 0)), int(population.get("cbd_drone_percent", 0)), 55.0)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	traffic_flow.begin_frame(agents)
	for agent in agents:
		var update_delta := _traffic_update_delta(agent, delta)
		if update_delta <= 0.0:
			continue
		var started := Time.get_ticks_usec() if benchmark_agent_updates else 0
		var previous_position: Vector2 = agent.position
		if str(agent.kind) == "traffic":
			_advance_traffic(agent, update_delta)
			traffic_flow.sync_agent_route(agent)
		else:
			_advance_agent(agent, update_delta)
		agent["moving"] = previous_position.distance_to(agent.position) > 0.1
		if bool(agent.moving) or str(agent.kind) == "drone":
			agent.phase = float(agent.get("phase", 0.0)) + update_delta
		if benchmark_agent_updates:
			var kind := str(agent.kind)
			benchmark_update_usec[kind] = int(benchmark_update_usec.get(kind, 0)) + Time.get_ticks_usec() - started
	queue_redraw()


func set_simulation_focus(position: Vector2) -> void:
	simulation_focus = position


func _traffic_update_delta(agent: Dictionary, delta: float) -> float:
	if str(agent.kind) != "traffic":
		return delta
	var accumulated := float(agent.get("update_accumulator", 0.0)) + delta
	if Vector2(agent.position).distance_squared_to(simulation_focus) <= DISTANT_TRAFFIC_RADIUS * DISTANT_TRAFFIC_RADIUS:
		agent.update_accumulator = 0.0
		return accumulated
	if accumulated < DISTANT_TRAFFIC_INTERVAL:
		agent.update_accumulator = accumulated
		return 0.0
	# Bound one remote movement step, retaining excess time after a stalled frame.
	agent.update_accumulator = maxf(0.0, accumulated - DISTANT_TRAFFIC_INTERVAL)
	return DISTANT_TRAFFIC_INTERVAL


func set_draw_view(position: Vector2, camera_zoom: float, full_overview: bool, viewport_size: Vector2 = Vector2(640.0, 360.0)) -> void:
	draw_full_overview = full_overview
	if camera_zoom <= 0.0:
		return
	var half_visible := viewport_size * 0.5 / camera_zoom
	draw_view_bounds = Rect2(position - half_visible, half_visible * 2.0).grow(70.0)


func _draws_position(position: Vector2) -> bool:
	return draw_full_overview or draw_view_bounds.has_point(position)


func set_gameplay_obstacles(obstacles: Array[Node2D]) -> void:
	traffic_obstacles = obstacles
	owned_wagon = obstacles[1] if obstacles.size() > 1 else null


func set_ground_check(check: Callable) -> void:
	ground_check = check


func set_building_segment_check(check: Callable) -> void:
	building_segment_check = check


func set_vehicle_road_segments(segments: Array) -> void:
	vehicle_road_segments = segments
	vehicle_road_cells.clear()
	for segment_index in segments.size():
		var segment: Dictionary = segments[segment_index]
		if bool(segment.get("walkway", false)) or bool(segment.get("bridge", false)) or bool(segment.get("tunnel", false)) or int(segment.get("layer", 0)) != 0:
			continue
		var margin := float(segment.get("half_width", 0.0)) + 2.0
		var bounds := Rect2(Vector2(segment.a), Vector2(segment.b) - Vector2(segment.a)).abs().grow(margin)
		var low := Vector2i(floori(bounds.position.x / 256.0), floori(bounds.position.y / 256.0))
		var high := Vector2i(floori(bounds.end.x / 256.0), floori(bounds.end.y / 256.0))
		for cell_y in range(low.y, high.y + 1):
			for cell_x in range(low.x, high.x + 1):
				vehicle_road_cells.get_or_add(Vector2i(cell_x, cell_y), []).append(segment_index)


func set_bridge_corridors(corridors: Array[Dictionary]) -> void:
	bridge_corridors = corridors
	water_bridge_ids.clear()
	for corridor_value in bridge_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.get("kind", "")) == "bridge" and bool(corridor.get("over_water", false)):
			for source_id in corridor.get("source_ids", [str(corridor.get("id", ""))]):
				water_bridge_ids[str(source_id)] = true
	queue_redraw()


func set_active_land_bridge(bridge_id: String) -> void:
	if active_land_bridge_id == bridge_id:
		return
	active_land_bridge_id = bridge_id
	active_bridge_source_ids.clear()
	for corridor_value in bridge_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.get("id", "")) != bridge_id:
			continue
		for source_id in corridor.get("source_ids", [bridge_id]):
			active_bridge_source_ids[str(source_id)] = true
		break
	queue_redraw()


func _advance_agent(agent: Dictionary, delta: float) -> void:
	if bool(agent.get("route_crossing", false)) and not bool(agent.get("crossing_committed", false)):
		agent["crossing_retry_seconds"] = float(agent.get("crossing_retry_seconds", 0.0)) - delta
		if float(agent.crossing_retry_seconds) > 0.0:
			return
		agent.crossing_retry_seconds = 0.25
		if str(agent.get("route_phase", "edge")) == "edge" and bool(agent.get("route_signal_control", false)) and traffic_flow.signal_state(Vector2(agent.target) - Vector2(agent.position), elapsed) != "green":
			return
		if not crossing_safety.can_begin(agent.position, agent.target, float(agent.speed), agents, owned_wagon):
			agent["crossing_wait_seconds"] = float(agent.get("crossing_wait_seconds", 0.0)) + 0.25
			if float(agent.crossing_wait_seconds) >= 8.0:
				_choose_next(agent, true)
			return
		crossing_safety.reserve(agent)
	var target: Vector2 = agent.target
	var current_position: Vector2 = agent.position
	var difference: Vector2 = target - current_position
	if difference.length() <= maxf(2.0, float(agent.speed) * delta):
		agent.position = target
		if bool(agent.get("crossing_committed", false)):
			crossing_safety.release(agent, true)
		if str(agent.get("route_phase", "")) == "link":
			agent.route_phase = "edge"
			agent.target = agent.get("route_end", target)
			agent.route_crossing = bool(agent.get("edge_crossing", false))
			agent.crossing_retry_seconds = 0.0
			return
		agent.node = agent.target_node
		_choose_next(agent)
	else:
		agent.position = current_position + difference.normalized() * float(agent.speed) * delta
		agent.angle = difference.angle()


func _advance_traffic(agent: Dictionary, delta: float) -> void:
	var target: Vector2 = agent.target
	var current_position: Vector2 = agent.position
	var difference: Vector2 = target - current_position
	var reaches_target := difference.length() <= maxf(2.0, float(agent.speed) * delta)
	var next_position := target if reaches_target else current_position + difference.normalized() * float(agent.speed) * delta
	var graph: Dictionary = graphs.traffic
	if traffic_flow.can_move(agent, agents, next_position, graph, traffic_obstacles, elapsed, delta, crossing_safety):
		agent.position = next_position
		agent.angle = lerp_angle(float(agent.angle), difference.angle(), 1.0 - exp(-delta * 7.0))
		agent.waiting_seconds = 0.0
		if reaches_target:
			agent.node = agent.target_node
			traffic_flow.complete_segment(agent)
			var planned_exit := int(agent.get("planned_exit_node", -1))
			_choose_next(agent, false, planned_exit)
		return
	if traffic_flow.update_wait_and_recover(agent, delta, elapsed, graph, agents, traffic_obstacles, rng):
		_choose_next(agent)


func counts_text() -> String:
	var counts: Dictionary = {"traffic": 0, "person": 0, "robot": 0, "drone": 0}
	for agent in agents:
		var kind: String = str(agent.kind)
		counts[kind] = int(counts.get(kind, 0)) + 1
	return "CARS %d  NPCs %d  NPRs %d  NPDs %d" % [counts.traffic, counts.person, counts.robot, counts.drone]


func _draw() -> void:
	_draw_traffic_controls()
	# Draw lower-layer road users first. The bridge deck is then painted over
	# them, and bridge users are painted on top of the deck. This preserves the
	# two independent OSM layers at a road-over-road crossing.
	for agent in agents:
		if bool(agent.get("route_tunnel", false)) or bool(agent.get("route_bridge", false)) or str(agent.kind) == "drone":
			continue
		if not _draws_position(agent.position):
			continue
		_draw_agent(agent)
	_draw_bridge_decks()
	for agent in agents:
		if bool(agent.get("route_tunnel", false)) or not bool(agent.get("route_bridge", false)):
			continue
		if not _draws_position(agent.position):
			continue
		if not _bridge_id_is_visible(str(agent.get("route_source_way_id", ""))):
			continue
		_draw_agent(agent)
	for agent in agents:
		if str(agent.kind) == "drone":
			if not _draws_position(agent.position):
				continue
			_draw_agent(agent)


func _draw_agent(agent: Dictionary) -> void:
	var position: Vector2 = agent.position
	match str(agent.kind):
		"traffic":
			var lane_direction := Vector2.UP.rotated(float(agent.angle))
			position += lane_direction * (8.0 if driving_side == "left" else -8.0)
			_draw_traffic_car(agent, position)
		"robot":
			_draw_robot(agent, position)
		"drone":
			_draw_drone(agent, position)
		_:
			_draw_person(agent, position)


func _draw_bridge_decks() -> void:
	for corridor_value in bridge_corridors:
		var corridor: Dictionary = corridor_value
		if str(corridor.get("kind", "")) != "bridge":
			continue
		if not _bridge_id_is_visible(str(corridor.get("id", ""))):
			continue
		var points: PackedVector2Array = corridor.points
		if points.size() < 2:
			continue
		var width := float(corridor.half_width) * 2.0
		draw_polyline(points, Color("#ece2c3"), width + 7.0, true)
		draw_polyline(points, Color("#747e7e"), width, true)
		_draw_bridge_markings(points)
		_draw_bridge_portal(points[0], points[0].direction_to(points[1]))
		_draw_bridge_portal(points[points.size() - 1], points[points.size() - 1].direction_to(points[points.size() - 2]))


func _draw_bridge_markings(points: PackedVector2Array) -> void:
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var finish: Vector2 = points[index + 1]
		var length := start.distance_to(finish)
		if length < 8.0:
			continue
		var direction := start.direction_to(finish)
		var offset := 4.0
		while offset < length:
			draw_line(start + direction * offset, start + direction * minf(offset + 5.0, length), Color("#e8e1bd"), 1.0, true)
			offset += 11.0


func _draw_bridge_portal(position: Vector2, inward: Vector2) -> void:
	var normal := Vector2(-inward.y, inward.x)
	var arrow := PackedVector2Array([position + inward * 8.0, position - inward * 5.0 + normal * 5.0, position - inward * 5.0 - normal * 5.0])
	draw_circle(position, 8.0, Color("#17343c"))
	draw_circle(position, 6.0, Color("#69d4df"))
	draw_colored_polygon(arrow, Color("#f4f1dd"))


func _bridge_id_is_visible(bridge_id: String) -> bool:
	return not bridge_id.is_empty() and (active_bridge_source_ids.has(bridge_id) or water_bridge_ids.has(bridge_id))


func _draw_traffic_car(agent: Dictionary, position: Vector2) -> void:
	draw_set_transform(position, float(agent.angle) + PI / 2.0, Vector2.ONE)
	var artwork: Dictionary = ActorArt.sprite(str(agent.get("vehicle_asset", "car_sedan_blue")))
	if not artwork.is_empty():
		var car_size := Vector2(16.0, 34.0)
		match str(agent.get("vehicle_style", "sedan")):
			"wagon":
				car_size = Vector2(16.5, 36.0)
			"ute":
				car_size = Vector2(17.0, 38.0)
		draw_circle(Vector2(0.0, 2.0), car_size.x * 0.5, Color(0.05, 0.10, 0.07, 0.18))
		draw_texture_rect_region(artwork.texture, Rect2(-car_size * 0.5, car_size), artwork.region)
		if bool(agent.get("moving", false)):
			var tyre_flash := Color("#90b2b3") if int(float(agent.phase) * 22.0) % 2 == 0 else Color("#2b3538")
			draw_rect(Rect2(-8.0, -11.0, 1.0, 3.0), tyre_flash)
			draw_rect(Rect2(7.0, -11.0, 1.0, 3.0), tyre_flash)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_rect(Rect2(-8.0, -17.0, 16.0, 34.0), Color("#d34f6a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_traffic_controls() -> void:
	for control_node_value in graphs.get("traffic", {}).get("control_nodes", []):
		var control_node: Dictionary = control_node_value
		var position: Vector2 = control_node.position
		if not _draws_position(position):
			continue
		match str(control_node.control):
			"traffic_signals":
				var horizontal_color := _signal_color(traffic_flow.signal_state(Vector2.RIGHT, elapsed))
				var vertical_color := _signal_color(traffic_flow.signal_state(Vector2.DOWN, elapsed))
				draw_rect(Rect2(position + Vector2(-11, -4), Vector2(6, 8)), Color("#263d31"))
				draw_circle(position + Vector2(-8, 0), 2.0, horizontal_color)
				draw_rect(Rect2(position + Vector2(5, -4), Vector2(6, 8)), Color("#263d31"))
				draw_circle(position + Vector2(8, 0), 2.0, vertical_color)
			"stop":
				draw_circle(position + Vector2(8, -8), 4.0, Color("#b84f43"))
				draw_circle(position + Vector2(8, -8), 2.2, Color("#edf0df"), false, 1.0)
			"give_way":
				var sign_points := PackedVector2Array([position + Vector2(4, -12), position + Vector2(12, -12), position + Vector2(8, -5)])
				draw_colored_polygon(sign_points, Color("#edf0df"))
				draw_polyline(sign_points + PackedVector2Array([sign_points[0]]), Color("#b84f43"), 1.2)


func _signal_color(state: String) -> Color:
	if state == "green":
		return Color("#83c76d")
	if state == "amber":
		return Color("#eabe68")
	return Color("#c65d43")


func _draw_person(agent: Dictionary, position: Vector2) -> void:
	var phase := float(agent.phase)
	var artwork: Dictionary = ActorArt.sprite(str(agent.get("npc_asset", "npc_medium_man_adult")))
	if not artwork.is_empty():
		var lift := absf(sin(phase * 14.0)) * 1.0 if bool(agent.get("moving", false)) else 0.0
		var lean := sin(phase * 14.0) * 0.035 if bool(agent.get("moving", false)) else 0.0
		draw_circle(position, 4.0, Color(0.05, 0.10, 0.07, 0.20))
		draw_set_transform(position + Vector2(0.0, -lift), lean, Vector2.ONE)
		draw_texture_rect_region(artwork.texture, Rect2(-7.0, -25.0, 14.0, 25.0), artwork.region)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_rect(Rect2(position + Vector2(-7.0, -25.0), Vector2(14.0, 25.0)), Color("#d34f6a"))


func _draw_robot(agent: Dictionary, position: Vector2) -> void:
	var phase := float(agent.phase)
	var foot := 1.0 if int(phase * 8.0) % 4 == 1 else (-1.0 if int(phase * 8.0) % 4 == 3 else 0.0)
	var artwork: Dictionary = ActorArt.sprite("npr")
	if not artwork.is_empty():
		var stride := sin(phase * 15.0) if bool(agent.get("moving", false)) else 0.0
		draw_circle(position, 4.0, Color(0.05, 0.10, 0.07, 0.20))
		draw_set_transform(position + Vector2(0.0, -absf(stride)), stride * 0.045, Vector2.ONE)
		draw_texture_rect_region(artwork.texture, Rect2(-9.0, -25.0, 18.0, 25.0), artwork.region)
		if int(elapsed * 4.0) % 2 == 0:
			draw_circle(Vector2(0.0, -24.0), 1.0, Color("#ffda75"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_agent_pixel(position, 4, 17, 3, 4 + foot, Color("#244a4e"))
	_agent_pixel(position, 9, 17, 3, 4 - foot, Color("#244a4e"))
	_agent_pixel(position, 3, 20 + foot, 4, 2, Color("#65aeb0"))
	_agent_pixel(position, 9, 20 - foot, 4, 2, Color("#65aeb0"))
	_agent_pixel(position, 3, 9, 10, 9, Color("#e6dfc9"))
	_agent_pixel(position, 5, 12, 6, 5, Color("#25818a"))
	_agent_pixel(position, 1, 11 - foot, 2, 5, Color("#4a6262"))
	_agent_pixel(position, 13, 11 + foot, 2, 5, Color("#4a6262"))
	_agent_pixel(position, 3, 2, 10, 8, Color("#e6dfc9"))
	_agent_pixel(position, 4, 4, 8, 4, Color("#172c31"))
	_agent_pixel(position, 5, 5, 2, 1, Color("#53e2e0"))
	_agent_pixel(position, 10, 5, 1, 1, Color("#53e2e0"))
	_agent_pixel(position, 7, 0, 3, 2, Color("#e49a32"))


func _draw_drone(agent: Dictionary, position: Vector2) -> void:
	var artwork: Dictionary = ActorArt.sprite("npd")
	if not artwork.is_empty():
		var phase := float(agent.phase)
		draw_circle(position + Vector2(4.0, 8.0), 7.0, Color(0.05, 0.08, 0.07, 0.22))
		draw_set_transform(position + Vector2(0.0, sin(phase * 4.0) * 1.5), 0.0, Vector2.ONE)
		draw_texture_rect_region(artwork.texture, Rect2(-14.0, -14.0, 28.0, 28.0), artwork.region)
		for rotor in [Vector2(-10.0, -10.0), Vector2(10.0, -10.0), Vector2(-10.0, 10.0), Vector2(10.0, 10.0)]:
			var rotor_angle := phase * 28.0
			var blade := Vector2(2.5, 0.0).rotated(rotor_angle)
			draw_line(rotor - blade, rotor + blade, Color("#8ee2e2"), 0.8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_circle(position + Vector2(3.0, 7.0), 7.0, Color(0.05, 0.08, 0.07, 0.22))
	for offset in [Vector2(-7, -5), Vector2(7, -5), Vector2(-7, 5), Vector2(7, 5)]:
		draw_circle(position + offset, 3.5, Color("#20383b"))
		draw_line(position + offset - Vector2(2.5, 0.0), position + offset + Vector2(2.5, 0.0), Color("#62bfc0"), 1.0)
		draw_line(position + offset - Vector2(0.0, 2.5), position + offset + Vector2(0.0, 2.5), Color("#62bfc0"), 1.0)
	draw_circle(position, 5.5, Color("#e6dfc9"))
	draw_rect(Rect2(position - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color("#25818a"))
	draw_circle(position, 1.2, Color("#53e2e0"))
	if int(float(agent.phase) * 8.0) % 2 == 0:
		draw_circle(position + Vector2(0.0, -5.0), 1.0, Color("#e49a32"))


func _agent_pixel(position: Vector2, x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(position + Vector2(x - 8.0, y - 21.0), Vector2(width, height)), color)


func _prepare_graph(graph: Dictionary, projection: Dictionary, scale: float, cbd_bounds: Dictionary, map_bounds: Dictionary = {}, traffic_graph: bool = false) -> Dictionary:
	var nodes: Dictionary = {}
	var geographic_by_node: Dictionary = {}
	var cbd_nodes: Array[int] = []
	var control_by_node: Dictionary = {}
	var control_nodes: Array[Dictionary] = []
	for node_value in graph.get("nodes", []):
		var node: Dictionary = node_value
		var id := int(node.id)
		var geographic := Vector2(float(node.longitude), float(node.latitude))
		if not map_bounds.is_empty() and (geographic.x < float(map_bounds.west) or geographic.x > float(map_bounds.east) or geographic.y < float(map_bounds.south) or geographic.y > float(map_bounds.north)):
			continue
		nodes[id] = ProjectionScript.geographic_to_world(geographic, projection, scale)
		geographic_by_node[id] = geographic
		var control := str(node.get("control", ""))
		if not control.is_empty():
			control_by_node[id] = control
			control_nodes.append({"id": id, "position": nodes[id], "control": control})
		if geographic.x >= float(cbd_bounds.west) and geographic.x <= float(cbd_bounds.east) and geographic.y >= float(cbd_bounds.south) and geographic.y <= float(cbd_bounds.north):
			cbd_nodes.append(id)
	var adjacency: Dictionary = {}
	var edge_by_pair: Dictionary = {}
	var neighbours: Dictionary = {}
	for edge_value in graph.get("edges", []):
		var edge: Dictionary = edge_value
		if traffic_graph and _unsafe_general_traffic_edge(edge):
			continue
		var from := int(edge.from)
		var to := int(edge.to)
		if not nodes.has(from) or not nodes.has(to):
			continue
		if not adjacency.has(from):
			adjacency[from] = []
		adjacency[from].append(to)
		edge_by_pair["%d>%d" % [from, to]] = edge.duplicate(true)
		if not neighbours.has(from):
			neighbours[from] = {}
		if not neighbours.has(to):
			neighbours[to] = {}
		neighbours[from][to] = true
		neighbours[to][from] = true
	var degree: Dictionary = {}
	for node_id in nodes:
		degree[node_id] = neighbours.get(node_id, {}).size()
	var routable_ids: Array = adjacency.keys()
	var routable_lookup: Dictionary = {}
	for node_id in routable_ids:
		routable_lookup[node_id] = true
	var routable_cbd_ids: Array[int] = []
	for node_id in cbd_nodes:
		if routable_lookup.has(node_id):
			routable_cbd_ids.append(node_id)
	return {"nodes": nodes, "geographic_by_node": geographic_by_node, "adjacency": adjacency, "edge_by_pair": edge_by_pair, "degree": degree, "control_by_node": control_by_node, "control_nodes": control_nodes, "all_ids": routable_ids, "cbd_ids": routable_cbd_ids}


func _unsafe_general_traffic_edge(edge: Dictionary) -> bool:
	var bridge := bool(edge.get("bridge", false))
	var tunnel := bool(edge.get("tunnel", false))
	var service := str(edge.get("service", "")).to_lower()
	if str(edge.get("highway", "")).to_lower() == "service" and service in ["driveway", "parking_aisle"]:
		return true
	return int(edge.get("layer", 0)) != 0 and not bridge and not tunnel


func _add_population(kind: String, count: int, cbd_percent: int, speed: float) -> void:
	var graph_key := "person" if kind == "robot" else kind
	var graph: Dictionary = graphs.get(graph_key, {})
	var all_ids: Array = graph.get("all_ids", [])
	if all_ids.is_empty():
		return
	var cbd_ids: Array = graph.get("cbd_ids", [])
	var cbd_count := roundi(count * cbd_percent / 100.0)
	for index in count:
		var candidates: Array = cbd_ids if index < cbd_count and not cbd_ids.is_empty() else all_ids
		var node_id := int(candidates[rng.randi_range(0, candidates.size() - 1)])
		var agent := {"kind": kind, "node": node_id, "target_node": node_id, "position": graph.nodes[node_id], "target": graph.nodes[node_id], "speed": speed * rng.randf_range(0.82, 1.18), "angle": 0.0, "graph_key": graph_key, "phase": rng.randf_range(0.0, 1.0)}
		if kind in ["person", "robot"]:
			agent["walker_id"] = agents.size()
			agent["first_route"] = true
		if kind == "person":
			# Even population sizes have an exact half-and-half split; an odd
			# population differs by only one. Alternation also balances the CBD.
			agent["gender"] = "woman" if index % 2 == 0 else "man"
			agent["skin_tone_group"] = _choose_skin_tone_group()
			agent["age_group"] = AGE_GROUPS[floori(index / 2.0) % AGE_GROUPS.size()]
			agent["npc_asset"] = "npc_%s_%s_%s" % [agent.skin_tone_group, agent.gender, agent.age_group]
		elif kind == "traffic":
			agent["vehicle_asset"] = CAR_VARIANTS[index % CAR_VARIANTS.size()]
			agent["vehicle_style"] = str(agent.vehicle_asset).split("_")[1]
			agent["traffic_id"] = agents.size()
			agent["reserved_node"] = -1
			agent["waiting_seconds"] = 0.0
			agent["stop_wait_seconds"] = 0.0
			agent["completed_stop_node"] = -1
			agent["jam_recoveries"] = 0
			agent["moving"] = false
		agents.append(agent)
		_choose_next(agent)


func _choose_next(agent: Dictionary, avoid_crossing: bool = false, preferred_target: int = -1) -> void:
	if bool(agent.get("crossing_committed", false)):
		crossing_safety.release(agent)
	var graph: Dictionary = graphs[agent.graph_key]
	var options: Array = graph.adjacency.get(agent.node, [])
	if avoid_crossing:
		var non_crossing_options: Array = []
		for option_value in options:
			var option := int(option_value)
			var option_edge: Dictionary = graph.get("edge_by_pair", {}).get("%d>%d" % [int(agent.node), option], {})
			if not bool(option_edge.get("crossing", false)):
				non_crossing_options.append(option)
		if not non_crossing_options.is_empty():
			options = non_crossing_options
	if options.is_empty():
		var all_ids: Array = graph.all_ids
		agent.node = int(all_ids[rng.randi_range(0, all_ids.size() - 1)])
		options = graph.adjacency.get(agent.node, [])
	if options.is_empty():
		agent.target_node = agent.node
		agent.target = graph.nodes[agent.node]
		agent["route_bridge"] = false
		agent["route_tunnel"] = false
		agent["route_layer"] = 0
		agent["route_source_way_id"] = ""
		agent["route_crossing"] = false
		return
	agent.target_node = preferred_target if preferred_target in options else int(options[rng.randi_range(0, options.size() - 1)])
	agent.target = graph.nodes[agent.target_node]
	var edge: Dictionary = graph.get("edge_by_pair", {}).get("%d>%d" % [int(agent.node), int(agent.target_node)], {})
	agent["route_bridge"] = bool(edge.get("bridge", false))
	agent["route_tunnel"] = bool(edge.get("tunnel", false))
	agent["route_layer"] = int(edge.get("layer", 0))
	agent["route_source_way_id"] = str(edge.get("source_way_id", ""))
	agent["route_crossing"] = bool(edge.get("crossing", false)) and str(agent.kind) in ["person", "robot"] and not bool(edge.get("bridge", false)) and not bool(edge.get("tunnel", false))
	if str(agent.kind) in ["person", "robot"]:
		_set_walking_route(agent, edge, graph)
	agent["crossing_retry_seconds"] = 0.0
	agent["crossing_wait_seconds"] = 0.0
	if str(agent.kind) == "traffic":
		var exit_options: Array = graph.adjacency.get(agent.target_node, []).duplicate()
		if exit_options.size() > 1:
			exit_options.erase(int(agent.node))
		agent["planned_exit_node"] = int(exit_options[rng.randi_range(0, exit_options.size() - 1)]) if not exit_options.is_empty() else -1


func _set_walking_route(agent: Dictionary, edge: Dictionary, graph: Dictionary) -> void:
	# OSM stores ordinary roads as centre lines. The render layer already paints
	# footpaths beyond their edges; ground actors must follow that same corridor.
	var from_position: Vector2 = graph.nodes[int(agent.node)]
	var to_position: Vector2 = graph.nodes[int(agent.target_node)]
	var source_id := str(edge.get("source_way_id", ""))
	var tags: Dictionary = road_tags_by_id.get(source_id, {})
	var is_road := not tags.is_empty() and not RoadDimensionsScript.is_walkway(tags)
	var route_start := from_position
	var route_end := to_position
	if is_road and not bool(edge.get("bridge", false)) and not bool(edge.get("tunnel", false)):
		var road_direction := from_position.direction_to(to_position)
		var normal := Vector2(-road_direction.y, road_direction.x)
		var sidewalk_sides: Array = RoadDimensionsScript.sidewalk_sides(tags)
		# Explicit sidewalk=no means an unmarked roadside shoulder, not a
		# fabricated surveyed pavement. It is still safer than the carriageway.
		if sidewalk_sides.is_empty():
			sidewalk_sides.append("left")
			sidewalk_sides.append("right")
		var source_from: Vector2 = graph.get("geographic_by_node", {}).get(int(agent.node), Vector2.ZERO)
		var source_to: Vector2 = graph.get("geographic_by_node", {}).get(int(agent.target_node), Vector2.ZERO)
		if road_forward_lookup.get(_way_segment_key(source_id, source_from, source_to), true) == false:
			var reversed_sides: Array = []
			for side in sidewalk_sides:
				reversed_sides.append("right" if side == "left" else "left")
			sidewalk_sides = reversed_sides
		var sidewalk_width := RoadDimensionsScript.sidewalk_width_metres(tags)
		var offset := (RoadDimensionsScript.half_width_metres(tags) + 0.35 + sidewalk_width * 0.5) * pixels_per_metre
		var best_distance := INF
		for side in sidewalk_sides:
			var signed_offset := offset if side == "right" else -offset
			var candidate_start := from_position + normal * signed_offset
			var candidate_end := to_position + normal * signed_offset
			if not _walk_segment_is_clear(candidate_start, candidate_end):
				continue
			if not bool(agent.get("first_route", false)) and not _walk_segment_is_clear(agent.position, candidate_start):
				continue
			var distance: float = agent.position.distance_to(candidate_start)
			if distance < best_distance:
				best_distance = distance
				route_start = candidate_start
				route_end = candidate_end
		# A blocked roadside is not permission to walk down the traffic lane.
		if best_distance == INF:
			agent.target_node = agent.node
			agent.target = agent.position
			agent.route_phase = "blocked"
			agent.route_crossing = false
			return
	var first_edge := bool(agent.get("first_route", false))
	if first_edge:
		agent.position = route_start
		agent.first_route = false
	var connection_distance: float = agent.position.distance_to(route_start)
	if connection_distance > 3.0 and not _walk_segment_is_clear(agent.position, route_start):
		agent.target_node = agent.node
		agent.target = agent.position
		agent.route_phase = "blocked"
		agent.route_crossing = false
		return
	agent.route_end = route_end
	agent.edge_crossing = (bool(edge.get("crossing", false)) or (not is_road and _walk_edge_crosses_vehicle_road(route_start, route_end))) and not bool(edge.get("bridge", false)) and not bool(edge.get("tunnel", false))
	var controls: Dictionary = graph.get("control_by_node", {})
	agent.route_signal_control = bool(agent.edge_crossing) and (str(controls.get(int(agent.node), "")) == "traffic_signals" or str(controls.get(int(agent.target_node), "")) == "traffic_signals")
	if connection_distance > 3.0 and not bool(edge.get("bridge", false)) and not bool(edge.get("tunnel", false)):
		# Switching sides or turning across a carriageway is a distinct,
		# reserved crossing. Cars yield only after the gap check succeeds.
		agent.route_phase = "link"
		agent.target = route_start
		agent.route_crossing = true
	else:
		agent.route_phase = "edge"
		agent.target = route_end
		agent.route_crossing = bool(agent.edge_crossing)


func _walk_segment_is_clear(start: Vector2, finish: Vector2) -> bool:
	if building_segment_check.is_valid() and not bool(building_segment_check.call(start, finish)):
		return false
	if not ground_check.is_valid():
		return true
	for step in 5:
		var point := start.lerp(finish, float(step) / 4.0)
		if not bool(ground_check.call(point, 2.0)):
			return false
	return true


func _way_segment_key(way_id: String, start: Vector2, finish: Vector2) -> String:
	return "%s|%.7f,%.7f>%.7f,%.7f" % [way_id, start.x, start.y, finish.x, finish.y]


func _walk_edge_crosses_vehicle_road(start: Vector2, finish: Vector2) -> bool:
	if start.distance_squared_to(finish) < 0.01:
		return false
	var bounds := Rect2(start, finish - start).abs()
	var low := Vector2i(floori(bounds.position.x / 256.0), floori(bounds.position.y / 256.0))
	var high := Vector2i(floori(bounds.end.x / 256.0), floori(bounds.end.y / 256.0))
	var candidates: Dictionary = {}
	for cell_y in range(low.y, high.y + 1):
		for cell_x in range(low.x, high.x + 1):
			for segment_index in vehicle_road_cells.get(Vector2i(cell_x, cell_y), []):
				candidates[segment_index] = true
	var walk_direction := start.direction_to(finish)
	for segment_index in candidates:
		var road: Dictionary = vehicle_road_segments[int(segment_index)]
		var road_start: Vector2 = road.a
		var road_end: Vector2 = road.b
		if Geometry2D.segment_intersects_segment(start, finish, road_start, road_end) != null:
			return true
		if absf(walk_direction.dot(road_start.direction_to(road_end))) < 0.6:
			var nearest_start := Geometry2D.get_closest_point_to_segment(start, road_start, road_end)
			var nearest_end := Geometry2D.get_closest_point_to_segment(finish, road_start, road_end)
			if minf(start.distance_to(nearest_start), finish.distance_to(nearest_end)) <= float(road.half_width) + 2.0:
				return true
	return false


func _choose_skin_tone_group() -> String:
	var roll := rng.randf_range(0.0, 100.0)
	var cumulative := 0.0
	for index in SKIN_TONE_KEYS.size():
		cumulative += float(skin_tone_distribution.get(SKIN_TONE_KEYS[index], 0.0))
		if roll <= cumulative:
			return str(SKIN_TONE_KEYS[index]).trim_suffix("_percent")
	return "medium"
