extends SceneTree

const Collision = preload("res://scripts/runtime/pedestrians/on_foot_actor_collision.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
const Interior = preload("res://scripts/interiors/runtime_interior_layer.gd")
const Traffic = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAILED: ", message)


func _run() -> void:
	var human := {"kind": "person", "position": Vector2.ZERO}
	var robot := {"kind": "robot", "position": Vector2.ZERO}
	for actor in [human, robot]:
		var gap := 4.0 + (4.5 if actor.kind == "robot" else 3.5)
		var stopped := Collision.resolve_motion([actor], Vector2(-30,0), Vector2(30,0), 4.0, {})
		_expect(stopped.x <= -gap and stopped.x >= -gap - 0.1, "Walking passed through a %s during a large step." % actor.kind)
		var around := Collision.resolve_motion([actor], Vector2(-9,5), Vector2(4,5), 4.0, {})
		_expect(around.y > 5 and around.length() >= gap, "A glancing contact did not slide around the sprite.")
		var escape := Collision.resolve_motion([actor], Vector2(-2,0), Vector2(-12,0), 4.0, {})
		_expect(escape.is_equal_approx(Vector2(-12,0)), "Old overlaps could not be escaped.")
		_expect(Collision.resolve_motion([actor], Vector2(-2,0), Vector2(2,0), 4.0, {}).x <= -2.0, "An old overlap allowed deeper movement.")
	_expect(Collision.resolve_motion([human], Vector2.ZERO, Vector2(10,0), 4.0, {}).x == 10.0, "Exact spawn overlap trapped the player.")
	_expect(Collision.resolve_motion([{"kind":"drone", "position":Vector2.ZERO}], Vector2(-30,0), Vector2(30,0), 4.0, {}).x == 30.0, "An airborne drone blocked walking.")
	for layer in [{"kind":"bridge", "layer":1}, {"kind":"tunnel", "layer":-1}]:
		var separated: Dictionary = human.duplicate()
		separated.route_layer = layer.layer
		separated.route_bridge = layer.kind == "bridge"
		separated.route_tunnel = layer.kind == "tunnel"
		_expect(Collision.resolve_motion([separated], Vector2(-30,0), Vector2(30,0), 4.0, {}).x == 30.0, "An actor on another crossing level blocked walking.")
		_expect(Collision.resolve_motion([separated], Vector2(-30,0), Vector2(30,0), 4.0, layer).x < 0.0, "Same-level bridge/tunnel actors did not collide.")
	for angle in [0.0, 0.7, PI * 0.5, PI]:
		var car := {"kind":"traffic", "position":Vector2(80,80), "angle":angle, "driving_side":"left"}
		var centre := Traffic.visible_vehicle_position(car, car.position)
		var rotation_value: float = float(angle) + PI * 0.5
		var start := centre + Vector2(-30,0).rotated(rotation_value)
		var finish := centre + Vector2(30,0).rotated(rotation_value)
		var result := Collision.resolve_motion([car], start, finish, 4.0, {})
		var local := (result - centre).rotated(-rotation_value)
		_expect(local.x <= -12.5 and local.x > -12.6, "Collision did not follow the car's visible lane centre/angle.")
		# Rounded corners should not act like an oversized square collider.
		var clear_start := centre + Vector2(12.1,22.7).rotated(rotation_value)
		var clear_end := centre + Vector2(12.2,22.7).rotated(rotation_value)
		_expect(Collision.resolve_motion([car], clear_start, clear_end, 4.0, {}).is_equal_approx(clear_end), "Car corner collision is oversized.")
	# Real player movement + population filtering, without town startup or LLM.
	var population := Population.new()
	root.add_child(population)
	population.set_process(false)
	population.visible = false
	population.agents = [human, robot]
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.actor_motion = population.player_on_foot_motion
	player.position = Vector2(-20,0)
	await physics_frame
	for frame in 60: player._move_on_foot(Vector2.RIGHT, 1.0 / 60.0)
	_expect(player.position.x < -8.5 and player.position.x > -8.6, "The walking player was not wired to population collision.")
	for frame in 60: player._move_on_foot(Vector2.RIGHT, 1.0 / 60.0)
	_expect(player.position.x < -8.5, "Repeated WASD-equivalent steps passed through a sprite.")
	for frame in 12: player._move_on_foot(Vector2.LEFT, 1.0 / 60.0)
	_expect(player.position.x < -16.0, "Player could not move away after contact.")
	var storyline := {"kind":"person", "position":Vector2.ZERO, "space":"interior", "building_id":"pub", "floor_id":"ground_floor"}
	var wrong_floor: Dictionary = storyline.duplicate()
	wrong_floor.floor_id = "floor_1"
	var wrong_building: Dictionary = storyline.duplicate()
	wrong_building.building_id = "other_pub"
	population.agents = [wrong_floor, wrong_building, human]
	population.set_active_interior("pub", "ground_floor")
	_expect(population.player_on_foot_motion(Vector2(-20,0), Vector2(20,0), 4.0, {}).x == 20.0, "Outdoor or another building/floor blocked the interior.")
	population.agents.append(storyline)
	player.set_interior_mode(true)
	player.position = Vector2(-20,0)
	for frame in 60: player._move_on_foot(Vector2.RIGHT, 1.0 / 60.0)
	_expect(player.position.x < -7.5 and player.collision_mask == 0, "Interior manual ground checks disabled NPC contact.")
	# Walkers cannot move through a stationary on-foot player, but can leave an
	# old overlap; hidden/in-car players and other crossing layers are excluded.
	player.position = Vector2.ZERO
	population.set_gameplay_obstacles([player])
	population.agents.clear()
	for kind in ["person", "robot"]:
		var walker := {"kind":kind, "position":Vector2(-12,0)}
		_expect(not population._walker_step_clear(walker, Vector2(12,0)), "NPC/NPR walked through the standing player.")
		walker.position = Vector2(-2,0)
		_expect(population._walker_step_clear(walker, Vector2(-12,0)), "A walker could not escape an old player overlap.")
		walker.position = Vector2(-12,0)
		walker.route_bridge = true
		walker.route_layer = 1
		_expect(population._walker_step_clear(walker, Vector2(12,0)), "Walker on a bridge was blocked by a surface player.")
	player.visible = false
	_expect(population._walker_step_clear({"kind":"person", "position":Vector2(-12,0)}, Vector2(12,0)), "Hidden driving player left an invisible foot collider.")
	# Walls/furniture retain their independent ground checks inside a building.
	var interior := Interior.new()
	root.add_child(interior)
	interior.floor_data = {"width_metres":20.0, "height_metres":20.0, "boundary_metres":[[0,0],[20,0],[20,20],[0,20]], "furniture":[{"collision":true,"x_metres":10.0,"y_metres":10.0,"width_metres":2.0,"depth_metres":2.0}], "walls":[], "holes_metres":[]}
	interior.pixels_per_metre = 8.0
	player.visible = true
	player.position = Vector2(58,80)
	player.set_ground_check(interior.is_traversable)
	for frame in 60: player._move_on_foot(Vector2.RIGHT, 1.0 / 60.0)
	_expect(player.position.x >= 58.0 and player.position.x < 68.0, "Adding sprite collision disabled furniture collision.")
	# Read-only canonical storyline data: exercise the same runtime conversion
	# used for the user's pub/other interiors, not just hand-made agent records.
	var town_path := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var npc_path := town_path.path_join("data/storyline_npcs.json")
	if FileAccess.file_exists(npc_path):
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(npc_path))
		var interior_records: Array = saved.npcs.filter(func(npc): return str(npc.get("location", {}).get("space", "")) == "interior")
		population.agents.clear()
		population.set_storyline_npcs({"npcs":interior_records})
		population._add_storyline_npcs({}, 8.0)
		for actor in population.agents:
			population.set_active_interior(str(actor.building_id), str(actor.floor_id))
			var centre := Vector2(actor.position)
			var stopped := population.player_on_foot_motion(centre + Vector2(-20,0), centre + Vector2(20,0), 4.0, {})
			_expect(stopped.x <= centre.x - 7.5, "A saved Albury interior storyline character was not solid.")
		print("READ-ONLY ALBURY INTERIOR ACTORS CHECKED: ", population.agents.size())
	if failures == 0: print("ON-FOOT SPRITE COLLISIONS PASSED: NPC/NPR and angled lane-centred cars, sweeps/slide/overlap escape, real player movement, interior building/floor filtering, reciprocal walking, bridge/tunnel separation, drones/hidden-player exclusion and furniture ground checks.")
	quit(1 if failures else 0)
