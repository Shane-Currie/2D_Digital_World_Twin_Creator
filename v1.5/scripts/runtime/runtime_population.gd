class_name RuntimePopulation
extends Node2D

const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const StorylineNpcStore = preload("res://scripts/npcs/storyline_npc_store.gd")
const TrafficFlowScript = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
const SignalJunctionsScript = preload("res://scripts/runtime/traffic/runtime_signal_junctions.gd")
const CrossingSafetyScript = preload("res://scripts/runtime/pedestrians/runtime_crossing_safety.gd")
const ActorCollisionScript = preload("res://scripts/runtime/traffic/runtime_actor_collision.gd")
const ImpactMotion = preload("res://scripts/runtime/crashes/impact_motion.gd")
const ParkedDetour = preload("res://scripts/runtime/pedestrians/parked_vehicle_detour.gd")
const OnFootCollision = preload("res://scripts/runtime/pedestrians/on_foot_actor_collision.gd")
# Fallback art uses this factor; production NPCs use the shared feet-anchored
# box in RuntimeActorArt. 25 source units become 13.75 world units.
const NPC_VISUAL_SCALE := 13.75 / 25.0
const NPR_VISUAL_SCALE := 0.625
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const GameSettingsStoreScript = preload("res://scripts/settings/game_settings_store.gd")
const RoadDimensionsScript = preload("res://scripts/roads/road_dimensions.gd")

var agents: Array[Dictionary] = []
var graphs: Dictionary = {}
var rng := RandomNumberGenerator.new()
var driving_side := "left"
var skin_tone_distribution: Dictionary = {}
var persona_library: Dictionary = {}
var storyline_npc_data: Dictionary = {"npcs": []}
var npc_personas: Array[Dictionary] = []
var npr_personas: Array[Dictionary] = []
var used_character_names: Dictionary = {}
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
var population_destinations: Array = []
var destinations_by_category: Dictionary = {}
var destination_route_cache: Dictionary = {}
const DISTANT_TRAFFIC_RADIUS := 900.0
const DISTANT_TRAFFIC_INTERVAL := 0.20
const WALKER_AVOIDANCE_CELL_SIZE := 32.0
const WALKER_PERSONAL_SPACE := 9.0
const WALKER_LOOK_AHEAD := 18.0

var walker_cells: Dictionary = {}
var active_interior_building_id := ""
var active_interior_floor_id := ""
var interior_visibility_check: Callable

const SKIN_TONE_KEYS := ["light_percent", "medium_percent", "dark_percent"]
const SKIN_TONE_COLORS := [
	Color("#e8bd99"), Color("#bd8159"), Color("#70442d")
]
const AGE_GROUPS := ["young", "adult", "older"]
const NPC_NAMES_BY_GENDER := {
	"woman": ["Amelia", "Chloe", "Ella", "Grace", "Hannah", "Isla", "Jade", "Layla", "Maya", "Mia", "Ruby", "Sophie", "Tahlia", "Willow", "Zoe"],
	"man": ["Aiden", "Ben", "Caleb", "Daniel", "Eli", "Finn", "Harrison", "Jack", "Liam", "Lucas", "Mason", "Noah", "Oliver", "Sam", "Thomas"]
}
const NPC_SURNAMES := [
	"Baker", "Brown", "Chen", "Clarke", "Davis", "Evans", "Garcia", "Harris", "Ibrahim", "Jones",
	"Khan", "Lee", "Martin", "Nguyen", "Patel", "Robinson", "Singh", "Taylor", "Walker", "Wilson"
]
const CAR_VARIANTS := [
	"car_sedan_blue", "car_sedan_red", "car_sedan_silver", "car_sedan_green",
	"car_wagon_white", "car_wagon_blue", "car_wagon_bronze", "car_wagon_grey",
	"car_ute_red", "car_ute_blue", "car_ute_white", "car_ute_green"
]


func setup(navigation: Dictionary, settings: Dictionary, projection: Dictionary, scale: float, cbd_bounds: Dictionary, town_seed: String, map_bounds: Dictionary = {}, features: Array = [], destination_data: Dictionary = {}) -> void:
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
	used_character_names.clear()
	for value in storyline_npc_data.get("npcs", []):
		if value is Dictionary and not str(value.get("display_name", "")).is_empty():
			used_character_names[str(value.display_name)] = true
	driving_side = str(settings.get("road_rules", {}).get("driving_side", "left"))
	skin_tone_distribution = GameSettingsStoreScript.migrate_skin_tones(settings.get("skin_tone_distribution", {}))
	traffic_flow.configure(settings)
	crossing_safety.reset()
	graphs = {
		"traffic": _prepare_graph(navigation.vehicle, projection, scale, cbd_bounds, map_bounds, true),
		"person": _prepare_graph(navigation.pedestrian, projection, scale, cbd_bounds, map_bounds),
		"drone": _prepare_graph(navigation.aerial, projection, scale, cbd_bounds, map_bounds)
	}
	_prepare_population_destinations(destination_data)
	var population: Dictionary = settings.get("population", {})
	_add_population("traffic", int(population.get("traffic_car_count", 0)), int(population.get("cbd_car_percent", 0)), 75.0)
	_add_population("person", int(population.get("pedestrian_count", 0)), int(population.get("cbd_pedestrian_percent", 0)), 30.0)
	_add_population("robot", int(population.get("robot_count", 0)), int(population.get("cbd_robot_percent", 0)), 27.0)
	_add_population("drone", int(population.get("drone_count", 0)), int(population.get("cbd_drone_percent", 0)), 55.0)
	_add_storyline_npcs(projection, scale)
	queue_redraw()


func set_persona_library(data: Dictionary) -> void:
	persona_library = data.duplicate(true)
	npc_personas.clear()
	npr_personas.clear()
	for value in persona_library.get("personas", []):
		if not value is Dictionary:
			continue
		var persona: Dictionary = value
		if bool(persona.get("trader_only", false)): continue
		if str(persona.get("actor_kind", "")) == "npr":
			npr_personas.append(persona)
		elif str(persona.get("actor_kind", "")) == "npc":
			npc_personas.append(persona)


func set_storyline_npcs(data: Dictionary) -> void:
	storyline_npc_data = data.duplicate(true)


func set_active_interior(building_id := "", floor_id := "") -> void:
	active_interior_building_id = building_id
	active_interior_floor_id = floor_id
	queue_redraw()


func set_interior_visibility_check(check: Callable = Callable()) -> void:
	interior_visibility_check = check
	queue_redraw()


func _interior_position_is_visible(position: Vector2) -> bool:
	return active_interior_building_id.is_empty() or not interior_visibility_check.is_valid() or bool(interior_visibility_check.call(position))


