extends SceneTree

const Profile = preload("res://scripts/buildings/building_height_profile.gd")
const Geometry = preload("res://scripts/buildings/building_height_geometry.gd")
const Store = preload("res://scripts/buildings/building_exterior_store.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const TownProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const Vehicle = preload("res://scripts/runtime/runtime_player_vehicle.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
const DoorArt = preload("res://scripts/buildings/building_door_art.gd")
const Clearance = preload("res://scripts/buildings/building_visual_clearance.gd")
const Details = preload("res://scripts/buildings/building_surface_details.gd")
var audit_failures := 0
var audit_building_id := "fixture"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(50).timeout.connect(func(): push_error("BUILDING HEIGHTS TIMED OUT"); quit(1))
	assert(Profile.resolve({}).total_floors == 1)
	assert(Profile.resolve({"height": "60"}).total_floors == 1)
	assert(Profile.resolve({"building:levels": "6"}).total_floors == 6)
	assert(Profile.resolve({"building:levels": "6", "roof:levels": "2"}).total_floors == 6)
	for invalid in ["1.5", "unknown", "0", "-1", "999", "2;3"]:
		assert(Profile.resolve({"building:levels": invalid}).total_floors == 1)
	assert(Profile.resolve({"building:levels": "6"}, {"total_floors": 3}).total_floors == 3)
	var store := Store.new()
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/building-heights-%s" % OS.get_process_id())
	var data: Dictionary = Profile.set_floors(store.empty_data(), "way/test", 12).data
	data = Profile.set_style(data, "way/test", "brick")
	assert(store.save_to_town(temporary, data).ok)
	assert(store.load_from_town(temporary).data.buildings["way/test"].total_floors == 12)
	assert(not Profile.set_floors(data, "way/test", 0).ok)
	var original_png := ProjectSettings.globalize_path("res://assets/actors/car_sedan_blue_v3.png")
	var imported := store.import_wall(temporary, data, "way/test", original_png)
	assert(imported.ok and imported.data.buildings["way/test"].has("wall") and not imported.data.buildings["way/test"].has("exterior"))
	assert(store.save_to_town(temporary, imported.data).ok)
	assert(Profile.restore(imported.data, "way/test").buildings["way/test"].has("wall"))
	var ring := PackedVector2Array([Vector2(0,0),Vector2(120,0),Vector2(120,100),Vector2(0,100)])
	var holes := [PackedVector2Array([Vector2(35,35),Vector2(65,35),Vector2(65,65),Vector2(35,65)])]
	var mesh := Geometry.build(ring, holes, 12, 8)
	assert(mesh.total_floors == 12 and mesh.walls.size() == 8)
	var box_mesh := Geometry.build(ring, [], 20, 8)
	assert(box_mesh.projection=="fitted_prism")
	assert(is_equal_approx(Geometry._pieces_area(box_mesh.roof),Geometry._pieces_area(box_mesh.base)),"Prism base and roof must have matching area before occlusion.")
	for wall in box_mesh.walls:
		assert((wall.top_a-wall.base_a).is_equal_approx(box_mesh.rise))
		assert((wall.top_b-wall.base_b).is_equal_approx(box_mesh.rise))
		assert((wall.top_b-wall.top_a).is_equal_approx(wall.base_b-wall.base_a),"Prism roof/base edges must be parallel and equal.")
	assert(box_mesh.total_floors == 20 and box_mesh.visual_floors == 10)
	assert(Geometry.build(ring, [], 200, 8).roof == box_mesh.roof, "Counts above ten must not increase projected height.")
	assert(box_mesh.walls.filter(func(wall): return wall.facing_camera).size() == 2, "A rectangle should show only two camera-facing facades.")
	var reversed_ring := ring.duplicate()
	reversed_ring.reverse()
	var reversed_mesh := Geometry.build(reversed_ring, [], 20, 8)
	assert(reversed_mesh.walls.filter(func(wall): return wall.facing_camera).size() == 2, "Face visibility changed with OSM winding.")
	var left_neighbour := PackedVector2Array([Vector2(-120,0),Vector2(0,0),Vector2(0,100),Vector2(-120,100)])
	var adjoining := [{"points":left_neighbour,"bounds":Geometry.polygon_bounds(left_neighbour),"owner":"left","floors":4}]
	var detached := Geometry.build(ring,[],4,8)
	var equal_height := Geometry.build(ring,[],4,8,adjoining)
	assert(_left_wall_area(equal_height) < 0.1, "Equal-height attached buildings must hide the shared side.")
	_assert_front_join(equal_height,Vector2(2,95))
	var reversed_join := Geometry.build(reversed_ring,[],4,8,adjoining)
	_assert_front_join(reversed_join,Vector2(2,95))
	_assert_contained(reversed_join,reversed_ring,[])
	adjoining[0].floors = 8
	var below_higher := Geometry.build(ring,[],4,8,adjoining)
	assert(_left_wall_area(below_higher) < 0.1, "A taller neighbour must hide the shorter building's side.")
	_assert_front_join(below_higher,Vector2(2,95))
	adjoining[0].floors = 2
	var above_lower := Geometry.build(ring,[],4,8,adjoining)
	assert(_left_wall_area(above_lower) > 0.1 and _left_wall_area(above_lower) < _left_wall_area(detached), "Only the wall above the lower neighbour may show.")
	_assert_front_join(above_lower,Vector2(2,95))
	var rotated_ring := PackedVector2Array()
	var rotated_neighbour := PackedVector2Array()
	for point in ring: rotated_ring.append(point.rotated(0.2)+Vector2(350,500))
	for point in left_neighbour: rotated_neighbour.append(point.rotated(0.2)+Vector2(350,500))
	var rotated_join := Geometry.build(rotated_ring,[],4,8,[{"points":rotated_neighbour,"owner":"left","floors":4}])
	_assert_front_join(rotated_join,Vector2(2,95).rotated(0.2)+Vector2(350,500))
	_assert_contained(rotated_join,rotated_ring,[])
	var partial_neighbour := PackedVector2Array([Vector2(-120,0),Vector2(0,0),Vector2(0,60),Vector2(-120,60)])
	var partial_join := Geometry.build(ring,[],4,8,[{"points":partial_neighbour,"owner":"left","floors":4}])
	assert(_left_wall_area(partial_join) > 0.1, "A partial party wall must keep its uncovered front end visible.")
	_assert_contained(partial_join,ring,[])
	var front_neighbour := PackedVector2Array([Vector2(-120,60),Vector2(0,60),Vector2(0,100),Vector2(-120,100)])
	var partial_front_join := Geometry.build(ring,[],4,8,[{"points":front_neighbour,"owner":"left","floors":4}])
	_assert_front_join(partial_front_join,Vector2(2,95))
	_assert_contained(partial_front_join,ring,[])
	_assert_contained(equal_height,ring,[])
	_assert_contained(above_lower,ring,[])
	var gap_neighbour := PackedVector2Array()
	for point in left_neighbour: gap_neighbour.append(point-Vector2(4,0))
	var gap_mesh := Geometry.build(ring,[],4,8,[{"points":gap_neighbour,"bounds":Geometry.polygon_bounds(gap_neighbour),"owner":"left","floors":4}])
	assert(is_equal_approx(_left_wall_area(gap_mesh),_left_wall_area(detached)), "A real gap must leave the side visible.")
	_assert_contained(mesh, ring, holes)
	for roof in mesh.roof: assert(not Geometry2D.is_point_in_polygon(Vector2(50,50), roof))
	var shapes := [
		PackedVector2Array([Vector2(0,0),Vector2(8,0),Vector2(8,300),Vector2(0,300)]),
		PackedVector2Array([Vector2(0,0),Vector2(200,0),Vector2(200,40),Vector2(40,40),Vector2(40,200),Vector2(0,200)]),
		PackedVector2Array([Vector2(0,0),Vector2(160,0),Vector2(160,120),Vector2(130,120),Vector2(130,30),Vector2(30,30),Vector2(30,120),Vector2(0,120)])
	]
	for outline in shapes:
		for floors in [1,20,24,200]:
			var projected := Geometry.build(outline, [], floors, 8)
			assert(not projected.roof.is_empty())
			_assert_contained(projected, outline, [])
	var test_facades: Array[PackedVector2Array] = []
	for wall in mesh.walls:
		for surface in wall.surfaces: test_facades.append(surface.points)
	var detailed_door := DoorArt.build(Vector2(60,100), Vector2(60,115), 8, mesh.ground, test_facades)
	assert(detailed_door.anchor == Vector2(60,100) and not detailed_door.surfaces.is_empty())
	var door_bounds := Rect2()
	for surface in detailed_door.surfaces:
		for point in surface.points:
			if not door_bounds.has_area(): door_bounds = Rect2(point, Vector2(0.0001,0.0001))
			else: door_bounds = door_bounds.expand(point)
	assert(door_bounds.size.x <= 7.91 and door_bounds.size.y <= 15.82, "Door artwork exceeded its character-scaled limit.")
	assert(door_bounds.size.y >= DoorArt.ActorArt.GROUND_CHARACTER_DRAW_SIZE.y*1.1, "A normal doorway should be slightly taller than the player.")
	for surface in detailed_door.surfaces:
		for roof in mesh.roof: _assert_disjoint(surface.points, roof)
	var tiny_ground: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0,0),Vector2(4,0),Vector2(4,4),Vector2(0,4)])]
	var tiny_facades: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0,3),Vector2(4,3),Vector2(4,4),Vector2(0,4)])]
	var tiny_door := DoorArt.build(Vector2(2,4), Vector2(2,8), 8, tiny_ground, tiny_facades)
	for surface in tiny_door.surfaces:
		assert(Geometry.polygon_bounds(surface.points).size.y <= 0.801, "Door must scale down with a tiny building.")
	var road_outline := PackedVector2Array([Vector2(-100,108),Vector2(200,108),Vector2(200,140),Vector2(-100,140)])
	var blocked := [{"points":road_outline,"bounds":Geometry.polygon_bounds(road_outline)}]
	var roadside_mesh := Geometry.build(ring, [], 20, 8, blocked)
	for wall in roadside_mesh.walls:
		for surface in wall.surfaces:
			_assert_disjoint(surface.points, road_outline)
			for point in surface.points: assert(point.y <= 108.2, "Facade continued beyond the first road obstacle.")
	_assert_contained(roadside_mesh, ring, [])
	var touching_neighbour := PackedVector2Array([Vector2(0,100),Vector2(120,100),Vector2(120,200),Vector2(0,200)])
	var touching_mesh := Geometry.build(ring, [], 200, 8, [{"points":touching_neighbour,"bounds":Geometry.polygon_bounds(touching_neighbour)}])
	for wall in touching_mesh.walls:
		for surface in wall.surfaces: _assert_disjoint(surface.points, touching_neighbour)
	var boundary_mesh := Geometry.build(ring, [], 200, 8, [], Rect2(0,0,120,100))
	_assert_contained(boundary_mesh, ring, [])
	# Actual read-only town: map-independent resolver plus creator interactions.
	var real := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio._load_existing_project(real)
	# A user-edited saved map can legitimately show its old stable-ID warning.
	# This read-only renderer check does not save or dismiss it in production.
	studio.message_dialog.hide()
	var raw_features: Array = studio.imported_town.features
	var original_geometry := JSON.stringify(raw_features)
	studio._show_advanced_map_editor_page()
	assert(studio.editor_tools_navigation.pages.size() == 6 and studio.editor_tools_navigation.pages.has("trees"))
	studio.editor_tools_navigation.open_page("heights")
	studio.editor_floor_control.value = 8
	var building: Dictionary = raw_features.filter(func(f): return f.kind == "building")[0]
	studio._on_editor_building_selected(building)
	assert(studio.building_exterior_data.buildings[str(building.id)].total_floors == 8)
	studio._editor_undo()
	assert(not studio.building_exterior_data.buildings.get(str(building.id), {}).has("total_floors"))
	studio._editor_redo()
	assert(studio.building_exterior_data.buildings[str(building.id)].total_floors == 8)
	studio.editor_height_restore = true
	studio._on_editor_building_selected(building)
	assert(not studio.building_exterior_data.buildings.get(str(building.id), {}).has("total_floors"))
	studio._show_building_creator_page()
	studio._on_building_creator_selected(building)
	studio.building_floor_control.value = 4
	assert(studio.building_exterior_data.buildings[str(building.id)].total_floors == 4)
	assert(JSON.stringify(raw_features) == original_geometry)
	var collisions: Dictionary = Builder.new().build(studio.imported_town.features, studio.imported_town.bounds)
	assert(collisions.ok)
	var start_usec := Time.get_ticks_usec()
	var renderer := Renderer.new()
	root.add_child(renderer)
	renderer.setup(raw_features, collisions.data, studio.imported_town.bounds, studio.building_exterior_data, real)
	# Exercise the actual runtime linkage, not a test-only assumption that every
	# painted door is playable. This reads the saved town and does not launch it.
	var entry_runtime = preload("res://scripts/runtime/town_runtime.gd").new()
	entry_runtime.renderer = renderer
	entry_runtime.building_exterior_data = studio.building_exterior_data
	var interiors: Dictionary = preload("res://scripts/interiors/building_interior_store.gd").new().load_from_town(real)
	assert(interiors.ok)
	entry_runtime.building_interior_data = interiors.data
	entry_runtime._build_runtime_interior_entrances(raw_features,renderer.projection,renderer.pixels_per_metre)
	assert(renderer.playable_entrance_keys.size() == entry_runtime.interior_entrances.size())
	assert(renderer.playable_entrance_keys.size() > 0)
	entry_runtime.free()
	print("ALBURY HEIGHT GEOMETRY: %d buildings prepared in %.2f ms" % [renderer.building_height_meshes.size(), (Time.get_ticks_usec()-start_usec)/1000.0])
	print("DETAIL CACHE: ",renderer.building_detail_timings)
	assert(renderer.building_height_meshes[str(building.id)].total_floors == 4)
	var clearance := Clearance.new()
	for candidate in renderer.ground_buildings:
		for piece in Geometry.Pieces.pieces(candidate.outer, candidate.holes): clearance.add_polygon(piece, str(candidate.id))
	for path in renderer.road_paths: clearance.add_path(path, renderer.pixels_per_metre)
	for path in renderer.sidewalk_paths: clearance.add_path(path, renderer.pixels_per_metre)
	for area in renderer.parking_areas:
		for piece in area.pieces: clearance.add_polygon(piece)
	for area in renderer.water_areas:
		for piece in Geometry.Pieces.pieces(area.outer, area.holes): clearance.add_polygon(piece)
	var high_rise_count := 0
	for actual in renderer.ground_buildings:
		if not renderer.building_height_meshes.has(str(actual.id)): continue
		var actual_mesh: Dictionary = renderer.building_height_meshes[str(actual.id)]
		audit_building_id = str(actual.id)
		_assert_contained(actual_mesh, actual.outer, actual.holes)
		var nearby := clearance.query(actual_mesh.visual_bounds, str(actual.id))
		for wall in actual_mesh.walls:
			for surface in wall.surfaces:
				for point in surface.points: assert(renderer.world_bounds.grow(0.001).has_point(point))
				for obstacle in nearby: _assert_disjoint(surface.points, obstacle.points)
		if actual_mesh.total_floors >= 20: high_rise_count += 1
	var drawn_doors := 0
	assert(not renderer.building_door_art["601183200:0"].surfaces.is_empty(), "The saved pub's camera-facing door must be visible on its facade.")
	var pub_door_bounds := Rect2()
	for surface in renderer.building_door_art["601183200:0"].surfaces:
		var surface_bounds := Geometry.polygon_bounds(surface.points)
		pub_door_bounds = pub_door_bounds.merge(surface_bounds) if pub_door_bounds.has_area() else surface_bounds
	assert(pub_door_bounds.size.y >= DoorArt.ActorArt.GROUND_CHARACTER_DRAW_SIZE.y*1.1, "The actual saved pub doorway must not shrink to a sticker smaller than the player.")
	print("PUB DOOR SCALE: %.2f world units high; character %.2f. No roof overlap." % [pub_door_bounds.size.y,DoorArt.ActorArt.GROUND_CHARACTER_DRAW_SIZE.y])
	for key in renderer.building_door_art:
		var artwork: Dictionary = renderer.building_door_art[key]
		var feature_id: String = key.rsplit(":",true,1)[0]
		var own_mesh: Dictionary = renderer.building_height_meshes[feature_id]
		for surface in artwork.surfaces:
			drawn_doors += 1
			for roof in own_mesh.roof: _assert_disjoint(surface.points, roof)
			for blocker in clearance.query(Geometry.polygon_bounds(surface.points), feature_id): _assert_disjoint(surface.points, blocker.points)
	assert(drawn_doors > 0, "At least one saved Albury facade door must remain visible.")
	_verify_surface_details(renderer)
	_verify_automatic_door_fixtures()
	if audit_failures > 0:
		push_error("ROOF/CLEARANCE FAILED: %d invalid polygons" % audit_failures)
		quit(1)
		return
	print("ROOF/CLEARANCE: audited all Albury roofs and exterior facades against own roof, neighbours, roads, paths, parking, water and map bounds; %d saved 20+ floor buildings. Door anchors unchanged." % high_rise_count)
	assert(JSON.stringify(raw_features) == original_geometry)
	if OS.get_cmdline_user_args().has("--render"):
		renderer.hide()
		studio._show_advanced_map_editor_page()
		studio.editor_tools_navigation.open_page("heights")
		await process_frame
		studio.message_dialog.hide()
		await process_frame
		assert(not studio.message_dialog.visible,"The renderer capture must not have a modal over it.")
		# Capture-only: remove the embedded popup after exercising editor loading.
		# Hiding the Studio itself does not hide its child Window. Production
		# warnings and the user's saved corrections are deliberately unchanged.
		studio.message_dialog.free()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_height_editor.png"))
		studio.hide()
		renderer.hide()
		await _render_albury(studio, renderer)
		await _render_demo()
		await _render_shared_wall_demo()
	studio.queue_free()
	renderer.queue_free()
	await process_frame
	print("BUILDING HEIGHTS PASSED: OSM/default/override, safe persistence/custom walls, courtyard geometry, tool hub click/undo/redo/restore, Building Creator and unchanged source geometry. User town files untouched.")
	quit()

