extends Node2D

const ProjectionScript = preload("res://scripts/runtime/town_projection.gd")
const WorldRendererScript = preload("res://scripts/runtime/runtime_world_renderer.gd")
const CollisionRuntimeScript = preload("res://scripts/collisions/building_collision_runtime.gd")
const PlayerScript = preload("res://scripts/runtime/runtime_player_character.gd")
const PlayerVehicleScript = preload("res://scripts/runtime/runtime_player_vehicle.gd")
const PopulationScript = preload("res://scripts/runtime/runtime_population.gd")
const StorylineNpcStoreScript = preload("res://scripts/npcs/storyline_npc_store.gd")
const TracksScript = preload("res://scripts/runtime/runtime_tracks.gd")
const BuildingInformationScript = preload("res://scripts/places/osm_building_information.gd")
const PopulationDestinationsScript = preload("res://scripts/population/osm_population_destinations.gd")
const MapOverrideStoreScript = preload("res://scripts/editor/map_override_store.gd")
const BuildingExteriorStoreScript = preload("res://scripts/buildings/building_exterior_store.gd")
const BuildingInteriorStoreScript = preload("res://scripts/interiors/building_interior_store.gd")
const RuntimeInteriorLayerScript = preload("res://scripts/interiors/runtime_interior_layer.gd")
const RuntimeObjectBubbleScript = preload("res://scripts/interiors/runtime_object_identification_bubble.gd")
const RuntimeConversationLayerScript = preload("res://scripts/npcs/runtime_conversation_layer.gd")
const PersonaStoreScript = preload("res://scripts/npcs/persona_store.gd")
const TownKnowledgeStoreScript = preload("res://scripts/npcs/town_knowledge_store.gd")
const LocationNotesScript = preload("res://scripts/npcs/locations/location_notes_store.gd")
const TraderDialoguePolicy = preload("res://scripts/npcs/traders/trader_dialogue_policy.gd")
var location_notes_data: Dictionary = {"locations": {}}
var location_note_texts: Dictionary = {}
var prepared_dialogue_system := ""
var trader_contexts: Dictionary = {}
const WikipediaTownContextScript = preload("res://scripts/npcs/wikipedia_town_context.gd")
const OllamaDialogueClientScript = preload("res://scripts/npcs/ollama_dialogue_client.gd")
const LocalLlmStartupLoaderScript = preload("res://scripts/npcs/local_llm_startup_loader.gd")
const LocalLlmLoadingScreenScript = preload("res://scripts/npcs/local_llm_loading_screen.gd")
const ActorArt = preload("res://scripts/runtime/runtime_actor_art.gd")
const SpeedometerGaugeScript = preload("res://scripts/runtime/ui/runtime_speedometer_gauge.gd")
const OdometerPanelScript = preload("res://scripts/runtime/ui/runtime_odometer_panel.gd")
const PlayerInventoryScript = preload("res://scripts/runtime/inventory/runtime_player_inventory.gd")
const InventoryPanelScript = preload("res://scripts/runtime/ui/runtime_inventory_panel.gd")
const ItemCatalogStoreScript = preload("res://scripts/inventory/item_catalog_store.gd")
const TraderStoreScript = preload("res://scripts/npcs/traders/trader_store.gd")
const TradeServiceScript = preload("res://scripts/npcs/traders/trade_service.gd")
const ShopScript = preload("res://scripts/npcs/traders/runtime_shop.gd")
signal trade_completed(trade: Dictionary)
var trader_data: Dictionary = {"traders": {}}
var conversation_trader: Dictionary = {}
var conversation_trader_id := ""
var shop
var conversation_shop_button: Button
const PlayerStatsScript = preload("res://scripts/runtime/inventory/runtime_player_stats.gd")
const PlayerStatsPanelScript = preload("res://scripts/runtime/ui/runtime_player_stats_panel.gd")
const GAME_VIEW_SIZE := Vector2i(640, 360)
const DRIVING_INSTRUMENT_SCALE := 0.55
const DRIVING_INSTRUMENT_LEFT := 8.0
const DRIVING_INSTRUMENT_SPEED_TOP := 246.0
const DRIVING_INSTRUMENT_ODOMETER_TOP := 300.0
const PLAY_AREA_BOTTOM := 330.0
const MAP_PLAY_AREA := Rect2(0.0, 34.0, 640.0, PLAY_AREA_BOTTOM - 34.0)

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
var interior_layer
var object_identification_bubble
var conversation_layer
var camera: Camera2D
var hud_label: Label
var hud_status: Label
var hud_help: Label
var speedometer_gauge: Control
var odometer_panel: Control
var player_inventory
var inventory_panel: Control
var item_catalog_data: Dictionary = {}
var player_stats
var player_stats_panel: Control
var map_coordinates: Label
var map_buttons: HBoxContainer
var map_copy_button: Button
var map_cursor_marker: Label
var tunnel_background: ColorRect
var building_information
var building_popup: PanelContainer
var building_popup_label: Label
var conversation_input: LineEdit
var conversation_send_button: Button
var conversation_end_button: Button
var pinned_building_id := ""
var building_popup_anchor := Vector2.ZERO
var occupied := false
var overview := false
var overview_base_zoom := 1.0
var overview_zoom := 1.0
var map_dragging := false
var map_pointer_down := false
var map_press_position := Vector2.ZERO
var map_cursor_screen_position := Vector2(320.0, 180.0)
var map_copy_text := ""
var capture_camera_locked := false
var character_zoom := 2.7
var in_car_zoom := 1.5
var notice_text := ""
var notice_time := 0.0
var location_text := ""
var location_timer := 0.0
var active_land_bridge_id := ""
var active_bridge_entry := Vector2.INF
var active_bridge_exit := Vector2.INF
var active_bridge_departed := false
var odometer_load_message := ""
var inventory_load_message := ""
var stats_load_message := ""
var building_exterior_data: Dictionary = {"buildings": {}}
var building_interior_data: Dictionary = {"buildings": {}}
var interior_entrances: Array[Dictionary] = []
var unlinked_exterior_entrances: Array[Dictionary] = []
const ENTRY_PRESS_GRACE_SECONDS := 0.4
var pending_entry_time := 0.0
var inside_building_id := ""
var inside_building_name := ""
var inside_floor_id := ""
var inside_floor_name := ""
var exterior_return_position := Vector2.INF
var conversation_active := false
var conversation_target_index := -1
var conversation_greeted := false
var conversation_waiting := false
var conversation_history: Array[Dictionary] = []
var conversation_persona: Dictionary = {}
var persona_data: Dictionary = {}
var storyline_npc_data: Dictionary = {"npcs": []}
var town_knowledge_data: Dictionary = {}
var town_custom_text := ""
var town_prompt_context := ""
var town_knowledge_store = TownKnowledgeStoreScript.new()
var dialogue_client
var wikipedia_client
var llm_startup_loader
var llm_loading_screen
var llm_startup_active := false
var local_llm_available := false
var wikipedia_refresh_complete := false


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
	var item_catalog_result := ItemCatalogStoreScript.new().load_from_town(town_directory)
	if not item_catalog_result.ok:
		_fail(item_catalog_result.message)
		return
	item_catalog_data = item_catalog_result.data
	var persistent_gameplay := not OS.get_cmdline_user_args().has("--capture-runtime") and not OS.get_cmdline_user_args().has("--verify-runtime")
	player_inventory = PlayerInventoryScript.new()
	var inventory_result: Dictionary = player_inventory.load_for_town(town_directory, persistent_gameplay, item_catalog_data)
	inventory_load_message = str(inventory_result.message)
	if not inventory_load_message.is_empty():
		push_warning(inventory_load_message)
	player_stats = PlayerStatsScript.new()
	var stats_result: Dictionary = player_stats.load_for_town(town_directory, persistent_gameplay)
	stats_load_message = str(stats_result.message)
	if not stats_load_message.is_empty():
		push_warning(stats_load_message)
	var persona_result := PersonaStoreScript.new().load_from_town(town_directory)
	if not persona_result.ok:
		_fail(persona_result.message)
		return
	persona_data = persona_result.data
	var knowledge_result := town_knowledge_store.load_from_town(town_directory)
	if not knowledge_result.ok:
		_fail(knowledge_result.message)
		return
	town_knowledge_data = knowledge_result.data
	town_custom_text = str(knowledge_result.custom_text)
	town_prompt_context = TownKnowledgeStoreScript.prompt_context(town_knowledge_data, town_custom_text, str(town.get("display_name", town_directory.get_file())), false)
	var source_features: Array = features_result.data.get("features", [])
	var override_load := MapOverrideStoreScript.new().load_from_town(town_directory, source_features, town_result.data.get("map_bounds", {}))
	if not override_load.ok:
		_fail(override_load.message)
		return
	var override_apply := MapOverrideStoreScript.new().apply(source_features, override_load.data)
	if not override_apply.ok:
		_fail(override_apply.message)
		return
	var features: Array = override_apply.features
	var exterior_result := BuildingExteriorStoreScript.new().load_from_town(town_directory)
	if not exterior_result.ok:
		_fail(exterior_result.message)
		return
	building_exterior_data = exterior_result.data
	var interior_result := BuildingInteriorStoreScript.new().load_from_town(town_directory)
	if not interior_result.ok:
		_fail(interior_result.message)
		return
	building_interior_data = interior_result.data
	var storyline_result := StorylineNpcStoreScript.new().load_from_town(town_directory, town.get("map_bounds", {}), features, persona_data, building_interior_data)
	if not storyline_result.ok:
		_fail(storyline_result.message)
		return
	storyline_npc_data = storyline_result.data
	var trader_load := TraderStoreScript.new().load_from_town(town_directory)
	if trader_load.ok: trader_data = trader_load.data
	else: push_warning(trader_load.message)
	# Role migration preserves legacy trader IDs, locations and saved stock.
	storyline_npc_data = TraderStoreScript.classify_placements(storyline_npc_data, trader_data)
	var venue_notes := LocationNotesScript.new().load_from_town(town_directory)
	if venue_notes.ok:
		location_notes_data = venue_notes.data
		location_note_texts = venue_notes.texts
		for warning in venue_notes.warnings: push_warning(warning)
	else: push_warning(venue_notes.message)
	_prepare_dialogue_context()
	var projection: Dictionary = collision_data.projection
	var scale: float = collision_data.runtime_scale.pixels_per_metre
	var driving_settings: Dictionary = settings_result.data.get("driving", {})
	character_zoom = float(settings_result.data.get("camera", {}).get("character_zoom", 2.7))
	# Retain the established JSON key for older towns, but treat its value as
	# an independent in-car camera zoom rather than a walking-view multiplier.
	in_car_zoom = float(driving_settings.get("camera_zoom_multiplier", 1.5))

	renderer = WorldRendererScript.new()
	add_child(renderer)
	renderer.setup(features, collision_data, town.map_bounds, building_exterior_data, town_directory)
	interior_layer = RuntimeInteriorLayerScript.new()
	interior_layer.set_town_directory(town_directory)
	add_child(interior_layer)
	_build_runtime_interior_entrances(features, projection, scale)
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
	var destination_data: Dictionary = {}
	var destination_path := town_directory.path_join("data").path_join("population_destinations.json")
	if FileAccess.file_exists(destination_path):
		var destination_result := _read_json(destination_path)
		if destination_result.ok:
			destination_data = destination_result.data
	if destination_data.is_empty():
		# Older projects gain the same deterministic behaviour in memory. Rebuild
		# later saves the canonical file for inspection and validation.
		destination_data = PopulationDestinationsScript.new().build(features, navigation_result.data, information_data).data
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
	wagon.configure(driving_settings, float(collision_data.runtime_scale.pixels_per_metre))
	var odometer_result: Dictionary = wagon.odometer.load_for_town(town_directory, not OS.get_cmdline_user_args().has("--capture-runtime") and not OS.get_cmdline_user_args().has("--verify-runtime"))
	odometer_load_message = str(odometer_result.message)
	if not odometer_load_message.is_empty():
		push_warning(odometer_load_message)
	wagon.position = ProjectionScript.geographic_to_world(ProjectionScript.value_to_location(town.starting_location.vehicle), projection, scale)
	wagon.rotation = deg_to_rad(float(town.starting_location.vehicle.get("rotation_degrees", 0.0)))
	wagon.set_ground_check(renderer.is_ground_traversable)
	wagon.set_drivable_pose_check(renderer.is_vehicle_pose_on_surface_road)
	wagon.gear_changed.connect(_on_wagon_gear_changed)
	wagon.gear_change_denied.connect(_on_wagon_gear_change_denied)
	wagon.z_index = 4
	add_child(wagon)
	player.crossing_travel.corridors = renderer.crossing_corridors
	wagon.crossing_travel.corridors = renderer.crossing_corridors
	_add_start_marker()

	population = PopulationScript.new()
	population.z_index = 3
	add_child(population)
	population.set_interior_visibility_check(interior_layer.is_position_discovered)
	interior_layer.room_discovery_changed.connect(population.queue_redraw)
	population.set_persona_library(persona_data)
	population.set_storyline_npcs(storyline_npc_data)
	population.set_ground_check(renderer.is_ground_traversable)
	population.set_building_segment_check(renderer._segment_clear_of_buildings)
	population.set_vehicle_road_segments(renderer.road_segments)
	var traffic_obstacles: Array[Node2D] = [player, wagon]
	population.set_gameplay_obstacles(traffic_obstacles)
	population.setup(navigation_result.data, settings_result.data, projection, scale, town.cbd.bounds, str(town.id), town.map_bounds, features, destination_data)
	population.set_bridge_corridors(renderer.crossing_corridors)
	population.set_simulation_focus(player.position)
	# The owned car collides with actual visible walkers through actor_check.
	# A whole reserved walking route is not a physical wall across the road.
	wagon.actor_check = population.player_vehicle_may_move
	player.actor_motion = population.player_on_foot_motion
	wagon.actor_contact_check = population.player_vehicle_contact
	wagon.actor_impact = population.apply_player_impact
	conversation_layer = RuntimeConversationLayerScript.new()
	add_child(conversation_layer)
	object_identification_bubble = RuntimeObjectBubbleScript.new()
	add_child(object_identification_bubble)
	dialogue_client = OllamaDialogueClientScript.new()
	add_child(dialogue_client)
	dialogue_client.reply_partial.connect(_on_dialogue_partial)
	dialogue_client.reply_ready.connect(_on_dialogue_reply)
	wikipedia_client = WikipediaTownContextScript.new()
	add_child(wikipedia_client)
	wikipedia_client.completed.connect(_on_wikipedia_town_context_completed)
	llm_startup_loader = LocalLlmStartupLoaderScript.new()
	add_child(llm_startup_loader)
	llm_startup_loader.completed.connect(_on_local_llm_startup_completed)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * character_zoom
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	renderer.update_detail_view(player.position, character_zoom, GAME_VIEW_SIZE)
	_build_hud()
	var verify_llm_startup := OS.get_cmdline_user_args().has("--verify-llm-startup")
	if DisplayServer.get_name() == "headless" and not verify_llm_startup:
		# Focused headless gameplay checks do not depend on a local desktop service.
		local_llm_available = true
	else:
		_start_local_llm_loading()
	if not odometer_load_message.is_empty():
		_notice(odometer_load_message)
	elif not inventory_load_message.is_empty():
		_notice(inventory_load_message)
	elif not stats_load_message.is_empty():
		_notice(stats_load_message)
	collisions.update_streaming(player.position)
	print("PLAYABLE TOWN PREVIEW READY: %s" % str(town.get("display_name", town_directory.get_file())))
	if OS.get_cmdline_user_args().has("--verify-runtime"):
		call_deferred("_verify_runtime")
	if OS.get_cmdline_user_args().has("--verify-interior"):
		call_deferred("_verify_loaded_interior")
	if OS.get_cmdline_user_args().has("--verify-conversation"):
		call_deferred("_verify_conversation")
	var capture_path := _argument_value("--capture-runtime")
	if not capture_path.is_empty():
		call_deferred("_capture_runtime", capture_path)


