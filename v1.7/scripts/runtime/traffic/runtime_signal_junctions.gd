extends RefCounted

## A signal may be mapped on several stop lines around one junction. Build a
## bounded connected region once, then make one entry decision for that region.
static func prepare(graph: Dictionary, scale: float) -> void:
	var neighbours: Dictionary = {}
	for key in graph.get("edge_by_pair", {}):
		var edge: Dictionary = graph.edge_by_pair[key]
		if bool(edge.get("bridge", false)) or bool(edge.get("tunnel", false)) or int(edge.get("layer", 0)) != 0:
			continue
		var ids := str(key).split(">")
		var a := int(ids[0])
		var b := int(ids[1])
		neighbours.get_or_add(a, {})[b] = true
		neighbours.get_or_add(b, {})[a] = true
	var zones: Dictionary = {}
	var regions: Array[Dictionary] = []
	var radius := 28.0 * scale
	var controls: Array = graph.get("control_by_node", {}).keys()
	controls.sort()
	for node in controls:
		if str(graph.control_by_node[node]) != "traffic_signals" or not neighbours.has(node):
			continue
		var nearby := _nearby(graph.nodes, neighbours, int(node), radius)
		var anchor := int(node)
		var nearest := INF
		for candidate in nearby:
			if int(graph.degree.get(candidate, 0)) >= 3 and float(nearby[candidate]) < nearest:
				anchor = int(candidate)
				nearest = float(nearby[candidate])
		# Standalone pedestrian lights also form a bounded region. Long street
		# segments cannot chain separate junctions into one town-wide permission.
		var members := _nearby(graph.nodes, neighbours, anchor, radius)
		regions.append({"id": int(node), "members": members})
	# The old first-node-wins assignment split overlapping regions around
	# divided roads. Union their connected geometry before assigning ownership.
	var changed := true
	while changed:
		changed = false
		for a in regions.size():
			for b in range(regions.size()-1, a, -1):
				var overlap := false
				for member in regions[b].members:
					if regions[a].members.has(member):
						overlap = true
						break
					# A divided carriageway can have distinct branching cores
					# linked across a wide central box, with no shared vertex.
					if int(graph.degree.get(member, 0)) < 3:
						continue
					for neighbour in neighbours.get(member, {}):
						if regions[a].members.has(neighbour) and int(graph.degree.get(neighbour, 0)) >= 3 and Vector2(graph.nodes[member]).distance_to(graph.nodes[neighbour]) <= 35.0 * scale:
							overlap = true
							break
				if not overlap:
					continue
				var combined: Dictionary = regions[a].members.duplicate()
				combined.merge(regions[b].members)
				var bounds := Rect2(Vector2(graph.nodes[combined.keys()[0]]), Vector2.ZERO)
				for member in combined:
					bounds = bounds.expand(graph.nodes[member])
				# Bound transitive merging so nearby controls cannot chain across town.
				if maxf(bounds.size.x, bounds.size.y) > 80.0 * scale:
					continue
				regions[a].members = combined
				regions.remove_at(b)
				changed = true
	for region in regions:
		for member in region.members:
			if not zones.has(member):
				zones[member] = int(region.id)
	graph.junction_zone_by_node = zones
	graph.junction_clearance = 25.0
	_prepare_approaches(graph, scale)


