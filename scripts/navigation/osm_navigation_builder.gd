class_name OsmNavigationBuilder
extends RefCounted

const SCHEMA_VERSION := 1
const METRES_PER_LATITUDE_DEGREE := 110540.0
const METRES_PER_LONGITUDE_DEGREE := 111320.0
const NON_DRIVABLE_HIGHWAYS := [
	"footway", "path", "pedestrian", "steps", "cycleway", "bridleway",
	"corridor", "platform", "construction", "proposed", "raceway"
]
const NON_WALKABLE_HIGHWAYS := ["motorway", "motorway_link", "construction", "proposed", "raceway"]
const PEDESTRIAN_SPECIFIC_HIGHWAYS := ["footway", "path", "pedestrian", "steps", "living_street", "corridor", "platform"]
const MapGeometryValidatorScript = preload("res://scripts/validation/map_geometry_validator.gd")


func build(features: Array, cbd_bounds: Dictionary, starting_location: Dictionary, game_settings: Dictionary = {}) -> Dictionary:
	var driving_side := str(game_settings.get("road_rules", {}).get("driving_side", "left"))
	if driving_side not in ["left", "right"]:
		driving_side = "left"
	var geometry_validation: Dictionary = MapGeometryValidatorScript.new().analyse(features)
	var blocked_segments: Dictionary = geometry_validation.blocked_segment_lookup
	var vehicle_graph := _build_graph(features, "vehicle", blocked_segments)
	var pedestrian_graph := _build_graph(features, "pedestrian", blocked_segments)
	var aerial_graph := _build_aerial_graph(features, cbd_bounds)
	var warnings: Array[String] = []
	for warning in geometry_validation.warnings:
		warnings.append(str(warning))
	if vehicle_graph.nodes.is_empty():
		warnings.append("No drivable OSM roads were found, so vehicle pathfinding is unavailable.")
	if pedestrian_graph.nodes.is_empty():
		warnings.append("No walkable OSM routes were found, so pedestrian pathfinding is unavailable.")
	if int(vehicle_graph.component_count) > 1:
		warnings.append("The vehicle network has %d disconnected sections." % vehicle_graph.component_count)
	if int(pedestrian_graph.component_count) > 1:
		warnings.append("The pedestrian network has %d disconnected sections." % pedestrian_graph.component_count)
	var vehicle_controls: Dictionary = vehicle_graph.get("traffic_control_counts", {})
	var explicit_vehicle_control_count := int(vehicle_controls.get("traffic_signals", 0)) + int(vehicle_controls.get("stop", 0)) + int(vehicle_controls.get("give_way", 0))
	if not vehicle_graph.nodes.is_empty() and explicit_vehicle_control_count == 0:
		warnings.append("No OSM traffic lights, stop signs or give-way signs were found. Cars will use basic safe intersection reservations.")

	var vehicle_start: Dictionary = starting_location.get("vehicle", {})
	var player_start: Dictionary = {
		"longitude": starting_location.get("longitude", 0.0),
		"latitude": starting_location.get("latitude", 0.0)
	}
	var vehicle_access := _access_report(vehicle_graph, vehicle_start, cbd_bounds)
	var pedestrian_access := _access_report(pedestrian_graph, player_start, cbd_bounds)
	var aerial_access := _access_report(aerial_graph, player_start, cbd_bounds)
	if not vehicle_graph.nodes.is_empty() and not vehicle_access.cbd_reachable:
		warnings.append("The player's vehicle start cannot reach the CBD through the imported road network.")
	if not pedestrian_graph.nodes.is_empty() and not pedestrian_access.cbd_reachable:
		warnings.append("The player start cannot reach the CBD through the imported walking network.")

	return {
		"ok": true,
		"message": "Navigation networks generated.",
		"data": {
			"schema_version": SCHEMA_VERSION,
			"kind": "osm_navigation_graphs",
			"road_rules": {"driving_side": driving_side},
			"vehicle": vehicle_graph,
			"pedestrian": pedestrian_graph,
			"aerial": aerial_graph,
			"geometry_validation": {
				"schema_version": geometry_validation.schema_version,
				"kind": geometry_validation.kind,
				"blocked_segments": geometry_validation.blocked_segments,
				"clearance_conflicts": geometry_validation.clearance_conflicts,
				"unclassified_vertical_roads": geometry_validation.unclassified_vertical_roads,
				"statistics": geometry_validation.statistics
			},
			"access": {"vehicle": vehicle_access, "pedestrian": pedestrian_access, "aerial": aerial_access},
			"assumptions": {
				"pedestrians_may_walk_beside_ordinary_roads": true,
				"shared_osm_node_ids_form_intersections": true,
				"missing_lane_counts_use_one_route_each_direction": true,
				"npd_drones_may_fly_over_building_footprints": true,
				"ground_routes_cross_water_only_on_tagged_bridges_or_tunnels": true,
				"ground_road_segments_inside_solid_buildings_are_excluded": true
			},
			"warnings": warnings
		}
	}