func _assert_front_join(mesh: Dictionary, point: Vector2) -> void:
	for roof in mesh.roof:
		if Geometry2D.is_point_in_polygon(point,roof):
			audit_failures+=1
			push_error("Roof fill obscures the shared front corner at %s." % point)
		assert(not Geometry2D.is_point_in_polygon(point,roof), "A hidden side must not leave a roof-coloured wedge in the front facade.")
	var covered := false
	for wall in mesh.walls:
		if wall.outward.x < -absf(wall.outward.y): continue
		for surface in wall.surfaces:
			if Geometry2D.is_point_in_polygon(point,surface.points): covered = true
	if not covered:
		audit_failures+=1
		push_error("The adjoining front facade must fill the shared corner at %s." % point)
	assert(covered, "The adjoining front facade must fill the shared corner.")

func _left_wall_area(mesh: Dictionary) -> float:
	var area := 0.0
	for wall in mesh.walls:
		if absf(wall.a.x) > 0.01 or absf(wall.b.x) > 0.01: continue
		for surface in wall.surfaces: area += _area(surface.points)
	return area

func _assert_contained(mesh: Dictionary, outer: PackedVector2Array, holes: Array) -> void:
	for roof in mesh.roof: _assert_polygon_inside(roof, outer, holes)
	assert(Geometry._pieces_area(mesh.roof) >= Geometry._pieces_area(mesh.ground)*0.40, "Projected roof lost too much usable area.")
	for wall in mesh.walls:
		for surface in wall.surfaces:
			_assert_polygon_inside(surface.points, outer, holes)
			for roof in mesh.roof: _assert_disjoint(surface.points, roof)
			assert(surface.points.size() == surface.uvs.size())

