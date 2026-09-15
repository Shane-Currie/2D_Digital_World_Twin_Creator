class_name RuntimePopulation
extends Node2D

const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const TrafficFlowScript = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
const CrossingSafetyScript = preload("res://scripts/runtime/pedestrians/runtime_crossing_safety.gd")

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

const SKIN_TONE_KEYS := [
	"very_light_percent", "light_percent", "medium_light_percent", "medium_percent",
	"medium_dark_percent", "dark_percent", "very_dark_percent"
]
const SKIN_TONE_COLORS := [
	Color("#f4d6bd"), Color("#e8bd99"), Color("#d6a177"), Color("#bd8159"),
	Color("#96603f"), Color("#70442d"), Color("#4b2d21")
]


func setup(navigation: Dictionary, settings: Dictionary, projection: Dictionary, scale: float, cbd_bounds: Dictionary, town_seed: String, map_bounds: Dictionary = {}) -> void:
	rng.seed = hash(town_seed)
	agents.clear()
	driving_side = str(settings.get("road_rules", {}).get("driving_side", "left"))
	skin_tone_distribution = settings.get("skin_tone_distribution", {})
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
	for agent in agents:
		agent.phase = float(agent.get("phase", 0.0)) + delta
		if str(agent.kind) == "traffic":
			_advance_traffic(agent, delta)
		else:
			_advance_agent(agent, delta)
	queue_redraw()


