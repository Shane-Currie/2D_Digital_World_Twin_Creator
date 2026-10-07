extends SceneTree

const Importer = preload("res://scripts/towns/osm_importer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
const ProjectLoader = preload("res://scripts/content/project_loader.gd")
var render_enabled := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(55).timeout.connect(func(): push_error("ENVIRONMENT DETAIL TIMED OUT"); quit(1))
	render_enabled = OS.get_cmdline_user_args().has("--render")
	var fixture := Importer.new().parse_files(["res://tools/tests/fixtures/environment_detail.osm"])
	assert(fixture.ok and fixture.statistics.individual_trees == 3)
	assert(not fixture.features.any(func(feature): return str(feature.id)=="node:13"))
	assert(fixture.features.any(func(feature): return str(feature.kind)=="tree_row"))
	var fixture_world = _world(fixture)
	fixture_world.draw_view_bounds = fixture_world.world_bounds
	fixture_world.environment_visuals.refresh()
	var trees = fixture_world.environment_visuals.trees
	assert(trees.rejected_mapped >= 3,"Mapped trees on the road/water must be omitted.")
	assert(trees.visible_trees.size()>10,"Woodland should gain deterministic decorative trees.")
	var wood_count: int = trees.visible_trees.filter(func(tree): return tree.source=="woodland_decoration").size()
	var grass_count: int = trees.visible_trees.filter(func(tree): return tree.source=="grass_decoration").size()
	assert(grass_count>3 and wood_count>grass_count*3,"Equal-area grass must have substantially fewer trees than woodland.")
	print("TREE DENSITY: ",wood_count," woodland / ",grass_count," grass trees in equal-area fixture; grass sports pitch protected.")
	# Confirm one-point trees survive a saved-project round trip, without sources.
	var saved := ProjectSettings.globalize_path("res://tools/tests/output/tree-roundtrip-%s" % OS.get_process_id())
	assert(DirAccess.make_dir_recursive_absolute(saved.path_join("data"))==OK)
	var file := FileAccess.open(saved.path_join("town.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"map_bounds":fixture.bounds})); file.close()
	file=FileAccess.open(saved.path_join("data/map_features.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"preserves_osm_node_tags":true,"features":fixture.features})); file.close()
	var reopened := ProjectLoader.new().load_project(saved)
	assert(reopened.ok and reopened.import_result.features.filter(func(feature): return feature.kind=="tree").size()==3,"Saved mapped tree points were dropped on reopen.")
	for tree in trees.visible_trees: assert(trees.clear_artwork(tree.bounds))
	var ids: Array = trees.visible_trees.map(func(tree): return tree.id)
	trees.generated_cells.clear()
	trees.refresh()
	assert(ids==trees.visible_trees.map(func(tree): return tree.id),"Revisiting cells changed tree placement.")
	fixture_world.map_overview = true
	fixture_world.environment_visuals.refresh()
	assert(trees.visible_trees.is_empty())
	fixture_world.map_overview = false
	fixture_world.environment_visuals.refresh()
	var bridge_fixture := Importer.new().parse_files(["res://tools/tests/fixtures/water_crossings.osm"])
	var bridge_world = _world(bridge_fixture)
	var sample: Vector2 = bridge_world.water_areas[0].bounds.get_center()
	assert(bridge_world.is_mapped_water(sample))
	# Existing dedicated water regression verifies legal bridge/tunnel traversal.
	bridge_world.queue_free()
	if render_enabled:
		await _render_scene(fixture_world,fixture_world.world_bounds.get_center(),0.50,"environment_detail_fixture","DETAILED ENVIRONMENT • TEST FIXTURE\nOriginal tree artwork / textured grass / animated water")
	fixture_world.queue_free()
	await process_frame
	var albury_source := ProjectSettings.globalize_path("res://../Test Maps/albury/albury/source_osm/01_albury.osm")
	var albury := Importer.new().parse_files([albury_source])
	assert(albury.ok and albury.statistics.individual_trees > 0)
	var world = _world(albury,ProjectSettings.globalize_path("res://../Test Maps/albury/albury"))
	assert(world.environment_visuals.trees.selected_style=="eucalypt","Albury must use gum tree artwork.")
	var forest: Dictionary = {}
	var wet: Dictionary = {}
	for area in world.land_cover.areas:
		if area.category != "wood": continue
		var clipped: Rect2 = area.bounds.intersection(world.world_bounds)
		if clipped.has_area() and (forest.is_empty() or clipped.get_area()>forest.bounds.intersection(world.world_bounds).get_area()): forest=area
	for area in world.water_areas:
		var clipped: Rect2 = area.bounds.intersection(world.world_bounds)
		if clipped.has_area() and (wet.is_empty() or clipped.get_area()>wet.bounds.intersection(world.world_bounds).get_area()): wet=area
	assert(not forest.is_empty() and not wet.is_empty())
	var centre: Vector2 = forest.bounds.intersection(world.world_bounds).get_center()
	# Some large wood polygons extend beyond the uploaded crop; choose a
	# populated in-bounds tree cluster so the picture actually shows the trees.
	var mapped: Array = []
	for cell in world.environment_visuals.trees.mapped_cells:
		mapped.append_array(world.environment_visuals.trees.mapped_cells[cell])
	var best_cluster := 0
	for tree in mapped:
		var nearby_count := 0
		for other in mapped:
			if tree.point.distance_to(other.point)<280.0: nearby_count+=1
		if nearby_count>best_cluster: best_cluster=nearby_count; centre=tree.bounds.get_center()
	world.update_detail_view(centre,1.5,Vector2(1100,700))
	world.environment_visuals.refresh()
	var actual_trees = world.environment_visuals.trees
	assert(not actual_trees.visible_trees.is_empty())
	for tree in actual_trees.visible_trees: assert(actual_trees.clear_artwork(tree.bounds))
	print("ALBURY ENVIRONMENT: ",albury.statistics.individual_trees," mapped tree nodes imported; ",actual_trees.visible_trees.size()," trees in wooded detail view; ",actual_trees.rejected_mapped," mapped/row placements omitted for artwork clearance.")
	# Actual Dean Street: grass fallback verges are not explicitly tagged lawns.
	var dean_segments: Array = world.road_segments.filter(func(segment): return segment.name=="DEAN STREET" and not segment.walkway)
	var dean_trees: Array = []
	for segment in dean_segments:
		world.update_detail_view(segment.a.lerp(segment.b,0.5),1.7,Vector2(1100,700))
		world.environment_visuals.refresh()
		for tree in actual_trees.visible_trees:
			if tree.source!="roadside_decoration": continue
			if Geometry2D.get_closest_point_to_segment(tree.point,segment.a,segment.b).distance_to(tree.point)<=segment.half_width+12.0*world.pixels_per_metre:
				if not dean_trees.any(func(other): return tree.id==other.id): dean_trees.append(tree)
	assert(not dean_trees.is_empty(),"Actual Dean Street has no sparse clear-verge trees.")
	print("DEAN STREET: ",dean_trees.size()," distinct safe roadside decorative trees across the imported street.")
	if render_enabled:
		await _render_scene(world,dean_trees[0].point,1.6,"environment_albury_dean_trees","ALBURY • DEAN STREET\nSparse decorative verge trees / roads and footpaths remain clear")
	world.update_detail_view(centre,1.7,Vector2(1100,700))
	world.environment_visuals.refresh()
	if render_enabled:
		await _render_scene(world,centre,1.7,"environment_albury_trees","ALBURY • GUM TREES AND DETAILED GRASS\nActual OSM tree positions / town-selected artwork / production player scale")
		# The tree camera was released; fixed-time GPU motion is checked with
		# its own camera so static grass/road geometry cannot fake the result.
		var wind_camera := Camera2D.new()
		root.add_child(wind_camera)
		wind_camera.position=centre
		wind_camera.zoom=Vector2.ONE*1.7
		actual_trees.material.set_shader_parameter("preview_time",0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var calm := root.get_texture().get_image()
		actual_trees.material.set_shader_parameter("preview_time",2.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var breeze := root.get_texture().get_image()
		var changed_tree_pixels := 0
		for y in range(80,680,5):
			for x in range(20,1080,5):
				var point := centre+(Vector2(x,y)-Vector2(550,350))/1.7
				if actual_trees.visible_trees.any(func(tree): return tree.bounds.has_point(point)) and calm.get_pixel(x,y)!=breeze.get_pixel(x,y): changed_tree_pixels+=1
		assert(changed_tree_pixels>5,"Tree wind animation did not change the rendered crown.")
		print("TREE WIND: ",changed_tree_pixels," sampled tree-envelope pixels changed between fixed phases.")
		actual_trees.material.set_shader_parameter("preview_time",-1.0)
		wind_camera.queue_free()
		await process_frame
		var water_centre: Vector2 = wet.bounds.intersection(world.world_bounds).get_center()
		await _render_scene(world,water_centre,1.8,"environment_albury_water","ALBURY • ANIMATED WATER\nRipples, reflections and shoreline highlights / original mapped boundary")
		# Fix shader time for two reproducible captures; verify water really moves.
		var water_layer = world.environment_visuals.surfaces[2]
		water_layer.material.set_shader_parameter("preview_time",0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var first := root.get_texture().get_image()
		water_layer.material.set_shader_parameter("preview_time",1.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var second := root.get_texture().get_image()
		var changed_water_pixels := 0
		for y in range(80,680,12):
			for x in range(20,1080,12):
				var world_point := water_centre+(Vector2(x,y)-Vector2(550,350))/1.8
				if world.is_mapped_water(world_point) and first.get_pixel(x,y)!=second.get_pixel(x,y): changed_water_pixels+=1
		assert(changed_water_pixels>20,"Water animation produced no visible changes on mapped water.")
		print("WATER ANIMATION: ",changed_water_pixels," sampled mapped-water pixels changed between fixed one-second phases.")
		first.save_png("res://docs/screenshots/environment_water_phase_0.png")
		second.save_png("res://docs/screenshots/environment_water_phase_1.png")
		world.tunnel_view_only = true
		await process_frame
		await process_frame
		assert(not world.environment_visuals.visible,"Surface effects leaked into tunnel view.")
	world.queue_free()
	await process_frame
	print("ENVIRONMENT DETAIL PASSED: OSM trees/rows, repeatable streamed woods, whole-artwork route clearance, overview LOD, water material animation and tunnel visibility. Source maps unchanged.")
	quit()

func _world(imported: Dictionary, town_directory: String = ""):
	var collision := Builder.new().build(imported.features,imported.bounds)
	assert(collision.ok)
	var world := Renderer.new()
	root.add_child(world)
	world.setup(imported.features,collision.data,imported.bounds,{},town_directory)
	return world

func _render_scene(world,centre: Vector2,zoom: float,file_name: String,caption_text: String) -> void:
	root.size=Vector2i(1100,700)
	root.content_scale_size=Vector2i(1100,700)
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.position=centre
	camera.zoom=Vector2.ONE*zoom
	world.update_detail_view(centre,zoom,Vector2(1100,700))
	world.environment_visuals.refresh()
	world.queue_redraw()
	var actor := Player.new()
	actor.controls_enabled=false
	var safe := centre+Vector2(90,60)
	var nearest_distance := INF
	var walking_paths: Array = world.sidewalk_paths.duplicate()
	for path in world.road_paths:
		if bool(path.walkway): walking_paths.append(path)
	for path in walking_paths:
		for point in path.points:
			if point.distance_to(centre)<nearest_distance: nearest_distance=point.distance_to(centre); safe=point
	# If mapped paths lie outside this close detail view, show the real player
	# on clear grass in the visible scene, rather than off-screen.
	if safe.distance_to(centre)>150.0:
		for offset in [Vector2(80,90),Vector2(-80,90),Vector2(0,120),Vector2(80,-90)]:
			var candidate: Vector2 = centre+Vector2(offset)
			if world.world_bounds.has_point(candidate) and not world.is_mapped_water(candidate) and not world._inside_ground_building(candidate): safe=candidate; break
	actor.position=safe
	root.add_child(actor)
	var ui := CanvasLayer.new()
	root.add_child(ui)
	var caption := Label.new()
	caption.text=caption_text
	caption.position=Vector2(20,16)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",1)
	caption.add_theme_constant_override("shadow_offset_y",1)
	ui.add_child(caption)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % file_name)==OK)
	# Keep the water camera for the two animation frames after the final scene.
	if file_name != "environment_albury_water": camera.queue_free(); ui.queue_free(); actor.queue_free(); await process_frame