func _build_aerial_graph(features: Array, cbd_bounds: Dictionary) -> Dictionary:
	var bounds := _feature_bounds(features)
	if bounds.is_empty():
		bounds = cbd_bounds.duplicate(true)
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	if bounds.is_empty() or float(bounds.east) <= float(bounds.west) or float(bounds.north) <= float(bounds.south):
		return {"mode": "aerial", "nodes": nodes, "edges": edges, "component_by_node": [], "component_sizes": [], "component_count": 0, "largest_component_size": 0, "allows_building_overflight": true}
	const GRID_SIZE := 5
	for row in GRID_SIZE:
		for column in GRID_SIZE:
			var longitude := lerpf(float(bounds.west), float(bounds.east), float(column) / float(GRID_SIZE - 1))
			var latitude := lerpf(float(bounds.south), float(bounds.north), float(row) / float(GRID_SIZE - 1))
			nodes.append({"id": nodes.size(), "longitude": longitude, "latitude": latitude})
	for row in GRID_SIZE:
		for column in GRID_SIZE:
			var from_id := row * GRID_SIZE + column
			if column + 1 < GRID_SIZE:
				_add_aerial_pair(edges, nodes, from_id, from_id + 1)
			if row + 1 < GRID_SIZE:
				_add_aerial_pair(edges, nodes, from_id, from_id + GRID_SIZE)
	return {
		"mode": "aerial",
		"nodes": nodes,
		"edges": edges,
		"component_by_node": _filled_array(nodes.size(), 0),
		"component_sizes": [nodes.size()],
		"component_count": 1,
		"largest_component_size": nodes.size(),
		"allows_building_overflight": true
	}


func _feature_bounds(features: Array) -> Dictionary:
	var west := INF
	var south := INF
	var east := -INF
	var north := -INF
	for feature in features:
		for point_value in feature.get("points", []):
			var point: Vector2 = point_value
			west = minf(west, point.x)
			south = minf(south, point.y)
			east = maxf(east, point.x)
			north = maxf(north, point.y)
	return {} if west == INF else {"west": west, "south": south, "east": east, "north": north}


func _add_aerial_pair(edges: Array[Dictionary], nodes: Array[Dictionary], first_id: int, second_id: int) -> void:
	var first := Vector2(float(nodes[first_id].longitude), float(nodes[first_id].latitude))
	var second := Vector2(float(nodes[second_id].longitude), float(nodes[second_id].latitude))
	var distance := snappedf(_distance_metres(first, second), 0.01)
	edges.append({"id": edges.size(), "from": first_id, "to": second_id, "distance_metres": distance, "inferred": true})
	edges.append({"id": edges.size(), "from": second_id, "to": first_id, "distance_metres": distance, "inferred": true})


func _filled_array(size_value: int, value: int) -> Array[int]:
	var result: Array[int] = []
	result.resize(size_value)
	result.fill(value)
	return result


