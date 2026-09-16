extends Node2D

const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const WorldRendererScript = preload("res://scripts/runtime/runtime_world_renderer.gd")
const CollisionRuntimeScript = preload("res://scripts/collisions/building_collision_runtime.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")
const PlayerVehicleScript = preload("res://scripts/runtime/runtime_player_vehicle.gd")
const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")
const TracksScript = preload("res://scripts/runtime/runtime_tracks.gd")
const BuildingInformationScript = preload("res://scripts/places/osm_building_information.gd")
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const GAME_VIEW_SIZE := Vector2i(640, 360)
const PLAY_AREA_BOTTOM := 330.0

var town_directory := ""
var town: Dictionary = {}
var collision_data: Dictionary = {}
var game_settings: Dictionary = {}
var renderer
var collisions
var player
var wagon
var population
var tracks
var camera: Camera2D
var hud_label: Label
var hud_status: Label
var hud_help: Label
var map_coordinates: Label
var map_buttons: HBoxContainer
var tunnel_background: ColorRect
var building_information
var building_popup: PanelContainer
var building_popup_label: Label
var pinned_building_id := ""
var building_popup_anchor := Vector2.ZERO
var occupied := false
var overview := false
var overview_base_zoom := 1.0
var overview_zoom := 1.0
var map_dragging := false
var capture_camera_locked := false
var character_zoom := 2.0
var in_car_zoom := 1.5
var notice_text := ""
var notice_time := 0.0
var location_text := ""
var location_timer := 0.0
var active_land_bridge_id := ""
var active_bridge_entry := Vector2.INF
var active_bridge_exit := Vector2.INF
var active_bridge_departed := false


func _ready() -> void:
	_configure_runtime_presentation()
	town_directory = _argument_value("--play-town")
	if town_directory.is_empty():
		_fail("No Creator Studio town was supplied.")
		return
	var town_result := _read_json(town_directory.path_join("town.json"))
	var features_result := _read_json(town_directory.path_join("data").path_join("map_features.json"))
	var collisions_result := _read_json(town_directory.path_join("data").path_join("building_collisions.json"))
	var navigation_result := _read_json(town_directory.path_join("data").path_join("navigation_graphs.json"))
	var settings_result := _read_json(town_directory.path_join("game_settings.json"))
	for result in [town_result, features_result, collisions_result, navigation_result, settings_result]:
		if not result.ok:
			_fail(result.message)
			return
	town = town_result.data
	collision_data = collisions_result.data
	game_settings = settings_result.data
	var features: Array = features_result.data.get("features", [])
	var projection: Dictionary = collision_data.projection
	var scale: float = collision_data.runtime_scale.pixels_per_metre
	var driving_settings: Dictionary = settings_result.data.get("driving", {})
	character_zoom = float(settings_result.data.get("camera", {}).get("character_zoom", 2.0))
	# Retain the established JSON key for older towns, but treat its value as
	# an independent in-car camera zoom rather than a walking-view multiplier.
	in_car_zoom = float(driving_settings.get("camera_zoom_multiplier", 1.5))

	renderer = WorldRendererScript.new()
	add_child(renderer)
	renderer.setup(features, collision_data, town.map_bounds)
	var information_path := town_directory.path_join("data").path_join("place_information.json")
	var information_data: Dictionary = {}
	if FileAccess.file_exists(information_path):
		var information_result := _read_json(information_path)
		if information_result.ok:
			information_data = information_result.data
	if information_data.is_empty():
		# Older v1.1 projects remain playable before their next Rebuild. The same
		# deterministic builder prepares an in-memory index without changing files.
		information_data = BuildingInformationScript.new().build(features).data
	building_information = BuildingInformationScript.new()
	building_information.setup_spatial_index(
		features,
		information_data,
		func(value: Variant) -> Vector2:
			return ProjectionScript.geographic_to_world(ProjectionScript.value_to_location(value), projection, scale)
	)
	collisions = CollisionRuntimeScript.new()
	add_child(collisions)
	assert(collisions.setup(collision_data).ok)
	tracks = TracksScript.new()
	tracks.z_index = 2
	add_child(tracks)

	player = PlayerScript.new()
	player.name = "Player"
	player.position = ProjectionScript.geographic_to_world(ProjectionScript.value_to_location(town.starting_location), projection, scale)
	player.set_ground_check(renderer.is_ground_traversable)
	player.z_index = 5
	add_child(player)
	wagon = PlayerVehicleScript.new()
	wagon.name = "HoldenVZWagon"
	wagon.configure(driving_settings)
	wagon.position = ProjectionScript.geographic_to_world(ProjectionScript.value_to_location(town.starting_location.vehicle), projection, scale)
	wagon.set_ground_check(renderer.is_ground_traversable)
	wagon.z_index = 4
	add_child(wagon)
	player.crossing_travel.corridors = renderer.crossing_corridors
	wagon.crossing_travel.corridors = renderer.crossing_corridors
	_add_start_marker()

	population = PopulationScript.new()
	population.z_index = 3
	add_child(population)
	population.setup(navigation_result.data, settings_result.data, projection, scale, town.cbd.bounds, str(town.id), town.map_bounds)
	population.set_bridge_corridors(renderer.crossing_corridors)
	var traffic_obstacles: Array[Node2D] = [player, wagon]
	population.set_gameplay_obstacles(traffic_obstacles)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * character_zoom
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	_build_hud()
	collisions.update_streaming(player.position)
	print("PLAYABLE TOWN PREVIEW READY: %s" % str(town.get("display_name", town_directory.get_file())))
	if OS.get_cmdline_user_args().has("--verify-runtime"):
		call_deferred("_verify_runtime")
	var capture_path := _argument_value("--capture-runtime")
	if not capture_path.is_empty():
		call_deferred("_capture_runtime", capture_path)