func _process(delta: float) -> void:
	if player == null or wagon == null or camera == null or collisions == null or tracks == null or renderer == null or population == null or hud_label == null:
		return
	if llm_startup_active:
		return
	notice_time = maxf(0.0, notice_time - delta)
	_process_pending_entry(delta)
	if not inside_building_id.is_empty():
		_process_interior()
		return
	if conversation_active:
		_process_conversation()
		return
	var focus: CharacterBody2D = wagon if occupied else player
	population.set_simulation_focus(focus.position)
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
		renderer.update_detail_view(camera.position, camera.zoom.x, GAME_VIEW_SIZE)
	population.set_draw_view(camera.position, camera.zoom.x, overview, GAME_VIEW_SIZE)
	renderer.update_street_label_presentation(camera.zoom.x, overview_zoom, overview)
	collisions.update_streaming(focus.position)
	var moving: bool = absf(wagon.speed) > 1.0 if occupied else player.walking
	tracks.update_tracks(delta, focus, moving, occupied, renderer.is_grass)
	var odometer_save: Dictionary = wagon.odometer.tick(delta)
	if not odometer_save.ok and wagon.odometer.seconds_since_save >= wagon.odometer.SAVE_INTERVAL_SECONDS:
		_notice(str(odometer_save.message))
	var status_text := ""
	if overview:
		status_text = notice_text if notice_time > 0.0 else "MAP · MOVE THE MOUSE TO CHOOSE A LOCATION"
	elif notice_time > 0.0:
		status_text = notice_text
	elif (wagon_in_tunnel if occupied else player_in_tunnel):
		status_text = "IN TUNNEL · route continues below the surface"
	elif on_bridge:
		status_text = "ON BRIDGE · upper road layer · traffic below stays on its own route"
	elif underpass_index >= 0:
		status_text = "UNDER BRIDGE · following the lower road"
	elif occupied:
		status_text = "↑/↓ set cruise by 1 km/h · Shift gear · ← → steer · Space brake · E exit"
	elif not _nearest_interior_entrance().is_empty():
		var nearby_entrance := _nearest_interior_entrance()
		status_text = "E: enter %s · WASD walk · M map" % str(nearby_entrance.get("building_name", "building"))
	elif not _nearest_unlinked_exterior_entrance().is_empty():
		status_text = "DOOR NEEDS INTERIOR LINK · use Interior Designer to place its arrival point"
	elif _near_wagon():
		status_text = "E: enter your white wagon · WASD walk · M map"
	else:
		var wagon_metres := roundi(player.position.distance_to(wagon.position) / float(collision_data.runtime_scale.pixels_per_metre))
		status_text = "ON FOOT · YOUR WAGON: %dm · WASD walk · E enter · M map" % wagon_metres
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
	speedometer_gauge.visible = occupied and not overview
	if speedometer_gauge.visible:
		speedometer_gauge.update_readings(wagon.speed_kmh(), wagon.target_speed_kmh, wagon.reverse_max_speed_kmh if wagon.gear == "R" else wagon.max_speed_kmh, wagon.gear)
	odometer_panel.set_display_state(occupied, overview)
	odometer_panel.update_readings(wagon.odometer.total_metres, wagon.odometer.trip_metres)
	hud_help.text = "Mouse selects location · Copy location · wheel/−/+ zoom · drag · M close" if overview else "T talk · E interact · M map · F11 full screen · Esc close"
	map_coordinates.visible = overview
	map_copy_button.visible = overview
	map_cursor_marker.visible = overview
	if overview:
		_update_map_cursor_location()
	_update_building_popup(covered_view)