func _agent_in_active_space(agent: Dictionary) -> bool:
	var space := str(agent.get("space", "outdoors"))
	if active_interior_building_id.is_empty():
		return space != "interior"
	return space == "interior" and str(agent.get("building_id", "")) == active_interior_building_id and str(agent.get("floor_id", "")) == active_interior_floor_id


func _outdoor_agents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for agent in agents:
		if str(agent.get("space", "outdoors")) != "interior":
			result.append(agent)
	return result


func _process(delta: float) -> void:
	elapsed += delta
	traffic_flow.begin_frame(_outdoor_agents())
	_rebuild_walker_cells()
	for agent in agents:
		if not _agent_in_active_space(agent):
			continue
		if ImpactMotion.advance(agent, delta, self):
			continue
		if bool(agent.get("conversation_paused", false)):
			agent["moving"] = false
			continue
		if bool(agent.get("storyline_stationary", false)):
			agent["moving"] = false
			continue
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


func player_vehicle_may_move(start: Vector2, finish: Vector2, angle: float, half_size: Vector2, crossing: Dictionary) -> bool:
	return ActorCollisionScript.vehicle_may_move(_outdoor_agents(), start, finish, angle, half_size, crossing)


func player_on_foot_motion(start: Vector2, finish: Vector2, radius: float, crossing: Dictionary) -> Vector2:
	if start.is_equal_approx(finish): return finish
	var active_agents: Array = []
	for agent in agents:
		if _agent_in_active_space(agent): active_agents.append(agent)
	return OnFootCollision.resolve_motion(active_agents, start, finish, radius, crossing)


func player_vehicle_contact(start: Vector2, finish: Vector2, angle: float, half_size: Vector2, crossing: Dictionary) -> Dictionary:
	return ActorCollisionScript.first_contact(_outdoor_agents(), start, finish, angle, half_size, crossing)


func apply_player_impact(contact: Dictionary, player_velocity: Vector2) -> Dictionary:
	return ImpactMotion.apply(contact, player_velocity, self)


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
	if str(agent.kind) in ["person", "robot"] and bool(agent.get("impact_rejoining", false)) and bool(agent.get("route_crossing", false)) and not bool(agent.get("crossing_committed", false)) and _point_on_vehicle_road(agent.position):
		# A knocked walker already in the carriageway must clear it, not wait
		# in the middle for permission to begin a crossing it is already on.
		crossing_safety.reserve(agent)
	if ParkedDetour.advance(agent, delta, self):
		return
	if _yield_crossing_landing(agent, delta):
		return
	var destination_wait := float(agent.get("destination_wait_seconds", 0.0))
	if destination_wait > 0.0:
		agent.destination_wait_seconds = maxf(0.0, destination_wait - delta)
		if float(agent.destination_wait_seconds) <= 0.0:
			_assign_destination_route(agent)
			_choose_next(agent)
		return
	if bool(agent.get("route_crossing", false)) and not bool(agent.get("crossing_committed", false)):
		agent["crossing_retry_seconds"] = float(agent.get("crossing_retry_seconds", 0.0)) - delta
		if float(agent.crossing_retry_seconds) > 0.0:
			return
		agent.crossing_retry_seconds = 0.25
		if bool(agent.get("route_signal_control", false)) and traffic_flow.signal_state(Vector2(agent.target) - Vector2(agent.position), elapsed) != "green":
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
	var is_ground_walker := str(agent.get("kind", "")) in ["person", "robot"]
	var occupied_arrival := is_ground_walker and difference.length() <= WALKER_PERSONAL_SPACE and _walker_target_occupied(agent, target)
	# Do not declare an outside landing reached while still in the traffic lane.
	if occupied_arrival and bool(agent.get("crossing_committed", false)) and _point_on_vehicle_road(current_position) and not _point_on_vehicle_road(target):
		occupied_arrival = false
	if difference.length() <= maxf(2.0, float(agent.speed) * delta) or occupied_arrival:
		if is_ground_walker and not occupied_arrival and (not _walker_step_clear(agent, target) or (bool(agent.get("impact_rejoining", false)) and not _walk_segment_is_clear(current_position, target))):
			return
		if not occupied_arrival:
			agent.position = target
		if bool(agent.get("crossing_committed", false)) and not _point_on_vehicle_road(agent.position):
			crossing_safety.release(agent, true)
		if str(agent.get("route_phase", "")) == "link":
			agent.route_phase = "edge"
			agent.target = agent.get("route_end", target)
			agent.route_crossing = bool(agent.get("edge_crossing", false))
			agent.route_signal_control = bool(agent.get("edge_signal_control", false))
			agent.crossing_retry_seconds = 0.0
			if bool(agent.get("crossing_committed", false)):
				crossing_safety.reserve(agent)
			return
		agent.node = agent.target_node
		agent.erase("impact_rejoining")
		_choose_next(agent)
		if bool(agent.get("crossing_committed", false)):
			crossing_safety.reserve(agent)
	else:
		var desired_distance := minf(float(agent.speed) * delta, difference.length())
		var desired_direction := difference.normalized()
		var movement_direction := _walker_avoidance_direction(agent, desired_direction) if is_ground_walker else desired_direction
		var next_position := current_position + movement_direction * desired_distance
		if is_ground_walker and not _walker_step_clear(agent, next_position):
			# A failed preferred side is not evidence both sides are blocked.
			movement_direction = _walker_avoidance_direction(agent, desired_direction, true)
			next_position = current_position + movement_direction * desired_distance
			if not _walker_step_clear(agent, next_position):
				return
		# The imported path was already validated. Repeat the more expensive
		# building/water probe only when avoidance actually leaves that line.
		var steering_sideways := absf(desired_direction.cross(movement_direction)) > 0.02
		if is_ground_walker and (steering_sideways or bool(agent.get("impact_rejoining", false))) and not _walk_segment_is_clear(current_position, next_position):
			# The preferred passing side may be blocked by a building, water or
			# the edge of the map. Try the other side before safely slowing down.
			movement_direction = _walker_avoidance_direction(agent, desired_direction, true)
			next_position = current_position + movement_direction * desired_distance
			if not _walk_segment_is_clear(current_position, next_position) or not _walker_step_clear(agent, next_position):
				next_position = current_position
		agent.position = next_position
		if next_position != current_position:
			agent.angle = movement_direction.angle()