func _assert_disjoint(first: PackedVector2Array, second: PackedVector2Array) -> void:
	if not Geometry.polygon_bounds(first).intersects(Geometry.polygon_bounds(second), true): return
	for overlap in Geometry2D.intersect_polygons(first, second):
		if _area(overlap) >= 0.1:
			audit_failures += 1
			if audit_failures <= 6: print("OVERLAP ", audit_building_id, " area=", _area(overlap), " first=", first, " second=", second)

func _assert_polygon_inside(polygon: PackedVector2Array, outer: PackedVector2Array, holes: Array) -> void:
	# Boolean-area checks catch an edge across a concavity, not just outside vertices.
	for outside in Geometry2D.clip_polygons(polygon, outer):
		if _area(outside) >= 0.1:
			audit_failures += 1
			if audit_failures <= 6: print("OUTSIDE AREA ", audit_building_id, " area=", _area(outside), " polygon=", outside)
	for hole in holes:
		for overlap in Geometry2D.intersect_polygons(polygon, hole):
			if _area(overlap) >= 0.1:
				audit_failures += 1
				if audit_failures <= 6: print("COURTYARD AREA ", audit_building_id, " area=", _area(overlap), " polygon=", overlap)

func _area(polygon: PackedVector2Array) -> float:
	return Geometry.polygon_area(polygon)