func _process(delta: float) -> void:
	if player == null or wagon == null or camera == null or collisions == null or tracks == null or renderer == null or population == null or hud_label == null:
		return
	notice_time = maxf(0.0, notice_time - delta)
	var focus: CharacterBody2D = wagon if occupied else player
	_update_land_bridge_state(focus.position, focus.velocity)
	var player_in_tunnel: bool = player.crossing_travel.active.get("kind", "") == "tunnel"
	var wagon_in_tunnel: bool = wagon.crossing_travel.active.get("kind", "") == "tunnel"
	var on_bridge: bool = focus.crossing_travel.active.get("kind", "") == "bridge"
	var tunnel_view := not overview and (wagon_in_tunnel if occupied else player_in_tunnel)
	var underpass_index: int = renderer.underpass_at(focus.position, occupied) if not overview and focus.crossing_travel.active.is_empty() else -1
	var covered_view := tunnel_view or underpass_index >= 0
	tunnel_background.visible = covered_view
	tunnel_background.color = Color("#4a4a4a") if underpass_index >= 0 else Color.BLACK
	renderer.set_tunnel_view(tunnel_view)
	renderer.set_underpass_view(underpass_index)
	renderer.set_map_overview(overview)
	population.visible = not covered_view
	tracks.visible = not covered_view
	var start_marker := get_node_or_null("StartingLocationMarker") as CanvasItem
	if start_marker != null:
		start_marker.visible = not covered_view
	# Show the controlled road user against black while underground. Surface
	# actors remain hidden; the M overview still shows the ordinary town map.
	player.visible = not occupied and (player_in_tunnel if tunnel_view else not player_in_tunnel)
	wagon.visible = wagon_in_tunnel if tunnel_view else not wagon_in_tunnel
	if underpass_index >= 0 and not wagon.crossing_travel.active.is_empty(): wagon.visible = false
	if not overview and not capture_camera_locked:
		camera.position = focus.position + focus.velocity * 0.35
		camera.zoom = Vector2.ONE * (in_car_zoom if occupied else character_zoom)
	renderer.update_street_label_presentation(camera.zoom.x, overview_zoom, overview)
	collisions.update_streaming(focus.position)
	var moving: bool = absf(wagon.speed) > 1.0 if occupied else player.walking
	tracks.update_tracks(delta, focus, moving, occupied, renderer.is_grass)
	var status_text := ""
	if overview:
		status_text = "MAP · STREET NAMES FROM OPENSTREETMAP"
	elif notice_time > 0.0:
		status_text = notice_text
	elif (wagon_in_tunnel if occupied else player_in_tunnel):
		status_text = "IN TUNNEL · route continues below the surface"
	elif on_bridge:
		status_text = "ON BRIDGE · upper road layer · traffic below stays on its own route"
	elif underpass_index >= 0:
		status_text = "UNDER BRIDGE · following the lower road"
	elif occupied:
		var speed_kph := roundi(absf(wagon.speed) * 3.6 / float(collision_data.runtime_scale.pixels_per_metre))
		status_text = "WHITE HOLDEN VZ WAGON · %02d km/h · arrows drive · Space brake · E exit · M map" % speed_kph
	elif _near_wagon():
		status_text = "E: enter your white wagon · arrows walk · M map"
	else:
		var wagon_metres := roundi(player.position.distance_to(wagon.position) / float(collision_data.runtime_scale.pixels_per_metre))
		status_text = "ON FOOT · YOUR WAGON: %dm · arrows walk · E enter · M map" % wagon_metres
	location_timer -= delta
	if location_timer <= 0.0:
		location_text = _location_heading(focus.position)
		location_timer = 0.15
	if overview:
		hud_label.size.x = 425.0
		hud_label.text = "MAP %d×\n%s" % [roundi(overview_zoom), population.counts_text()]
	else:
		hud_label.size.x = 560.0
		hud_label.text = location_text
	hud_status.text = status_text
	hud_help.text = "Wheel/−/+ zoom · drag empty ground · click building · M close · F11 full screen" if overview else "Hover/click buildings · M map · E interact · F11 full screen · Esc close"
	map_coordinates.visible = overview
	if overview:
		# Invert the rendered camera transform so smoothing cannot make the
		# readout jump ahead of the map that is actually visible.
		var centre := get_viewport().get_canvas_transform().affine_inverse() * (get_viewport_rect().size * 0.5)
		var projection: Dictionary = collision_data.projection
		var scale: float = collision_data.runtime_scale.pixels_per_metre
		var latitude := float(projection.origin_latitude) - centre.y / scale / float(projection.latitude_metres_per_degree)
		var longitude := float(projection.origin_longitude) + centre.x / scale / float(projection.longitude_metres_per_degree)
		map_coordinates.text = "Latitude: %.6f°\nLongitude: %.6f°" % [latitude, longitude]
	_update_building_popup(covered_view)