func _build_graph(features: Array, mode: String, blocked_segments: Dictionary = {}) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	var node_by_coordinate: Dictionary = {}
	var undirected_neighbours: Dictionary = {}
	var edge_keys: Dictionary = {}
	var inferred_edge_count := 0
	var excluded_building_conflict_segments := 0
	var water_areas := _water_areas(features)
	for feature in features:
		if str(feature.get("kind", "")) != "road":
			continue
		var tags: Dictionary = feature.get("tags", {})
		var highway := str(tags.get("highway", ""))
		if not _route_allowed(tags, highway, mode):
			continue
		var points: Array = feature.get("points", [])
		var source_node_ids: Array = feature.get("node_ids", [])
		var source_node_tags: Dictionary = feature.get("node_tags", {})
		if points.size() < 2:
			continue
		var one_way := _one_way_direction(tags) if mode == "vehicle" else 0
		var bridge := _tag_enabled(tags.get("bridge", ""))
		var tunnel := _tag_enabled(tags.get("tunnel", ""))
		var inferred_walking := mode == "pedestrian" and highway not in PEDESTRIAN_SPECIFIC_HIGHWAYS and not tags.has("sidewalk")
		for index in range(points.size() - 1):
			if blocked_segments.has("%s:%d" % [str(feature.get("id", "unknown")), index]):
				excluded_building_conflict_segments += 1
				continue
			var first: Vector2 = points[index]
			var second: Vector2 = points[index + 1]
			var distance_metres := _distance_metres(first, second)
			if distance_metres < 0.05:
				continue
			if not bridge and not tunnel and _segment_crosses_water(first, second, water_areas):
				continue
			var first_key := "osm:%s" % str(source_node_ids[index]) if index < source_node_ids.size() else _coordinate_key(first)
			var second_key := "osm:%s" % str(source_node_ids[index + 1]) if index + 1 < source_node_ids.size() else _coordinate_key(second)
			var first_tags: Dictionary = source_node_tags.get(str(source_node_ids[index]), {}) if index < source_node_ids.size() else {}
			var second_tags: Dictionary = source_node_tags.get(str(source_node_ids[index + 1]), {}) if index + 1 < source_node_ids.size() else {}
			var first_id := _node_id(first, first_key, nodes, node_by_coordinate, first_tags)
			var second_id := _node_id(second, second_key, nodes, node_by_coordinate, second_tags)
			_add_neighbour(undirected_neighbours, first_id, second_id)
			_add_neighbour(undirected_neighbours, second_id, first_id)
			var forward_key := "%s>%s" % [first_key, second_key]
			var reverse_key := "%s>%s" % [second_key, first_key]
			if one_way >= 0 and not edge_keys.has(forward_key):
				edge_keys[forward_key] = true
				edges.append(_edge(edges.size(), first_id, second_id, distance_metres, feature, highway, inferred_walking))
			if one_way <= 0 and not edge_keys.has(reverse_key):
				edge_keys[reverse_key] = true
				edges.append(_edge(edges.size(), second_id, first_id, distance_metres, feature, highway, inferred_walking))
			if inferred_walking:
				inferred_edge_count += 2

	var component_data := _components(nodes.size(), undirected_neighbours)
	var control_counts := {"traffic_signals": 0, "stop": 0, "give_way": 0, "crossing": 0}
	for node in nodes:
		var control := str(node.get("control", ""))
		if control_counts.has(control):
			control_counts[control] += 1
	return {
		"mode": mode,
		"nodes": nodes,
		"edges": edges,
		"component_by_node": component_data.component_by_node,
		"component_sizes": component_data.component_sizes,
		"component_count": component_data.component_sizes.size(),
		"largest_component_size": component_data.largest_component_size,
		"inferred_edge_count": inferred_edge_count,
		"excluded_building_conflict_segments": excluded_building_conflict_segments,
		"traffic_control_counts": control_counts
	}


func _route_allowed(tags: Dictionary, highway: String, mode: String) -> bool:
	if highway.is_empty():
		return false
	if _tag_enabled(tags.get("indoor", "")) or highway == "corridor":
		return false
	var general_access := str(tags.get("access", "")).to_lower()
	if general_access in ["no", "private"]:
		return false
	var layer_text := str(tags.get("layer", "0"))
	var layer := int(layer_text) if layer_text.is_valid_int() else 0
	var explicit_crossing := _tag_enabled(tags.get("bridge", "")) or _tag_enabled(tags.get("tunnel", ""))
	var location := str(tags.get("location", "")).to_lower()
	if (layer != 0 or location in ["underground", "underwater", "overground"]) and not explicit_crossing:
		return false
	if mode == "vehicle":
		if highway in NON_DRIVABLE_HIGHWAYS:
			return false
		# General town traffic must not wander into private-looking access lanes or
		# ambiguous stacked geometry. These OSM ways commonly describe ramps inside
		# car parks and driveways above/below buildings, which looked like flying
		# cars when treated as ordinary public streets.
		var service := str(tags.get("service", "")).to_lower()
		if highway == "service" and service in ["driveway", "parking_aisle"]:
			return false
		return str(tags.get("motor_vehicle", tags.get("vehicle", ""))).to_lower() not in ["no", "private"]
	if highway in NON_WALKABLE_HIGHWAYS:
		return false
	return str(tags.get("foot", "")).to_lower() not in ["no", "private"]