func _process_interior() -> void:
	interior_layer.update_player_position(player.position)
	population.set_simulation_focus(exterior_return_position)
	renderer.visible = false
	population.visible = true
	tracks.visible = false
	wagon.visible = false
	interior_layer.visible = true
	tunnel_background.visible = false
	var start_marker := get_node_or_null("StartingLocationMarker") as CanvasItem
	if start_marker != null:
		start_marker.visible = false
	player.visible = true
	if not overview:
		camera.position = player.position + player.velocity * 0.2
		camera.zoom = Vector2.ONE * character_zoom
	# Population culling normally follows the outdoor camera. Refresh it with
	# interior-local coordinates or valid indoor storyline NPCs are filtered out.
	population.set_draw_view(camera.position, camera.zoom.x, overview, GAME_VIEW_SIZE)
	collisions.update_streaming(exterior_return_position)
	speedometer_gauge.visible = false
	odometer_panel.set_display_state(false, false)
	building_popup.hide()
	var room_name: String = interior_layer.current_room_name(player.position)
	var floor_heading := inside_floor_name.to_upper()
	if not room_name.is_empty(): floor_heading += " · " + room_name.to_upper()
	if overview:
		hud_label.size.x = 425.0
		hud_label.text = "INTERIOR MAP %d×\n%s · %s" % [roundi(overview_zoom), inside_building_name.to_upper(), floor_heading]
		hud_status.text = notice_text if notice_time > 0.0 else "INTERIOR MAP · MOVE THE MOUSE TO CHOOSE A LOCATION"
		hud_help.text = "Mouse selects interior X/Y · Copy location · wheel/−/+ zoom · drag · M close"
		map_coordinates.visible = true
		map_copy_button.visible = true
		map_cursor_marker.visible = true
		map_buttons.visible = true
		_update_map_cursor_location()
		return
	hud_label.size.x = 560.0
	hud_label.text = "%s\n%s" % [inside_building_name.to_upper(), floor_heading]
	var internal_door: Dictionary = interior_layer.nearest_internal_door(player.position, maxf(12.0, float(interior_layer.pixels_per_metre) * 1.8))
	if _near_interior_exit():
		hud_status.text = "E: exit building"
	elif not internal_door.is_empty():
		hud_status.text = "E: locked internal door" if bool(internal_door.get("door", {}).get("locked", false)) else "E: enter through internal doorway"
	else:
		hud_status.text = "INSIDE · WASD walk · green doors use E · red doors are locked"
	hud_help.text = "WASD walk · E use doors/exits · M map · F11 full screen · Esc close"
	# Location details belong to the map, not over normal play or dialogue.
	map_coordinates.visible = false
	map_copy_button.visible = false
	map_cursor_marker.visible = false
	map_buttons.visible = false


func _process_conversation() -> void:
	var target_position: Vector2 = population.conversation_target_position(conversation_target_index)
	if target_position == Vector2.INF:
		_end_conversation("The character moved away.")
		return
	var midpoint: Vector2 = player.position.lerp(target_position, 0.5) + Vector2(0, -4)
	var distance: float = player.position.distance_to(target_position)
	var framing_zoom := minf(character_zoom * 1.5, 540.0 / maxf(distance + 70.0, 1.0))
	camera.position = midpoint
	camera.zoom = Vector2.ONE * maxf(character_zoom, framing_zoom)
	var conversation_is_inside := not inside_building_id.is_empty()
	renderer.visible = not conversation_is_inside
	population.visible = true
	tracks.visible = not conversation_is_inside
	wagon.visible = not conversation_is_inside
	interior_layer.visible = conversation_is_inside
	tunnel_background.visible = false
	population.set_simulation_focus(midpoint)
	population.set_draw_view(midpoint, camera.zoom.x, false, GAME_VIEW_SIZE)
	if not conversation_is_inside:
		renderer.update_detail_view(midpoint, camera.zoom.x, GAME_VIEW_SIZE)
	player.visible = true
	if not conversation_is_inside:
		collisions.update_streaming(midpoint)
	var target_name: String = population.conversation_target_name(conversation_target_index)
	hud_label.size.x = 560.0
	hud_label.text = "CONVERSATION · %s" % target_name
	hud_status.text = "%s is replying…" % target_name if conversation_waiting else "Type a message below and press Enter or Send."
	hud_help.text = "Short local Ollama conversation · Esc or End finishes"
	speedometer_gauge.visible = false
	odometer_panel.set_display_state(false, false)
	map_coordinates.visible = false
	map_buttons.visible = false
	building_popup.hide()


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
	var expected_population: int = (
		int(population_settings.get("traffic_car_count", 0))
		+ int(population_settings.get("pedestrian_count", 0))
		+ int(population_settings.get("robot_count", 0))
		+ int(population_settings.get("drone_count", 0))
		+ storyline_npc_data.get("npcs", []).size()
	)
	assert(population.agents.size() == expected_population, "Expected %d road users but generated %d." % [expected_population, population.agents.size()])
	var gender_counts := {"man": 0, "woman": 0}
	var roaming_gender_counts := {"man": 0, "woman": 0}
	var age_counts := {"young": 0, "adult": 0, "older": 0}
	var vehicle_styles := {"sedan": 0, "wagon": 0, "ute": 0}
	var vehicle_assets := {}
	for road_user in population.agents:
		if str(road_user.kind) == "person":
			gender_counts[str(road_user.gender)] += 1
			if str(road_user.get("storyline_npc_id", "")).is_empty():
				roaming_gender_counts[str(road_user.gender)] += 1
			age_counts[str(road_user.age_group)] += 1
			assert(not ActorArt.sprite(str(road_user.npc_asset)).is_empty())
		elif str(road_user.kind) == "traffic":
			vehicle_styles[str(road_user.vehicle_style)] += 1
			vehicle_assets[str(road_user.vehicle_asset)] = true
	assert(roaming_gender_counts.woman == ceili(float(population_settings.get("pedestrian_count", 0)) / 2.0))
	assert(roaming_gender_counts.man == int(population_settings.get("pedestrian_count", 0)) - roaming_gender_counts.woman)
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
	var expected_maximum_kmh := float(game_settings.get("driving", {}).get("max_speed_kmh", 200.0))
	assert(is_equal_approx(wagon.max_speed_kmh, expected_maximum_kmh))
	assert(is_equal_approx(wagon.forward_speed, expected_maximum_kmh / 3.6 * float(collision_data.runtime_scale.pixels_per_metre)))
	assert(player.get_script() == PlayerScript and wagon.get_script() == PlayerVehicleScript)
	assert(collisions.loaded_chunks.size() > 0)
	assert(get_window().content_scale_size == GAME_VIEW_SIZE)
	assert(hud_label.position == Vector2(8, 3) and hud_status.position == Vector2(8, 332))
	assert(player_inventory.quantity("keks") >= 0 and player_inventory.quantity("bananas") >= 0 and player_inventory.quantity("water_bottles") >= 0)
	assert(player_stats != null and player_stats.nutrient >= 0 and player_stats.nutrient <= 100 and player_stats.hydration >= 0 and player_stats.hydration <= 100)
	assert(inventory_panel != null and inventory_panel.BACKPACK_RECT.position.x >= 580.0)
	assert(player_stats_panel != null and not player_stats_panel.is_open(), "Player stats should start hidden behind its top-right button.")
	inventory_panel.set_open(true)
	assert(inventory_panel.is_open() and not _screen_can_select_building(inventory_panel.LIST_RECT.get_center()), "The backpack item list did not open or leaked clicks into the map.")
	inventory_panel.set_open(false)
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