func _verify_surface_details(renderer) -> void:
	var front_mesh := Geometry.build(Details.rectangle(Rect2(0,0,240,360)),[],4,8.0)
	var front_unit := Details.roof_equipment(front_mesh,8.0)
	assert(front_unit.has_area() and front_unit.get_center().y > front_mesh.roof_bounds.get_center().y,"Cooling equipment should favour the visible front roof edge.")
	var equipment_count := 0
	var generated_count := 0
	var visible_generated := 0
	var unresolved_count := 0
	for id in renderer.building_roof_equipment:
		var placed: Rect2 = renderer.building_roof_equipment[id]
		if not placed.has_area(): continue
		equipment_count += 1
		assert(placed.size.is_equal_approx(Vector2(1.8,2.0)*renderer.pixels_per_metre))
		var remainder: Array[PackedVector2Array] = [Details.rectangle(placed.grow(renderer.pixels_per_metre*0.3))]
		for roof in renderer.building_height_meshes[id].roof: remainder = Geometry.subtract_polygon(remainder,roof)
		assert(Geometry._pieces_area(remainder) < 0.01,"Roof equipment or its safety margin crosses the visible roof boundary.")
	for id in renderer.building_detail_doors:
		var mesh: Dictionary = renderer.building_height_meshes[id]
		var blanks: Array[PackedVector2Array] = []
		for wall in mesh.walls:
			for bay in wall.get("blank_bays",[]): blanks.append(bay.points)
		for door in renderer.building_detail_doors[id]:
			for surface in door.surfaces:
				for roof in mesh.roof: _assert_disjoint(surface.points,roof)
				var uncovered: Array[PackedVector2Array] = [surface.points]
				for blank in blanks: uncovered = Geometry.subtract_polygon(uncovered,blank)
				assert(Geometry._pieces_area(uncovered) < 0.1,"A door has window material behind it.")
	for id in renderer.automatic_door_status:
		var automatic: Dictionary = renderer.automatic_door_status[id]
		if automatic.is_empty(): unresolved_count += 1; continue
		generated_count += 1
		assert(renderer.building_detail_doors[id].size() == 1)
		assert(automatic.source == "generated_visual_only")
		if not renderer._entrance_route_clear(automatic.outside,automatic.route):
			audit_failures+=1
			push_error("Generated door approach blocked for building %s." % id)
		assert(renderer._entrance_route_clear(automatic.outside,automatic.route))
		if not renderer.building_detail_doors[id][0].surfaces.is_empty(): visible_generated += 1
	print("SURFACE DETAILS: %d complete roof units; %d generated doors (%d camera-visible); %d unresolved/no clear nearby route. All drawn doors have blank bays and no roof overlap." % [equipment_count,generated_count,visible_generated,unresolved_count])
	# Courtyard, narrow roofs and far-from-origin positions must not clip props.
	for ring in [PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(12,200),Vector2(0,200)]),PackedVector2Array([Vector2(0,0),Vector2(160,0),Vector2(160,180),Vector2(0,180)])]:
		var holes: Array = []
		if ring[1].x > 100: holes = [PackedVector2Array([Vector2(30,20),Vector2(130,20),Vector2(130,150),Vector2(30,150)])]
		var mesh := Geometry.build(ring,holes,4,8.0)
		var unit := Details.roof_equipment(mesh,8.0)
		if ring[1].x < 20: assert(not unit.has_area(),"Tiny roof must omit equipment rather than shrink/crop it.")
		if unit.has_area():
			var remainder: Array[PackedVector2Array] = [Details.rectangle(unit.grow(2.4))]
			for roof in mesh.roof: remainder = Geometry.subtract_polygon(remainder,roof)
			assert(Geometry._pieces_area(remainder)<0.01,"Equipment test remainder: %s / %s" % [Geometry._pieces_area(remainder),unit])