func _water_areas(features: Array) -> Array[Dictionary]:
	var areas: Array[Dictionary] = []
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) != "water":
			continue
		var outer := PackedVector2Array()
		for point_value in feature.get("points", []):
			outer.append(point_value if point_value is Vector2 else Vector2(float(point_value[0]), float(point_value[1])))
		if outer.size() > 2 and outer[0].is_equal_approx(outer[outer.size() - 1]):
			outer.remove_at(outer.size() - 1)
		if outer.size() < 3:
			continue
		var holes: Array[PackedVector2Array] = []
		for hole_value in feature.get("holes", []):
			var hole := PackedVector2Array()
			for point_value in hole_value:
				hole.append(point_value if point_value is Vector2 else Vector2(float(point_value[0]), float(point_value[1])))
			if hole.size() > 2 and hole[0].is_equal_approx(hole[hole.size() - 1]):
				hole.remove_at(hole.size() - 1)
			if hole.size() >= 3:
				holes.append(hole)
		var bounds := Rect2(outer[0], Vector2.ZERO)
		for point in outer:
			bounds = bounds.expand(point)
		areas.append({"outer": outer, "holes": holes, "bounds": bounds})
	return areas


func _segment_crosses_water(first: Vector2, second: Vector2, water_areas: Array[Dictionary]) -> bool:
	var segment_bounds := Rect2(first, second - first).abs()
	for area_value in water_areas:
		var area: Dictionary = area_value
		var area_bounds: Rect2 = area.bounds
		if not area_bounds.intersects(segment_bounds, true):
			continue
		for sample_index in range(1, 6):
			var sample := first.lerp(second, float(sample_index) / 6.0)
			if not Geometry2D.is_point_in_polygon(sample, area.outer):
				continue
			var in_hole := false
			for hole_value in area.holes:
				if Geometry2D.is_point_in_polygon(sample, hole_value):
					in_hole = true
					break
			if not in_hole:
				return true
	return false


func _tag_enabled(value: Variant) -> bool:
	var text := str(value).to_lower()
	return not text.is_empty() and text not in ["no", "false", "0"]


func _one_way_direction(tags: Dictionary) -> int:
	var value := str(tags.get("oneway", "")).to_lower()
	if value == "-1":
		return -1
	if value in ["yes", "true", "1"] or str(tags.get("junction", "")).to_lower() == "roundabout":
		return 1
	return 0


func _coordinate_key(point: Vector2) -> String:
	return "coordinate:%.7f,%.7f" % [point.x, point.y]


func _node_id(point: Vector2, key: String, nodes: Array[Dictionary], node_by_coordinate: Dictionary, tags: Dictionary = {}) -> int:
	if node_by_coordinate.has(key):
		var existing_id := int(node_by_coordinate[key])
		var incoming_control := _control_for_node(tags)
		if str(nodes[existing_id].get("control", "")).is_empty() and not incoming_control.is_empty():
			nodes[existing_id].control = incoming_control
		return existing_id
	var id := nodes.size()
	node_by_coordinate[key] = id
	nodes.append({"id": id, "longitude": point.x, "latitude": point.y, "control": _control_for_node(tags)})
	return id


func _control_for_node(tags: Dictionary) -> String:
	var highway := str(tags.get("highway", "")).to_lower()
	var crossing := str(tags.get("crossing", "")).to_lower()
	if highway == "traffic_signals" or crossing == "traffic_signals" or str(tags.get("crossing:signals", "")).to_lower() == "yes":
		return "traffic_signals"
	if highway == "stop":
		return "stop"
	if highway == "give_way":
		return "give_way"
	if highway == "crossing" or not crossing.is_empty():
		return "crossing"
	return ""


func _edge(id: int, from_id: int, to_id: int, distance_metres: float, feature: Dictionary, highway: String, inferred: bool) -> Dictionary:
	var tags: Dictionary = feature.get("tags", {})
	return {
		"id": id,
		"from": from_id,
		"to": to_id,
		"distance_metres": snappedf(distance_metres, 0.01),
		"source_way_id": str(feature.get("id", "")),
		"highway": highway,
		"service": str(tags.get("service", "")),
		"inferred": inferred,
		"bridge": _tag_enabled(tags.get("bridge", "")),
		"tunnel": _tag_enabled(tags.get("tunnel", "")),
		"layer": int(str(tags.get("layer", "0"))) if str(tags.get("layer", "0")).is_valid_int() else 0
	}


func _add_neighbour(neighbours: Dictionary, from_id: int, to_id: int) -> void:
	if not neighbours.has(from_id):
		neighbours[from_id] = []
	if to_id not in neighbours[from_id]:
		neighbours[from_id].append(to_id)