func _verify_loaded_interior() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	assert(not interior_entrances.is_empty(), "The loaded test town has no linked playable interior entrance.")
	var entrance: Dictionary = interior_entrances[0]
	player.position = Vector2(entrance.world_position)
	var found := _nearest_interior_entrance()
	assert(not found.is_empty(), "The saved exterior arrow was not detected as an E interaction.")
	_enter_interior(found)
	assert(not inside_building_id.is_empty() and player.interior_mode, "The player did not transfer inside.")
	_process(0.0)
	assert(interior_layer.visible and not renderer.visible and population.visible, "The interior view did not replace the outdoor view or retain indoor storyline characters.")
	assert(not map_coordinates.visible, "Interior location details were still drawn over the playable view.")
	_toggle_map()
	_process(0.0)
	assert(overview and map_coordinates.visible and map_copy_button.visible and map_cursor_marker.visible, "M did not open the interior map and its location-copy controls.")
	assert(str(map_coordinates.text).contains("Building:") and str(map_coordinates.text).contains("Floor: ground_floor"), "The interior map did not identify its building and ground floor.")
	assert(str(map_copy_text).begins_with("Interior: building="), "The interior map did not prepare plain paste-ready location text.")
	_toggle_map()
	_process(0.0)
	assert(not overview and not map_coordinates.visible and player.controls_enabled, "Closing the interior map did not restore clean playable movement.")
	player.position = interior_layer.exit_position
	_try_exit_interior()
	assert(inside_building_id.is_empty() and not player.interior_mode and renderer.visible, "The player did not return outside.")
	assert(player.position == Vector2(entrance.world_position), "The player returned to the wrong exterior entrance.")
	_toggle_map()
	_process(0.0)
	assert(str(map_coordinates.text).contains("Cursor latitude:") and str(map_coordinates.text).contains("Cursor longitude:"), "The outdoor map did not follow the mouse with latitude/longitude.")
	assert(StorylineNpcStoreScript.parse_location_text(map_copy_text).ok, "The outdoor map did not prepare paste-ready latitude/longitude text.")
	_toggle_map()
	print("LOADED INTERIOR PLAY TEST PASSED: interior and outdoor M maps follow the mouse with paste-ready locations, normal play stays clear, and E exits to the exterior arrow.")
	get_tree().quit()


func _verify_conversation() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	var named_people := 0
	var named_robots := 0
	var npc_persona_ids: Dictionary = {}
	var character_names: Dictionary = {}
	for agent_value in population.agents:
		var agent: Dictionary = agent_value
		var kind := str(agent.get("kind", ""))
		if kind == "person":
			assert(not str(agent.get("display_name", "")).is_empty(), "An NPC was created without a random name.")
			assert(not character_names.has(str(agent.display_name)), "Two characters received the same random name.")
			character_names[str(agent.display_name)] = true
			assert(not str(agent.get("persona_id", "")).is_empty(), "An NPC was created without a random-pool persona.")
			named_people += 1
			npc_persona_ids[str(agent.persona_id)] = true
		elif kind == "robot":
			assert(not str(agent.get("display_name", "")).is_empty(), "An NPR was created without a random serial name.")
			assert(not character_names.has(str(agent.display_name)), "Two characters received the same random name.")
			character_names[str(agent.display_name)] = true
			named_robots += 1
	assert(named_people > 0 and named_robots > 0, "The conversation fixture needs named NPCs and NPRs.")
	assert(npc_persona_ids.size() >= 2, "The NPC population did not exercise random persona assignment.")
	var target_index := -1
	var synthetic_target := false
	for index in population.agents.size():
		if str(population.agents[index].get("kind", "")) in ["person", "robot"] and not bool(population.agents[index].get("route_bridge", false)) and not bool(population.agents[index].get("route_tunnel", false)):
			target_index = index
			break
	if target_index < 0:
		synthetic_target = true
		population.agents.append({
			"kind": "person", "position": player.position + Vector2(12, 0), "target": player.position + Vector2(12, 0),
			"phase": 0.0, "moving": false, "angle": PI, "npc_asset": "npc_medium_man_adult",
			"route_bridge": false, "route_tunnel": false, "speed": 30.0
		})
		target_index = population.agents.size() - 1
	player.position = Vector2(population.agents[target_index].position)
	var talk_event := InputEventKey.new()
	talk_event.keycode = KEY_T
	talk_event.pressed = true
	_unhandled_input(talk_event)
	assert(conversation_active and conversation_target_index == target_index, "T did not select the nearby NPC/NPR.")
	assert(not player.controls_enabled and bool(population.agents[target_index].conversation_paused), "Conversation did not pause both participants.")
	assert(conversation_input.visible and conversation_send_button.visible, "The typed dialogue controls were not shown.")
	conversation_waiting = true
	conversation_input.editable = false
	conversation_send_button.disabled = true
	_on_dialogue_partial("Nice to")
	assert(conversation_layer.target_text == "Nice to", "A streamed partial reply did not update the NPC/NPR bubble.")
	_on_dialogue_reply(true, "Nice to meet you.", "Reply received.")
	_process(0.0)
	assert(conversation_greeted and conversation_layer.target_text == "Nice to meet you.", "The NPC/NPR reply did not reach its speech bubble.")
	assert(conversation_input.editable and not conversation_send_button.disabled, "Dialogue input did not reopen after the reply.")
	assert(camera.zoom.x > character_zoom, "The camera did not zoom in on the conversation.")
	_unhandled_input(talk_event)
	assert(not conversation_active and player.controls_enabled and not bool(population.agents[target_index].conversation_paused), "Ending the conversation did not restore movement.")
	assert(not conversation_input.visible and not conversation_send_button.visible, "Dialogue controls stayed visible after the conversation ended.")
	assert(is_equal_approx(camera.zoom.x, character_zoom), "Ending the conversation did not restore the walking camera.")
	if synthetic_target:
		population.agents.remove_at(target_index)
	print("PERSONA CONVERSATION PASSED: every NPC/NPR has a random name, NPC personas come from the random pool, streamed text reaches the bubble, and movement/zoom restore.")
	get_tree().quit()


func _capture_runtime(path_value: String) -> void:
	# Allow the canvas, camera and first population positions to render before the
	# focused visual check captures the actual running scene.
	# Captures verify the map/UI rather than the optional desktop Ollama service.
	if llm_startup_active:
		_continue_without_local_llm()
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
	elif capture_focus == "speedometer":
		occupied = true
		wagon.occupied = true
		player.active = false
		wagon.set_cruise_target(80.0)
		wagon.speed = wagon.kilometres_per_hour_to_world_speed(45.0)
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
	elif capture_focus == "conversation":
		var target_index := -1
		for index in population.agents.size():
			if str(population.agents[index].get("kind", "")) in ["person", "robot"] and not bool(population.agents[index].get("route_bridge", false)) and not bool(population.agents[index].get("route_tunnel", false)):
				target_index = index
				break
		assert(target_index >= 0, "The capture town needs an NPC or NPR.")
		player.position = Vector2(population.agents[target_index].position) + Vector2(-12, 0)
		_start_conversation()
		_on_dialogue_reply(true, "Hello from the local persona.", "Reply received.")
		_process_conversation()
		print("CONVERSATION CAPTURE: typed local persona dialogue with %s" % ("NPR" if population.conversation_target_kind(conversation_target_index) == "robot" else "NPC"))
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
	elif capture_focus == "interior-map":
		assert(not interior_entrances.is_empty(), "The capture town needs a linked playable interior.")
		var entrance: Dictionary = interior_entrances[0]
		player.position = Vector2(entrance.world_position)
		_enter_interior(entrance)
		assert(not inside_building_id.is_empty(), "The capture could not enter the selected interior.")
		overview = true
		player.controls_enabled = false
		wagon.controls_enabled = false
		map_buttons.visible = true
		camera.position_smoothing_enabled = false
		_fit_overview()
		map_cursor_screen_position = MAP_PLAY_AREA.get_center()
		_process_interior()
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
	renderer.update_detail_view(camera.position, camera.zoom.x, GAME_VIEW_SIZE)
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
	if shop != null and shop.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: shop.close()
		return
	if llm_startup_active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_continue_without_local_llm()
		return
	if overview and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			map_pointer_down = _screen_can_select_building(event.position) if inside_building_id.is_empty() else _screen_can_select_interior_object(event.position)
			map_press_position = event.position
			map_dragging = false
		else:
			var was_dragging := map_dragging
			map_pointer_down = false
			map_dragging = false
			if was_dragging:
				get_viewport().set_input_as_handled()
				return
			if inside_building_id.is_empty() and _screen_can_select_building(event.position):
				var record := _building_at_screen(event.position)
				pinned_building_id = str(record.get("feature_id", ""))
				building_popup_anchor = event.position
				_update_building_popup(false)
		get_viewport().set_input_as_handled()
		return
	if overview and map_pointer_down and event is InputEventMouseMotion:
		if not map_dragging and event.position.distance_to(map_press_position) >= 5.0:
			map_dragging = true
			camera.position -= (event.position - map_press_position) / camera.zoom
			pinned_building_id = ""
			building_popup.hide()
		elif map_dragging:
			camera.position -= event.relative / camera.zoom
		get_viewport().set_input_as_handled()
		return
	if not inside_building_id.is_empty() and not overview and not conversation_active and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _screen_can_select_interior_object(event.position):
		var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		var selected_object: Dictionary = interior_layer.furniture_at_world(world_position)
		if not selected_object.is_empty():
			object_identification_bubble.show_object(player, BuildingInteriorStoreScript.object_description(selected_object))
			get_viewport().set_input_as_handled()
			return
	if inside_building_id.is_empty() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _screen_can_select_building(event.position):
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE:
			if inventory_panel != null and inventory_panel.close_topmost():
				pass
			elif player_stats_panel != null and player_stats_panel.is_open():
				player_stats_panel.set_open(false)
			elif conversation_active:
				_end_conversation("Conversation ended.")
			elif overview:
				_toggle_map()
			else:
				get_tree().quit()
		elif event.keycode == KEY_T:
			if conversation_active:
				_end_conversation("Conversation ended.")
			elif overview:
				_notice("Close the town map before talking.")
			elif occupied:
				_notice("Exit the wagon before starting a conversation.")
			else:
				_start_conversation()
		elif conversation_active:
			return
		elif event.keycode == KEY_M:
			_toggle_map()
		elif overview and event.keycode == KEY_C:
			_copy_map_location()
		elif overview and event.keycode in [KEY_EQUAL, KEY_KP_ADD]:
			_zoom_overview(1.5)
		elif overview and event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_zoom_overview(1.0 / 1.5)
		elif overview and event.keycode == KEY_HOME:
			_fit_overview()
		elif overview and event.keycode == KEY_F:
			camera.position = wagon.position if occupied else player.position
		elif event.keycode == KEY_E and not overview:
			pending_entry_time = 0.0
			if conversation_active:
				return
			if not inside_building_id.is_empty():
				if _near_interior_exit():
					_try_exit_interior()
				else:
					_try_internal_door()
			elif occupied:
				_toggle_wagon()
			else:
				if not _request_outdoor_entry(): _toggle_wagon()


