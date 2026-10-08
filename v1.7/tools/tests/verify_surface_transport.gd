extends SceneTree

const Importer = preload("res://scripts/towns/osm_importer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const Dimensions = preload("res://scripts/roads/road_dimensions.gd")
const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(is_equal_approx(Dimensions.full_width_metres({"highway": "residential", "width": "6.4 m"}), 6.4))
	assert(is_equal_approx(Dimensions.full_width_metres({"highway": "primary", "lanes": "4"}), 13.0))
	assert(is_equal_approx(Dimensions.full_width_metres({"highway": "service", "service": "parking_aisle"}), 6.0))
	assert(Dimensions.sidewalk_sides({"highway": "residential"}) == ["left", "right"])
	assert(Dimensions.sidewalk_sides({"highway": "residential", "sidewalk": "separate"}).is_empty())

	var imported: Dictionary = Importer.new().parse_files(["res://tools/tests/fixtures/surface_transport.osm"])
	assert(imported.ok)
	assert(imported.statistics.parking_areas == 1)
	assert(imported.features.filter(func(feature: Dictionary) -> bool: return feature.kind == "parking").size() == 1)
	var collision_result: Dictionary = Builder.new().build(imported.features, imported.bounds)
	assert(collision_result.ok)
	var renderer = Renderer.new()
	root.add_child(renderer)
	renderer.setup(imported.features, collision_result.data, imported.bounds)
	var summary: Dictionary = renderer.surface_style_summary()
	assert(summary.vehicle_roads == 2)
	assert(summary.explicit_width_roads == 1 and summary.lane_scaled_roads == 1)
	assert(summary.explicit_footpaths == 1 and summary.generated_sidewalk_sides == 2)
	assert(summary.surface_parking_areas == 1 and summary.inferred_parking_bay_lines > 0)
	assert(summary.transport_blending_mode == "layered_edges_fills_markings")
	assert(summary.parking_matches_road_asphalt)
	assert(is_equal_approx(float(summary.player_vehicle_metres.length), 5.0))
	var world := func(longitude: float, latitude: float) -> Vector2:
		return ProjectionScript.geographic_to_world(Vector2(longitude, latitude), collision_result.data.projection, collision_result.data.runtime_scale.pixels_per_metre)
	assert(renderer.surface_kind_at(world.call(150.0007, -30.0016)) == "parking")
	assert(renderer.surface_kind_at(world.call(150.00125, -30.0020)).is_empty(), "A solid building did not mask overlapping parking artwork.")
	assert(renderer.surface_kind_at(world.call(150.0025, -30.0030)) == "road")
	assert(renderer.surface_kind_at(world.call(150.0025, -30.0008)) == "footpath")
	print("SCALED TRANSPORT CHECK PASSED: metre widths, blended junctions and parking entrances, footpaths, bay guides and solid-building masking")
	renderer.queue_free()
	quit(0)
