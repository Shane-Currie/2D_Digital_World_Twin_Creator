extends SceneTree
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(256,256)
	viewport.add_child(black)
	var world := Renderer.new()
	viewport.add_child(world)
	world.world_bounds = Rect2(0,0,256,256)
	var tunnel_points := PackedVector2Array([Vector2(0,0),Vector2(256,256)])
	world.road_paths = [{"points":tunnel_points,"half_width":20.0,"tunnel":true,"bridge":false}]
	world.crossing_corridors = [{"id":"bridge","kind":"bridge","points":PackedVector2Array([Vector2(128,0),Vector2(128,256)]),"half_width":24.0,"over_water":true},{"id":"tunnel","kind":"tunnel","points":tunnel_points,"half_width":20.0}]
	await process_frame
	await RenderingServer.frame_post_draw
	var surface := viewport.get_texture().get_image()
	assert(surface.get_pixel(50,55).is_equal_approx(Renderer.GRASS), "A buried road still paints across the surface")
	assert(surface.get_pixel(140,135).is_equal_approx(Renderer.ROAD), "The bridge deck is interrupted at the tunnel overlap")
	world.set_tunnel_view(true)
	await process_frame
	await RenderingServer.frame_post_draw
	var underground := viewport.get_texture().get_image()
	assert(underground.get_pixel(50,55).is_equal_approx(Renderer.TUNNEL_ROAD), "The underground road disappeared")
	assert(underground.get_pixel(128,60).is_equal_approx(Color.BLACK), "The bridge or surface leaked into tunnel view")
	world.set_tunnel_view(false)
	world.crossing_corridors[0].over_water = false
	world.crossing_corridors.append({"id":"second_bridge","kind":"bridge","points":PackedVector2Array([Vector2(208,0),Vector2(208,256)]),"half_width":24.0,"over_water":false})
	world.set_map_overview(true)
	await process_frame
	await RenderingServer.frame_post_draw
	var overview_image := viewport.get_texture().get_image()
	for x in [140,220]:
		for y in [60,135,200]:
			assert(overview_image.get_pixel(x,y).is_equal_approx(Renderer.ROAD), "An inactive land bridge is missing from the overview")
	assert(world.active_land_bridge_id.is_empty(), "Opening the map changed player crossing state")
	world.set_map_overview(false)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(140,135).is_equal_approx(Renderer.GRASS), "Closing the map did not restore gameplay bridge visibility")
	print("CROSSING RENDER PASSED: uninterrupted bridge, hidden surface tunnel, black tunnel view, complete inactive land bridges in overview, gameplay restoration")
	quit()