func _verify_automatic_door_fixtures() -> void:
	var arrow_start := Renderer.entrance_arrow_points(Vector2.ZERO,Vector2.UP,8.0,0.0)
	var arrow_forward := Renderer.entrance_arrow_points(Vector2.ZERO,Vector2.UP,8.0,0.7)
	assert(arrow_start[0].y > arrow_forward[0].y and arrow_forward[0].is_zero_approx())
	assert(Geometry.polygon_bounds(arrow_start).size.x > 7.5,"Usable entry marker should be wider than the walking character.")
	var demo := Renderer.new()
	demo.pixels_per_metre = 8.0
	var ring := PackedVector2Array([Vector2(0,0),Vector2(120,0),Vector2(120,100),Vector2(0,100)])
	var building := {"id":"fixture","bounds":Rect2(0,0,120,100),"outer":ring,"holes":[]}
	demo.ground_buildings.append(building)
	demo._index_ground_building(0)
	var mesh := Geometry.build(ring,[],4,8.0)
	for path in [PackedVector2Array([Vector2(-40,150),Vector2(160,150)]),PackedVector2Array([Vector2(-40,-50),Vector2(160,-50)]),PackedVector2Array([Vector2(-50,-40),Vector2(-50,140)]),PackedVector2Array([Vector2(170,-40),Vector2(170,140)])]:
		demo.road_paths.assign([{"points":path,"walkway":true}])
		demo._cache_entrance_routes()
		var entry: Dictionary = demo._automatic_building_door(building,mesh)
		assert(not entry.is_empty(),"Every exposed road-facing side should be eligible, not just camera-facing fronts.")
		assert(entry.point.direction_to(entry.outside).dot(entry.point.direction_to(entry.route))>0.9)
	demo.road_paths.assign([{"points":PackedVector2Array([Vector2(0,150),Vector2(120,150)]),"bridge":true}])
	demo._cache_entrance_routes()
	assert(demo._automatic_building_door(building,mesh).is_empty(),"An elevated bridge is not an entrance approach.")
	demo.road_paths.clear()
	demo._cache_entrance_routes()
	assert(demo._automatic_building_door(building,mesh).is_empty(),"Missing roads must not invent a verified entrance.")
	var thin_blocker := {"bounds":Rect2(-10,124,150,0.2),"outer":Details.rectangle(Rect2(-10,124,150,0.2)),"holes":[]}
	demo.ground_buildings.append(thin_blocker)
	demo._index_ground_building(1)
	assert(not demo._entrance_route_clear(Vector2(60,104),Vector2(60,150)),"A thin building obstruction must not be skipped by route sampling.")
	demo.ground_buildings.pop_back()
	demo.ground_building_cells.clear()
	demo._index_ground_building(0)
	demo.water_areas.append({"outer":thin_blocker.outer,"holes":[]})
	assert(not demo._entrance_route_clear(Vector2(60,104),Vector2(60,150)),"A narrow water channel must block a generated approach.")
	demo.free()

