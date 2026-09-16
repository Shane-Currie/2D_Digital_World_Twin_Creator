extends SceneTree

const NavigationBuilderScript = preload("res://scripts/navigation/osm_navigation_builder.gd")


func _initialize() -> void:
	var builder = NavigationBuilderScript.new()
	var horizontal := _road("horizontal", ["h1", "h2", "h3"], [
		Vector2(146.000, -36.000), Vector2(146.001, -36.000), Vector2(146.002, -36.000)
	], {"highway": "residential", "oneway": "yes"})
	horizontal.node_tags = {"h2": {"highway": "traffic_signals"}}
	var vertical_separate := _road("vertical", ["v1", "v2", "v3"], [
		Vector2(146.001, -36.001), Vector2(146.001, -36.000), Vector2(146.001, -35.999)
	], {"highway": "residential"})
	var cbd := {"west": 146.0015, "south": -36.0005, "east": 146.0022, "north": -35.9995}
	var start := {
		"longitude": 146.000, "latitude": -36.000,
		"vehicle": {"longitude": 146.000, "latitude": -36.000}
	}

	var separated: Dictionary = builder.build([horizontal, vertical_separate], cbd, start, {"road_rules": {"driving_side": "right"}})
	assert(separated.ok)
	assert(separated.data.road_rules.driving_side == "right")
	assert(separated.data.vehicle.component_count == 2, "Crossing coordinates with different OSM nodes were falsely joined.")
	assert(separated.data.vehicle.edges.size() == 6, "One-way and two-way edge directions were not preserved.")
	assert(separated.data.vehicle.traffic_control_counts.traffic_signals == 1, "A tagged OSM traffic signal was not preserved in the vehicle graph.")
	assert(separated.data.aerial.nodes.size() == 25, "The map-wide NPD aerial network was not generated.")
	assert(separated.data.aerial.allows_building_overflight, "NPD routes should permit building overflight.")
	var forward: Dictionary = builder.find_route(separated.data.vehicle, {"longitude": 146.000, "latitude": -36.000}, {"longitude": 146.002, "latitude": -36.000})
	var reverse: Dictionary = builder.find_route(separated.data.vehicle, {"longitude": 146.002, "latitude": -36.000}, {"longitude": 146.000, "latitude": -36.000})
	assert(forward.ok, "A legal one-way route was not found.")
	assert(not reverse.ok, "Pathfinding travelled backwards along a one-way road.")

	var vertical_joined: Dictionary = vertical_separate.duplicate(true)
	vertical_joined.node_ids = ["v1", "h2", "v3"]
	var joined: Dictionary = builder.build([horizontal, vertical_joined], cbd, start)
	assert(joined.data.vehicle.component_count == 1, "Roads sharing an OSM intersection node were not joined.")
	assert(joined.data.pedestrian.nodes.size() > 0, "The pedestrian fallback beside ordinary roads was not generated.")

	var public_road := _road("public", ["p1", "p2"], [Vector2(146.010, -36.010), Vector2(146.011, -36.010)], {"highway": "residential"})
	var driveway := _road("driveway", ["d1", "d2"], [Vector2(146.010, -36.011), Vector2(146.011, -36.011)], {"highway": "service", "service": "driveway"})
	var ambiguous_layer := _road("stacked", ["s1", "s2"], [Vector2(146.010, -36.012), Vector2(146.011, -36.012)], {"highway": "service", "layer": "1"})
	var valid_bridge := _road("bridge", ["b1", "b2"], [Vector2(146.010, -36.013), Vector2(146.011, -36.013)], {"highway": "primary", "bridge": "yes", "layer": "1"})
	var filtering: Dictionary = builder.build([public_road, driveway, ambiguous_layer, valid_bridge], cbd, start)
	var source_ids: Dictionary = {}
	for edge_value in filtering.data.vehicle.edges:
		source_ids[str(edge_value.source_way_id)] = true
	assert(source_ids.has("public") and source_ids.has("bridge"), "Valid public surface and bridge routes were removed.")
	assert(not source_ids.has("driveway") and not source_ids.has("stacked"), "General traffic retained an ambiguous driveway or unclassified vertical route.")
	print("NAVIGATION BUILDER PASSED: OSM controls, node intersections, grade separation, one-way routing, traffic-safe vertical filtering, walking graph and driving side.")
	quit(0)


func _road(id: String, node_ids: Array, points: Array, tags: Dictionary) -> Dictionary:
	return {"id": id, "kind": "road", "node_ids": node_ids, "points": points, "tags": tags}