static func _prepare_approaches(graph: Dictionary, scale: float) -> void:
	var entries: Dictionary = {}
	var posts: Array[Dictionary] = []
	var zones: Dictionary = graph.junction_zone_by_node
	var keys: Array = graph.get("edge_by_pair", {}).keys()
	keys.sort()
	for key in keys:
		var edge: Dictionary = graph.edge_by_pair[key]
		if bool(edge.get("bridge", false)) or bool(edge.get("tunnel", false)) or int(edge.get("layer", 0)) != 0:
			continue
		var ids := str(key).split(">")
		var from := int(ids[0])
		var to := int(ids[1])
		var zone := int(zones.get(to, -1))
		if zone < 0 or int(zones.get(from, -1)) == zone:
			continue # Internal and outbound edges are not new traffic lights.
		var start: Vector2 = graph.nodes[from]
		var finish: Vector2 = graph.nodes[to]
		var direction := start.direction_to(finish)
		var setback := minf(42.0, start.distance_to(finish) * 0.45)
		var stop_position := finish - direction * setback
		var post: Dictionary = {}
		for existing in posts:
			if int(existing.zone) == zone and Vector2(existing.direction).dot(direction) > 0.94 and Vector2(existing.stop_position).distance_to(stop_position) < 20.0 * scale:
				post = existing
				break
		if post.is_empty():
			post = {"zone":zone, "direction":direction, "stop_position":stop_position, "side_distance":maxf(22.0, float(edge.get("half_width_pixels",18.0)) + 4.0), "edge_keys":[]}
			posts.append(post)
		post.edge_keys.append(str(key))
		# Drawing and entry permission share this exact approach direction.
		entries[str(key)] = {"post":post, "stop_position":stop_position, "direction":direction}
	graph.signal_approaches = entries
	graph.signal_posts = posts


static func _nearby(nodes: Dictionary, neighbours: Dictionary, seed: int, radius: float) -> Dictionary:
	var distance := {seed: 0.0}
	var pending: Array = [seed]
	while not pending.is_empty() and distance.size() < 256:
		var current := int(pending.pop_front())
		for next in neighbours.get(current, {}):
			var travelled := float(distance[current]) + Vector2(nodes[current]).distance_to(nodes[next])
			if travelled > radius or (distance.has(next) and float(distance[next]) <= travelled):
				continue
			distance[next] = travelled
			pending.append(next)
	return distance


static func plan(agent: Dictionary, graph: Dictionary, rng: RandomNumberGenerator) -> void:
	var zones: Dictionary = graph.get("junction_zone_by_node", {})
	var zone := int(zones.get(int(agent.target_node), -1))
	if zone < 0:
		agent.junction_route = []
		return
	var route: Array = []
	var seed := int(agent.target_node)
	var visited := {int(agent.node): true, seed: true}
	var pending: Array = [[seed]]
	# Search a bounded local graph so a random dead-end choice cannot strand
	# the car when another legal exit exists.
	while not pending.is_empty() and visited.size() < 256:
		var candidate: Array = pending.pop_front()
		var cursor := int(candidate[-1])
		var options: Array = []
		for value in graph.adjacency.get(cursor, []):
			if not visited.has(int(value)):
				options.append(int(value))
		if options.is_empty():
			continue
		var preferred := int(agent.get("planned_exit_node", -1)) if candidate.size() == 1 else int(options[rng.randi_range(0, options.size()-1)])
		if preferred in options:
			options.erase(preferred)
			options.push_front(preferred)
		for next in options:
			var branch: Array = candidate.duplicate()
			branch.append(next)
			visited[next] = true
			if int(zones.get(next, -1)) != zone:
				route = branch
				break
			pending.append(branch)
		if not route.is_empty():
			break
	agent.junction_route = route
	agent.junction_route_zone = zone


