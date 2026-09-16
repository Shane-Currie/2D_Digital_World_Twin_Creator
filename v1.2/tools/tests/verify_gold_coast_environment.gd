extends SceneTree

const ImporterScript = preload("res://scripts/towns/osm_importer.gd")
const CollisionBuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")
const RendererScript = preload("res://scripts/runtime/runtime_world_renderer.gd")


func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://../OSM/gold.osm")
	assert(FileAccess.file_exists(source), "The user-uploaded Gold Coast OSM source is missing.")
	var imported: Dictionary = ImporterScript.new().parse_files(PackedStringArray([source]))
	assert(imported.ok)
	assert(int(imported.statistics.incomplete_water_relations) == 1)
	assert(int(imported.statistics.unresolved_water_relations) == 0, "Missing inner island holes incorrectly blocked this otherwise complete water area.")
	assert(int(imported.statistics.water_areas) == 168)
	assert(int(imported.statistics.inferred_coastal_water_areas) == 2)
	var warning_text := " ".join(imported.warnings)
	assert(warning_text.contains("complete water edge"))
	assert(warning_text.contains("inner island/land"))
	var collisions: Dictionary = CollisionBuilderScript.new().build(imported.features, imported.bounds)
	assert(collisions.ok)
	assert(int(collisions.data.statistics.blocking_water_areas) == 168)
	var renderer = RendererScript.new()
	root.add_child(renderer)
	renderer.setup(imported.features, collisions.data, imported.bounds)
	var fit_zoom := minf(384.0 / renderer.world_bounds.size.x, 190.0 / renderer.world_bounds.size.y) * 0.94
	renderer.update_street_label_presentation(fit_zoom, 1.0, true)
	var broad_labels: Array[String] = []
	for child in renderer.get_children():
		if child.is_in_group("generated_street_labels") and child.visible:
			broad_labels.append(str(child.text))
	assert(not broad_labels.is_empty())
	assert(broad_labels.size() <= 20, "The fitted Gold Coast map still contains too many street labels to read.")
	var unique_names: Dictionary = {}
	for label_name in broad_labels:
		assert(not unique_names.has(label_name), "A broad overview repeated the same street name.")
		unique_names[label_name] = true
	renderer.update_street_label_presentation(0.12, 2.0, true)
	var close_label_count := 0
	for child in renderer.get_children():
		if child.is_in_group("generated_street_labels") and child.visible:
			close_label_count += 1
	assert(close_label_count > broad_labels.size(), "Zooming in did not progressively reveal more street names.")
	print("GOLD COAST ENVIRONMENT CHECK PASSED: coastal ocean filled; complete outer water accepted; fitted labels reduced to %d readable names and expand to %d after zooming." % [broad_labels.size(), close_label_count])
	quit(0)