func _start_conversation() -> void:
	if object_identification_bubble != null: object_identification_bubble.hide_bubble()
	var maximum_distance := maxf(32.0, 8.0 * float(collision_data.get("runtime_scale", {}).get("pixels_per_metre", 1.0)))
	var target: Dictionary = population.nearest_conversation_target(player.position, maximum_distance)
	if target.is_empty():
		_notice("Move closer to an NPC or NPR, then press T.")
		return
	conversation_target_index = int(target.index)
	if not population.begin_conversation(conversation_target_index, player.position):
		_notice("That character is not available to talk.")
		conversation_target_index = -1
		return
	conversation_active = true
	conversation_greeted = false
	conversation_waiting = false
	conversation_history.clear()
	conversation_persona = population.conversation_target_persona(conversation_target_index)
	if conversation_persona.is_empty():
		conversation_persona = PersonaStoreScript.find_persona(PersonaStoreScript.recommended_data(), "civic_robot" if population.conversation_target_kind(conversation_target_index) == "robot" else "friendly_local")
	# A name identifies this particular random town resident. The separately
	# assigned persona controls only how the character speaks.
	conversation_persona = conversation_persona.duplicate(true)
	conversation_trader_id = str(population.agents[conversation_target_index].get("storyline_npc_id", ""))
	conversation_trader = trader_data.get("traders", {}).get(conversation_trader_id, {})
	if str(population.agents[conversation_target_index].get("npc_role", "trader" if not conversation_trader.is_empty() else "storyline")) != "trader": conversation_trader = {}
	if bool(conversation_trader.get("enabled", false)):
		var trader_persona := TraderStoreScript.persona(str(conversation_trader.get("persona_id", "")), persona_data)
		if not trader_persona.is_empty(): conversation_persona = trader_persona
	else: conversation_trader = {}
	conversation_persona["character_name"] = population.conversation_target_name(conversation_target_index)
	var has_shop := not conversation_trader.is_empty()
	conversation_shop_button.visible = has_shop
	conversation_input.size.x = 330.0 if has_shop else 392.0
	conversation_send_button.position.x = 400.0 if has_shop else 462.0
	if has_shop: shop.bind_trader(player_inventory, item_catalog_data, town_directory, conversation_trader_id, conversation_trader, str(conversation_persona.character_name))
	player.controls_enabled = false
	player.velocity = Vector2.ZERO
	player.walking = false
	var target_position: Vector2 = population.conversation_target_position(conversation_target_index)
	player.facing = player.position.direction_to(target_position)
	conversation_layer.start(player, population, conversation_target_index)
	conversation_layer.show_reply(str(conversation_persona.get("greeting", "Hello.")))
	conversation_input.visible = true
	conversation_input.editable = true
	conversation_input.clear()
	conversation_input.grab_focus()
	conversation_send_button.visible = true
	conversation_send_button.disabled = false
	conversation_end_button.visible = true
	_notice("Conversation started. Type a short message.")


func _submit_conversation(message: String = "") -> void:
	if shop != null and shop.visible: return
	if not conversation_active or conversation_waiting:
		return
	var player_text := message if not message.is_empty() else conversation_input.text
	player_text = player_text.strip_edges()
	if player_text.is_empty(): return
	if player_text.length() > OllamaDialogueClientScript.MAX_PLAYER_TEXT:
		_notice("Keep the message under 280 characters.")
		return
	var live_stock: Dictionary = {}
	if not conversation_trader.is_empty():
		live_stock = _refresh_trader_context(conversation_trader_id)
		var recognised := TraderDialoguePolicy.classify(player_text, live_stock, item_catalog_data)
		if bool(recognised.get("handled", false)):
			conversation_history.append({"role": "user", "content": player_text})
			conversation_history.append({"role": "assistant", "content": recognised.reply})
			conversation_input.clear()
			conversation_layer.show_reply(str(recognised.reply))
			if recognised.has("item_id"): shop.propose(str(recognised.item_id), recognised.quantity)
			return
	if not local_llm_available:
		_notice("Local conversations are unavailable. Restart the map after starting Ollama; Shop still works.")
		return
	var dialogue_context := TownKnowledgeStoreScript.conversation_context(
		town_knowledge_data,
		town_custom_text,
		str(town.get("display_name", town_directory.get_file())),
		player_text
	)
	var actor_location: Dictionary = {"space": "outdoors"}
	if conversation_target_index >= 0 and conversation_target_index < population.agents.size():
		actor_location = population.agents[conversation_target_index]
	dialogue_context += "\n" + LocationNotesScript.conversation_context(location_notes_data, location_note_texts, actor_location, building_interior_data, player_text)
	var start_result: Dictionary = dialogue_client.ask(
		conversation_persona,
		player_text,
		conversation_history,
		persona_data.get("provider", {}),
		dialogue_context,
		persona_data.get("personas", []),
		live_stock,
		prepared_dialogue_system
	)
	if not start_result.ok:
		_notice(start_result.message)
		return
	conversation_history.append({"role": "user", "content": player_text})
	conversation_input.clear()
	conversation_input.editable = false
	conversation_send_button.disabled = true
	conversation_waiting = true
	conversation_layer.show_reply("…")


func _on_dialogue_partial(reply: String) -> void:
	if not conversation_active or not conversation_waiting or reply.is_empty():
		return
	conversation_layer.show_reply(reply)


func _on_dialogue_reply(ok: bool, reply: String, message: String) -> void:
	if not conversation_active:
		return
	conversation_waiting = false
	conversation_input.editable = true
	conversation_send_button.disabled = false
	if ok:
		if not conversation_trader.is_empty():
			var last_player_text := ""
			for line in conversation_history:
				if str(line.get("role", "")) == "user": last_player_text = str(line.get("content", ""))
			var checked := TraderDialoguePolicy.validate_reply(reply, dialogue_client.purchase_suggestion, _refresh_trader_context(conversation_trader_id), item_catalog_data, last_player_text)
			reply = str(checked.reply)
			dialogue_client.purchase_suggestion = checked.suggestion
		conversation_greeted = true
		conversation_history.append({"role": "assistant", "content": reply})
		conversation_layer.show_reply(reply)
		if not conversation_trader.is_empty() and not dialogue_client.purchase_suggestion.is_empty():
			shop.propose(str(dialogue_client.purchase_suggestion.item_id), dialogue_client.purchase_suggestion.quantity)
	else:
		conversation_layer.show_reply("Sorry, I can't talk right now.")
		_notice(message)
	if shop == null or not shop.visible: conversation_input.grab_focus()


func _end_conversation(message: String) -> void:
	if shop != null: shop.close()
	conversation_trader = {}
	conversation_trader_id = ""
	if conversation_shop_button != null: conversation_shop_button.hide()
	if conversation_target_index >= 0:
		population.end_conversation(conversation_target_index)
	conversation_layer.finish()
	if dialogue_client != null:
		dialogue_client.cancel()
	conversation_active = false
	conversation_greeted = false
	conversation_waiting = false
	conversation_history.clear()
	conversation_persona = {}
	conversation_target_index = -1
	player.controls_enabled = true
	conversation_input.visible = false
	conversation_send_button.visible = false
	conversation_end_button.visible = false
	camera.position = player.position
	camera.zoom = Vector2.ONE * character_zoom
	_notice(message)


func _on_trade_accepted(quote: Dictionary) -> void:
	if not conversation_active or conversation_trader.is_empty() or str(quote.get("npc_id", "")) != conversation_trader_id: return
	var result := TradeServiceScript.purchase(player_inventory, conversation_trader, item_catalog_data, quote)
	shop.status.text = result.message
	shop.refresh()
	if result.ok:
		_refresh_trader_context(conversation_trader_id)
		inventory_panel.refresh()
		conversation_layer.show_reply("Here you go, thanks!")
		trade_completed.emit(result.trade)
	_notice(result.message)


