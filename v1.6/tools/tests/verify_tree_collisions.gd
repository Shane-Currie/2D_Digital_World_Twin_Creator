extends SceneTree

const Importer = preload("res://scripts/towns/osm_importer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
const Vehicle = preload("res://scripts/runtime/runtime_player_vehicle.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
const Impact = preload("res://scripts/runtime/crashes/impact_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _world(imported: Dictionary, directory: String = ""):
	var collision := Builder.new().build(imported.features,imported.bounds)
	assert(collision.ok)
	var world := Renderer.new()
	root.add_child(world)
	world.setup(imported.features,collision.data,imported.bounds,{},directory)
	return world

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("TREE COLLISIONS TIMED OUT"); quit(1))
	var imported := Importer.new().parse_files(["res://tools/tests/fixtures/environment_detail.osm"])
	# Add a mapped tree on clear grass; existing nodes lie on water/road.
	imported.features.append({"kind":"tree","id":"collision-tree","tags":{"natural":"tree"},"points":[{"latitude":-36.0016,"longitude":146.9041}]})
	var world = _world(imported)
	world.draw_view_bounds=world.world_bounds
	world.environment_visuals.refresh()
	var trees = world.environment_visuals.trees
	var tree: Dictionary = trees.visible_trees.filter(func(value): return value.id=="collision-tree")[0]
	world.tree_collisions.update_focus([tree.point])
	assert(world.tree_collisions.bodies.has(tree.id))
	var first_body = world.tree_collisions.bodies[tree.id]
	world.tree_collisions.update_focus([tree.point+Vector2.ONE])
	assert(first_body==world.tree_collisions.bodies[tree.id],"Unchanged actor cells should reuse bodies.")
	assert(not world.is_ground_traversable(tree.point,2))
	assert(not trees.trunk_segment_clear(tree.point-Vector2(30,0),tree.point+Vector2(30,0),2))
	assert(world.is_ground_traversable(tree.point+Vector2(0,-15),2),"Canopy must not be solid.")
	var population := Population.new()
	root.add_child(population)
	population.set_process(false)
	population.set_ground_check(world.is_ground_traversable)
	population.set_building_segment_check(world._segment_clear_of_buildings)
	assert(not population._walk_segment_is_clear(tree.point-Vector2(30,0),tree.point+Vector2(30,0)))
	assert(population._walk_segment_is_clear(tree.point+Vector2(-20,-15),tree.point+Vector2(20,-15)))
	assert(not Impact.world_pose_clear({"kind":"person"},tree.point-Vector2(30,0),tree.point+Vector2(30,0),population))
	var player := Player.new()
	player.controls_enabled=false
	root.add_child(player)
	player.set_ground_check(world.is_ground_traversable)
	player.position=tree.point+Vector2(-30,0)
	await physics_frame
	await physics_frame
	assert(player.move_and_collide(Vector2(60,0))!=null,"Player passed through trunk.")
	assert(player.position.x<tree.point.x-tree.radius)
	player.position=tree.point+Vector2(-25,-15)
	await physics_frame
	assert(player.move_and_collide(Vector2(50,0))==null,"Leaves blocked the player.")
	player.position=world.world_bounds.position+Vector2(10,10)
	var car := Vehicle.new()
	car.controls_enabled=false
	root.add_child(car)
	car.rotation=PI*0.5
	car.position=tree.point+Vector2(-80,0)
	# Even a road waiver cannot disable the dedicated trunk layer.
	car.set_drivable_pose_check(func(_point,_angle,_half): return true)
	await physics_frame
	await physics_frame
	car.collision_mask=car._collision_mask_for_motion(car.position,tree.point+Vector2(80,0),car.rotation)
	assert(car.collision_mask==(2|64))
	assert(car.move_and_collide(Vector2(160,0))!=null,"Swept fast vehicle passed through a trunk.")
	assert(car.position.x<tree.point.x-tree.radius)
	car.position=tree.point+Vector2(-80,0)
	car.occupied=true
	car.controls_enabled=true
	car.set_physics_process(false)
	car.set_ground_check(world.is_ground_traversable)
	car.speed=car.kilometres_per_hour_to_world_speed(200)
	car.target_speed_kmh=200
	await physics_frame
	car._physics_process(1.0)
	assert(car.position.x<tree.point.x-tree.radius and car.speed==0 and car.target_speed_kmh==0,"Driving contact did not stop speed/cruise.")
	car.controls_enabled=false
	car.position=world.world_bounds.position+Vector2(40,40)
	# Overview/pan/tunnel artwork hiding must not remove surface physics.
	world.map_overview=true
	world.draw_view_bounds=Rect2(100000,100000,100,100)
	world.environment_visuals.refresh()
	assert(trees.visible_trees.is_empty() and world.tree_collisions.bodies.has(tree.id))
	trees.selected_style="eucalypt"
	var custom := Image.create(8,16,false,Image.FORMAT_RGBA8)
	custom.fill(Color.GREEN)
	trees.custom_texture=ImageTexture.create_from_image(custom)
	assert(not trees.trunk_segment_clear(tree.point,tree.point,2),"Artwork changes disabled trunk collision.")
	player.position=tree.point+Vector2(-30,0)
	player.set_interior_mode(true)
	assert(player.collision_mask==0)
	await physics_frame
	assert(player.move_and_collide(Vector2(60,0))==null,"Outdoor trunk leaked into interior space.")
	player.set_interior_mode(false)
	player.crossing_travel.active={"kind":"bridge"}
	player.refresh_collision_mask_for_crossing()
	assert((player.collision_mask&64)==0)
	player.position=tree.point+Vector2(-30,0)
	await physics_frame
	assert(player.move_and_collide(Vector2(60,0))==null,"Ground trunk obstructed separate bridge level.")
	car.crossing_travel.active={"kind":"tunnel"}
	assert((car._collision_mask_for_motion(car.position,car.position,car.rotation)&64)==0)
	world.tree_collisions.update_focus([tree.point],false)
	assert(first_body.collision_layer==0)
	world.tree_collisions.update_focus([tree.point],true)
	assert(first_body.collision_layer==64)
	world.tree_collisions.update_focus([Vector2(100000,100000)])
	assert(world.tree_collisions.bodies.is_empty(),"Old tree bodies did not unload.")
	world.tree_collisions.update_focus([tree.point])
	assert(world.tree_collisions.bodies.has(tree.id),"Revisit did not restore trunk collision.")
	assert(trees.generated_cells.size()<=trees.MAX_CACHED_CELLS)
	player.queue_free(); car.queue_free(); population.queue_free(); world.queue_free()
	await process_frame
	# Read-only actual Albury: check every emitted trunk in a Dean Street window.
	var directory := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var albury := Importer.new().parse_files([directory.path_join("source_osm/01_albury.osm")])
	var actual = _world(albury,directory)
	assert(actual.environment_visuals.trees.safe_starts.size()==2)
	for start in actual.environment_visuals.trees.safe_starts:
		assert(actual.environment_visuals.trees.trunk_segment_clear(start,start,2))
	var segment: Dictionary = actual.road_segments.filter(func(value): return value.name=="DEAN STREET" and not value.walkway)[0]
	actual.update_detail_view(segment.a.lerp(segment.b,0.5),1.7,Vector2(1100,700))
	actual.environment_visuals.refresh()
	actual.tree_collisions.update_focus([segment.a.lerp(segment.b,0.5)])
	var checked := 0
	for value in actual.environment_visuals.trees.visible_trees:
		assert(actual.environment_visuals.trees.clear_artwork(value.bounds))
		assert(actual.tree_collisions.bodies.has(value.id))
		assert(not actual.is_ground_traversable(value.point,2))
		checked+=1
	assert(checked>0)
	if OS.get_cmdline_user_args().has("--render"):
		var target: Dictionary = actual.environment_visuals.trees.visible_trees[0]
		var approach: Vector2 = segment.a
		var nearest := INF
		var street := ""
		for road in actual.road_segments:
			if road.walkway or road.bridge or road.tunnel: continue
			var candidate := Geometry2D.get_closest_point_to_segment(target.point,road.a,road.b)
			if candidate.distance_to(target.point)<nearest:
				nearest=candidate.distance_to(target.point); approach=candidate; street=road.name
		var preview := Vehicle.new()
		preview.controls_enabled=false
		preview.position=approach
		preview.rotation=approach.direction_to(target.point).angle()+PI*0.5
		root.add_child(preview)
		actual.tree_collisions.update_focus([target.point])
		await physics_frame
		await physics_frame
		assert(preview.move_and_collide(target.point-approach)!=null)
		for offset in [Vector2.ZERO,Vector2(-8.5,-20),Vector2(8.5,20),Vector2(-8.5,20),Vector2(8.5,-20)]:
			assert(not actual._inside_ground_building(preview.position+Vector2(offset).rotated(preview.rotation)),"Preview car intersects mapped building.")
		var actor := Player.new()
		actor.controls_enabled=false
		actor.position=target.point+Vector2(40,-20)
		root.add_child(actor)
		root.size=Vector2i(1000,650)
		var camera := Camera2D.new()
		root.add_child(camera)
		camera.position=target.point+Vector2(0,10)
		camera.zoom=Vector2.ONE*2.4
		actual.update_detail_view(camera.position,2.4,Vector2(1000,650))
		actual.environment_visuals.refresh()
		var ui := CanvasLayer.new()
		root.add_child(ui)
		var label := Label.new()
		label.text="ALBURY • "+street+"\nCar stopped at a solid tree trunk — leaves remain passable"
		label.position=Vector2(20,15)
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x",1)
		label.add_theme_constant_override("shadow_offset_y",1)
		ui.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/screenshots/environment_tree_collision.png")==OK)
		preview.queue_free(); actor.queue_free(); camera.queue_free(); ui.queue_free()
	print("TREE COLLISIONS PASSED: solid mapped/generated/custom trunks, swept car/player contacts, passable canopy, NPC detour/impact blocking, overview/pan independence, interior/bridge/tunnel isolation, streaming reuse/revisit. Actual Dean Street: ",checked," visible trunks checked. No town writes.")
	actual.queue_free()
	await process_frame
	quit()
