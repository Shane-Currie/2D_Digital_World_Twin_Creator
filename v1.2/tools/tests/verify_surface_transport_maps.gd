extends SceneTree

const Importer = preload("res://scripts/towns/osm_importer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")

const MAPS := [
	{"name": "Howlong", "source": "res://../OSM/howlong.osm"},
	{"name": "Gold Coast", "source": "res://../OSM/gold.osm"},
	{"name": "Sydney Harbour", "source": "res://../OSM/Sydney/harbor.osm"},
	{"name": "Kingston ACT", "source": "res://../OSM/Canberra/kingston.osm"}
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var reports: Array[Dictionary] = []
	for map_entry in MAPS:
		var imported: Dictionary = Importer.new().parse_files([str(map_entry.source)])
		assert(imported.ok, "%s did not import: %s" % [str(map_entry.name), str(imported.get("message", ""))])
		assert(int(imported.statistics.roads) > 0)
		assert(int(imported.statistics.parking_areas) > 0, "%s did not preserve its mapped surface car parks." % str(map_entry.name))
		var collision_result: Dictionary = Builder.new().build(imported.features, imported.bounds)
		assert(collision_result.ok)
		var renderer = Renderer.new()
		root.add_child(renderer)
		renderer.setup(imported.features, collision_result.data, imported.bounds)
		var summary: Dictionary = renderer.surface_style_summary()
		assert(int(summary.vehicle_roads) > 0 and int(summary.explicit_footpaths) > 0)
		assert(int(summary.surface_parking_areas) == int(imported.statistics.parking_areas))
		assert(summary.transport_blending_mode == "layered_edges_fills_markings")
		assert(summary.parking_matches_road_asphalt)
		assert(float(summary.minimum_vehicle_road_width_metres) > float(summary.player_vehicle_metres.width))
		assert(float(summary.maximum_vehicle_road_width_metres) <= 40.0)
		var checked_buildings := 0
		for building in renderer.ground_buildings:
			if checked_buildings >= 250:
				break
			var centre: Vector2 = building.bounds.get_center()
			if renderer._inside_area(centre, building.outer, building.holes):
				assert(renderer.surface_kind_at(centre).is_empty(), "Transport artwork remained active inside a solid %s building." % str(map_entry.name))
				checked_buildings += 1
		assert(checked_buildings > 0)
		reports.append({"name": map_entry.name, "source": ProjectSettings.globalize_path(str(map_entry.source)), "import_statistics": imported.statistics, "surface_style": summary, "sampled_building_masks": checked_buildings})
		print("SCALED TRANSPORT REAL MAP: %s roads=%d footpaths=%d sidewalks=%d parking=%d bay-guides=%d" % [str(map_entry.name), int(summary.vehicle_roads), int(summary.explicit_footpaths), int(summary.generated_sidewalk_sides), int(summary.surface_parking_areas), int(summary.inferred_parking_bay_lines)])
		renderer.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/tests/output"))
	var report_file := FileAccess.open("res://tools/tests/output/surface_transport_maps.json", FileAccess.WRITE)
	assert(report_file != null)
	report_file.store_string(JSON.stringify({"passed": true, "maps": reports}, "  ") + "\n")
	print("SCALED TRANSPORT REAL-MAP CHECK PASSED: four contrasting OSM exports")
	quit(0)
