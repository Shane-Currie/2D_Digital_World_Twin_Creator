extends SceneTree

const ImporterScript = preload("res://scripts/towns/osm_importer.gd")
const BuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")
const RuntimeScript = preload("res://scripts/collisions/building_collision_runtime.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := ProjectSettings.globalize_path("res://tools/tests/fixtures/tiny_town.osm")
	var imported: Dictionary = ImporterScript.new().parse_files(PackedStringArray([source]))
	assert(imported.ok)
	var builder = BuilderScript.new()
	var built: Dictionary = builder.build(imported.features, imported.bounds)
	assert(built.ok)
	assert(built.data.statistics.collision_buildings == 1)
	assert(built.data.buildings[0].area_square_metres > 30000.0)

	var runtime = RuntimeScript.new()
	get_root().add_child(runtime)
	var setup_result: Dictionary = runtime.setup(built.data)
	assert(setup_result.ok)
	runtime.activate_all_for_testing()
	await physics_frame
	await physics_frame

	var projection: Dictionary = built.data.projection
	var scale: float = built.data.runtime_scale.pixels_per_metre
	var inside := builder.geographic_to_local_metres(Vector2(146.004, -36.005), projection) * scale
	var outside := builder.geographic_to_local_metres(Vector2(146.0028, -36.005), projection) * scale
	var point_query := PhysicsPointQueryParameters2D.new()
	point_query.collision_mask = 1
	point_query.position = inside
	assert(not runtime.get_world_2d().direct_space_state.intersect_point(point_query).is_empty(), "The OSM footprint did not create active collision.")
	point_query.position = outside
	assert(runtime.get_world_2d().direct_space_state.intersect_point(point_query).is_empty(), "Open ground was incorrectly made solid.")

	var player := _moving_body(CircleShape2D.new(), Vector2(8.0, 8.0))
	(player.get_child(0).shape as CircleShape2D).radius = 4.0
	player.position = outside
	get_root().add_child(player)
	await physics_frame
	assert(player.move_and_collide(Vector2(180.0, 0.0)) != null, "A player-sized body crossed the building footprint.")
	player.queue_free()

	var car_shape := RectangleShape2D.new()
	car_shape.size = Vector2(32.0, 16.0)
	var car := _moving_body(car_shape, car_shape.size)
	car.position = outside
	get_root().add_child(car)
	await physics_frame
	assert(car.move_and_collide(Vector2(180.0, 0.0)) != null, "A car-sized body crossed the building footprint.")
	print("BUILDING COLLISION RUNTIME PASSED: exact OSM polygon active, open ground clear, player and car blocked.")
	quit(0)


func _moving_body(shape: Shape2D, _size: Vector2) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	body.add_child(collision_shape)
	return body