func _build_runtime_interior_entrances(features: Array, projection: Dictionary, scale: float) -> void:
	interior_entrances.clear()
	unlinked_exterior_entrances.clear()
	var active_feature_ids: Dictionary = {}
	var linked_keys: Dictionary = {}
	for feature_value in features:
		if feature_value is Dictionary and str(feature_value.get("kind", "")) == "building":
			active_feature_ids[str(feature_value.get("id", ""))] = true
	for feature_id_value in building_interior_data.get("buildings", {}):
		var feature_id := str(feature_id_value)
		if not active_feature_ids.has(feature_id):
			continue
		var interior_record: Dictionary = building_interior_data.buildings[feature_id]
		var floors: Array = interior_record.get("floors", [])
		if floors.is_empty():
			continue
		var ground_floor: Dictionary = floors[0]
		var exterior_record: Dictionary = building_exterior_data.get("buildings", {}).get(feature_id, {})
		var doors: Array = exterior_record.get("doors", [exterior_record.door] if exterior_record.has("door") else [])
		for link_value in ground_floor.get("entry_links", []):
			var link: Dictionary = link_value
			var entrance_id := str(link.get("exterior_entrance_id", ""))
			for door_value in doors:
				var door: Dictionary = door_value
				if str(door.get("id", "")) != entrance_id:
					continue
				var outside_location := Vector2(float(door.get("outside_longitude", 0.0)), float(door.get("outside_latitude", 0.0)))
				interior_entrances.append({
					"feature_id": feature_id,
					"building_name": str(exterior_record.get("custom_name", interior_record.get("name", "Building"))),
					"world_position": ProjectionScript.geographic_to_world(outside_location, projection, scale),
					"record": interior_record,
					"floor": ground_floor,
					"link": link
				})
				linked_keys["%s:%s" % [feature_id, entrance_id]] = true
				break
	for feature_id_value in building_exterior_data.get("buildings", {}):
		var feature_id := str(feature_id_value)
		if not active_feature_ids.has(feature_id):
			continue
		var record: Dictionary = building_exterior_data.buildings[feature_id]
		var doors: Array = record.get("doors", [record.door] if record.has("door") else [])
		for door_value in doors:
			var door: Dictionary = door_value
			var entrance_id := str(door.get("id", ""))
			if linked_keys.has("%s:%s" % [feature_id, entrance_id]):
				continue
			var outside_location := Vector2(float(door.get("outside_longitude", 0.0)), float(door.get("outside_latitude", 0.0)))
			unlinked_exterior_entrances.append({
				"feature_id": feature_id,
				"building_name": str(record.get("name", "Building")),
				"world_position": ProjectionScript.geographic_to_world(outside_location, projection, scale)
			})


func _request_outdoor_entry() -> bool:
	var entrance := _nearest_interior_entrance()
	if not entrance.is_empty():
		_enter_interior(entrance)
		return true
	if not _nearest_unlinked_exterior_entrance().is_empty():
		_notice("This door is not linked yet. In Interior Designer, choose it and place its ground-floor entry point.")
		return true
	# Remember an early E press only when already approaching a linked door.
	# Do not enlarge the usable radius or require crossing its solid footprint.
	var scale := float(collision_data.get("runtime_scale", {}).get("pixels_per_metre", 1.0))
	var approach_radius: float = maxf(12.0, 3.5 * scale) + float(player.walk_speed) * ENTRY_PRESS_GRACE_SECONDS
	for candidate in interior_entrances:
		if player.position.distance_to(Vector2(candidate.world_position)) <= approach_radius:
			pending_entry_time = ENTRY_PRESS_GRACE_SECONDS
			_notice("Move to the green entry arrow to enter.")
			return true
	return false


func _process_pending_entry(delta: float) -> void:
	if pending_entry_time <= 0.0: return
	if occupied or overview or conversation_active or not inside_building_id.is_empty():
		pending_entry_time = 0.0
		return
	pending_entry_time = maxf(0.0, pending_entry_time - delta)
	if pending_entry_time <= 0.0: return
	var entrance := _nearest_interior_entrance()
	if not entrance.is_empty():
		pending_entry_time = 0.0
		_enter_interior(entrance)


func _nearest_interior_entrance() -> Dictionary:
	if occupied or not inside_building_id.is_empty():
		return {}
	var nearest: Dictionary = {}
	var threshold := maxf(12.0, 3.5 * float(collision_data.get("runtime_scale", {}).get("pixels_per_metre", 1.0)))
	var nearest_distance := threshold
	for entrance in interior_entrances:
		var distance: float = player.position.distance_to(Vector2(entrance.world_position))
		if distance <= nearest_distance:
			nearest = entrance
			nearest_distance = distance
	return nearest


func _nearest_unlinked_exterior_entrance() -> Dictionary:
	if occupied or not inside_building_id.is_empty():
		return {}
	var nearest: Dictionary = {}
	var threshold := maxf(12.0, 3.5 * float(collision_data.get("runtime_scale", {}).get("pixels_per_metre", 1.0)))
	var nearest_distance := threshold
	for entrance in unlinked_exterior_entrances:
		var distance: float = player.position.distance_to(Vector2(entrance.world_position))
		if distance <= nearest_distance:
			nearest = entrance
			nearest_distance = distance
	return nearest


func _enter_interior(entrance: Dictionary) -> void:
	var scale := float(collision_data.get("runtime_scale", {}).get("pixels_per_metre", 1.0))
	var open_result: Dictionary = interior_layer.open_floor(entrance.record, entrance.floor, entrance.link, scale)
	if not open_result.ok:
		_notice(open_result.message)
		return
	exterior_return_position = Vector2(entrance.world_position)
	inside_building_id = str(entrance.feature_id)
	inside_building_name = str(entrance.building_name)
	inside_floor_id = str(entrance.floor.get("id", "ground_floor"))
	inside_floor_name = str(entrance.floor.get("name", "Ground floor"))
	if population != null and population.has_method("set_active_interior"):
		population.set_active_interior(inside_building_id, inside_floor_id)
	overview = false
	player.set_interior_mode(true)
	player.set_ground_check(interior_layer.is_traversable)
	player.position = Vector2(open_result.position)
	player.velocity = Vector2.ZERO
	_notice("Entered %s. Return to the green marker and press E to leave." % inside_building_name)


func _try_exit_interior() -> void:
	if not _near_interior_exit():
		_notice("Return to the green exit marker before pressing E.")
		return
	player.set_ground_check(renderer.is_ground_traversable)
	player.set_interior_mode(false)
	if object_identification_bubble != null: object_identification_bubble.hide_bubble()
	player.position = exterior_return_position
	player.velocity = Vector2.ZERO
	interior_layer.close_floor()
	inside_building_id = ""
	inside_building_name = ""
	inside_floor_id = ""
	inside_floor_name = ""
	if population != null and population.has_method("set_active_interior"):
		population.set_active_interior()
	renderer.visible = true
	population.visible = true
	tracks.visible = true
	wagon.visible = true
	_notice("Exited the building.")


func _try_internal_door() -> void:
	var result: Dictionary = interior_layer.cross_internal_door(player.position, 4.0 * float(player.art_scale))
	if not result.ok:
		if bool(result.get("locked", false)) and object_identification_bubble != null:
			object_identification_bubble.show_object(player, "The door is locked.", 2.6)
		_notice(result.message)
		return
	player.position = Vector2(result.position)
	player.velocity = Vector2.ZERO
	interior_layer.update_player_position(player.position)
	_notice(result.message)


func _near_interior_exit() -> bool:
	if inside_building_id.is_empty() or interior_layer == null:
		return false
	var threshold := maxf(10.0, 2.5 * float(collision_data.get("runtime_scale", {}).get("pixels_per_metre", 1.0)))
	return player.position.distance_to(interior_layer.exit_position) <= threshold


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
		wagon.set_cruise_target(0.0)
		wagon.speed = 0.0
		wagon.reset_gear()
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
		wagon.set_cruise_target(0.0)
		wagon.reset_gear()
		_notice("Cruise: ↑/↓ set speed · Shift selects Reverse at a stop · ← → steer · Space stops")
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


func _on_trip_reset_requested() -> void:
	var result: Dictionary = wagon.odometer.reset_trip()
	odometer_panel.update_readings(wagon.odometer.total_metres, wagon.odometer.trip_metres)
	_notice("Trip meter reset." if result.ok else str(result.message))


