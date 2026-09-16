extends SceneTree

const ImporterScript = preload("res://scripts/towns/osm_importer.gd")
const CollisionBuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")
const RendererScript = preload("res://scripts/runtime/runtime_world_renderer.gd")


func _initialize() -> void:
	call_deferred("_render_preview")


func _render_preview() -> void:
	var source := ProjectSettings.globalize_path("res://../OSM/gold.osm")
	var imported: Dictionary = ImporterScript.new().parse_files(PackedStringArray([source]))
	assert(imported.ok and int(imported.statistics.inferred_coastal_water_areas) > 0)
	var collisions: Dictionary = CollisionBuilderScript.new().build(imported.features, imported.bounds)
	assert(collisions.ok)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(viewport)
	var world: Node2D = RendererScript.new()
	viewport.add_child(world)
	world.setup(imported.features, collisions.data, imported.bounds)
	var camera := Camera2D.new()
	viewport.add_child(camera)
	camera.enabled = true
	camera.position = world.world_bounds.get_center()
	var fit := minf(float(viewport.size.x) / world.world_bounds.size.x, float(viewport.size.y) / world.world_bounds.size.y) * 0.94
	camera.zoom = Vector2.ONE * fit
	await process_frame
	await process_frame
	await process_frame
	var output_directory := ProjectSettings.globalize_path("res://tools/tests/output")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_path := output_directory.path_join("gold_coast_environment.png")
	assert(viewport.get_texture().get_image().save_png(output_path) == OK)
	print("GOLD COAST ENVIRONMENT PREVIEW SAVED: ", output_path)
	quit(0)