func _update_land_bridge_state(_focus_position: Vector2, _travel_direction: Vector2 = Vector2.ZERO) -> void:
	var focus = wagon if occupied else player
	var crossing: Dictionary = focus.crossing_travel.active
	var bridge_id := str(crossing.get("id", "")) if crossing.get("kind", "") == "bridge" else ""
	if active_land_bridge_id == bridge_id: return
	active_land_bridge_id = bridge_id
	renderer.set_active_land_bridge(bridge_id)
	population.set_active_land_bridge(bridge_id)


func _clear_active_land_bridge() -> void:
	active_land_bridge_id = ""
	active_bridge_entry = Vector2.INF
	active_bridge_exit = Vector2.INF
	active_bridge_departed = false
	renderer.set_active_land_bridge("")
	population.set_active_land_bridge("")


func _verify_runtime() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	assert(renderer.world_bounds.size.x > 0.0 and renderer.world_bounds.size.y > 0.0)
	var population_settings: Dictionary = game_settings.get("population", {})
	var expected_population := (
		int(population_settings.get("traffic_car_count", 0))
		+ int(population_settings.get("pedestrian_count", 0))
		+ int(population_settings.get("robot_count", 0))
		+ int(population_settings.get("drone_count", 0))
	)
	assert(population.agents.size() == expected_population)
	var gender_counts := {"man": 0, "woman": 0}
	var age_counts := {"young": 0, "adult": 0, "older": 0}
	var vehicle_styles := {"sedan": 0, "wagon": 0, "ute": 0}
	var vehicle_assets := {}
	for road_user in population.agents:
		if str(road_user.kind) == "person":
			gender_counts[str(road_user.gender)] += 1
			age_counts[str(road_user.age_group)] += 1
			assert(not ActorArt.sprite(str(road_user.npc_asset)).is_empty())
		elif str(road_user.kind) == "traffic":
			vehicle_styles[str(road_user.vehicle_style)] += 1
			vehicle_assets[str(road_user.vehicle_asset)] = true
	assert(gender_counts.woman == ceili(float(population_settings.get("pedestrian_count", 0)) / 2.0))
	assert(gender_counts.man == int(population_settings.get("pedestrian_count", 0)) - gender_counts.woman)
	for style_name in vehicle_styles:
		assert(vehicle_styles[style_name] > 0, "The traffic population lost a vehicle body style: %s" % style_name)
	for age_name in age_counts:
		assert(age_counts[age_name] > 0, "The NPC population lost an age group: %s" % age_name)
	assert(vehicle_assets.size() >= mini(12, int(population_settings.get("traffic_car_count", 0))), "The NPC traffic lost its fixed car variants.")
	for artwork_name in ActorArt.PATHS:
		assert(not ActorArt.sprite(str(artwork_name)).is_empty(), "A transparent game sprite could not load: %s" % artwork_name)
	print("ACTOR ART CHECK PASSED: %d women / %d men; %s age groups; %s car body styles; %d static cars" % [gender_counts.woman, gender_counts.man, age_counts, vehicle_styles, vehicle_assets.size()])
	assert(population.driving_side == str(game_settings.get("road_rules", {}).get("driving_side", "left")))
	assert(is_equal_approx(character_zoom, float(game_settings.get("camera", {}).get("character_zoom", 1.0))))
	assert(is_equal_approx(in_car_zoom, float(game_settings.get("driving", {}).get("camera_zoom_multiplier", 0.8))))
	assert(is_equal_approx(wagon.forward_speed, float(game_settings.get("driving", {}).get("forward_speed", 108.0))))
	assert(player.get_script() == PlayerScript and wagon.get_script() == PlayerVehicleScript)
	assert(collisions.loaded_chunks.size() > 0)
	assert(get_window().content_scale_size == GAME_VIEW_SIZE)
	assert(hud_label.position == Vector2(8, 3) and hud_status.position == Vector2(8, 332))
	assert(renderer.visual_style_version == "v1.3-scaled-transport-2")
	assert(renderer.water_areas.size() == collision_data.get("water_areas", []).size())
	assert(renderer.street_label_count > 0, "The imported test map should expose OSM street names.")
	assert(renderer._building_style({"building": "retail"}, "shop") == "commercial")
	assert(renderer._building_style({"amenity": "hospital"}, "health") == "health")
	assert(renderer._building_style({"building": "warehouse"}, "shed") == "industrial")
	assert(renderer._building_style({"building": "apartments"}, "flats") == "tall")
	assert(building_information.indexed_footprints.size() > 0, "The imported buildings were not available for hover/click information.")
	var information_record: Dictionary = building_information.first_named_record()
	assert(not information_record.is_empty())
	assert(str(information_record.source_attribution) == "© OpenStreetMap contributors")
	assert(building_popup != null and building_popup_label != null)
	pinned_building_id = str(information_record.feature_id)
	building_popup_anchor = Vector2(636.0, 325.0)
	_update_building_popup(false)
	assert(building_popup.visible and building_popup_label.text.contains("© OpenStreetMap contributors"))
	assert(building_popup.position.x >= 4.0 and building_popup.position.y >= 36.0)
	assert(
		building_popup.position.x + building_popup.size.x <= 636.0 and building_popup.position.y + building_popup.size.y <= 327.0,
		"Building popup escaped the safe play area: position=%s size=%s" % [building_popup.position, building_popup.size]
	)
	pinned_building_id = ""
	building_popup.hide()
	var nearby_road: Dictionary = renderer.nearest_named_road(wagon.position, 160.0 * float(collision_data.runtime_scale.pixels_per_metre))
	if not nearby_road.is_empty():
		assert(_location_heading(wagon.position).contains(str(nearby_road.name)))
	_toggle_map()
	assert(overview and map_buttons.visible)
	var fitted_zoom := camera.zoom.x
	_zoom_overview(1.5)
	assert(camera.zoom.x > fitted_zoom)
	_fit_overview()
	assert(is_equal_approx(camera.zoom.x, fitted_zoom))
	_toggle_map()
	assert(not overview and not map_buttons.visible)
	_process(0.0)
	assert(is_equal_approx(camera.zoom.x, character_zoom), "Closing the map did not restore the creator's walking zoom.")
	# Exercise the inherited enter/exit rules without keyboard input.
	player.position = wagon.driver_door()
	_toggle_wagon()
	assert(occupied and wagon.occupied and not player.visible)
	_process(0.0)
	assert(is_equal_approx(camera.zoom.x, in_car_zoom), "Entering the wagon did not apply the independent in-car zoom.")
	_toggle_wagon()
	_process(0.0)
	assert(is_equal_approx(camera.zoom.x, character_zoom), "Leaving the wagon did not restore the on-foot zoom.")
	assert(not occupied and not wagon.occupied and player.visible and player.collision_layer == 2)
	var bridge_overlap: Dictionary = renderer.bridge_road_overlap()
	if not bridge_overlap.is_empty():
		var bridge_points: PackedVector2Array = bridge_overlap.bridge.points
		var bridge_direction: Vector2 = bridge_points[0].direction_to(bridge_points[1])
		var bridge_portal: Dictionary = renderer.bridge_portal_at(bridge_points[0], bridge_direction)
		assert(not bridge_portal.is_empty())
		player.position = bridge_portal.entry
		player.crossing_travel.commit_move(bridge_portal.entry - bridge_direction * 10.0, bridge_portal.entry + bridge_direction * 10.0)
		_update_land_bridge_state(player.position, bridge_direction)
		assert(active_land_bridge_id == str(bridge_portal.id), "Entering a bridge endpoint did not select the upper road layer.")
		player.position = _path_midpoint(bridge_points)
		_update_land_bridge_state(player.position, bridge_direction)
		player.position = bridge_portal.exit
		var exit_direction := bridge_points[bridge_points.size() - 2].direction_to(bridge_portal.exit)
		player.crossing_travel.commit_move(bridge_portal.exit, bridge_portal.exit + exit_direction * 30.0)
		_update_land_bridge_state(player.position, bridge_direction)
		assert(active_land_bridge_id.is_empty(), "Leaving the opposite bridge endpoint did not restore the surface layer.")
		player.position = bridge_overlap.position
		var lower_road_direction: Vector2 = bridge_overlap.road.a.direction_to(bridge_overlap.road.b)
		_update_land_bridge_state(player.position, lower_road_direction)
		assert(active_land_bridge_id.is_empty(), "A car on the lower crossing road incorrectly activated the bridge above it.")
	print("TOWN RUNTIME CHECK PASSED: %d moving road users; %d collision chunks loaded." % [population.agents.size(), collisions.loaded_chunks.size()])
	get_tree().quit()