func _components(node_count: int, neighbours: Dictionary) -> Dictionary:
	var component_by_node: Array[int] = []
	component_by_node.resize(node_count)
	component_by_node.fill(-1)
	var component_sizes: Array[int] = []
	var largest := 0
	for start_id in node_count:
		if component_by_node[start_id] != -1:
			continue
		var component_id := component_sizes.size()
		var queue: Array[int] = [start_id]
		component_by_node[start_id] = component_id
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			for neighbour_value in neighbours.get(current, []):
				var neighbour := int(neighbour_value)
				if component_by_node[neighbour] == -1:
					component_by_node[neighbour] = component_id
					queue.append(neighbour)
		var size_value := queue.size()
		component_sizes.append(size_value)
		largest = maxi(largest, size_value)
	return {"component_by_node": component_by_node, "component_sizes": component_sizes, "largest_component_size": largest}


func _access_report(graph: Dictionary, start_location: Dictionary, cbd_bounds: Dictionary) -> Dictionary:
	if graph.nodes.is_empty() or start_location.is_empty() or cbd_bounds.is_empty():
		return {"start_node_id": -1, "start_component_id": -1, "cbd_node_count": 0, "cbd_reachable": false}
	var start_point := Vector2(float(start_location.get("longitude", 0.0)), float(start_location.get("latitude", 0.0)))
	var start_id := _nearest_node(graph.nodes, start_point)
	var start_component := int(graph.component_by_node[start_id])
	var reachable_nodes := _directed_reachable_nodes(graph, start_id)
	var cbd_count := 0
	var reachable := false
	for node in graph.nodes:
		if node.longitude >= cbd_bounds.west and node.longitude <= cbd_bounds.east and node.latitude >= cbd_bounds.south and node.latitude <= cbd_bounds.north:
			cbd_count += 1
			if reachable_nodes.has(int(node.id)):
				reachable = true
	return {"start_node_id": start_id, "start_component_id": start_component, "cbd_node_count": cbd_count, "cbd_reachable": reachable}


func _directed_reachable_nodes(graph: Dictionary, start_id: int) -> Dictionary:
	var outgoing: Dictionary = {}
	for edge in graph.edges:
		if not outgoing.has(int(edge.from)):
			outgoing[int(edge.from)] = []
		outgoing[int(edge.from)].append(int(edge.to))
	var reached := {start_id: true}
	var queue: Array[int] = [start_id]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for neighbour in outgoing.get(current, []):
			var neighbour_id := int(neighbour)
			if not reached.has(neighbour_id):
				reached[neighbour_id] = true
				queue.append(neighbour_id)
	return reached


func find_route(graph: Dictionary, start_location: Dictionary, destination: Dictionary) -> Dictionary:
	if graph.get("nodes", []).is_empty():
		return {"ok": false, "message": "The navigation network is empty.", "node_ids": []}
	var start_point := Vector2(float(start_location.longitude), float(start_location.latitude))
	var destination_point := Vector2(float(destination.longitude), float(destination.latitude))
	var start_id := _nearest_node(graph.nodes, start_point)
	var destination_id := _nearest_node(graph.nodes, destination_point)
	var origin_node: Dictionary = graph.nodes[0]
	var origin := Vector2(float(origin_node.longitude), float(origin_node.latitude))
	var astar := AStar2D.new()
	for node in graph.nodes:
		var geographic := Vector2(float(node.longitude), float(node.latitude))
		var mean_latitude := deg_to_rad((geographic.y + origin.y) * 0.5)
		var local_position := Vector2(
			(geographic.x - origin.x) * METRES_PER_LONGITUDE_DEGREE * cos(mean_latitude),
			(geographic.y - origin.y) * METRES_PER_LATITUDE_DEGREE
		)
		astar.add_point(int(node.id), local_position)
	for edge in graph.edges:
		var from_id := int(edge.from)
		var to_id := int(edge.to)
		if not astar.are_points_connected(from_id, to_id, false):
			astar.connect_points(from_id, to_id, false)
	var path := astar.get_id_path(start_id, destination_id)
	return {
		"ok": not path.is_empty(),
		"message": "Route found." if not path.is_empty() else "No connected route was found.",
		"start_node_id": start_id,
		"destination_node_id": destination_id,
		"node_ids": Array(path)
	}


func _nearest_node(nodes: Array, point: Vector2) -> int:
	var nearest_id := -1
	var nearest_distance := INF
	for node in nodes:
		var candidate := Vector2(float(node.longitude), float(node.latitude))
		var distance := _distance_metres(point, candidate)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = int(node.id)
	return nearest_id


func _distance_metres(first: Vector2, second: Vector2) -> float:
	var mean_latitude := deg_to_rad((first.y + second.y) * 0.5)
	var x := (second.x - first.x) * METRES_PER_LONGITUDE_DEGREE * cos(mean_latitude)
	var y := (second.y - first.y) * METRES_PER_LATITUDE_DEGREE
	return Vector2(x, y).length()