func _yield_crossing_landing(agent: Dictionary, delta: float) -> bool:
	# A waiting walker must not occupy the exact landing point of an admitted
	# walker. Step along the pavement, never sideways into the carriageway.
	if str(agent.get("kind", "")) not in ["person", "robot"] or bool(agent.get("crossing_committed", false)) or bool(agent.get("route_bridge", false)) or bool(agent.get("route_tunnel", false)):
		return false
	if _point_on_vehicle_road(agent.position):
		return false
	for other in _nearby_walkers(agent.position):
		if other == agent or not bool(other.get("crossing_committed", false)) or int(other.get("route_layer", 0)) != int(agent.get("route_layer", 0)):
			continue
		if Vector2(other.target).distance_to(agent.position) > 9.0:
			continue
		var side := Vector2(other.position).direction_to(other.target).orthogonal()
		for sign_value in [1.0, -1.0]:
			var next: Vector2 = agent.position + side * sign_value * minf(float(agent.speed) * delta, 2.0)
			if _point_on_vehicle_road(next) or not _walk_segment_is_clear(agent.position, next) or not _walker_step_clear(agent, next):
				continue
			agent.position = next
			return true
	return false


func _rebuild_walker_cells() -> void:
	walker_cells.clear()
	for agent in agents:
		if not _agent_in_active_space(agent):
			continue
		if str(agent.get("kind", "")) not in ["person", "robot"]:
			continue
		walker_cells.get_or_add(_walker_cell(Vector2(agent.position)), []).append(agent)


func _walker_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / WALKER_AVOIDANCE_CELL_SIZE), floori(position.y / WALKER_AVOIDANCE_CELL_SIZE))


func _walker_target_occupied(agent: Dictionary, target: Vector2) -> bool:
	for other in _nearby_walkers(target):
		if other == agent or int(other.get("route_layer", 0)) != int(agent.get("route_layer", 0)) or bool(other.get("route_bridge", false)) != bool(agent.get("route_bridge", false)) or bool(other.get("route_tunnel", false)) != bool(agent.get("route_tunnel", false)):
			continue
		if Vector2(other.position).distance_to(target) < _walker_body_gap(agent, other):
			return true
	return false


func _walker_body_gap(agent: Dictionary, other: Dictionary) -> float:
	# Match the physical impact radii, rather than allowing ordinary walking
	# to pack two bodies into a four-pixel gap before a crash occurs.
	return (4.5 if str(agent.kind) == "robot" else 3.5) + (4.5 if str(other.kind) == "robot" else 3.5)


func _walker_step_clear(agent: Dictionary, next_position: Vector2) -> bool:
	# Population sprites have no physics bodies. Respect the walking player's
	# feet too, so a stationary player cannot be walked through by NPCs/NPRs.
	if not traffic_obstacles.is_empty():
		var foot_player := traffic_obstacles[0] as CharacterBody2D
		if is_instance_valid(foot_player) and foot_player.visible:
			var travel = foot_player.get("crossing_travel")
			if travel != null and OnFootCollision.same_level(agent, travel.active):
				var radius: float = (4.5 if str(agent.kind) == "robot" else 3.5) + 4.0 * float(foot_player.get("art_scale"))
				if not OnFootCollision._circle_contact(Vector2(agent.position), next_position, foot_player.position, radius).is_empty(): return false
	if bool(agent.get("crossing_committed", false)):
		var reservation: Dictionary = crossing_safety.reservations.get(int(agent.get("walker_id", -1)), {})
		var segments: Array = reservation.get("segments", [])
		if not segments.is_empty():
			var in_corridor := false
			for segment in segments:
				var nearest := Geometry2D.get_closest_point_to_segment(next_position, segment.start, segment.finish)
				if nearest.distance_to(next_position) <= WALKER_PERSONAL_SPACE:
					in_corridor = true
					break
			if not in_corridor:
				return false
	if is_instance_valid(owned_wagon) and owned_wagon.visible and owned_wagon.shape != null:
		var crossing: Dictionary = owned_wagon.crossing_travel.active
		var same_level := int(agent.get("route_layer", 0)) == int(crossing.get("layer", 0)) and bool(agent.get("route_bridge", false)) == (str(crossing.get("kind", "")) == "bridge") and bool(agent.get("route_tunnel", false)) == (str(crossing.get("kind", "")) == "tunnel")
		if same_level:
			var half: Vector2 = owned_wagon.shape.size * 0.5 + Vector2.ONE * 4.0
			var local_start := (Vector2(agent.position) - owned_wagon.position).rotated(-owned_wagon.rotation)
			var local_end := (next_position - owned_wagon.position).rotated(-owned_wagon.rotation)
			var bounds := Rect2(-half, half * 2.0)
			var approaching := local_end.length_squared() <= local_start.length_squared()
			if bounds.has_point(local_start):
				if approaching:
					return false
			else:
				if bounds.has_point(local_end):
					return false
				var corners := [Vector2(-half.x,-half.y), Vector2(half.x,-half.y), half, Vector2(-half.x,half.y)]
				for index in 4:
					if Geometry2D.segment_intersects_segment(local_start, local_end, corners[index], corners[(index+1)%4]) != null:
						return false
	for other in _nearby_walkers(agent.position):
		if other == agent or int(other.get("route_layer", 0)) != int(agent.get("route_layer", 0)) or bool(other.get("route_bridge", false)) != bool(agent.get("route_bridge", false)) or bool(other.get("route_tunnel", false)) != bool(agent.get("route_tunnel", false)):
			continue
		var before := Vector2(agent.position).distance_to(other.position)
		var nearest := Geometry2D.get_closest_point_to_segment(other.position, agent.position, next_position)
		var body_gap := _walker_body_gap(agent, other)
		if nearest.distance_to(other.position) < body_gap and (before >= body_gap or next_position.distance_to(other.position) < before):
			return false
	return true


func _nearby_walkers(position: Vector2) -> Array:
	var nearby: Array = []
	var centre := _walker_cell(position)
	for cell_y in range(centre.y - 1, centre.y + 2):
		for cell_x in range(centre.x - 1, centre.x + 2):
			nearby.append_array(walker_cells.get(Vector2i(cell_x, cell_y), []))
	return nearby