func _capture_runtime(path_value: String) -> void:
	# Allow the canvas, camera and first population positions to render before the
	# focused visual check captures the actual running scene.
	if OS.get_cmdline_user_args().has("--capture-fullscreen"):
		_toggle_fullscreen()
		assert(get_window().mode == Window.MODE_FULLSCREEN, "The game failed to switch to full screen.")
		print("GAME VIEW CHECK PASSED: full-screen 16:9 runtime window")
	var capture_focus := _argument_value("--capture-focus")
	if capture_focus in ["tunnel", "tunnel-entry", "tunnel-exit"]:
		var surface_position: Vector2 = wagon.position
		var tunnel_corridor: Dictionary = renderer.longest_crossing_corridor("tunnel")
		assert(not tunnel_corridor.is_empty(), "The capture map needs a mapped tunnel.")
		var tunnel_points: PackedVector2Array = tunnel_corridor.points
		var tunnel_position: Vector2 = _path_midpoint(tunnel_points)
		if capture_focus == "tunnel-entry":
			tunnel_position = tunnel_points[0] + tunnel_points[0].direction_to(tunnel_points[1]) * 12.0
		elif capture_focus == "tunnel-exit":
			tunnel_position = tunnel_points[tunnel_points.size() - 1] + tunnel_points[tunnel_points.size() - 1].direction_to(tunnel_points[tunnel_points.size() - 2]) * 12.0
		occupied = true
		wagon.occupied = true
		player.active = false
		wagon.position = tunnel_position
		wagon.crossing_travel.active = tunnel_corridor
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		if capture_focus == "tunnel":
			_fit_camera_to_path(tunnel_points)
		else:
			camera.position = tunnel_position
			camera.zoom = Vector2.ONE
		await get_tree().process_frame
		await get_tree().process_frame
		assert(wagon.visible and tunnel_background.visible and renderer.visible and renderer.tunnel_view_only)
		_toggle_map()
		await get_tree().process_frame
		await get_tree().process_frame
		assert(renderer.visible and not renderer.tunnel_view_only and not tunnel_background.visible)
		_toggle_map()
		wagon.position = surface_position
		wagon.crossing_travel.active = {}
		await get_tree().process_frame
		await get_tree().process_frame
		assert(renderer.visible and not renderer.tunnel_view_only and wagon.visible and not tunnel_background.visible)
		wagon.position = tunnel_position
		wagon.crossing_travel.active = tunnel_corridor
		print("TUNNEL PRESENTATION PASSED: entry/exit points, visible wagon and tunnel roads, black surroundings, M overview, surface restoration")
	elif capture_focus == "underpass":
		var surface_position: Vector2 = wagon.position
		var overlap: Dictionary = renderer.bridge_road_overlap()
		assert(not overlap.is_empty(), "The capture map needs a road under a bridge.")
		occupied = true
		wagon.occupied = true
		player.active = false
		wagon.crossing_travel.active = {}
		wagon.position = overlap.position
		wagon.rotation = overlap.road.a.direction_to(overlap.road.b).angle() + PI/2
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		camera.position = wagon.position
		camera.zoom = Vector2.ONE
		await get_tree().process_frame
		await get_tree().process_frame
		assert(wagon.visible and renderer.underpass_path_index >= 0 and not renderer.tunnel_view_only)
		assert(tunnel_background.visible and tunnel_background.color == Color("#4a4a4a"))
		var shown_path: Dictionary = renderer.road_paths[renderer.underpass_path_index]
		assert(shown_path.path_id == overlap.road.path_id, "The grey view selected a different road after sorting")
		_toggle_map()
		await get_tree().process_frame
		await get_tree().process_frame
		assert(renderer.underpass_path_index == -1 and not tunnel_background.visible)
		_toggle_map()
		wagon.position = surface_position
		await get_tree().process_frame
		await get_tree().process_frame
		assert(renderer.underpass_path_index == -1 and not tunnel_background.visible)
		wagon.position = overlap.position
		camera.position = wagon.position
		camera.zoom = Vector2.ONE
		print("UNDERPASS PRESENTATION PASSED: visible lower road/wagon, grey surroundings, correct road after sorting, no upper-layer activation, M overview and surface restoration")
	elif capture_focus in ["bridge", "bridge-entry", "bridge-exit"]:
		var overlap: Dictionary = renderer.bridge_road_overlap()
		var bridge_corridor: Dictionary = overlap.get("bridge", renderer.longest_crossing_corridor("bridge"))
		assert(not bridge_corridor.is_empty(), "The capture map needs a mapped bridge.")
		var bridge_points: PackedVector2Array = bridge_corridor.points
		occupied = true
		wagon.occupied = true
		player.active = false
		active_land_bridge_id = str(bridge_corridor.id)
		wagon.crossing_travel.active = bridge_corridor
		active_bridge_entry = bridge_points[0]
		active_bridge_exit = bridge_points[bridge_points.size() - 1]
		if capture_focus == "bridge-exit":
			active_bridge_entry = bridge_points[bridge_points.size() - 1]
			active_bridge_exit = bridge_points[0]
		active_bridge_departed = false
		renderer.set_active_land_bridge(active_land_bridge_id)
		population.set_active_land_bridge(active_land_bridge_id)
		wagon.position = overlap.get("position", _path_midpoint(bridge_points))
		if capture_focus == "bridge-entry":
			wagon.position = bridge_points[0] + bridge_points[0].direction_to(bridge_points[1]) * 12.0
		elif capture_focus == "bridge-exit":
			wagon.position = bridge_points[bridge_points.size() - 1] + bridge_points[bridge_points.size() - 1].direction_to(bridge_points[bridge_points.size() - 2]) * 12.0
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		if capture_focus == "bridge":
			_fit_camera_to_path(bridge_points)
		else:
			camera.position = wagon.position
			camera.zoom = Vector2.ONE
		print("BRIDGE PRESENTATION READY: entry/exit points, upper deck and lower town/road layers")
	elif capture_focus == "vehicle":
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		camera.position = wagon.position
	elif capture_focus == "player":
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		camera.position = player.position
	elif capture_focus == "driving-camera":
		occupied = true
		wagon.occupied = true
		player.active = false
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		camera.position = wagon.position
		camera.zoom = Vector2.ONE * in_car_zoom
	elif capture_focus == "crowd":
		# Select a real, current concentration of NPCs and NPRs. This moves
		# only the review camera, never an agent or the creator's saved start.
		var best_centre: Vector2 = player.position
		var best_score := -1
		for candidate in population.agents:
			if str(candidate.kind) != "robot":
				continue
			var candidate_position: Vector2 = candidate.position
			var score := 0
			for nearby in population.agents:
				if candidate_position.distance_to(nearby.position) <= 260.0:
					score += 1
			if score > best_score:
				best_score = score
				best_centre = candidate_position
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		camera.position = best_centre
		camera.zoom = Vector2.ONE * character_zoom
		print("ACTOR ART CAPTURE: %d actual nearby town agents" % best_score)
	elif capture_focus == "transport":
		var preview: Dictionary = renderer.transport_preview_area()
		assert(not preview.is_empty(), "The capture map needs a mapped surface car park with room for inferred bay guides.")
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		camera.position = preview.position
		camera.zoom = Vector2.ONE * 0.65
		wagon.position = preview.position
		wagon.rotation = Vector2(preview.direction).angle() + PI * 0.5
		print("SCALED TRANSPORT CAPTURE: parking=%s bay guides=%d" % [str(preview.id), int(preview.stripe_count)])
	elif capture_focus == "building-info":
		var record: Dictionary = building_information.first_named_record()
		assert(not record.is_empty(), "The capture map needs at least one imported building.")
		var building_centre: Vector2 = building_information.world_centre_for_feature(str(record.feature_id))
		assert(building_centre != Vector2.INF)
		capture_camera_locked = true
		camera.position_smoothing_enabled = false
		camera.position = building_centre
		camera.zoom = Vector2.ONE * 0.6
		pinned_building_id = str(record.feature_id)
		building_popup_anchor = Vector2(174.0, 112.0)
		_update_building_popup(false)
	elif capture_focus == "map":
		overview = true
		map_buttons.visible = true
		camera.position_smoothing_enabled = false
		_fit_overview()
		_zoom_overview(48.0)
		camera.position = player.position
		# Optional geographic focus for reproducing user map-view screenshots.
		var capture_latitude := _argument_value("--capture-latitude")
		var capture_longitude := _argument_value("--capture-longitude")
		if not capture_latitude.is_empty() and not capture_longitude.is_empty():
			camera.position = ProjectionScript.geographic_to_world(Vector2(float(capture_longitude), float(capture_latitude)), renderer.projection, renderer.pixels_per_metre)
		var capture_map_zoom := _argument_value("--capture-map-zoom")
		if not capture_map_zoom.is_empty():
			overview_zoom = maxf(1.0, float(capture_map_zoom))
			_apply_overview_zoom()
	elif capture_focus == "map-fit":
		overview = true
		map_buttons.visible = true
		camera.position_smoothing_enabled = false
		_fit_overview()
	for _unused_frame in 4:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(path_value.get_base_dir())
	var captured_image := get_viewport().get_texture().get_image()
	if captured_image == null:
		printerr("Runtime capture needs a graphical renderer; headless mode cannot create this review image.")
		get_tree().quit(1)
		return
	var save_error := captured_image.save_png(path_value)
	assert(save_error == OK, "Could not save runtime review image.")
	print("TOWN RUNTIME CAPTURE SAVED: %s" % path_value)
	get_tree().quit()


