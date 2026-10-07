extends SceneTree

const Importer = preload("res://scripts/towns/osm_importer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const Cover = preload("res://scripts/land_cover/land_cover.gd")
const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var imported: Dictionary = Importer.new().parse_files(["res://tools/tests/fixtures/land_cover.osm"])
	assert(imported.ok)
	# The malformed wetland's member must not suppress the independently tagged
	# grass way; the forest's inner house must retain building collision.
	var ids: Array = imported.features.map(func(feature: Dictionary) -> String: return str(feature.id))
	assert("100" in ids and "104" in ids and "relation:200" in ids)
	assert("106" not in ids and "107" not in ids and "relation:201" not in ids)
	assert(imported.warnings.size() == 2)
	var result: Dictionary = Builder.new().build(imported.features, imported.bounds)
	assert(result.ok and result.data.buildings.size() == 1)
	var world := Renderer.new()
	root.add_child(world)
	world.setup(imported.features, result.data, imported.bounds)
	var project := func(lon: float, lat: float) -> Vector2: return ProjectionScript.geographic_to_world(Vector2(lon,lat),result.data.projection,result.data.runtime_scale.pixels_per_metre)
	var hole: Vector2 = project.call(150.0035,-30.0035)
	assert(world.land_cover.category_at(hole) == "grass" and world.is_grass(hole))
	var forest: Vector2 = project.call(150.005,-30.003)
	assert(world.land_cover.category_at(forest) == "wood" and not world.is_grass(forest))
	assert(not world.is_grass(project.call(150.0065,-30.0065)))
	assert(not world.is_grass(project.call(150.0015,-30.005)))
	for area in world.land_cover.areas:
		if area.category == "wood":
			assert(not area.pieces.is_empty())
			for piece in area.pieces:
				assert(not Geometry2D.is_point_in_polygon(hole,piece), "A forest fill covered its mapped hole")
	world.queue_free()
	var aliases := [{"tags":{"landuse":"meadow"},"category":"grass"},{"tags":{"natural":"grassland"},"category":"grass"},{"tags":{"landuse":"forest"},"category":"wood"},{"tags":{"landcover":"trees"},"category":"wood"},{"tags":{"natural":"wetland"},"category":"wetland"},{"tags":{"natural":"heath"},"category":"scrub"},{"tags":{"leisure":"park"},"category":"park"},{"tags":{"amenity":"parking","surface":"grass"},"category":"grass"},{"tags":{"surface":"asphalt"},"category":"paved"},{"tags":{"natural":"sand"},"category":"sand"},{"tags":{"natural":"bare_rock"},"category":"rock"},{"tags":{"landuse":"orchard"},"category":"farmland"},{"tags":{"landuse":"residential"},"category":""}]
	for entry in aliases: assert(Cover.classify(entry.tags) == entry.category)
	assert(Cover.classify({"surface":"concrete","layer":"1"}).is_empty())
	assert(Cover.classify({"landuse":"grass","tunnel":"yes"}).is_empty())
	var reports: Array = []
	for source in ["res://../OSM/Sydney/The Rocks.osm", "res://../OSM/howlong.osm"]:
		var real: Dictionary = Importer.new().parse_files([source])
		assert(real.ok and real.statistics.land_cover_areas > 0)
		var old_features: Array = real.features.filter(func(feature: Dictionary) -> bool: return feature.kind != "land_cover")
		var before: Dictionary = Builder.new().build(old_features, real.bounds)
		var after: Dictionary = Builder.new().build(real.features, real.bounds)
		assert(before.data.buildings == after.data.buildings)
		assert(before.data.water_areas == after.data.water_areas)
		var features_report: Array = []
		for feature in real.features:
			if feature.kind == "land_cover": features_report.append({"id": str(feature.id), "category": Cover.classify(feature.tags),"holes":feature.holes.size()})
		reports.append({"source":ProjectSettings.globalize_path(source),"land_cover":features_report,"statistics":real.statistics})
		print("LAND COVER REAL MAP: ",source," areas=",real.statistics.land_cover_areas," unchanged building/water collision geometry")
	var file := FileAccess.open("res://tools/tests/output/land_cover_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"maps":reports},"  "))
	print("LAND COVER CHECK PASSED: multipart holes, independent house, incomplete data, tag aliases, road/building exclusions and two real maps")
	quit()