func _on_inventory_consume_requested(item_id: String) -> void:
	var item := ItemCatalogStoreScript.find_item(item_catalog_data, item_id)
	if item.is_empty():
		_notice("That item is no longer in this town's catalogue.")
		return
	var type_value := str(item.get("type", ""))
	var points := int(item.get("nutrient_points", 0)) if type_value == "nutrient" else int(item.get("hydration_points", 0))
	if type_value not in ["nutrient", "hydration"] or points <= 0:
		_notice("%s cannot be consumed." % str(item.get("display_name", "This item")))
		return
	if player_stats.available_gain(type_value) <= 0:
		_notice("%s is already full." % ("Nutrients" if type_value == "nutrient" else "Hydration"))
		return
	var original_quantity: int = player_inventory.quantity(item_id)
	if original_quantity <= 0:
		_notice("There are no %s left." % str(item.get("display_name", "items")))
		return
	var inventory_result: Dictionary = player_inventory.set_quantity(item_id, original_quantity - 1)
	if not inventory_result.ok:
		_notice(str(inventory_result.message))
		return
	var stats_result: Dictionary = player_stats.apply_points(type_value, points)
	if not stats_result.ok:
		# Restore the consumed item if the stat save could not be completed.
		player_inventory.set_quantity(item_id, original_quantity)
		_notice(str(stats_result.message))
		return
	inventory_panel.refresh()
	player_stats_panel.refresh()
	_notice("Consumed 1 %s · %s" % [str(item.get("display_name", "item")).trim_suffix("s"), str(stats_result.message)])


func _exit_tree() -> void:
	if player_stats != null and player_stats.dirty and player_stats.saving_enabled:
		var stats_save: Dictionary = player_stats.save()
		if not stats_save.ok:
			push_warning(str(stats_save.message))
	if player_inventory != null and player_inventory.dirty and player_inventory.saving_enabled:
		var inventory_save: Dictionary = player_inventory.save()
		if not inventory_save.ok:
			push_warning(str(inventory_save.message))
	if is_instance_valid(wagon) and wagon.odometer != null and wagon.odometer.dirty and wagon.odometer.saving_enabled:
		var result: Dictionary = wagon.odometer.save()
		if not result.ok:
			push_warning(str(result.message))


func _on_wagon_gear_changed(gear_name: String) -> void:
	_notice("Reverse selected. ↑/↓ set reverse speed." if gear_name == "R" else "Drive selected. ↑/↓ set cruising speed.")


func _on_wagon_gear_change_denied() -> void:
	_notice("Stop the wagon before changing between Drive and Reverse.")


func _toggle_map() -> void:
	overview = not overview
	map_dragging = false
	map_pointer_down = false
	player.controls_enabled = not overview
	wagon.controls_enabled = not overview
	map_buttons.visible = overview
	if overview:
		if object_identification_bubble != null: object_identification_bubble.hide_bubble()
		var mouse_position := get_viewport().get_mouse_position()
		map_cursor_screen_position = mouse_position if MAP_PLAY_AREA.has_point(mouse_position) else MAP_PLAY_AREA.get_center()
		_fit_overview()
	else:
		camera.position = wagon.position if occupied else player.position
		camera.zoom = Vector2.ONE * (in_car_zoom if occupied else character_zoom)
		map_coordinates.visible = false
		map_copy_button.visible = false
		map_cursor_marker.visible = false


func _fit_overview() -> void:
	# Reserve the top and bottom HUD bars while fitting maps of any dimensions.
	var bounds: Rect2 = renderer.world_bounds
	if not inside_building_id.is_empty() and interior_layer != null:
		bounds = interior_layer.floor_bounds_world()
		var margin := maxf(4.0, float(interior_layer.pixels_per_metre) * 2.0)
		bounds = bounds.grow(margin)
	overview_base_zoom = minf(605.0 / maxf(bounds.size.x, 1.0), 270.0 / maxf(bounds.size.y, 1.0))
	overview_zoom = 1.0
	camera.position = bounds.get_center()
	_apply_overview_zoom()


func _zoom_overview(factor: float) -> void:
	# Relative zoom alone would prevent a geographically large city from ever
	# reaching street level. Bound the final camera scale instead of the map size.
	var maximum_detail := maxf(64.0, 8.0 / maxf(overview_base_zoom, 0.000001))
	overview_zoom = clampf(overview_zoom * factor, 1.0, maximum_detail)
	_apply_overview_zoom()


func _apply_overview_zoom() -> void:
	camera.zoom = Vector2.ONE * overview_base_zoom * overview_zoom
	if inside_building_id.is_empty():
		renderer.update_street_label_presentation(camera.zoom.x, overview_zoom, true)


func _update_map_cursor_location() -> void:
	if not overview:
		return
	var mouse_position := get_viewport().get_mouse_position()
	if _screen_can_choose_map_location(mouse_position):
		map_cursor_screen_position = mouse_position
	map_cursor_marker.position = map_cursor_screen_position - Vector2(7.0, 9.0)
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * map_cursor_screen_position
	var details := _map_location_for_world(world_position)
	map_coordinates.text = str(details.get("display", ""))
	map_copy_text = str(details.get("copy", ""))
	map_copy_button.disabled = map_copy_text.is_empty()


func _map_location_for_world(world_position: Vector2) -> Dictionary:
	if not inside_building_id.is_empty():
		if interior_layer == null:
			return {"display": "Interior location unavailable", "copy": ""}
		var scale := maxf(float(interior_layer.pixels_per_metre), 0.1)
		var metres := world_position / scale
		return {
			"display": "Building: %s\nFloor: %s\nCursor X: %.2f m · Y: %.2f m" % [inside_building_id, inside_floor_id, metres.x, metres.y],
			"copy": StorylineNpcStoreScript.format_interior_location(inside_building_id, inside_floor_id, metres),
			"world": world_position,
			"metres": metres
		}
	var projection: Dictionary = collision_data.get("projection", {})
	var scale := float(collision_data.get("runtime_scale", {}).get("pixels_per_metre", 1.0))
	if projection.is_empty():
		return {"display": "Map location unavailable", "copy": ""}
	var geographic := ProjectionScript.world_to_geographic(world_position, projection, scale)
	return {
		"display": "Cursor latitude: %.6f°\nCursor longitude: %.6f°" % [geographic.y, geographic.x],
		"copy": "%.6f, %.6f" % [geographic.y, geographic.x],
		"world": world_position,
		"geographic": geographic
	}


func _screen_can_choose_map_location(screen_position: Vector2) -> bool:
	if not MAP_PLAY_AREA.has_point(screen_position):
		return false
	if map_coordinates != null and map_coordinates.get_global_rect().has_point(screen_position):
		return false
	if map_copy_button != null and map_copy_button.get_global_rect().has_point(screen_position):
		return false
	if inventory_panel != null and inventory_panel.contains_screen_point(screen_position):
		return false
	if player_stats_panel != null and player_stats_panel.contains_screen_point(screen_position):
		return false
	return true


func _screen_can_select_interior_object(screen_position: Vector2) -> bool:
	if not MAP_PLAY_AREA.has_point(screen_position): return false
	if inventory_panel != null and inventory_panel.contains_screen_point(screen_position): return false
	if player_stats_panel != null and player_stats_panel.contains_screen_point(screen_position): return false
	return true