func _render_albury(studio, renderer: Node2D) -> void:
	# In-memory height preview on the user's actual map; never save test overrides.
	var town: Dictionary = studio.project_loader.load_project(ProjectSettings.globalize_path("res://../Test Maps/albury/albury")).town
	var vehicle_point := TownProjectionScript.geographic_to_world(TownProjectionScript.value_to_location(town.starting_location.vehicle), renderer.projection, renderer.pixels_per_metre)
	var player_point := TownProjectionScript.geographic_to_world(TownProjectionScript.value_to_location(town.starting_location), renderer.projection, renderer.pixels_per_metre)
	var nearest: Dictionary = {}
	var distance := INF
	for building in renderer.ground_buildings:
		if str(building.kind) != "building": continue
		var candidate: float = vehicle_point.distance_to(building.bounds.get_center())
		if candidate < distance:
			distance = candidate
			nearest = building
	# Reproduce the user-reported saved 20-floor building rather than a low-rise proxy.
	for building in renderer.ground_buildings:
		if str(building.id) == "601183203": nearest = building; break
	var id := str(nearest.id)
	assert(renderer.building_height_meshes[id].total_floors == 20)
	var framing: Rect2 = nearest.bounds.grow(renderer.pixels_per_metre * 12.0)
	framing = framing.expand(vehicle_point).expand(player_point)
	var centre: Vector2 = framing.get_center()
	var zoom := minf(1.5, minf(1200.0/framing.size.x, 680.0/framing.size.y))
	var group := Node2D.new()
	group.scale = Vector2.ONE * zoom
	group.position = Vector2(640,360) - centre * zoom
	root.add_child(group)
	renderer.reparent(group, false)
	renderer.position = Vector2.ZERO
	renderer.scale = Vector2.ONE
	renderer.draw_view_bounds = Rect2(centre-Vector2(640,360)/zoom,Vector2(1280,720)/zoom).grow(270)
	renderer.show()
	renderer.queue_redraw()
	var wagon := Vehicle.new()
	wagon.position = vehicle_point
	wagon.rotation = deg_to_rad(float(town.starting_location.vehicle.get("rotation_degrees",0)))
	wagon.controls_enabled = false
	group.add_child(wagon)
	var actor := Player.new()
	actor.position = player_point
	actor.controls_enabled = false
	group.add_child(actor)
	var caption := Label.new()
	caption.text = "ALBURY • FITTED SOLID BUILDINGS • SAVED 20 FLOORS / VISUAL CAP 10\nConsistent roof/base corners. Actual map / production actors; town unchanged."
	caption.position = Vector2(24,20)
	root.add_child(caption)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_height_albury.png"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_solid_geometry_albury.png"))
	# Actual pub entrance: close view of the new door and existing character.
	var pub_door: Dictionary = renderer.building_exterior_data.buildings["601183200"].doors[0]
	var door_point := TownProjectionScript.geographic_to_world(TownProjectionScript.value_to_location(pub_door), renderer.projection, renderer.pixels_per_metre)
	var previous_window_size := root.size
	var previous_content_size := root.content_scale_size
	root.size = Vector2i(640,480)
	root.content_scale_size = Vector2i(640,480)
	group.scale = Vector2.ONE * 6.0
	group.position = Vector2(320,220) - door_point * 6.0
	var outside_point := TownProjectionScript.geographic_to_world(Vector2(float(pub_door.outside_longitude), float(pub_door.outside_latitude)), renderer.projection, renderer.pixels_per_metre)
	actor.position = door_point + door_point.direction_to(outside_point) * 24 + Vector2(12,0)
	wagon.hide()
	renderer.draw_view_bounds = Rect2(door_point-Vector2(640,480)/6.0,Vector2(1280,960)/6.0)
	renderer.queue_redraw()
	caption.text = "ALBURY PUB • ACTUAL SAVED ENTRANCE\nFrame / glazing / panels / handle / threshold"
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_exterior_door.png"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_solid_geometry_pub_door.png"))
	# Two real engine frames show the enlarged marker travelling toward the door.
	renderer.entrance_indicators.set_process(false)
	for frame in 2:
		renderer.entrance_indicators.pointing_time = frame*0.7
		renderer.entrance_indicators.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_entry_arrow_%d.png" % frame))
	renderer.entrance_indicators.set_process(true)
	# Inspect a nearby narrow, angled real footprint, not just a square fixture.
	var narrow: Dictionary = {}
	var nearest_narrow := INF
	for candidate in renderer.ground_buildings:
		var equipment: Rect2 = renderer.building_roof_equipment.get(str(candidate.id),Rect2())
		if not equipment.has_area(): continue
		var size: Vector2 = candidate.bounds.size
		if maxf(size.x,size.y)/maxf(1.0,minf(size.x,size.y)) < 2.5: continue
		var roof_distance: float = candidate.bounds.get_center().distance_to(door_point)
		if roof_distance < nearest_narrow: nearest_narrow = roof_distance; narrow = candidate
	assert(not narrow.is_empty())
	root.size = Vector2i(960,640)
	root.content_scale_size = Vector2i(960,640)
	var roof_focus: Rect2 = narrow.bounds.grow(renderer.pixels_per_metre*4.0)
	var roof_zoom := minf(3.5,minf(800.0/roof_focus.size.x,500.0/roof_focus.size.y))
	group.scale = Vector2.ONE*roof_zoom
	group.position = Vector2(480,355)-roof_focus.get_center()*roof_zoom
	renderer.draw_view_bounds = Rect2(roof_focus.get_center()-Vector2(480,320)/roof_zoom,Vector2(960,640)/roof_zoom)
	renderer.queue_redraw()
	var auto_door: Dictionary = renderer.automatic_door_status.get(str(narrow.id),{})
	actor.position = auto_door.get("outside",roof_focus.position)
	caption.text = "ALBURY • NARROW OSM FOOTPRINT %s\nFront-edge cooling units • complete artwork with roof clearance" % str(narrow.id)
	print("ROOF DETAIL CAPTURE: actual Albury building ",narrow.id)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_roof_equipment_albury.png"))
	root.size = previous_window_size
	root.content_scale_size = previous_content_size
	renderer.reparent(root, false)
	renderer.hide()
	group.queue_free()
	caption.queue_free()
	await process_frame