static func permitted(agent: Dictionary, agents: Array[Dictionary], next_position: Vector2, graph: Dictionary, flow: RefCounted, elapsed: float) -> bool:
	var zones: Dictionary = graph.junction_zone_by_node
	var target_zone := int(zones.get(int(agent.target_node), -1))
	refresh_permission(agent, graph)
	var held := int(agent.get("signal_zone", -1))
	if held >= 0:
		agent.blocked_reason = ""
		return true
	if target_zone < 0:
		return true
	var approach: Dictionary = graph.get("signal_approaches", {}).get("%d>%d" % [int(agent.node), int(agent.target_node)], {})
	var legacy_graph := not graph.has("signal_approaches")
	var direction: Vector2 = Vector2(agent.target) - Vector2(graph.nodes.get(int(agent.node), agent.position))
	if not approach.is_empty():
		direction = approach.post.direction
		if (next_position - Vector2(approach.stop_position)).dot(Vector2(approach.direction)) < 0.0:
			return true
	elif legacy_graph and next_position.distance_to(agent.target) > flow.JUNCTION_APPROACH_PIXELS:
		return true
	# Only incoming approaches have lights. Internal nodes never acquire a
	# second red-light requirement, including initial cars already in the area.
	if (legacy_graph or not approach.is_empty()) and flow.signal_state(direction, elapsed) != "green":
		agent.blocked_reason = "Traffic signal"
		return false
	var route: Array = agent.get("junction_route", [])
	if route.is_empty() or int(zones.get(int(route[-1]), -1)) == target_zone:
		agent.blocked_reason = "No clear intersection exit route"
		return false
	var path := PackedVector2Array([agent.position])
	for node in route:
		path.append(graph.nodes[int(node)])
	var exit_start := path[-2]
	var exit_direction := exit_start.direction_to(path[-1])
	path[-1] = exit_start + exit_direction * minf(exit_start.distance_to(path[-1]), flow.JUNCTION_EXIT_CLEARANCE_PIXELS)
	# Check occupied exits even when OSM splits them into short edges. Hold
	# conflicting paths across the whole zone, not just a centre vertex.
	for other in agents:
		if other == agent or str(other.get("kind", "")) != "traffic":
			continue
		if bool(other.get("route_bridge", false)) or bool(other.get("route_tunnel", false)) or int(other.get("route_layer", 0)) != 0:
			continue
		var exit_distance := Vector2(other.position).distance_to(Geometry2D.get_closest_point_to_segment(other.position, exit_start, path[-1]))
		var same_direction := Vector2.RIGHT.rotated(float(other.get("angle", 0.0))).dot(exit_direction) > 0.5
		if exit_distance < 25.0 and same_direction and Vector2(other.position - exit_start).dot(exit_direction) >= 0.0 and not bool(other.get("moving", true)):
			agent.blocked_reason = "Intersection exit occupied"
			return false
		if int(other.get("signal_zone", -1)) != target_zone:
			continue
		var other_path: PackedVector2Array = other.get("signal_path", PackedVector2Array())
		# Same entry and route share a moving queue with a full following gap.
		if agent.get("junction_route", []) == other.get("signal_route", []) and bool(other.get("moving", true)) and Vector2(agent.position).distance_to(other.position) >= flow.FOLLOWING_GAP_PIXELS:
			continue
		# Independent opposing straight lanes can clear together.
		if _straight(path) and _straight(other_path) and path[0].direction_to(path[-1]).dot(other_path[0].direction_to(other_path[-1])) < -0.9:
			continue
		for a in range(path.size()-1):
			for b in range(other_path.size()-1):
				if flow._segment_distance(path[a], path[a+1], other_path[b], other_path[b+1]) < 25.0:
					agent.blocked_reason = "Conflicting intersection movement"
					return false
	agent.signal_zone = target_zone
	agent.signal_path = path
	agent.signal_route = route.duplicate()
	agent.blocked_reason = ""
	return true


static func refresh_permission(agent: Dictionary, graph: Dictionary) -> void:
	var held := int(agent.get("signal_zone", -1))
	if held < 0:
		return
	var zones: Dictionary = graph.get("junction_zone_by_node", {})
	var from := int(agent.node)
	if int(zones.get(int(agent.target_node), -1)) == held:
		return
	if int(zones.get(from, -1)) == held and Vector2(agent.position).distance_to(graph.nodes[from]) < float(graph.junction_clearance):
		return
	agent.erase("signal_zone")
	agent.erase("signal_path")


static func _straight(path: PackedVector2Array) -> bool:
	if path.size() < 2:
		return false
	var direction := path[0].direction_to(path[-1])
	for index in range(path.size()-1):
		if path[index].direction_to(path[index+1]).dot(direction) < 0.95:
			return false
	return true