func _walker_avoidance_direction(agent: Dictionary, desired: Vector2, opposite_side: bool = false) -> Vector2:
	# Unadmitted crossings and grade-separated corridors keep their line.
	# Admitted crossings may pass a character, bounded to the reserved corridor
	# by _walker_step_clear; they cannot wander into an unreserved traffic lane.
	var may_step_sideways := (not bool(agent.get("route_crossing", false)) or bool(agent.get("crossing_committed", false))) and not bool(agent.get("route_bridge", false)) and not bool(agent.get("route_tunnel", false))
	var steering := desired
	var nearest_ahead := INF
	for other_value in _nearby_walkers(Vector2(agent.position)):
		var other: Dictionary = other_value
		if other == agent or int(other.get("route_layer", 0)) != int(agent.get("route_layer", 0)):
			continue
		if bool(other.get("route_bridge", false)) != bool(agent.get("route_bridge", false)) or bool(other.get("route_tunnel", false)) != bool(agent.get("route_tunnel", false)):
			continue
		var offset := Vector2(other.position) - Vector2(agent.position)
		var distance := offset.length()
		if distance < 0.01:
			var own_id := int(agent.get("walker_id", 0))
			var other_id := int(other.get("walker_id", 0))
			if may_step_sideways:
				# Spawn nodes and narrow corners can put two walkers at exactly
				# the same coordinate. Stable IDs give them opposing escape sides.
				var escape_side := -1.0 if own_id < other_id else 1.0
				if opposite_side:
					escape_side *= -1.0
				steering += desired.orthogonal() * escape_side * 1.8
			elif own_id > other_id:
				return Vector2.ZERO
			continue
		if distance > WALKER_LOOK_AHEAD or desired.dot(offset) <= -1.0 or absf(desired.cross(offset)) > _walker_body_gap(agent, other) + 0.5:
			continue
		nearest_ahead = minf(nearest_ahead, distance)
		if may_step_sideways:
			# Everyone favours the same side relative to their own direction.
			# Head-on walkers therefore choose opposite world-space sides and pass
			# rather than mirroring one another back into the blockage.
			var passing_side := -1.0 if opposite_side else 1.0
			var side := desired.orthogonal() * passing_side
			var urgency := clampf((WALKER_LOOK_AHEAD - distance) / WALKER_LOOK_AHEAD, 0.0, 1.0)
			steering += side * (0.45 + urgency * 1.35)
			steering -= offset.normalized() * urgency * 0.55
	if nearest_ahead < WALKER_PERSONAL_SPACE and not may_step_sideways:
		# Stay on the legal crossing/corridor and leave a short walking gap.
		return desired * clampf(nearest_ahead / WALKER_PERSONAL_SPACE, 0.08, 0.65)
	# Unbounded summed repulsion can point backwards or become a tangential
	# orbit around a shared destination. Retain forward route progress.
	var forward := maxf(0.45, steering.dot(desired))
	var lateral := clampf(steering.dot(desired.orthogonal()), -1.2, 1.2)
	steering = desired * forward + desired.orthogonal() * lateral
	return steering.normalized() if steering.length_squared() > 0.001 else desired


func _advance_traffic(agent: Dictionary, delta: float) -> void:
	var target: Vector2 = agent.target
	var current_position: Vector2 = agent.position
	var difference: Vector2 = target - current_position
	var reaches_target := difference.length() <= maxf(2.0, float(agent.speed) * delta)
	var next_position := target if reaches_target else current_position + difference.normalized() * float(agent.speed) * delta
	agent.next_angle = lerp_angle(float(agent.angle), difference.angle(), 1.0 - exp(-delta * 7.0))
	if bool(agent.get("impact_rejoining", false)):
		var from := TrafficFlowScript.visible_vehicle_position(agent, current_position)
		var clear := true
		var steps := maxi(1, ceili(current_position.distance_to(next_position) / 2.0))
		steps = maxi(steps, ceili(absf(angle_difference(float(agent.angle), float(agent.next_angle))) / 0.08))
		for step in range(1, steps + 1):
			var fraction := float(step) / steps
			var heading := lerp_angle(float(agent.angle), float(agent.next_angle), fraction)
			var to := current_position.lerp(next_position, fraction) + Vector2.UP.rotated(heading) * (9.5 if driving_side == "left" else -9.5)
			if not ImpactMotion.pose_clear(agent, from, to, self, heading + PI * 0.5):
				clear = false
				break
			from = to
		if not clear:
			agent.blocked_reason = "Crash recovery path blocked"
			# Retain the existing bounded jam recovery if returning is impossible.
			if traffic_flow.update_wait_and_recover(agent, delta, elapsed, graphs.traffic, _outdoor_agents(), traffic_obstacles, rng):
				agent.erase("impact_rejoining")
				_choose_next(agent)
			return
	var graph: Dictionary = graphs.traffic
	var outdoor_agents := _outdoor_agents()
	if traffic_flow.can_move(agent, outdoor_agents, next_position, graph, traffic_obstacles, elapsed, delta, crossing_safety):
		agent.position = next_position
		agent.angle = agent.next_angle
		agent.waiting_seconds = 0.0
		if reaches_target:
			agent.erase("impact_rejoining")
			agent.node = agent.target_node
			traffic_flow.complete_segment(agent)
			var planned_exit := int(agent.get("planned_exit_node", -1))
			_choose_next(agent, false, planned_exit)
		return
	if traffic_flow.update_wait_and_recover(agent, delta, elapsed, graph, outdoor_agents, traffic_obstacles, rng):
		_choose_next(agent)


func counts_text() -> String:
	var counts: Dictionary = {"traffic": 0, "person": 0, "robot": 0, "drone": 0}
	for agent in agents:
		var kind: String = str(agent.kind)
		counts[kind] = int(counts.get(kind, 0)) + 1
	return "CARS %d  NPCs %d  NPRs %d  NPDs %d" % [counts.traffic, counts.person, counts.robot, counts.drone]


func nearest_conversation_target(position: Vector2, maximum_distance: float) -> Dictionary:
	var result: Dictionary = {}
	var nearest_distance := maximum_distance
	for index in agents.size():
		var agent: Dictionary = agents[index]
		if not _agent_in_active_space(agent):
			continue
		if not _interior_position_is_visible(Vector2(agent.get("position", Vector2.INF))):
			continue
		if str(agent.get("kind", "")) not in ["person", "robot"]:
			continue
		if bool(agent.get("route_tunnel", false)) or bool(agent.get("route_bridge", false)):
			continue
		var distance: float = position.distance_to(Vector2(agent.get("position", Vector2.INF)))
		if distance > nearest_distance:
			continue
		if active_interior_building_id.is_empty() and building_segment_check.is_valid() and not bool(building_segment_check.call(position, Vector2(agent.position))):
			continue
		nearest_distance = distance
		result = {"index": index, "agent": agent, "distance": distance}
	return result


func begin_conversation(agent_index: int, player_position: Vector2) -> bool:
	if agent_index < 0 or agent_index >= agents.size():
		return false
	var agent: Dictionary = agents[agent_index]
	if not _agent_in_active_space(agent) or not _interior_position_is_visible(Vector2(agent.get("position", Vector2.INF))):
		return false
	if str(agent.get("kind", "")) not in ["person", "robot"]:
		return false
	agent["conversation_paused"] = true
	agent["moving"] = false
	agent["angle"] = Vector2(agent.position).direction_to(player_position).angle()
	queue_redraw()
	return true


func end_conversation(agent_index: int) -> void:
	if agent_index < 0 or agent_index >= agents.size():
		return
	agents[agent_index]["conversation_paused"] = false
	queue_redraw()