func _render_demo() -> void:
	# Actual renderer fixture: explicit test heights, not a real-town survey.
	var features: Array = []
	var designs: Dictionary = Store.new().empty_data()
	for index in 3:
		var x := 146.901 + float(index) * 0.00045
		var id := str(index + 1)
		features.append({"id":id,"kind":"building","tags":{"building":"yes","building:levels":str([1,4,20][index])},"points":[[x,-36.001],[x+0.00025,-36.001],[x+0.00025,-36.00075],[x,-36.00075],[x,-36.001]],"holes":[]})
		designs = Profile.set_style(designs,id,["brick","rendered","tall"][index])
		features.append({"id":"neighbour_"+id,"kind":"building","tags":{"building":"yes"},"points":[[x,-36.00064],[x+0.00025,-36.00064],[x+0.00025,-36.00053],[x,-36.00053],[x,-36.00064]],"holes":[]})
	features.append({"id":"road","kind":"road","tags":{"highway":"residential"},"points":[[146.9005,-36.0011],[146.9027,-36.0011]],"holes":[]})
	features.append({"id":"rear_road","kind":"road","tags":{"highway":"residential"},"points":[[146.9005,-36.000695],[146.9027,-36.000695]],"holes":[]})
	var bounds := {"west":146.9005,"east":146.9027,"north":-36.0005,"south":-36.0015}
	var collision: Dictionary = Builder.new().build(features,bounds)
	assert(collision.ok)
	var demo := Renderer.new()
	root.add_child(demo)
	demo.setup(features,collision.data,bounds,designs,"")
	demo.scale = Vector2(0.6,0.6)
	demo.position = Vector2(70,180) - demo.world_bounds.position * 0.6
	var caption := Label.new()
	caption.text = "v1.6 SOLID BUILDING TEST • 1 / 4 / 20 SAVED FLOORS • VISUAL CAP 10\nMatching roof/base shapes and parallel rising corners. Not a surveyed town scene."
	caption.position=Vector2(32,20)
	root.add_child(caption)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_height_visuals.png"))
	demo.queue_free()
	caption.queue_free()

