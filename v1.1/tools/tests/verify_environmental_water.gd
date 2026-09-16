extends SceneTree

const ImporterScript = preload("res://scripts/towns/osm_importer.gd")
const CollisionBuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")
const NavigationBuilderScript = preload("res://scripts/navigation/osm_navigation_builder.gd")
const RendererScript = preload("res://scripts/runtime/runtime_world_renderer.gd")
const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const SpawnSafetyScript = preload("res://scripts/towns/spawn_safety.gd")
const ContentPackScript = preload("res://scripts/content/content_pack.gd")


func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://tools/tests/fixtures/water_crossings.osm")
	var imported: Dictionary = ImporterScript.new().parse_files(PackedStringArray([source]))
	assert(imported.ok)
	assert(imported.statistics.water_areas == 1)
	assert(imported.statistics.bridge_roads == 1)
	assert(imported.statistics.tunnel_roads == 1)
	assert(imported.statistics.overhead_structures == 1)
	assert(imported.statistics.incomplete_water_relations == 1)
	assert(imported.statistics.unresolved_water_relations == 1)
	assert(str(imported.warnings[0]).contains("Incomplete Fixture Harbour"))

	var collision_result: Dictionary = CollisionBuilderScript.new().build(imported.features, imported.bounds)
	assert(collision_result.ok)
	var collision_data: Dictionary = collision_result.data
	assert(collision_data.buildings.is_empty(), "building=roof must not become a ground-solid building.")
	assert(collision_data.water_areas.size() == 1)
	assert(collision_data.water_crossings.size() == 2)

	var renderer = RendererScript.new()
	root.add_child(renderer)
	renderer.setup(imported.features, collision_data, imported.bounds)
	var projection: Dictionary = collision_data.projection
	var scale := float(collision_data.runtime_scale.pixels_per_metre)
	var water := _world(Vector2(146.0050, -36.0040), projection, scale)
	var bridge := _world(Vector2(146.0050, -36.0030), projection, scale)
	var tunnel := _world(Vector2(146.0050, -36.0050), projection, scale)
	var unsafe_road := _world(Vector2(146.0050, -36.0070), projection, scale)
	var dry_land := _world(Vector2(146.0020, -36.0040), projection, scale)
	assert(renderer.is_open_water(water))
	assert(not renderer.is_ground_traversable(water, 4.0))
	assert(renderer.is_ground_traversable(bridge, 4.0), "A tagged bridge did not remain traversable over water.")
	assert(renderer.is_ground_traversable(tunnel, 4.0), "A tagged tunnel did not remain traversable below water.")
	assert(renderer.crossing_kind_at(bridge) == "bridge")
	assert(renderer.crossing_kind_at(tunnel) == "tunnel")
	assert(not renderer.is_ground_traversable(unsafe_road, 4.0), "An unprotected road was allowed across open water.")
	assert(renderer.is_ground_traversable(dry_land, 4.0))
	var beyond_export := _world(Vector2(145.9999, -36.0040), projection, scale)
	assert(not renderer.is_ground_traversable(beyond_export, 0.0), "The player could escape around water beyond the OSM export boundary.")

	var cbd := {"west": 146.0005, "south": -36.0098, "east": 146.0095, "north": -36.0005}
	var start := {"longitude": 146.0020, "latitude": -36.0030, "vehicle": {"longitude": 146.0022, "latitude": -36.0030}}
	var unsafe_export_validation: Dictionary = ContentPackScript.new().validate_town("Incomplete Water Fixture", imported, cbd, start)
	assert(not unsafe_export_validation.passed)
	assert(" ".join(unsafe_export_validation.errors).contains("incomplete water boundaries"))
	var navigation: Dictionary = NavigationBuilderScript.new().build(imported.features, cbd, start).data
	var source_ids: Dictionary = {}
	var bridge_metadata_found := false
	var tunnel_metadata_found := false
	for edge_value in navigation.vehicle.edges:
		var edge: Dictionary = edge_value
		source_ids[str(edge.source_way_id)] = true
		bridge_metadata_found = bridge_metadata_found or (str(edge.source_way_id) == "200" and bool(edge.bridge) and int(edge.layer) == 1)
		tunnel_metadata_found = tunnel_metadata_found or (str(edge.source_way_id) == "300" and bool(edge.tunnel) and int(edge.layer) == -1)
	assert(source_ids.has("200") and source_ids.has("300"))
	assert(not source_ids.has("400"), "Navigation retained an untagged road through water.")
	assert(bridge_metadata_found and tunnel_metadata_found)

	var rejected := SpawnSafetyScript.create_starting_location({"longitude": 146.0050, "latitude": -36.0040}, imported.features)
	assert(not rejected.ok and str(rejected.message).contains("mapped water"))
	print("ENVIRONMENTAL WATER CHECK PASSED: automatic water blocking, bridge/tunnel corridors, underground metadata, roof classification and incomplete-relation warning.")
	quit(0)


func _world(location: Vector2, projection: Dictionary, scale: float) -> Vector2:
	return ProjectionScript.geographic_to_world(location, projection, scale)
