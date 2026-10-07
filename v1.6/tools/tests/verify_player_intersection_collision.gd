extends SceneTree

const RendererScript = preload("res://scripts/runtime/runtime_world_renderer.gd")
const VehicleScript = preload("res://scripts/runtime/runtime_player_vehicle.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var renderer = RendererScript.new()
	renderer.world_bounds = Rect2(-200.0, -200.0, 400.0, 400.0)
	var vertical := _road_segment(0, Vector2(0.0, -120.0), Vector2(0.0, 120.0), 16.0)
	var horizontal := _road_segment(1, Vector2(-120.0, 0.0), Vector2(120.0, 0.0), 16.0)
	for segment in [vertical, horizontal]:
		renderer.road_segments.append(segment)
		renderer._index_drivable_road_segment(segment)

	var car_half_size := Vector2(8.5, 20.0)
	assert(renderer.is_vehicle_pose_on_surface_road(Vector2.ZERO, 0.0, car_half_size), "A wagon aligned through the intersection was not recognised as road-contained.")
	assert(renderer.is_vehicle_pose_on_surface_road(Vector2.ZERO, PI * 0.25, car_half_size), "The union of crossing road arms did not contain a turning wagon.")
	assert(not renderer.is_vehicle_pose_on_surface_road(Vector2(24.0, 28.0), 0.0, car_half_size), "A wagon leaving the road was incorrectly classified as road-contained.")
	var bridge := _road_segment(2, Vector2(-120.0, 60.0), Vector2(120.0, 60.0), 20.0)
	bridge.bridge = true
	assert(not renderer.is_vehicle_pose_on_surface_road(Vector2(70.0, 60.0), PI * 0.5, car_half_size), "An elevated bridge was incorrectly admitted as an ordinary surface-road waiver.")

	var building := StaticBody2D.new()
	building.collision_layer = 1
	building.collision_mask = 0
	var building_shape := RectangleShape2D.new()
	building_shape.size = Vector2(13.0, 10.0)
	var building_hit := CollisionShape2D.new()
	building_hit.shape = building_shape
	building.add_child(building_hit)
	building.position = Vector2(12.0, 0.0)
	get_root().add_child(building)

	var vehicle = VehicleScript.new()
	get_root().add_child(vehicle)
	vehicle.set_drivable_pose_check(renderer.is_vehicle_pose_on_surface_road)
	vehicle.position = Vector2.ZERO
	await physics_frame
	assert(vehicle._can_rotate_to(PI * 0.25), "A road-contained intersection turn was still blocked by the conflicting footprint edge.")
	vehicle.position = Vector2(0.0, 30.0)
	await physics_frame
	var through_intersection := Vector2(0.0, -60.0)
	vehicle.collision_mask = vehicle._collision_mask_for_motion(vehicle.position, vehicle.position + through_intersection, 0.0)
	assert(vehicle.collision_mask == (2 | 64), "A fully road-contained movement must waive only buildings, retaining trunks.")
	assert(vehicle.move_and_collide(through_intersection) == null, "The wagon still struck an OSM building edge inside the visible intersection.")

	building.position = Vector2(34.0, 0.0)
	vehicle.position = Vector2(34.0, 30.0)
	vehicle.rotation = 0.0
	await physics_frame
	var toward_offroad_building := Vector2(0.0, -30.0)
	vehicle.collision_mask = vehicle._collision_mask_for_motion(vehicle.position, vehicle.position + toward_offroad_building, 0.0)
	assert(vehicle.collision_mask == (1 | 2 | 64), "Leaving the visible road incorrectly disabled building/trunk collisions.")
	assert(vehicle.move_and_collide(toward_offroad_building) != null, "The ordinary off-road building collision was weakened.")

	print("PLAYER INTERSECTION COLLISION PASSED: road-union turns and conflicting OSM edges are clear while off-road buildings remain solid.")
	vehicle.queue_free()
	building.queue_free()
	renderer.free()
	await process_frame
	quit(0)


func _road_segment(identifier: int, start: Vector2, finish: Vector2, half_width: float) -> Dictionary:
	return {
		"segment_id": identifier,
		"path_index": identifier,
		"path_id": str(identifier),
		"a": start,
		"b": finish,
		"half_width": half_width,
		"name": "TEST ROAD",
		"walkway": false,
		"bridge": false,
		"tunnel": false,
		"layer": 0
	}