func _render_shared_wall_demo() -> void:
	var features: Array = []
	var designs: Dictionary = Store.new().empty_data()
	for index in 3:
		var x := 146.901+float(index)*0.0008
		for side in 2:
			var left := x+side*0.00025+(0.00004 if index == 2 and side == 1 else 0.0)
			var id := "attached_%d_%d" % [index,side]
			var floors: int = ([2,6][side] if index == 1 else 4)
			features.append({"id":id,"kind":"building","tags":{"building":"yes","building:levels":str(floors)},"points":[[left,-36.001],[left+0.00025,-36.001],[left+0.00025,-36.00075],[left,-36.00075],[left,-36.001]],"holes":[]})
			designs = Profile.set_style(designs,id,"brick" if side == 0 else "rendered")
	features.append({"id":"front_road","kind":"road","tags":{"highway":"residential"},"points":[[146.9007,-36.00115],[146.9034,-36.00115]],"holes":[]})
	var bounds := {"west":146.9007,"east":146.9034,"north":-36.0006,"south":-36.0015}
	var collision: Dictionary = Builder.new().build(features,bounds)
	assert(collision.ok)
	var demo := Renderer.new()
	root.add_child(demo)
	demo.setup(features,collision.data,bounds,designs,"")
	demo.scale = Vector2.ONE*0.62
	demo.position = Vector2(22,170)-demo.world_bounds.position*0.62
	var caption := Label.new()
	caption.text = "SHARED-WALL RENDERER TEST • NOT A REAL TOWN\nEqual height: shared side hidden     |     2 beside 6 floors: upper side visible     |     Real gap: full side visible"
	caption.position = Vector2(24,28)
	root.add_child(caption)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_shared_walls.png"))
	# A closer engine capture makes the reported front seam easy to inspect.
	var previous_window_size := root.size
	var previous_content_size := root.content_scale_size
	root.size = Vector2i(640,480)
	root.content_scale_size = Vector2i(640,480)
	var focus: Rect2 = demo.building_height_meshes["attached_0_0"].visual_bounds.merge(demo.building_height_meshes["attached_0_1"].visual_bounds)
	demo.scale = Vector2.ONE*1.35
	demo.position = Vector2(320,260)-focus.get_center()*1.35
	caption.text = "ATTACHED-BUILDING JOIN • ENGINE TEST\nFront facades meet without a grey roof wedge"
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_shared_wall_join.png"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_solid_geometry_join.png"))
	root.size = previous_window_size
	root.content_scale_size = previous_content_size
	demo.queue_free()
	caption.queue_free()