func conversation_target_position(agent_index: int) -> Vector2:
	if agent_index < 0 or agent_index >= agents.size():
		return Vector2.INF
	return Vector2(agents[agent_index].get("position", Vector2.INF))


func conversation_target_kind(agent_index: int) -> String:
	if agent_index < 0 or agent_index >= agents.size():
		return ""
	return str(agents[agent_index].get("kind", ""))


func conversation_target_persona(agent_index: int) -> Dictionary:
	if agent_index < 0 or agent_index >= agents.size():
		return {}
	var persona_id := str(agents[agent_index].get("persona_id", ""))
	for value in persona_library.get("personas", []):
		if value is Dictionary and str(value.get("id", "")) == persona_id:
			return value
	return {}


func conversation_target_name(agent_index: int) -> String:
	if agent_index < 0 or agent_index >= agents.size():
		return "Character"
	var agent: Dictionary = agents[agent_index]
	return str(agent.get("display_name", "NPR" if str(agent.get("kind", "")) == "robot" else "NPC"))


func conversation_target_height(agent_index: int) -> float:
	if agent_index < 0 or agent_index >= agents.size():
		return 0.0
	if str(agents[agent_index].get("kind", "")) == "robot":
		return 25.0 * NPR_VISUAL_SCALE
	return ActorArt.GROUND_CHARACTER_DRAW_SIZE.y


func _draw() -> void:
	if not active_interior_building_id.is_empty():
		for agent in agents:
			if _agent_in_active_space(agent) and _interior_position_is_visible(Vector2(agent.position)) and _draws_position(agent.position):
				_draw_agent(agent)
		return
	_draw_traffic_controls()
	# Draw lower-layer road users first. The bridge deck is then painted over
	# them, and bridge users are painted on top of the deck. This preserves the
	# two independent OSM layers at a road-over-road crossing.
	for agent in agents:
		if not _agent_in_active_space(agent):
			continue
		if bool(agent.get("route_tunnel", false)) or bool(agent.get("route_bridge", false)) or str(agent.kind) == "drone":
			continue
		if not _draws_position(agent.position):
			continue
		_draw_agent(agent)
	_draw_bridge_decks()
	for agent in agents:
		if not _agent_in_active_space(agent):
			continue
		if bool(agent.get("route_tunnel", false)) or not bool(agent.get("route_bridge", false)):
			continue
		if not _draws_position(agent.position):
			continue
		if not _bridge_id_is_visible(str(agent.get("route_source_way_id", ""))):
			continue
		_draw_agent(agent)
	for agent in agents:
		if not _agent_in_active_space(agent):
			continue
		if str(agent.kind) == "drone":
			if not _draws_position(agent.position):
				continue
			_draw_agent(agent)


func _draw_agent(agent: Dictionary) -> void:
	var position: Vector2 = agent.position
	match str(agent.kind):
		"traffic":
			position = TrafficFlowScript.visible_vehicle_position(agent, position)
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
	for post in graphs.get("traffic", {}).get("signal_posts", []):
		var direction: Vector2 = post.direction
		var side := Vector2(direction.y, -direction.x) * (1.0 if driving_side == "left" else -1.0)
		var position: Vector2 = post.stop_position + side * float(post.get("side_distance", 22.0))
		if not _draws_position(position):
			continue
		var color := _signal_color(traffic_flow.signal_state(direction, elapsed))
		draw_line(position, position + Vector2(0, 5), Color("#263d31"), 2.0)
		draw_rect(Rect2(position - Vector2(3, 5), Vector2(6, 8)), Color("#263d31"))
		draw_circle(position - Vector2(0, 2), 2.0, color)
		# Small approach-facing stop line; no light is drawn on the exit lane.
		var line_centre: Vector2 = post.stop_position + side * 9.5 + direction * 20.0
		draw_line(line_centre - side * 9.0, line_centre + side * 9.0, Color("#e2dcc0"), 1.0)
	for control_node_value in graphs.get("traffic", {}).get("control_nodes", []):
		var control_node: Dictionary = control_node_value
		var position: Vector2 = control_node.position
		if not _draws_position(position):
			continue
		match str(control_node.control):
			"traffic_signals":
				pass # Approach-owned posts above replace raw OSM signal-node pairs.
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
	var facing := Vector2.RIGHT.rotated(float(agent.get("angle", 0.0)))
	var artwork: Dictionary = ActorArt.directional_sprite(str(agent.get("npc_asset", "npc_medium_man_adult")), facing)
	if not artwork.is_empty():
		var lift := absf(sin(phase * 14.0)) * 1.0 if bool(agent.get("moving", false)) else 0.0
		var lean := sin(phase * 14.0) * 0.035 if bool(agent.get("moving", false)) else 0.0
		draw_circle(position, ActorArt.GROUND_CHARACTER_DRAW_SIZE.x * 0.32, Color(0.05, 0.10, 0.07, 0.20))
		draw_set_transform(position + Vector2(0.0, -lift * NPC_VISUAL_SCALE), lean, Vector2.ONE)
		draw_texture_rect_region(artwork.texture, ActorArt.grounded_character_rect(), artwork.region)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_rect(Rect2(position + ActorArt.grounded_character_rect().position, ActorArt.GROUND_CHARACTER_DRAW_SIZE), Color("#d34f6a"))


