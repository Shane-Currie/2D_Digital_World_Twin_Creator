extends SceneTree

const ImporterScript = preload("res://scripts/towns/osm_importer.gd")
const CollisionBuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")
const NavigationBuilderScript = preload("res://scripts/navigation/osm_navigation_builder.gd")
const RendererScript = preload("res://scripts/runtime/runtime_world_renderer.gd")


func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://../OSM/Sydney/The Rocks.osm")
	assert(FileAccess.file_exists(source), "The user-supplied The Rocks OSM source is missing.")
	var started := Time.get_ticks_msec()
	var imported: Dictionary = ImporterScript.new().parse_files(PackedStringArray([source]))
	assert(imported.ok)
	assert(int(imported.statistics.water_areas) >= 8)
	assert(int(imported.statistics.bridge_roads) > 0)
	assert(int(imported.statistics.tunnel_roads) > 0)
	assert(int(imported.statistics.overhead_structures) >= 60)
	assert(int(imported.statistics.incomplete_water_relations) == 2)
	assert(int(imported.statistics.inferred_clipped_water_areas) == 4)
	print("THE ROCKS IMPORT STATS: ", imported.statistics)
	for warning in imported.warnings:
		print("THE ROCKS IMPORT WARNING: ", warning)
	var warning_text := " ".join(imported.warnings)
	assert(warning_text.contains("Sydney Harbour") and warning_text.contains("Port Jackson"))

	var collision_result: Dictionary = CollisionBuilderScript.new().build(imported.features, imported.bounds)
	assert(collision_result.ok)
	assert(collision_result.data.water_areas.size() >= 8)
	assert(collision_result.data.water_crossings.size() > 0)
	assert(collision_result.data.buildings.size() == int(imported.statistics.buildings))
	var renderer = RendererScript.new()
	root.add_child(renderer)
	renderer.setup(imported.features, collision_result.data, imported.bounds)
	var road_overlap: Dictionary = renderer.bridge_road_overlap()
	assert(not road_overlap.is_empty(), "The real OSM fixture should contain a bridge crossing a lower road without creating a junction.")
	var land_direction: Vector2 = road_overlap.bridge.points[0].direction_to(road_overlap.bridge.points[1])
	var land_portal: Dictionary = renderer.bridge_portal_at(road_overlap.bridge.points[0], land_direction)
	assert(not land_portal.is_empty(), "A land bridge did not expose its automatic entry zone.")
	renderer.set_active_land_bridge(str(land_portal.id))
	assert(renderer.active_land_bridge_id == str(land_portal.id))
	var water_bridge_found := false
	for corridor_value in renderer.crossing_corridors:
		water_bridge_found = water_bridge_found or (str(corridor_value.kind) == "bridge" and bool(corridor_value.over_water))
	assert(water_bridge_found, "The real OSM fixture should keep at least one water bridge permanently visible.")

	var cbd := {
		"west": float(imported.bounds.west), "south": float(imported.bounds.south),
		"east": float(imported.bounds.east), "north": float(imported.bounds.north)
	}
	var centre := {
		"longitude": (float(imported.bounds.west) + float(imported.bounds.east)) * 0.5,
		"latitude": (float(imported.bounds.south) + float(imported.bounds.north)) * 0.5
	}
	var start := centre.duplicate(true)
	start["vehicle"] = centre.duplicate(true)
	var navigation: Dictionary = NavigationBuilderScript.new().build(imported.features, cbd, start).data
	var bridge_edges := 0
	var tunnel_edges := 0
	for edge_value in navigation.vehicle.edges:
		var edge: Dictionary = edge_value
		bridge_edges += 1 if bool(edge.get("bridge", false)) else 0
		tunnel_edges += 1 if bool(edge.get("tunnel", false)) else 0
	assert(bridge_edges > 0 and tunnel_edges > 0)
	print("THE ROCKS ENVIRONMENT CHECK PASSED in %d ms: %d safe closed water areas; %d incomplete harbour relations clearly reported; %d bridge edges; %d tunnel edges; real road-over-road layer and water-bridge presentation verified." % [Time.get_ticks_msec() - started, imported.statistics.water_areas, imported.statistics.incomplete_water_relations, bridge_edges, tunnel_edges])
	quit(0)
