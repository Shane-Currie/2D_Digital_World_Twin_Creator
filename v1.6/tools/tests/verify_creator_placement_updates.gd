extends SceneTree

const Canvas = preload("res://scripts/towns/map_canvas.gd")
const FloorCanvas = preload("res://scripts/interiors/interior_floor_canvas.gd")
const Importer = preload("res://scripts/towns/osm_importer.gd")
const ExteriorStore = preload("res://scripts/buildings/building_exterior_store.gd")
const InteriorStore = preload("res://scripts/interiors/building_interior_store.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")
const CollisionRuntime = preload("res://scripts/collisions/building_collision_runtime.gd")
const Vehicle = preload("res://scripts/runtime/runtime_player_vehicle.gd")
const ActorCollision = preload("res://scripts/runtime/traffic/runtime_actor_collision.gd")
const CrossingSafety = preload("res://scripts/runtime/pedestrians/runtime_crossing_safety.gd")
const TownRuntime = preload("res://scripts/runtime/town_runtime.gd")

func _initialize() -> void:
	call_deferred("_run")

func _button(button: int, pressed: bool, point: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	return event

func _motion(point: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	return event

func _run() -> void:
	var imported := Importer.new().parse_files(["res://tools/tests/fixtures/tiny_town.osm"])
	assert(imported.ok)
	var map = Canvas.new()
	root.add_child(map)
	map.size = Vector2(700, 500)
	map.set_map_data(imported)
	map._set_start_from_screen(map._geographic_to_screen(Vector2(146.007, -36.0035)))
	assert(not map.start_location.is_empty())
	map.set_edit_mode(Canvas.EditMode.SET_VEHICLE_START)
	var car_point := map._geographic_to_screen(Vector2(float(map.start_location.vehicle.longitude), float(map.start_location.vehicle.latitude)))
	map._gui_input(_button(MOUSE_BUTTON_RIGHT, true, car_point))
	map._gui_input(_button(MOUSE_BUTTON_RIGHT, false, car_point))
	assert(map.start_location.vehicle.rotation_degrees == 15.0)
	map._gui_input(_button(MOUSE_BUTTON_RIGHT, true, car_point))
	map._gui_input(_motion(car_point + Vector2(60, 0), Vector2(60, 0)))
	map._gui_input(_button(MOUSE_BUTTON_RIGHT, false, car_point + Vector2(60, 0)))
	assert(map.start_location.vehicle.rotation_degrees == 45.0)
	var moved_car := Vector2(float(map.start_location.vehicle.longitude) + 0.0001, float(map.start_location.vehicle.latitude))
	var moved_screen := map._geographic_to_screen(moved_car)
	map._gui_input(_button(MOUSE_BUTTON_LEFT, true, moved_screen))
	map._gui_input(_button(MOUSE_BUTTON_LEFT, false, moved_screen))
	assert(is_equal_approx(float(map.start_location.vehicle.longitude), moved_car.x) and map.start_location.vehicle.rotation_degrees == 45.0, "A safe car-start click did not persist its position and direction.")
	var original_start: Dictionary = map.start_location.duplicate(true)
	var building: Dictionary = imported.features.filter(func(f): return f.kind == "building")[0]
	var centre := Vector2.ZERO
	for i in 4: centre += Vector2(building.points[i]) / 4.0
	map._apply_map_click(map._geographic_to_screen(centre))
	assert(map.start_location == original_start, "Rejected car placement destroyed the safe saved start.")
	map.set_edit_mode(Canvas.EditMode.INSPECT)
	map.zoom_in()
	var before: Vector2 = map.view_center_ratio
	map._gui_input(_button(MOUSE_BUTTON_LEFT, true, Vector2(350, 250)))
	map._gui_input(_motion(Vector2(380, 270), Vector2(30, 20)))
	map._gui_input(_button(MOUSE_BUTTON_LEFT, false, Vector2(380, 270)))
	assert(map.view_center_ratio != before and map.selected_building_id.is_empty(), "Left-drag selected a footprint instead of panning.")
	var exterior = ExteriorStore.new()
	var named := exterior.set_custom_name(exterior.empty_data(), str(building.id), "My Test Building")
	assert(named.ok and exterior.validate(named.data).ok)
	assert(not exterior.set_custom_name(named.data, str(building.id), "Bad\nName").ok)
	map.set_building_exterior_data(named.data, "")
	map._show_osm_building_hover(building, Vector2(300, 200))
	assert(map.osm_hover_label.text.contains("Creator name: My Test Building") and map.osm_hover_label.text.contains("Name: Fixture House"))

	var store = InteriorStore.new()
	var data := store.empty_data()
	data.buildings.test = {"feature_id": "test", "floors": [{"id": "ground_floor", "width_metres": 20.0, "height_metres": 20.0, "boundary_metres": [[0,0],[20,0],[20,20],[0,20]], "holes_metres": [], "entry_links": [], "walls": [], "furniture": []}]}
	var placed := store.place_furniture(data, "test", "ground_floor", "sofa", Vector2(10,10), 0.0)
	assert(placed.ok)
	var rotated := store.rotate_furniture(placed.data, "test", "ground_floor", placed.furniture_id, 45.0)
	assert(rotated.ok and rotated.data.buildings.test.floors[0].furniture[0].rotation_degrees == 45.0)
	var near_wall := store.place_furniture(data, "test", "ground_floor", "sofa", Vector2(1.5,0.55), 0.0)
	assert(near_wall.ok)
	assert(not store.rotate_furniture(near_wall.data, "test", "ground_floor", near_wall.furniture_id, 90.0).ok, "Rotation through the wall was accepted.")
	var floor = FloorCanvas.new()
	root.add_child(floor)
	floor.size = Vector2(700,500)
	floor.set_floor(rotated.data.buildings.test.floors[0])
	floor.selected_furniture_id = placed.furniture_id
	var rotation_changes: Array = []
	floor.furniture_rotation_requested.connect(func(id, degrees): rotation_changes.append([id, degrees]))
	floor._gui_input(_button(MOUSE_BUTTON_RIGHT, true, Vector2(350,250)))
	floor._gui_input(_button(MOUSE_BUTTON_RIGHT, false, Vector2(350,250)))
	assert(rotation_changes == [[placed.furniture_id,45.0]])
	floor.zoom_in()
	var floor_before: Vector2 = floor.view_center_ratio
	floor._gui_input(_button(MOUSE_BUTTON_LEFT, true, Vector2(300,180)))
	floor._gui_input(_motion(Vector2(340,200), Vector2(40,20)))
	floor._gui_input(_button(MOUSE_BUTTON_LEFT, false, Vector2(340,200)))
	assert(floor.view_center_ratio != floor_before)
	# Attach the runtime script after the test node is ready so only its input
	# handler runs; this check needs neither town startup nor a local LLM.
	var runtime := Node2D.new()
	root.add_child(runtime)
	runtime.set_script(TownRuntime)
	runtime.set_process(false)
	runtime.set_physics_process(false)
	runtime.set_process_unhandled_input(false)
	runtime.camera = Camera2D.new()
	runtime.add_child(runtime.camera)
	runtime.building_popup = PanelContainer.new()
	runtime.add_child(runtime.building_popup)
	runtime.overview = true
	for interior_id in ["", "test_building"]:
		runtime.inside_building_id = interior_id
		runtime.camera.position = Vector2.ZERO
		runtime._unhandled_input(_button(MOUSE_BUTTON_LEFT, true, Vector2(300,200)))
		runtime._unhandled_input(_motion(Vector2(340,220), Vector2(40,20)))
		runtime._unhandled_input(_button(MOUSE_BUTTON_LEFT, false, Vector2(340,220)))
		assert(runtime.camera.position == Vector2(-40,-20) and not runtime.map_pointer_down, "The playable outdoor/interior map did not pan by left-drag.")
	runtime.queue_free()

	# A reservation can span empty roadway after its walker has moved away.
	# The owned car uses live actor bodies; NPC traffic retains its yielding rule.
	var crossing = CrossingSafety.new()
	crossing.reservations[1] = {"start": Vector2(-80,0), "finish": Vector2(80,0)}
	assert(not crossing.car_may_move(Vector2(0,-50), Vector2(0,50)))
	assert(ActorCollision.vehicle_may_move([], Vector2(0,-50), Vector2(0,50), 0.0, Vector2(8.5,20), {}))
	assert(not ActorCollision.vehicle_may_move([{"kind":"person","position":Vector2.ZERO}], Vector2(0,-50), Vector2(0,50), 0.0, Vector2(8.5,20), {}))
	assert(await _check_dean_street())
	print("CREATOR PLACEMENT UPDATES PASSED: left map drag, right-mouse rotations, safe car starts, separate creator names, blocked furniture rotations, real actor collision and Albury Dean Street geometry.")
	quit(0)

func _check_dean_street() -> bool:
	var path := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var features: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("data/map_features.json")))
	var collisions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("data/building_collisions.json")))
	var town: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("town.json")))
	var renderer = Renderer.new()
	root.add_child(renderer)
	var first_building: Dictionary = features.features.filter(func(f): return f.kind == "building")[0]
	var custom_data := {"buildings": {str(first_building.id): {"feature_id": str(first_building.id), "custom_name": "Dean Street Test Venue"}}}
	renderer.setup(features.features, collisions, town.map_bounds, custom_data)
	renderer.update_street_label_presentation(0.5, 5.0, true)
	var custom_labels: Array = renderer.get_children().filter(func(child): return child.is_in_group("custom_building_labels"))
	assert(custom_labels.size() == 1 and custom_labels[0].text == "Dean Street Test Venue" and custom_labels[0].visible, "The custom building's name was missing from the playable map.")
	renderer.update_street_label_presentation(1.0, 1.0, false)
	assert(not custom_labels[0].visible, "The map building-name label leaked into ordinary gameplay.")
	var collision_layer = CollisionRuntime.new()
	root.add_child(collision_layer)
	assert(collision_layer.setup(collisions).ok)
	var car = Vehicle.new()
	root.add_child(car)
	car.set_drivable_pose_check(renderer.is_vehicle_pose_on_surface_road)
	var samples := 0
	var dean_segments := 0
	var boundary_samples := 0
	for segment in renderer.road_segments:
		if str(segment.name).to_lower() != "dean street" or bool(segment.walkway) or bool(segment.bridge) or bool(segment.tunnel): continue
		dean_segments += 1
		var heading: float = Vector2(segment.a).direction_to(segment.b).angle() + PI * 0.5
		car.rotation = heading
		collision_layer.update_streaming(Vector2(segment.a))
		await physics_frame
		var steps := maxi(1, ceili(Vector2(segment.a).distance_to(segment.b) / 12.0))
		for step in steps:
			var start: Vector2 = Vector2(segment.a).lerp(segment.b, float(step) / steps)
			var finish: Vector2 = Vector2(segment.a).lerp(segment.b, float(step+1) / steps)
			car.position = start
			car.collision_mask = car._collision_mask_for_motion(start, finish, heading)
			assert(car.move_and_collide(finish-start) == null, "Dean Street has a solid footprint barrier at %s" % start)
			if not renderer.world_bounds.grow(-10.0).has_point(finish):
				boundary_samples += 1
			elif not renderer.is_ground_traversable(finish, 10.0):
				printerr("Dean Street ground refusal: position=%s open_water=%s" % [finish, renderer.is_open_water(finish)])
				return false
			samples += 1
	assert(dean_segments > 0 and samples > 20)
	print("ALBURY DEAN STREET: %d segments / %d movement samples clear of fixed footprint and water barriers; %d samples at the import edge excluded from ground audit." % [dean_segments, samples, boundary_samples])
	car.queue_free()
	collision_layer.queue_free()
	renderer.queue_free()
	return true
