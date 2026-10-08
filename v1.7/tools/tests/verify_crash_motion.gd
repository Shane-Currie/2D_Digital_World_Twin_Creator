extends SceneTree

const Population = preload("res://scripts/runtime/runtime_population.gd")
const Vehicle = preload("res://scripts/runtime/runtime_player_vehicle.gd")
const Motion = preload("res://scripts/runtime/crashes/impact_motion.gd")
const Settings = preload("res://scripts/runtime/crashes/crash_settings.gd")
const Actors = preload("res://scripts/runtime/traffic/runtime_actor_collision.gd")
const Detour = preload("res://scripts/runtime/pedestrians/parked_vehicle_detour.gd")


func _initialize() -> void:
	call_deferred("_run")


func _actor(kind: String, position: Vector2) -> Dictionary:
	return {"kind": kind, "position": position, "target": position + Vector2(0, -150), "node": 0, "target_node": 1,
		"angle": -PI * 0.5, "speed": 12.0, "graph_key": "person" if kind != "traffic" else "traffic",
		"phase": 0.0, "moving": false, "walker_id": 1, "traffic_id": 1, "reserved_node": -1,
		"route_layer": 0, "route_bridge": false, "route_tunnel": false, "route_crossing": false}


func _run() -> void:
	var slow := Motion.impulse_response(Vector2(10.0 / 3.6 * 2.0, 0), Vector2.ZERO, Vector2.RIGHT, 75.0, 2.0)
	var fast := Motion.impulse_response(Vector2(60.0 / 3.6 * 2.0, 0), Vector2.ZERO, Vector2.RIGHT, 75.0, 2.0)
	assert(Vector2(fast.actor_velocity).length() > Vector2(slow.actor_velocity).length() * 5.9, "Higher speed did not increase transferred momentum.")
	var heavy := Motion.impulse_response(Vector2(60.0 / 3.6 * 2.0, 0), Vector2.ZERO, Vector2.RIGHT, 1600.0, 2.0)
	assert(Vector2(heavy.actor_velocity).length() < Vector2(fast.actor_velocity).length(), "A car was pushed as easily as a person.")
	var robot := Motion.impulse_response(Vector2(60.0 / 3.6 * 2.0, 0), Vector2.ZERO, Vector2.RIGHT, Settings.ROBOT_MASS_KG, 2.0)
	assert(Vector2(robot.actor_velocity).length() < Vector2(fast.actor_velocity).length())
	assert(is_zero_approx(float(Motion.impulse_response(Vector2.ZERO, Vector2.ZERO, Vector2.RIGHT, 75.0, 2.0).impulse_ns)))
	assert(is_zero_approx(float(Motion.impulse_response(Vector2.LEFT * 10, Vector2.ZERO, Vector2.RIGHT, 75.0, 2.0).impulse_ns)), "Separating contact created energy.")
	var glancing := Motion.impulse_response(Vector2(30, 0), Vector2.ZERO, Vector2(1,1).normalized(), 75.0, 2.0)
	assert(Vector2(glancing.actor_velocity).y > 0.0 and float(glancing.impulse_ns) < float(fast.impulse_ns))
	var momentum_before := Vector2(30, 0) * Settings.PLAYER_MASS_KG
	var momentum_after := Vector2(glancing.player_velocity) * Settings.PLAYER_MASS_KG + Vector2(glancing.actor_velocity) * 75.0
	assert(momentum_before.distance_to(momentum_after) < 0.01)
	var scaled := Motion.impulse_response(Vector2(30, 0), Vector2.ZERO, Vector2.RIGHT, 75.0, 1.0)
	var double_scale := Motion.impulse_response(Vector2(60, 0), Vector2.ZERO, Vector2.RIGHT, 75.0, 2.0)
	assert(is_equal_approx(float(scaled.impulse_ns), float(double_scale.impulse_ns)), "Map scale changed the physical impulse.")
	var centred_car := Motion.impulse_response(Vector2(30,0), Vector2.ZERO, Vector2.RIGHT, 1600.0, 2.0, Vector2.ZERO, 4000.0)
	var off_centre_car := Motion.impulse_response(Vector2(30,0), Vector2.ZERO, Vector2.RIGHT, 1600.0, 2.0, Vector2(0,1.5), 4000.0)
	var opposite_corner := Motion.impulse_response(Vector2(30,0), Vector2.ZERO, Vector2.RIGHT, 1600.0, 2.0, Vector2(0,-1.5), 4000.0)
	assert(is_zero_approx(float(centred_car.actor_angular_velocity)))
	assert(float(off_centre_car.actor_angular_velocity) < 0.0 and float(opposite_corner.actor_angular_velocity) > 0.0, "Opposite corner hits did not turn the car in opposite directions.")
	assert(float(off_centre_car.impulse_ns) < float(centred_car.impulse_ns), "An off-centre hit did not share impulse with rotation.")
	var kinetic_before := 0.5 * Settings.PLAYER_MASS_KG * pow(30.0 / 2.0, 2.0)
	var kinetic_after := 0.5 * Settings.PLAYER_MASS_KG * Vector2(off_centre_car.player_velocity).length_squared() / 4.0 + 0.5 * 1600.0 * Vector2(off_centre_car.actor_velocity).length_squared() / 4.0 + 0.5 * 4000.0 * pow(float(off_centre_car.actor_angular_velocity), 2.0)
	assert(kinetic_after < kinetic_before, "The collision added energy instead of losing it.")

	var pedestrian := _actor("person", Vector2(0,-45))
	var contact := Actors.first_contact([pedestrian], Vector2.ZERO, Vector2(0,-200), 0.0, Vector2(8.5,20), {})
	assert(not contact.is_empty() and float(contact.fraction) < 0.2, "Swept fast movement missed a person.")
	assert(Vector2(contact.normal).dot(Vector2.UP) > 0.99)
	var far := _actor("robot", Vector2(0,-100))
	var nearest := Actors.first_contact([far, pedestrian], Vector2.ZERO, Vector2(0,-200), 0.0, Vector2(8.5,20), {})
	assert(nearest.agent == pedestrian, "Contact order depends on population order.")
	pedestrian.route_layer = 1
	pedestrian.route_bridge = true
	assert(Actors.first_contact([pedestrian], Vector2.ZERO, Vector2(0,-200), 0.0, Vector2(8.5,20), {}).is_empty())
	pedestrian.route_layer = 0
	pedestrian.route_bridge = false
	assert(Actors.vehicle_may_move([_actor("person", Vector2(0, -18))], Vector2.ZERO, Vector2(0,10), 0.0, Vector2(8.5,20), {}), "Existing overlaps cannot separate.")
	assert(Actors.first_contact([_actor("person", Vector2(0,45))], Vector2.ZERO, Vector2(0,100), 0.0, Vector2(8.5,20), {}).normal.y > 0.99, "Reverse impact points the wrong way.")

	var population := Population.new()
	root.add_child(population)
	population.set_process(false)
	var wagon := Vehicle.new()
	root.add_child(wagon)
	wagon.set_physics_process(false)
	population.set_gameplay_obstacles([Node2D.new(), wagon])
	wagon.actor_check = population.player_vehicle_may_move
	wagon.actor_contact_check = population.player_vehicle_contact
	wagon.actor_impact = population.apply_player_impact
	population.agents.append(pedestrian)
	wagon.occupied = true
	wagon.speed = 60.0 / 3.6 * 2.0
	wagon.target_speed_kmh = 60.0
	await physics_frame
	wagon._physics_process(1.0)
	assert(pedestrian.has("impact_velocity") and Vector2(pedestrian.impact_velocity).y < 0.0, "Actual wagon movement did not apply a shove.")
	assert(wagon.target_speed_kmh == 0.0 and wagon.speed > 0.0, "Impact did not cancel cruise while retaining momentum.")
	assert(wagon.position.y > pedestrian.position.y + 20.0, "The wagon passed through the struck sprite.")
	var original_position: Vector2 = pedestrian.position
	for step in 150:
		Motion.advance(pedestrian, 1.0 / 30.0, population)
	assert(Vector2(pedestrian.position).distance_to(original_position) > 20.0)
	assert(not pedestrian.has("impact_velocity"), "Sprite never finished sliding/recovery.")
	var pushed_distance: float = Vector2(pedestrian.position).distance_to(original_position) / population.pixels_per_metre
	var slow_person := _actor("person", Vector2(200,0))
	slow_person.impact_velocity = slow.actor_velocity
	slow_person.impact_recovery_seconds = 0.8
	population.agents.clear()
	population.agents.append(slow_person)
	var slow_start: Vector2 = slow_person.position
	for step in 150:
		Motion.advance(slow_person, 1.0 / 30.0, population)
	assert(Vector2(slow_person.position).distance_to(slow_start) / population.pixels_per_metre < pushed_distance, "Higher-speed contact did not produce more actual displacement.")
	# Restarting ordinary movement uses the displaced coordinate, not a teleport.
	population._rebuild_walker_cells()
	var settled: Vector2 = pedestrian.position
	population.agents.clear()
	population.agents.append(pedestrian)
	population._advance_agent(pedestrian, 1.0 / 30.0)
	assert(Vector2(pedestrian.position).distance_to(settled) < 1.0)
	assert(not pedestrian.has("health") and not slow_person.has("health"), "Stage one added unrequested damage state.")

	# A wall or water in front of the contact must prevent any impulse beyond it.
	var blocked_sprite := _actor("robot", Vector2(400,-45))
	population.agents.clear()
	population.agents.append(blocked_sprite)
	wagon.position = Vector2(400,0)
	wagon.speed = 60.0 / 3.6 * 2.0
	wagon.target_speed_kmh = 60.0
	wagon.set_ground_check(func(point: Vector2, _radius: float) -> bool: return point.y > -10.0)
	wagon._physics_process(1.0)
	assert(not blocked_sprite.has("impact_velocity") and wagon.position == Vector2(400,0), "A contact beyond water was applied before ground validation.")
	wagon.set_ground_check(Callable())

	# An actual static wall catches the whole displaced car envelope.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var hit := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6,100)
	hit.shape = rectangle
	wall.add_child(hit)
	wall.position = Vector2(60,200)
	root.add_child(wall)
	await physics_frame
	var struck_car := _actor("traffic", Vector2(0,200))
	struck_car.angle = 0.0
	struck_car.impact_velocity = Vector2(100,0)
	struck_car.impact_recovery_seconds = 0.8
	population.agents.clear()
	population.agents.append(struck_car)
	for step in 60:
		Motion.advance(struck_car, 1.0 / 30.0, population)
	assert(Vector2(struck_car.position).x <= 38.0, "A displaced car passed its envelope through a solid wall.")
	population.set_ground_check(func(point: Vector2, radius: float) -> bool: return point.x + radius < 30.0)
	var swimmer := _actor("robot", Vector2(0,300))
	swimmer.impact_velocity = Vector2(100,0)
	swimmer.impact_recovery_seconds = 0.8
	population.agents.clear()
	population.agents.append(swimmer)
	for step in 60:
		Motion.advance(swimmer, 1.0 / 30.0, population)
	assert(Vector2(swimmer.position).x < 24.0, "A shoved robot entered blocked water.")
	population.set_ground_check(Callable())
	# Contact geometry, not just a manually supplied normal, controls car hits.
	for impact_case in ["front", "side", "corner"]:
		var car := _actor("traffic", Vector2(300,300))
		population.agents.clear()
		population.agents.append(car)
		var centre := Vector2(290.5,300)
		var from := centre + Vector2(0,-70)
		var to := centre + Vector2(0,70)
		var angle := 0.0
		var velocity := Vector2.DOWN * 35.0
		if impact_case == "side":
			from = centre + Vector2(-70,0)
			to = centre + Vector2(70,0)
			angle = PI * 0.5
			velocity = Vector2.RIGHT * 35.0
		elif impact_case == "corner":
			from.x += 12.0
			to.x += 12.0
		var hit_car := Actors.first_contact([car], from, to, angle, Vector2(8.5,20), {})
		assert(not hit_car.is_empty())
		var response := Motion.apply(hit_car, velocity, population)
		if impact_case == "side":
			assert(Vector2(response.actor_velocity).x > 0.0 and absf(Vector2(response.actor_velocity).y) < 0.01)
		elif impact_case == "front":
			assert(Vector2(response.actor_velocity).y > 0.0 and absf(float(response.actor_angular_velocity)) < 0.01)
		else:
			assert(absf(float(response.actor_angular_velocity)) > 0.01)
			var before_angle: float = car.angle
			Motion.advance(car, 1.0 / 30.0, population)
			assert(absf(float(car.angle) - before_angle) > 0.001, "Corner hit did not rotate the displayed car.")

	# Walk past both sides of a rotated parked wagon, without changing routes.
	for kind in ["person", "robot"]:
		for angle in [0.0, 0.7, PI * 0.5]:
			wagon.position = Vector2(0,400)
			wagon.rotation = angle
			wagon.speed = 0.0
			wagon.occupied = false
			var walker := _actor(kind, wagon.position + Vector2(-60,0).rotated(angle))
			walker.target = wagon.position + Vector2(60,0).rotated(angle)
			walker.speed = 20.0
			population.agents.clear()
			population.agents.append(walker)
			var destination: Vector2 = walker.target
			for step in 300:
				population._rebuild_walker_cells()
				Detour.advance(walker, 1.0 / 30.0, population)
				if Vector2(walker.position).distance_to(destination) < 0.01:
					break
			assert(Vector2(walker.position).distance_to(destination) < 0.01, "A %s stayed stuck on a rotated parked car." % kind)
	var around := Detour.plan(Vector2(-60,0), Vector2(60,0), Vector2.ZERO, 0.0, Vector2(14,26), func(a: Vector2, b: Vector2) -> bool: return a.y >= -0.1 and b.y >= -0.1)
	assert(not around.is_empty(), "Planner failed to choose the free side of a parked car.")
	assert(Detour.plan(Vector2(-60,0), Vector2(60,0), Vector2.ZERO, 0.0, Vector2(14,26), func(_a: Vector2, _b: Vector2) -> bool: return false).is_empty())
	# Also exercise the production _advance_agent binding, not just the helper.
	wagon.position = Vector2(0,600)
	wagon.rotation = 0.0
	var integrated_walker := _actor("person", Vector2(-60,600))
	integrated_walker.target = Vector2(60,600)
	integrated_walker.speed = 20.0
	population.agents.clear()
	population.agents.append(integrated_walker)
	for step in 350:
		population._rebuild_walker_cells()
		population._advance_agent(integrated_walker, 1.0 / 30.0)
		if Vector2(integrated_walker.position).distance_to(integrated_walker.target) < 0.01:
			break
	assert(Vector2(integrated_walker.position).x >= 59.9)
	var eastbound := _actor("person", Vector2(-60,600))
	var westbound := _actor("robot", Vector2(60,600))
	eastbound.target = Vector2(60,600)
	westbound.target = Vector2(-60,600)
	eastbound.speed = 20.0
	westbound.speed = 20.0
	westbound.walker_id = 2
	population.agents.clear()
	population.agents.append(eastbound)
	population.agents.append(westbound)
	for step in 650:
		population._rebuild_walker_cells()
		for walker in [eastbound, westbound]:
			if Vector2(walker.position).distance_to(walker.target) > 0.01:
				Detour.advance(walker, 1.0 / 30.0, population)
	assert(Vector2(eastbound.position).x > 59.9 and Vector2(westbound.position).x < -59.9, "Opposing walkers became stuck beside the parked wagon.")
	population.traffic_obstacles[0].free()
	population.queue_free()
	wagon.queue_free()
	wall.queue_free()
	await process_frame
	print("CRASH MOTION PASSED: speed/mass/scale, front/side/corner impulse and rotation, swept contacts, reverse, layers, wagon integration, slowing/recovery, solid walls/water, and NPC/NPR parked-car detours.")
	quit(0)
