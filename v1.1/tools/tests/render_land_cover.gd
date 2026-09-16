extends SceneTree

const Importer = preload("res://scripts/towns/osm_importer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const Cover = preload("res://scripts/land_cover/land_cover.gd")

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var imported: Dictionary = Importer.new().parse_files(["res://../OSM/Sydney/The Rocks.osm"])
	var collisions: Dictionary = Builder.new().build(imported.features, imported.bounds)
	assert(imported.ok and collisions.ok)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Renderer.new()
	viewport.add_child(world)
	world.setup(imported.features,collisions.data,imported.bounds)
	var camera := Camera2D.new()
	viewport.add_child(camera)
	camera.position = world.world_bounds.get_center()
	camera.zoom = Vector2.ONE * minf(1200.0/world.world_bounds.size.x,620.0/world.world_bounds.size.y)
	var canvas := CanvasLayer.new()
	viewport.add_child(canvas)
	var title := Label.new()
	title.text = "THE ROCKS · IMPORTED LAND COVER\nActual Godot renderer · OpenStreetMap contributors"
	title.position = Vector2(16,10)
	title.add_theme_font_size_override("font_size",18)
	canvas.add_child(title)
	var x := 16.0
	for category in ["grass","park","wood","scrub","wetland","paved","sand","rock","farmland"]:
		var swatch := ColorRect.new()
		swatch.color = Cover.colour(category)
		swatch.position = Vector2(x,686)
		swatch.size = Vector2(16,16)
		canvas.add_child(swatch)
		var label := Label.new()
		label.text = category.capitalize()
		label.position = Vector2(x + 22,682)
		canvas.add_child(label)
		x += 135
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png("res://tools/tests/output/land_cover_overview.png") == OK)
	var preview: Control = load("res://scripts/towns/map_canvas.gd").new()
	root.add_child(preview)
	preview.position = Vector2(12,12)
	preview.size = Vector2(1256,776)
	preview.clip_contents = true
	preview.set_map_data(imported)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://tools/tests/output/land_cover_creator_preview.png") == OK)
	print("LAND COVER OVERVIEW RENDERED")
	quit()
