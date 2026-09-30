extends SceneTree

const ValidatorScript = preload("res://scripts/validation/map_geometry_validator.gd")
const NavigationBuilderScript = preload("res://scripts/navigation/osm_navigation_builder.gd")
const CollisionBuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")
const VehicleScript = preload("res://scripts/runtime/runtime_player_vehicle.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ground_building := _building("ground-building", 146.0008, -36.0002, 146.0012, -35.9998)
	var raised_building := _building("raised-building", 146.0028, -36.0002, 146.0032, -35.9998, {"building": "yes", "building:min_level": "1"})
	var underground_building := _building("underground-building", 146.0048, -36.0002, 146.0052, -35.9998, {"building": "yes", "location": "underground"})
	var roof := _building("roof", 146.0038, -36.0002, 146.0042, -35.9998, {"building": "roof"})
	roof.kind = "overhead_structure"
	var ground_conflict := _road("ground-conflict", [Vector2(146.0000, -36.0000), Vector2(146.0020, -36.0000)], {"highway": "residential"})
	var near_edge := _road("near-edge", [Vector2(146.0000, -36.00022), Vector2(146.0020, -36.00022)], {"highway": "residential"})
	var clear_ground := _road("clear-ground", [Vector2(146.0000, -36.0010), Vector2(146.0020, -36.0010)], {"highway": "residential"})
	var bridge := _road("valid-bridge", [Vector2(146.0000, -36.00005), Vector2(146.0020, -36.00005)], {"highway": "primary", "bridge": "yes", "layer": "1"})
	var tunnel := _road("valid-tunnel", [Vector2(146.0000, -35.99995), Vector2(146.0020, -35.99995)], {"highway": "primary", "tunnel": "building_passage", "layer": "-1"})
	var ambiguous := _road("ambiguous-layer", [Vector2(146.0000, -36.0012), Vector2(146.0020, -36.0012)], {"highway": "residential", "layer": "1"})
	var roof_road := _road("roof-road", [Vector2(146.0035, -36.0000), Vector2(146.0045, -36.0000)], {"highway": "residential"})
	var features := [ground_building, raised_building, underground_building, roof, ground_conflict, near_edge, clear_ground, bridge, tunnel, ambiguous, roof_road]

	var validation: Dictionary = ValidatorScript.new().analyse(features)
	assert(validation.statistics.blocked_ground_road_segments == 1, "Only the untagged ground road through the solid building should be blocked.")
	assert(validation.statistics.road_clearance_conflicts == 1, "The close but centre-line-clear road should be reported without being removed.")
	assert(validation.statistics.unclassified_vertical_roads == 1, "The ambiguous layered road was not reported.")
	assert(validation.statistics.explicit_vertical_passages == 2, "The tagged bridge and tunnel should be accepted as separate levels.")
	assert(validation.blocked_segments[0].road_id == "ground-conflict")

	var cbd := {"west": 146.0, "south": -36.0015, "east": 146.0045, "north": -35.9995}
	var start := {"longitude": 146.0, "latitude": -36.001, "vehicle": {"longitude": 146.0, "latitude": -36.001}}
	var navigation: Dictionary = NavigationBuilderScript.new().build(features, cbd, start)
	var vehicle_sources := _edge_sources(navigation.data.vehicle.edges)
	var pedestrian_sources := _edge_sources(navigation.data.pedestrian.edges)
	assert(not vehicle_sources.has("ground-conflict") and not pedestrian_sources.has("ground-conflict"), "A ground route still passes through a solid footprint.")
	assert(not vehicle_sources.has("ambiguous-layer") and not pedestrian_sources.has("ambiguous-layer"), "An unclassified vertical route remained usable.")
	for expected in ["near-edge", "clear-ground", "valid-bridge", "valid-tunnel", "roof-road"]:
		assert(vehicle_sources.has(expected), "A safe or explicitly separated vehicle route was removed: %s" % expected)
		assert(pedestrian_sources.has(expected), "A safe or explicitly separated walking route was removed: %s" % expected)

	var collision_build: Dictionary = CollisionBuilderScript.new().build(features, cbd)
	assert(collision_build.ok)
	assert(collision_build.data.statistics.collision_buildings == 1, "A non-ground structure received surface collision.")
	assert(collision_build.data.statistics.non_ground_structures == 2, "Raised and underground buildings were not classified separately.")
	assert(collision_build.data.buildings[0].vertical_context == "ground")
	assert(ValidatorScript.building_vertical_context(raised_building) == "overhead")
	assert(ValidatorScript.building_vertical_context(underground_building) == "underground")

	var player = PlayerScript.new()
	get_root().add_child(player)
	player.crossing_travel.active = {"kind": "tunnel"}
	player.refresh_collision_mask_for_crossing()
	assert(player.collision_mask == 4, "A walker in a tunnel still collides with surface buildings.")
	player.crossing_travel.active = {}
	player.refresh_collision_mask_for_crossing()
	assert(player.collision_mask == (1 | 4), "Surface building collision was not restored for the walker.")

	var vehicle = VehicleScript.new()
	get_root().add_child(vehicle)
	vehicle.crossing_travel.active = {"kind": "bridge"}
	vehicle.refresh_collision_mask_for_crossing()
	assert(vehicle.collision_mask == 2, "A vehicle on a bridge still collides with ground buildings below.")
	vehicle.crossing_travel.active = {}
	vehicle.refresh_collision_mask_for_crossing()
	assert(vehicle.collision_mask == (1 | 2), "Surface building collision was not restored for the vehicle.")

	print("MAP GEOMETRY PASSED: ground conflicts removed, near edges reported, vertical ambiguity excluded, bridge/tunnel routes retained and crossing collision layers separated.")
	quit(0)


func _building(id: String, west: float, south: float, east: float, north: float, tags: Dictionary = {"building": "yes"}) -> Dictionary:
	return {
		"id": id,
		"kind": "building",
		"tags": tags,
		"points": [Vector2(west, south), Vector2(east, south), Vector2(east, north), Vector2(west, north), Vector2(west, south)],
		"holes": []
	}


func _road(id: String, points: Array, tags: Dictionary) -> Dictionary:
	return {"id": id, "kind": "road", "tags": tags, "points": points, "node_ids": ["%s-a" % id, "%s-b" % id], "node_tags": {}}


func _edge_sources(edges: Array) -> Dictionary:
	var result: Dictionary = {}
	for edge_value in edges:
		result[str(edge_value.source_way_id)] = true
	return result