func _path_midpoint(points: PackedVector2Array) -> Vector2:
	var total_length := 0.0
	for index in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	var remaining := total_length * 0.5
	for index in range(points.size() - 1):
		var segment_length := points[index].distance_to(points[index + 1])
		if remaining <= segment_length:
			return points[index].lerp(points[index + 1], remaining / maxf(segment_length, 0.001))
		remaining -= segment_length
	return points[points.size() - 1]


func _fit_camera_to_path(points: PackedVector2Array) -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	bounds = bounds.grow(36.0)
	camera.position = bounds.get_center()
	var zoom := minf(590.0 / maxf(bounds.size.x, 1.0), 255.0 / maxf(bounds.size.y, 1.0))
	camera.zoom = Vector2.ONE * clampf(zoom, 0.08, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _screen_can_select_building(event.position):
		var selected_building := _building_at_screen(event.position)
		if not selected_building.is_empty():
			pinned_building_id = str(selected_building.feature_id)
			building_popup_anchor = event.position
			_update_building_popup(false)
			get_viewport().set_input_as_handled()
			return
		if not pinned_building_id.is_empty():
			pinned_building_id = ""
			building_popup.hide()
	if overview and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_overview(1.35)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_overview(1.0 / 1.35)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			map_dragging = event.pressed
			return
	if overview and map_dragging and event is InputEventMouseMotion:
		camera.position -= event.relative / camera.zoom
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_M:
			_toggle_map()
		elif overview and event.keycode in [KEY_EQUAL, KEY_KP_ADD]:
			_zoom_overview(1.5)
		elif overview and event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_zoom_overview(1.0 / 1.5)
		elif overview and event.keycode == KEY_HOME:
			_fit_overview()
		elif overview and event.keycode == KEY_F:
			camera.position = wagon.position if occupied else player.position
		elif event.keycode == KEY_E and not overview:
			_toggle_wagon()


func _toggle_wagon() -> void:
	if occupied:
		if absf(wagon.speed) > 2.0:
			_notice("Stop the wagon before getting out.")
			return
		var exit_spot := _safe_exit()
		if exit_spot == Vector2.INF:
			_notice("No clear space to get out. Move the wagon away from the building.")
			return
		occupied = false
		wagon.occupied = false
		wagon.speed = 0.0
		player.position = exit_spot
		player.crossing_travel.active = wagon.crossing_travel.active
		player.active = true
		player.collision_layer = 2
		player.show()
		_notice("On foot. Move beside your wagon and press E to get in again.")
	elif _near_wagon():
		if player.crossing_travel.active.get("id", "") != wagon.crossing_travel.active.get("id", ""):
			_notice("Reach the wagon on the same road level before getting in.")
			return
		var ray := PhysicsRayQueryParameters2D.create(player.position, wagon.position, 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			_notice("Walk around the building or obstacle to reach your wagon.")
			return
		occupied = true
		wagon.occupied = true
		player.active = false
		player.collision_layer = 0
		player.hide()
		_notice("Wagon: ↑ forward · ↓ brake/reverse · ← → steer · Space brake · E exit")
	else:
		_notice("Move beside your white wagon to get in.")


func _near_wagon() -> bool:
	var local_position: Vector2 = wagon.to_local(player.position)
	var nearest := local_position.clamp(Vector2(-9.0, -20.0), Vector2(9.0, 20.0))
	return local_position.distance_to(nearest) <= 14.0


func _safe_exit() -> Vector2:
	for offset in [Vector2(18.0, -3.0), Vector2(-18.0, -3.0), Vector2(20.0, 10.0), Vector2(-20.0, 10.0)]:
		var target: Vector2 = wagon.position + offset.rotated(wagon.rotation)
		if not renderer.world_bounds.has_point(target):
			continue
		if not wagon.crossing_travel.active.is_empty() and not player.crossing_travel.contains_pose(wagon.crossing_travel.active, target, 0.0, player.crossing_travel.half_size):
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 5.0
		query.shape = circle
		query.transform = Transform2D(0.0, target)
		query.collision_mask = 1
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return target
	return Vector2.INF


func _notice(message: String) -> void:
	notice_text = message
	notice_time = 3.0


func _toggle_map() -> void:
	overview = not overview
	map_dragging = false
	player.controls_enabled = not overview
	wagon.controls_enabled = not overview
	map_buttons.visible = overview
	if overview:
		_fit_overview()
	else:
		camera.position = wagon.position if occupied else player.position
		camera.zoom = Vector2.ONE * (in_car_zoom if occupied else character_zoom)


func _fit_overview() -> void:
	# Reserve the top and bottom HUD bars while fitting maps of any dimensions.
	overview_base_zoom = minf(605.0 / renderer.world_bounds.size.x, 270.0 / renderer.world_bounds.size.y)
	overview_zoom = 1.0
	camera.position = renderer.world_bounds.get_center()
	_apply_overview_zoom()


func _zoom_overview(factor: float) -> void:
	# Relative zoom alone would prevent a geographically large city from ever
	# reaching street level. Bound the final camera scale instead of the map size.
	var maximum_detail := maxf(64.0, 8.0 / maxf(overview_base_zoom, 0.000001))
	overview_zoom = clampf(overview_zoom * factor, 1.0, maximum_detail)
	_apply_overview_zoom()


func _apply_overview_zoom() -> void:
	camera.zoom = Vector2.ONE * overview_base_zoom * overview_zoom
	renderer.update_street_label_presentation(camera.zoom.x, overview_zoom, true)


func _build_hud() -> void:
	var underground_canvas := CanvasLayer.new()
	underground_canvas.name = "TunnelBackground"
	underground_canvas.layer = -1
	add_child(underground_canvas)
	tunnel_background = ColorRect.new()
	tunnel_background.color = Color.BLACK
	tunnel_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tunnel_background.visible = false
	underground_canvas.add_child(tunnel_background)
	tunnel_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	for panel_rect in [Rect2(0, 0, 640, 34), Rect2(0, 330, 640, 30)]:
		var panel := ColorRect.new()
		panel.color = Color("263d31")
		panel.position = panel_rect.position
		panel.size = panel_rect.size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(panel)
	hud_label = Label.new()
	hud_label.position = Vector2(8, 3)
	hud_label.size = Vector2(425, 30)
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_label.add_theme_font_size_override("font_size", 8)
	hud_label.add_theme_color_override("font_color", Color("f3edcf"))
	canvas.add_child(hud_label)
	hud_status = Label.new()
	hud_status.position = Vector2(8, 332)
	hud_status.add_theme_font_size_override("font_size", 8)
	hud_status.add_theme_color_override("font_color", Color("f3edcf"))
	canvas.add_child(hud_status)
	hud_help = Label.new()
	hud_help.position = Vector2(8, 345)
	hud_help.add_theme_font_size_override("font_size", 8)
	hud_help.add_theme_color_override("font_color", Color("f3edcf"))
	canvas.add_child(hud_help)
	map_coordinates = Label.new()
	map_coordinates.name = "MapCoordinates"
	map_coordinates.position = Vector2(500, 303)
	map_coordinates.size = Vector2(136, 24)
	map_coordinates.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_coordinates.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_coordinates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_coordinates.add_theme_font_size_override("font_size", 8)
	map_coordinates.add_theme_color_override("font_color", Color("f3edcf"))
	var coordinate_background := StyleBoxFlat.new()
	coordinate_background.bg_color = Color("#17231feb")
	coordinate_background.content_margin_right = 3
	map_coordinates.add_theme_stylebox_override("normal", coordinate_background)
	map_coordinates.visible = false
	canvas.add_child(map_coordinates)
	var north := Label.new()
	north.text = "N ↑  v1.2"
	north.position = Vector2(592, 1)
	north.add_theme_font_size_override("font_size", 8)
	north.add_theme_color_override("font_color", Color("f3edcf"))
	north.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(north)
	map_buttons = HBoxContainer.new()
	map_buttons.position = Vector2(455, 10)
	map_buttons.visible = false
	canvas.add_child(map_buttons)
	for caption in ["−", "+", "Fit", "You"]:
		var button := Button.new()
		button.text = caption
		button.add_theme_font_size_override("font_size", 8)
		button.custom_minimum_size = Vector2(28, 18)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			if caption == "Fit":
				_fit_overview()
			elif caption == "You":
				camera.position = wagon.position if occupied else player.position
			elif caption == "+":
				_zoom_overview(1.5)
			else:
				_zoom_overview(1.0 / 1.5)
		)
		map_buttons.add_child(button)
	building_popup = PanelContainer.new()
	building_popup.name = "BuildingInformationPopup"
	building_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_popup.clip_contents = true
	building_popup.visible = false
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color("#17231ff2")
	popup_style.border_color = Color("#5bd6b2")
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(3)
	popup_style.content_margin_left = 6
	popup_style.content_margin_right = 6
	popup_style.content_margin_top = 4
	popup_style.content_margin_bottom = 4
	building_popup.add_theme_stylebox_override("panel", popup_style)
	canvas.add_child(building_popup)
	building_popup_label = Label.new()
	building_popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_popup_label.clip_text = true
	building_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	building_popup_label.add_theme_font_size_override("font_size", 7)
	building_popup_label.add_theme_color_override("font_color", Color("#f3edcf"))
	building_popup.add_child(building_popup_label)


func _update_building_popup(covered_view: bool) -> void:
	var transport_capture := capture_camera_locked and _argument_value("--capture-focus") == "transport"
	if building_popup == null or building_information == null or covered_view or map_dragging or transport_capture:
		if building_popup != null:
			building_popup.hide()
		return
	var record: Dictionary = {}
	var pinned := not pinned_building_id.is_empty()
	if pinned:
		record = building_information.record_for_feature(pinned_building_id)
	else:
		var mouse_position := get_viewport().get_mouse_position()
		if _screen_can_select_building(mouse_position):
			record = _building_at_screen(mouse_position)
			building_popup_anchor = mouse_position
	if record.is_empty():
		building_popup.hide()
		return
	var lines: Array[String] = BuildingInformationScript.detailed_popup_lines(record) if pinned else BuildingInformationScript.brief_popup_lines(record)
	building_popup_label.text = "\n".join(PackedStringArray(lines))
	var popup_size := Vector2(202.0, float(lines.size() * 9 + 9))
	building_popup_label.custom_minimum_size = Vector2(190.0, popup_size.y - 8.0)
	building_popup.size = popup_size
	var desired := building_popup_anchor + Vector2(10.0, 8.0)
	building_popup.position = Vector2(
		clampf(desired.x, 4.0, 636.0 - popup_size.x),
		clampf(desired.y, 36.0, 327.0 - popup_size.y)
	)
	building_popup.show()


func _building_at_screen(screen_position: Vector2) -> Dictionary:
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	return building_information.building_at(world_position)


func _screen_can_select_building(screen_position: Vector2) -> bool:
	return screen_position.x >= 0.0 and screen_position.x <= 640.0 and screen_position.y >= 34.0 and screen_position.y <= PLAY_AREA_BOTTOM


func _add_start_marker() -> void:
	var location_label := str(town.get("starting_location", {}).get("label", ""))
	if location_label.is_empty():
		return
	# Long creator notes belong in project data, not across the play area. The
	# first comma-separated place name remains visible as a compact map marker.
	var short_location_label := _short_location_name(location_label)
	var marker := Label.new()
	marker.name = "StartingLocationMarker"
	marker.text = "START · %s" % short_location_label.to_upper()
	marker.position = player.position + Vector2(-70.0, -30.0)
	marker.size = Vector2(140.0, 16.0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 8)
	marker.add_theme_color_override("font_color", Color("#d7f1e6"))
	marker.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.07, 0.88))
	marker.add_theme_constant_override("outline_size", 2)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 7
	add_child(marker)