func set_gameplay_obstacles(obstacles: Array[Node2D]) -> void:
	traffic_obstacles = obstacles
	owned_wagon = obstacles[1] if obstacles.size() > 1 else null


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
			_choose_next(agent)
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
		_draw_agent(agent)
	_draw_bridge_decks()
	for agent in agents:
		if bool(agent.get("route_tunnel", false)) or not bool(agent.get("route_bridge", false)):
			continue
		if not _bridge_id_is_visible(str(agent.get("route_source_way_id", ""))):
			continue
		_draw_agent(agent)
	for agent in agents:
		if str(agent.kind) == "drone":
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
	var body: Color = agent.get("body_color", Color("#af5945"))
	for wheel_position in [Vector2(-8.0, -11.0), Vector2(8.0, -11.0), Vector2(-8.0, 11.0), Vector2(8.0, 11.0)]:
		draw_rect(Rect2(wheel_position - Vector2(1.5, 3.0), Vector2(3.0, 6.0)), Color("#263d37"))
	draw_rect(Rect2(-7.0, -18.0, 14.0, 36.0), Color("#293f39"))
	draw_rect(Rect2(-6.0, -17.0, 12.0, 34.0), body)
	draw_rect(Rect2(-5.0, -7.0, 10.0, 7.0), Color("#294e58"))
	draw_rect(Rect2(-4.0, -6.0, 8.0, 2.0), Color("#8cafaa"))
	draw_rect(Rect2(-5.0, 10.0, 10.0, 4.0), Color("#335961"))
	draw_rect(Rect2(-5.0, -16.0, 3.0, 2.0), Color("#f6e6ad"))
	draw_rect(Rect2(2.0, -16.0, 3.0, 2.0), Color("#f6e6ad"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_traffic_controls() -> void:
	for control_node_value in graphs.get("traffic", {}).get("control_nodes", []):
		var control_node: Dictionary = control_node_value
		var position: Vector2 = control_node.position
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
	var foot := 1.0 if int(phase * 8.0) % 4 == 1 else (-1.0 if int(phase * 8.0) % 4 == 3 else 0.0)
	var skin: Color = agent.get("skin_tone", Color("#d6a177"))
	var hair: Color = agent.get("hair", Color("#49382c"))
	var shirt: Color = agent.get("shirt", Color("#537e9a"))
	var trousers: Color = agent.get("trousers", Color("#3e535d"))
	_agent_pixel(position, 3, 20, 10, 2, Color("#748667"))
	_agent_pixel(position, 4, 15, 3, 5 + foot, trousers)
	_agent_pixel(position, 9, 15, 3, 5 - foot, trousers)
	_agent_pixel(position, 3, 20 + foot, 4, 2, Color("#34483f"))
	_agent_pixel(position, 9, 20 - foot, 4, 2, Color("#34483f"))
	_agent_pixel(position, 3, 9, 10, 8, shirt)
	if bool(agent.get("skirt", false)):
		_agent_pixel(position, 2, 15, 12, 3, shirt.darkened(0.15))
	_agent_pixel(position, 1, 10 - foot, 3, 5, skin)
	_agent_pixel(position, 13, 10 + foot, 2, 5, skin)
	_agent_pixel(position, 4, 3, 9, 7, skin)
	_agent_pixel(position, 3, 1, 10, 4, hair)
	_agent_pixel(position, 5, 0, 7, 2, hair)
	if bool(agent.get("long_hair", false)):
		_agent_pixel(position, 3, 3, 2, 8, hair)


func _draw_robot(agent: Dictionary, position: Vector2) -> void:
	var phase := float(agent.phase)
	var foot := 1.0 if int(phase * 8.0) % 4 == 1 else (-1.0 if int(phase * 8.0) % 4 == 3 else 0.0)
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
	return {"nodes": nodes, "adjacency": adjacency, "edge_by_pair": edge_by_pair, "degree": degree, "control_by_node": control_by_node, "control_nodes": control_nodes, "all_ids": routable_ids, "cbd_ids": routable_cbd_ids}


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
		if kind == "person":
			agent["skin_tone"] = _choose_skin_tone()
			agent["hair"] = Color(["49382c", "242c2c", "775539", "a48550", "aaa797"][rng.randi_range(0, 4)])
			agent["shirt"] = Color(["537e9a", "a95d52", "638253", "c4a067", "816b93", "c6c8ad", "477c77"][rng.randi_range(0, 6)])
			agent["trousers"] = Color(["3e535d", "665d4c", "444d42"][rng.randi_range(0, 2)])
			agent["long_hair"] = rng.randf() < 0.45
			agent["skirt"] = rng.randf() < 0.2
		elif kind == "traffic":
			agent["body_color"] = Color(["af5945", "4d7199", "bfc5b5", "69806b", "c4a067"][rng.randi_range(0, 4)])
			agent["traffic_id"] = agents.size()
			agent["reserved_node"] = -1
			agent["waiting_seconds"] = 0.0
			agent["stop_wait_seconds"] = 0.0
			agent["completed_stop_node"] = -1
			agent["jam_recoveries"] = 0
		agents.append(agent)
		_choose_next(agent)


func _choose_next(agent: Dictionary, avoid_crossing: bool = false) -> void:
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
	agent.target_node = int(options[rng.randi_range(0, options.size() - 1)])
	agent.target = graph.nodes[agent.target_node]
	var edge: Dictionary = graph.get("edge_by_pair", {}).get("%d>%d" % [int(agent.node), int(agent.target_node)], {})
	agent["route_bridge"] = bool(edge.get("bridge", false))
	agent["route_tunnel"] = bool(edge.get("tunnel", false))
	agent["route_layer"] = int(edge.get("layer", 0))
	agent["route_source_way_id"] = str(edge.get("source_way_id", ""))
	agent["route_crossing"] = bool(edge.get("crossing", false)) and str(agent.kind) in ["person", "robot"] and not bool(edge.get("bridge", false)) and not bool(edge.get("tunnel", false))
	agent["crossing_retry_seconds"] = 0.0
	agent["crossing_wait_seconds"] = 0.0


func _choose_skin_tone() -> Color:
	var roll := rng.randf_range(0.0, 100.0)
	var cumulative := 0.0
	for index in SKIN_TONE_KEYS.size():
		cumulative += float(skin_tone_distribution.get(SKIN_TONE_KEYS[index], 0.0))
		if roll <= cumulative:
			return SKIN_TONE_COLORS[index]
	return SKIN_TONE_COLORS[3]