func _copy_map_location() -> void:
	if map_copy_text.is_empty():
		_notice("Move the mouse over the map before copying a location.")
		return
	DisplayServer.clipboard_set(map_copy_text)
	_notice("Location copied. Paste it into the Storyline NPC creator.")


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
	conversation_input = LineEdit.new()
	conversation_input.name = "ConversationTextInput"
	conversation_input.placeholder_text = "Type what you want to say…"
	conversation_input.max_length = 280
	conversation_input.position = Vector2(64, 296)
	conversation_input.size = Vector2(392, 27)
	conversation_input.add_theme_font_size_override("font_size", 10)
	conversation_input.visible = false
	conversation_input.text_submitted.connect(_submit_conversation)
	canvas.add_child(conversation_input)
	conversation_send_button = Button.new()
	conversation_send_button.name = "ConversationSend"
	conversation_send_button.text = "Send"
	conversation_send_button.position = Vector2(462, 296)
	conversation_send_button.size = Vector2(55, 27)
	conversation_send_button.add_theme_font_size_override("font_size", 9)
	conversation_send_button.visible = false
	conversation_send_button.pressed.connect(_submit_conversation)
	canvas.add_child(conversation_send_button)
	conversation_end_button = Button.new()
	conversation_end_button.name = "ConversationEnd"
	conversation_end_button.text = "End"
	conversation_end_button.position = Vector2(523, 296)
	conversation_end_button.size = Vector2(52, 27)
	conversation_end_button.add_theme_font_size_override("font_size", 9)
	conversation_end_button.visible = false
	conversation_end_button.pressed.connect(_end_conversation.bind("Conversation ended."))
	canvas.add_child(conversation_end_button)
	conversation_shop_button = Button.new()
	conversation_shop_button.text = "Shop"
	conversation_shop_button.position = Vector2(462, 296)
	conversation_shop_button.size = Vector2(55, 27)
	conversation_shop_button.add_theme_font_size_override("font_size", 9)
	conversation_shop_button.hide()
	conversation_shop_button.pressed.connect(func(): shop.open())
	canvas.add_child(conversation_shop_button)
	speedometer_gauge = SpeedometerGaugeScript.new()
	speedometer_gauge.name = "SpeedometerGauge"
	speedometer_gauge.position = Vector2(DRIVING_INSTRUMENT_LEFT, DRIVING_INSTRUMENT_SPEED_TOP)
	speedometer_gauge.scale = Vector2.ONE * DRIVING_INSTRUMENT_SCALE
	speedometer_gauge.visible = false
	canvas.add_child(speedometer_gauge)
	odometer_panel = OdometerPanelScript.new()
	odometer_panel.name = "OdometerPanel"
	odometer_panel.position = Vector2(DRIVING_INSTRUMENT_LEFT, DRIVING_INSTRUMENT_ODOMETER_TOP)
	odometer_panel.scale = Vector2.ONE * DRIVING_INSTRUMENT_SCALE
	odometer_panel.visible = false
	odometer_panel.trip_reset_requested.connect(_on_trip_reset_requested)
	canvas.add_child(odometer_panel)
	player_stats_panel = PlayerStatsPanelScript.new()
	player_stats_panel.name = "PlayerStatsHud"
	canvas.add_child(player_stats_panel)
	player_stats_panel.bind_stats(player_stats)
	inventory_panel = InventoryPanelScript.new()
	inventory_panel.name = "PlayerInventoryHud"
	canvas.add_child(inventory_panel)
	inventory_panel.bind_inventory(player_inventory, item_catalog_data, town_directory)
	inventory_panel.consume_requested.connect(_on_inventory_consume_requested)
	inventory_panel.notice_requested.connect(_notice)
	map_coordinates = Label.new()
	map_coordinates.name = "MapCoordinates"
	map_coordinates.position = Vector2(386, 218)
	map_coordinates.size = Vector2(246, 48)
	map_coordinates.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	map_coordinates.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_coordinates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_coordinates.add_theme_font_size_override("font_size", 8)
	map_coordinates.add_theme_color_override("font_color", Color("f3edcf"))
	var coordinate_background := StyleBoxFlat.new()
	coordinate_background.bg_color = Color("#17231feb")
	coordinate_background.content_margin_left = 5
	coordinate_background.content_margin_right = 3
	map_coordinates.add_theme_stylebox_override("normal", coordinate_background)
	map_coordinates.visible = false
	canvas.add_child(map_coordinates)
	map_copy_button = Button.new()
	map_copy_button.name = "CopyMapLocation"
	map_copy_button.text = "Copy location"
	map_copy_button.tooltip_text = "Copy location text to the clipboard for the Storyline NPC creator or another app"
	map_copy_button.position = Vector2(472, 270)
	map_copy_button.size = Vector2(104, 22)
	map_copy_button.focus_mode = Control.FOCUS_NONE
	map_copy_button.add_theme_font_size_override("font_size", 8)
	map_copy_button.pressed.connect(_copy_map_location)
	map_copy_button.visible = false
	canvas.add_child(map_copy_button)
	map_cursor_marker = Label.new()
	map_cursor_marker.name = "MapLocationCrosshair"
	map_cursor_marker.text = "+"
	map_cursor_marker.size = Vector2(14, 18)
	map_cursor_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_cursor_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_cursor_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_cursor_marker.add_theme_font_size_override("font_size", 12)
	map_cursor_marker.add_theme_color_override("font_color", Color("#5bd6b2"))
	map_cursor_marker.add_theme_color_override("font_outline_color", Color("#102019"))
	map_cursor_marker.add_theme_constant_override("outline_size", 2)
	map_cursor_marker.visible = false
	canvas.add_child(map_cursor_marker)
	var north := Label.new()
	north.text = "N ↑  v1.5"
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
	llm_loading_screen = LocalLlmLoadingScreenScript.new()
	llm_loading_screen.retry_requested.connect(_start_local_llm_loading)
	llm_loading_screen.continue_requested.connect(_continue_without_local_llm)
	canvas.add_child(llm_loading_screen)
	shop = ShopScript.new()
	shop.trade_accepted.connect(_on_trade_accepted)
	canvas.add_child(shop)


func _start_local_llm_loading() -> void:
	if llm_startup_loader == null or llm_loading_screen == null:
		return
	llm_startup_active = true
	local_llm_available = false
	player.controls_enabled = false
	wagon.controls_enabled = false
	population.set_process(false)
	var provider: Dictionary = persona_data.get("provider", {})
	llm_loading_screen.begin(str(provider.get("model", "Ollama model")))
	var wikipedia_url := str(town_knowledge_data.get("wikipedia", {}).get("url", "")).strip_edges()
	if not wikipedia_url.is_empty() and not wikipedia_refresh_complete:
		llm_loading_screen.show_stage("Refreshing optional Wikipedia town information…")
		var wikipedia_result: Dictionary = wikipedia_client.fetch(wikipedia_url)
		if wikipedia_result.ok:
			return
		wikipedia_refresh_complete = true
		# Invalid or unavailable optional context never blocks local conversations.
		_start_local_model_warmup(provider)
		return
	_start_local_model_warmup(provider)


func _start_local_model_warmup(provider: Dictionary) -> void:
	llm_loading_screen.show_stage("Preparing personas, live trader stock, venue notes and %s…" % str(provider.get("model", "Ollama model")))
	_prepare_dialogue_context()
	var startup_context := TownKnowledgeStoreScript.prompt_context(
		town_knowledge_data,
		town_custom_text,
		str(town.get("display_name", town_directory.get_file())),
		true,
		""
	)
	var personas: Array = persona_data.get("personas", [])
	var result: Dictionary = llm_startup_loader.preload_model(provider, startup_context, personas, prepared_dialogue_system)
	if not result.ok:
		llm_loading_screen.show_error(result.message)

func _refresh_trader_context(npc_id: String) -> Dictionary:
	var profile: Dictionary = trader_data.get("traders", {}).get(npc_id, {})
	var stock := TradeServiceScript.context(player_inventory, npc_id, profile, item_catalog_data)
	trader_contexts[npc_id] = stock
	return stock

func _prepare_dialogue_context() -> void:
	# No LLM is asked to calculate stock. Save data is the authoritative source.
	trader_contexts.clear()
	for id in trader_data.get("traders", {}): _refresh_trader_context(str(id))
	var context := TownKnowledgeStoreScript.prompt_context(town_knowledge_data, town_custom_text, str(town.get("display_name", town_directory.get_file())), true, "").left(600)
	context += "\n" + LocationNotesScript.summary(location_notes_data, location_note_texts).left(600)
	# Each full persona is already loaded in memory. Add only the assigned one
	# per request, avoiding a huge catalogue that evicts venue/stock facts.
	prepared_dialogue_system = OllamaDialogueClientScript.catalog_system_prompt([], context)
	var stock_lines: Array[String] = []
	for id in trader_contexts:
		stock_lines.append("%s: %s" % [id, JSON.stringify(trader_contexts[id])])
	prepared_dialogue_system += "\nStartup stock snapshot (latest live stock in each trader request overrides it; other characters cannot sell): " + "\n".join(stock_lines).left(600)


func _on_wikipedia_town_context_completed(ok: bool, page: Dictionary, _message: String) -> void:
	if not llm_startup_active:
		return
	wikipedia_refresh_complete = true
	if ok:
		var save_result := town_knowledge_store.save_wikipedia_cache(town_directory, town_knowledge_data, page)
		if save_result.ok:
			town_knowledge_data = save_result.data
		else:
			town_knowledge_data.wikipedia["title"] = str(page.get("title", ""))
			town_knowledge_data.wikipedia["canonical_url"] = str(page.get("canonical_url", ""))
			town_knowledge_data.wikipedia["language"] = str(page.get("language", ""))
			town_knowledge_data.wikipedia["summary"] = str(page.get("summary", ""))
	town_prompt_context = TownKnowledgeStoreScript.prompt_context(town_knowledge_data, town_custom_text, str(town.get("display_name", town_directory.get_file())), false)
	_start_local_model_warmup(persona_data.get("provider", {}))


func _on_local_llm_startup_completed(ok: bool, detail: String, load_seconds: float) -> void:
	if not llm_startup_active:
		return
	if not ok:
		local_llm_available = false
		llm_loading_screen.show_error(detail)
		return
	local_llm_available = true
	llm_loading_screen.show_ready(load_seconds)
	await get_tree().create_timer(0.45).timeout
	if llm_startup_active and local_llm_available:
		_finish_local_llm_startup()


func _continue_without_local_llm() -> void:
	if not llm_startup_active:
		return
	llm_startup_loader.cancel()
	if wikipedia_client != null:
		wikipedia_client.cancel()
	local_llm_available = false
	_finish_local_llm_startup()
	_notice("Town opened without local conversations. Start Ollama and reopen the map to enable them.")


func _finish_local_llm_startup() -> void:
	llm_startup_active = false
	llm_loading_screen.finish()
	population.set_process(true)
	player.controls_enabled = true
	wagon.controls_enabled = true
	if OS.get_cmdline_user_args().has("--verify-llm-startup"):
		assert(local_llm_available, "The integration verifier must finish with local dialogue available.")
		assert(not llm_loading_screen.visible and player.controls_enabled and population.is_processing(), "The loading screen did not hand control to the map.")
		print("LOCAL LLM STARTUP PASSED: model preloaded behind the startup progress screen, then map control was restored.")
		get_tree().quit()


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
	var custom_name := str(building_exterior_data.get("buildings", {}).get(str(record.get("feature_id", "")), {}).get("custom_name", ""))
	if not custom_name.is_empty(): lines.push_front("Creator name: %s" % custom_name)
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
	if shop != null and shop.visible: return false
	if inventory_panel != null and inventory_panel.contains_screen_point(screen_position):
		return false
	if player_stats_panel != null and player_stats_panel.contains_screen_point(screen_position):
		return false
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