func _fail(message: String) -> void:
	var label := Label.new()
	label.text = "Town preview could not start.\n%s\n\nPress Escape to close." % message
	label.position = Vector2(12, 48)
	label.size = Vector2(360, 150)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)


func _configure_runtime_presentation() -> void:
	# Creator Studio keeps its roomy 1280x800 editing interface. Play tests switch
	# to a 640x360 (16:9) canvas: a larger actual town view and a clean 3x
	# pixel scale on a 1920x1080 full-screen display.
	# This is independent of the imported town's physical size or coordinates.
	var runtime_window := get_window()
	runtime_window.content_scale_size = GAME_VIEW_SIZE
	runtime_window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	runtime_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _toggle_fullscreen() -> void:
	var runtime_window := get_window()
	runtime_window.mode = Window.MODE_WINDOWED if runtime_window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _short_location_name(location_label: String) -> String:
	return location_label.get_slice(",", 0).strip_edges()


func _location_heading(focus_position: Vector2) -> String:
	var heading_parts: Array[String] = [str(town.get("display_name", town_directory.get_file())).to_upper()]
	var start_data: Dictionary = town.get("starting_location", {})
	var start_label := str(start_data.get("label", ""))
	if not start_label.is_empty():
		var start_world := ProjectionScript.geographic_to_world(
			ProjectionScript.value_to_location(start_data),
			collision_data.projection,
			float(collision_data.runtime_scale.pixels_per_metre)
		)
		if focus_position.distance_to(start_world) <= 100.0 * float(collision_data.runtime_scale.pixels_per_metre):
			heading_parts.append(_short_location_name(start_label).to_upper())
	var nearest_road: Dictionary = renderer.nearest_named_road(
		focus_position,
		160.0 * float(collision_data.runtime_scale.pixels_per_metre)
	)
	if not nearest_road.is_empty():
		var road_name := str(nearest_road.name)
		heading_parts.append(road_name if bool(nearest_road.on_road) else "NEAR %s" % road_name)
	return " / ".join(heading_parts)


func _read_json(path_value: String) -> Dictionary:
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "%s is missing or unreadable." % path_value.get_file()}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "message": "%s is not valid project data." % path_value.get_file()}
	return {"ok": true, "data": parsed}


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index] == name and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""