func _draw_robot(agent: Dictionary, position: Vector2) -> void:
	var phase := float(agent.phase)
	var foot := 1.0 if int(phase * 8.0) % 4 == 1 else (-1.0 if int(phase * 8.0) % 4 == 3 else 0.0)
	var facing := Vector2.RIGHT.rotated(float(agent.get("angle", 0.0)))
	var walk_frame := int(phase * 8.0) % 4 if bool(agent.get("moving", false)) else 0
	var artwork: Dictionary = ActorArt.directional_sprite("npr", facing, walk_frame)
	if not artwork.is_empty():
		var stride := sin(phase * 15.0) if bool(agent.get("moving", false)) else 0.0
		draw_circle(position, 4.0 * NPR_VISUAL_SCALE, Color(0.05, 0.10, 0.07, 0.20))
		draw_set_transform(position + Vector2(0.0, -absf(stride) * NPR_VISUAL_SCALE), stride * 0.045, Vector2.ONE * NPR_VISUAL_SCALE)
		draw_texture_rect_region(artwork.texture, Rect2(-9.0, -25.0, 18.0, 25.0), artwork.region)
		if int(elapsed * 4.0) % 2 == 0:
			draw_circle(Vector2(0.0, -24.0), 1.0, Color("#ffda75"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform(position, 0.0, Vector2.ONE * NPR_VISUAL_SCALE)
	_agent_pixel(Vector2.ZERO, 4, 17, 3, 4 + foot, Color("#244a4e"))
	_agent_pixel(Vector2.ZERO, 9, 17, 3, 4 - foot, Color("#244a4e"))
	_agent_pixel(Vector2.ZERO, 3, 20 + foot, 4, 2, Color("#65aeb0"))
	_agent_pixel(Vector2.ZERO, 9, 20 - foot, 4, 2, Color("#65aeb0"))
	_agent_pixel(Vector2.ZERO, 3, 9, 10, 9, Color("#e6dfc9"))
	_agent_pixel(Vector2.ZERO, 5, 12, 6, 5, Color("#25818a"))
	_agent_pixel(Vector2.ZERO, 1, 11 - foot, 2, 5, Color("#4a6262"))
	_agent_pixel(Vector2.ZERO, 13, 11 + foot, 2, 5, Color("#4a6262"))
	_agent_pixel(Vector2.ZERO, 3, 2, 10, 8, Color("#e6dfc9"))
	_agent_pixel(Vector2.ZERO, 4, 4, 8, 4, Color("#172c31"))
	_agent_pixel(Vector2.ZERO, 5, 5, 2, 1, Color("#53e2e0"))
	_agent_pixel(Vector2.ZERO, 10, 5, 1, 1, Color("#53e2e0"))
	_agent_pixel(Vector2.ZERO, 7, 0, 3, 2, Color("#e49a32"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_drone(agent: Dictionary, position: Vector2) -> void:
	var artwork: Dictionary = ActorArt.sprite("npd")
	if not artwork.is_empty():
		var phase := float(agent.phase)
		draw_circle(position + Vector2(4.0, 8.0), 7.0, Color(0.05, 0.08, 0.07, 0.22))
		draw_set_transform(position + Vector2(0.0, sin(phase * 4.0) * 1.5), float(agent.get("angle", 0.0)) + PI * 0.5, Vector2.ONE)
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
		if traffic_graph:
			var tags: Dictionary = road_tags_by_id.get(str(edge.get("source_way_id", "")), {})
			edge_by_pair["%d>%d" % [from, to]]["half_width_pixels"] = RoadDimensionsScript.half_width_metres(tags) * scale
		if not neighbours.has(from):
			neighbours[from] = {}
		if not neighbours.has(to):
			neighbours[to] = {}
		neighbours[from][to] = true
		neighbours[to][from] = true
	var degree: Dictionary = {}
	for node_id in nodes:
		degree[node_id] = neighbours.get(node_id, {}).size()
	var component_by_node := _component_lookup(nodes, neighbours)
	var routable_ids: Array = adjacency.keys()
	var routable_lookup: Dictionary = {}
	for node_id in routable_ids:
		routable_lookup[node_id] = true
	var routable_cbd_ids: Array[int] = []
	for node_id in cbd_nodes:
		if routable_lookup.has(node_id):
			routable_cbd_ids.append(node_id)
	var prepared := {"nodes": nodes, "geographic_by_node": geographic_by_node, "adjacency": adjacency, "edge_by_pair": edge_by_pair, "degree": degree, "component_by_node": component_by_node, "control_by_node": control_by_node, "control_nodes": control_nodes, "all_ids": routable_ids, "cbd_ids": routable_cbd_ids}
	if traffic_graph:
		SignalJunctionsScript.prepare(prepared, scale)
	return prepared


func _component_lookup(nodes: Dictionary, neighbours: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var component_id := 0
	for node_value in nodes:
		var node_id := int(node_value)
		if result.has(node_id):
			continue
		var queue: Array[int] = [node_id]
		var head := 0
		result[node_id] = component_id
		while head < queue.size():
			var current := queue[head]
			head += 1
			for neighbour_value in neighbours.get(current, {}):
				var neighbour := int(neighbour_value)
				if result.has(neighbour):
					continue
				result[neighbour] = component_id
				queue.append(neighbour)
		component_id += 1
	return result


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
			agent["route_nodes"] = []
			agent["destination_node"] = -1
			agent["destination_wait_seconds"] = 0.0
			agent["completed_destinations"] = 0
			var choices: Array[Dictionary] = npr_personas if kind == "robot" else npc_personas
			if not choices.is_empty():
				agent["persona_id"] = str(choices[rng.randi_range(0, choices.size() - 1)].get("id", ""))
		if kind == "person":
			# Even population sizes have an exact half-and-half split; an odd
			# population differs by only one. Alternation also balances the CBD.
			agent["gender"] = "woman" if index % 2 == 0 else "man"
			agent["display_name"] = _random_npc_name(str(agent.gender))
			agent["skin_tone_group"] = _choose_skin_tone_group()
			agent["age_group"] = AGE_GROUPS[floori(index / 2.0) % AGE_GROUPS.size()]
			agent["npc_asset"] = "npc_%s_%s_%s" % [agent.skin_tone_group, agent.gender, agent.age_group]
		elif kind == "robot":
			agent["display_name"] = _random_robot_name()
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
		if kind in ["person", "robot"]:
			_initialise_destination_travel(agent)
		_choose_next(agent)
		if kind == "traffic" and not _place_traffic_at_clear_start(agent, candidates):
			agents.erase(agent)
			push_warning("No clear legal startup space for a traffic car; omitted rather than overlapping the player or another car.")


func _add_storyline_npcs(projection: Dictionary, scale: float) -> void:
	var graph: Dictionary = graphs.get("person", {})
	var graph_nodes: Dictionary = graph.get("nodes", {})
	for value in storyline_npc_data.get("npcs", []):
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		var location: Dictionary = record.get("location", {})
		var nearest_node := -1
		var location_space := str(location.get("space", "outdoors"))
		var position := Vector2.ZERO
		if location_space == "interior":
			position = Vector2(float(location.get("x_metres", 0.0)), float(location.get("y_metres", 0.0))) * scale
		else:
			position = ProjectionScript.geographic_to_world(ProjectionScript.value_to_location(location), projection, scale)
			if ground_check.is_valid() and not bool(ground_check.call(position, 1.0)):
				push_warning("Storyline NPC %s was omitted because its saved outdoor location is no longer safe ground." % str(record.get("id", "")))
				continue
			var nearest_distance := INF
			for node_value in graph_nodes:
				var node_id := int(node_value)
				var distance: float = position.distance_squared_to(Vector2(graph_nodes[node_id]))
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_node = node_id
			if nearest_node < 0 or sqrt(nearest_distance) > StorylineNpcStore.MAXIMUM_PEDESTRIAN_LINK_METRES * scale:
				push_warning("Storyline NPC %s was omitted because it is no longer near a generated pedestrian route." % str(record.get("id", "")))
				continue
		var appearance: Dictionary = record.get("appearance", {})
		var agent := {
			"kind": "robot" if str(record.get("actor_kind", "")) == "npr" or str(record.get("npc_role", "")) == "npr" else "person", "node": nearest_node, "target_node": nearest_node,
			"position": position, "target": position, "speed": 0.0, "angle": 0.0,
			"graph_key": "person", "phase": 0.0, "walker_id": agents.size(),
			"persona_id": str(record.get("persona_id", "")),
			"display_name": str(record.get("display_name", "Storyline NPC")),
			"gender": str(appearance.get("gender", "woman")),
			"skin_tone_group": str(appearance.get("skin_tone_group", "medium")),
			"age_group": str(appearance.get("age_group", "adult")),
			"npc_asset": str(appearance.get("npc_asset", "npc_medium_woman_adult")),
			"storyline_npc_id": str(record.get("id", "")),
			"npc_role": str(record.get("npc_role", "storyline")),
			"storyline_stationary": bool(record.get("behaviour", {}).get("stationary", true)),
			"space": location_space,
			"building_id": str(location.get("building_id", "")),
			"floor_id": str(location.get("floor_id", "")),
			"moving": false, "route_bridge": false, "route_tunnel": false, "route_layer": 0
		}
		agents.append(agent)


func _random_npc_name(gender: String) -> String:
	var first_names: Array = NPC_NAMES_BY_GENDER.get(gender, NPC_NAMES_BY_GENDER.man)
	for _attempt in 64:
		var candidate := "%s %s" % [first_names[rng.randi_range(0, first_names.size() - 1)], NPC_SURNAMES[rng.randi_range(0, NPC_SURNAMES.size() - 1)]]
		if not used_character_names.has(candidate):
			used_character_names[candidate] = true
			return candidate
	var fallback := "%s %s-%03d" % [first_names[rng.randi_range(0, first_names.size() - 1)], NPC_SURNAMES[rng.randi_range(0, NPC_SURNAMES.size() - 1)], used_character_names.size() + 1]
	used_character_names[fallback] = true
	return fallback


func _random_robot_name() -> String:
	for _attempt in 64:
		var candidate := "NPR-%03d" % rng.randi_range(1, 999)
		if not used_character_names.has(candidate):
			used_character_names[candidate] = true
			return candidate
	var fallback := "NPR-%04d" % (used_character_names.size() + 1)
	used_character_names[fallback] = true
	return fallback


func _place_traffic_at_clear_start(agent: Dictionary, preferred_ids: Array) -> bool:
	var graph: Dictionary = graphs.traffic
	for attempt in 96:
		var ids: Array = preferred_ids if attempt < 48 and not preferred_ids.is_empty() else graph.all_ids
		if ids.is_empty():
			return false
		traffic_flow.complete_segment(agent, true)
		agent.node = int(ids[rng.randi_range(0, ids.size()-1)])
		agent.position = graph.nodes[agent.node]
		_choose_next(agent)
		var direction: Vector2 = agent.target - agent.position
		if direction.length() < 70.0:
			continue
		agent.position = Vector2(agent.position).lerp(agent.target, rng.randf_range(0.15, 0.85))
		agent.angle = direction.angle()
		var centre := TrafficFlowScript.visible_vehicle_position(agent, agent.position)
		var clear := true
		for obstacle in traffic_obstacles:
			if is_instance_valid(obstacle) and centre.distance_to(obstacle.position) < 160.0:
				clear = false
		for other in agents:
			if other != agent and str(other.get("kind", "")) == "traffic" and centre.distance_to(TrafficFlowScript.visible_vehicle_position(other, other.position)) < 70.0:
				clear = false
		var zones: Dictionary = graph.get("junction_zone_by_node", {})
		for node in [int(agent.node), int(agent.target_node)]:
			if zones.has(node) and centre.distance_to(graph.nodes[node]) < 80.0:
				clear = false
		if ground_check.is_valid() and not bool(ground_check.call(centre, 22.0)) and not bool(agent.get("route_bridge", false)) and not bool(agent.get("route_tunnel", false)):
			clear = false
		if clear:
			return true
	return false


func _choose_next(agent: Dictionary, avoid_crossing: bool = false, preferred_target: int = -1) -> void:
	# A vertex inside the carriageway is not a safe crossing exit.
	if bool(agent.get("crossing_committed", false)) and not _point_on_vehicle_road(agent.position):
		crossing_safety.release(agent)
	var graph: Dictionary = graphs[agent.graph_key]
	if str(agent.kind) == "traffic":
		var junction_route: Array = agent.get("junction_route", [])
		if not junction_route.is_empty() and int(junction_route[0]) == int(agent.node):
			junction_route.pop_front()
		if not junction_route.is_empty():
			preferred_target = int(junction_route[0])
	if str(agent.kind) in ["person", "robot"] and bool(agent.get("destination_routing", false)):
		if avoid_crossing:
			# A prolonged unsafe crossing invalidates this route. Choose a safe
			# local edge now, then plan a fresh destination from the next node.
			agent.route_nodes = []
			agent.destination_node = -1
		elif preferred_target < 0:
			var planned_route: Array = agent.get("route_nodes", [])
			if not planned_route.is_empty():
				preferred_target = int(planned_route.pop_front())
				agent.route_nodes = planned_route
			elif int(agent.get("destination_node", -1)) == int(agent.node) and not bool(agent.get("crossing_committed", false)):
				_start_destination_visit(agent)
				return
			elif _assign_destination_route(agent):
				planned_route = agent.get("route_nodes", [])
				if not planned_route.is_empty():
					preferred_target = int(planned_route.pop_front())
					agent.route_nodes = planned_route
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
	if preferred_target >= 0 and preferred_target not in options and str(agent.kind) in ["person", "robot"]:
		agent.route_nodes = []
		agent.destination_node = -1
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
		if str(agent.get("route_phase", "")) == "blocked" and bool(agent.get("destination_routing", false)):
			agent.route_nodes = []
			agent.destination_node = -1
			agent.destination_wait_seconds = 1.0
	agent["crossing_retry_seconds"] = 0.0
	agent["crossing_wait_seconds"] = 0.0
	if str(agent.kind) == "traffic":
		agent.driving_side = driving_side
		var exit_options: Array = graph.adjacency.get(agent.target_node, []).duplicate()
		if exit_options.size() > 1:
			exit_options.erase(int(agent.node))
		agent["planned_exit_node"] = int(exit_options[rng.randi_range(0, exit_options.size() - 1)]) if not exit_options.is_empty() else -1
		if graph.has("junction_zone_by_node"):
			var remaining: Array = agent.get("junction_route", [])
			if remaining.is_empty() or int(remaining[0]) != int(agent.target_node):
				SignalJunctionsScript.plan(agent, graph, rng)
			remaining = agent.get("junction_route", [])
			if remaining.size() > 1:
				agent.planned_exit_node = int(remaining[1])
		agent["planned_exit_position"] = graph.nodes.get(int(agent.planned_exit_node), agent.target)


func _prepare_population_destinations(destination_data: Dictionary) -> void:
	population_destinations.clear()
	destinations_by_category.clear()
	destination_route_cache.clear()
	var pedestrian_nodes: Dictionary = graphs.get("person", {}).get("nodes", {})
	for value in destination_data.get("destinations", []):
		var destination: Dictionary = value.duplicate(true)
		var node_id := int(destination.get("pedestrian_node_id", -1))
		if not pedestrian_nodes.has(node_id):
			continue
		var category := str(destination.get("category", ""))
		if category.is_empty():
			continue
		destination["route_component"] = int(graphs.person.get("component_by_node", {}).get(node_id, -1))
		population_destinations.append(destination)
		destinations_by_category.get_or_add(category, []).append(destination)


func _initialise_destination_travel(agent: Dictionary) -> void:
	agent.destination_routing = not _destinations_in_agent_component(agent, population_destinations).is_empty()
	if not bool(agent.destination_routing):
		return
	if str(agent.kind) == "person":
		var homes := _destinations_in_agent_component(agent, destinations_by_category.get("residential", []))
		if not homes.is_empty():
			var home: Dictionary = homes[rng.randi_range(0, homes.size() - 1)]
			agent.home_destination_id = str(home.get("id", ""))
			agent.home_destination_node = int(home.get("pedestrian_node_id", -1))
	_assign_destination_route(agent)


func _assign_destination_route(agent: Dictionary) -> bool:
	if not bool(agent.get("destination_routing", false)):
		return false
	var candidates: Array = []
	var next_mode := "activity"
	var previous_mode := str(agent.get("destination_mode", ""))
	if str(agent.kind) == "person" and previous_mode == "activity" and int(agent.get("home_destination_node", -1)) >= 0:
		for home_value in destinations_by_category.get("residential", []):
			var home: Dictionary = home_value
			if str(home.get("id", "")) == str(agent.get("home_destination_id", "")):
				candidates.append(home)
				break
		next_mode = "home"
	else:
		for destination in population_destinations:
			if str(destination.get("category", "")) != "residential" and _destination_matches_agent_component(agent, destination):
				candidates.append(destination)
		if candidates.is_empty():
			candidates = _destinations_in_agent_component(agent, population_destinations)
	if candidates.is_empty():
		return false
	var first_index := rng.randi_range(0, candidates.size() - 1)
	var attempts := mini(candidates.size(), 16)
	for offset in attempts:
		var destination: Dictionary = candidates[(first_index + offset) % candidates.size()]
		var destination_node := int(destination.get("pedestrian_node_id", -1))
		if destination_node == int(agent.node):
			continue
		var route := _find_route(graphs.person, int(agent.node), destination_node)
		if route.size() < 2:
			continue
		agent.route_nodes = route.slice(1)
		agent.destination_node = destination_node
		agent.destination_id = str(destination.get("id", ""))
		agent.destination_name = str(destination.get("name", "Mapped destination"))
		agent.destination_category = str(destination.get("category", ""))
		agent.destination_mode = next_mode
		return true
	return false


func _destinations_in_agent_component(agent: Dictionary, source: Array) -> Array:
	var result: Array = []
	for value in source:
		var destination: Dictionary = value
		if _destination_matches_agent_component(agent, destination):
			result.append(destination)
	return result


func _destination_matches_agent_component(agent: Dictionary, destination: Dictionary) -> bool:
	var graph: Dictionary = graphs.get("person", {})
	var component_by_node: Dictionary = graph.get("component_by_node", {})
	var agent_component := int(component_by_node.get(int(agent.node), -1))
	return agent_component >= 0 and agent_component == int(destination.get("route_component", -2))


func _start_destination_visit(agent: Dictionary) -> void:
	agent.completed_destinations = int(agent.get("completed_destinations", 0)) + 1
	agent.destination_wait_seconds = rng.randf_range(4.0, 10.0)
	agent.target_node = agent.node
	agent.target = graphs[agent.graph_key].nodes[agent.node]
	agent.route_bridge = false
	agent.route_tunnel = false
	agent.route_layer = 0
	agent.route_source_way_id = ""
	agent.route_crossing = false
	agent.route_phase = "destination"


func _find_route(graph: Dictionary, start_node: int, destination_node: int) -> Array:
	if start_node == destination_node:
		return [start_node]
	var cache_key := "%d>%d" % [start_node, destination_node]
	if destination_route_cache.has(cache_key):
		return destination_route_cache[cache_key].duplicate()
	var queue: Array[int] = [start_node]
	var head := 0
	var previous: Dictionary = {start_node: -1}
	while head < queue.size():
		var current := queue[head]
		head += 1
		for next_value in graph.get("adjacency", {}).get(current, []):
			var next_node := int(next_value)
			if previous.has(next_node):
				continue
			previous[next_node] = current
			if next_node == destination_node:
				head = queue.size()
				break
			queue.append(next_node)
	if not previous.has(destination_node):
		return []
	var reversed: Array[int] = [destination_node]
	var cursor := destination_node
	while cursor != start_node:
		cursor = int(previous[cursor])
		reversed.append(cursor)
	reversed.reverse()
	if destination_route_cache.size() >= 512:
		destination_route_cache.clear()
	destination_route_cache[cache_key] = reversed.duplicate()
	return reversed


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
	var has_signal := str(controls.get(int(agent.node), "")) == "traffic_signals" or str(controls.get(int(agent.target_node), "")) == "traffic_signals"
	agent.edge_signal_control = bool(agent.edge_crossing) and has_signal
	agent.route_signal_control = agent.edge_signal_control
	if connection_distance > 3.0 and not bool(edge.get("bridge", false)) and not bool(edge.get("tunnel", false)):
		# Switching sides or turning across a carriageway is a distinct,
		# reserved crossing. Cars yield only after the gap check succeeds.
		agent.route_phase = "link"
		agent.target = route_start
		agent.route_crossing = _walk_edge_crosses_vehicle_road(agent.position, route_start)
		agent.route_signal_control = bool(agent.route_crossing) and has_signal
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


func _point_on_vehicle_road(point: Vector2) -> bool:
	var cell := Vector2i(floori(point.x / 256.0), floori(point.y / 256.0))
	for index in vehicle_road_cells.get(cell, []):
		var road: Dictionary = vehicle_road_segments[int(index)]
		var nearest := Geometry2D.get_closest_point_to_segment(point, road.a, road.b)
		if point.distance_to(nearest) <= float(road.half_width) + 2.0:
			return true
	return false


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
