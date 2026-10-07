extends SceneTree

const Runtime = preload("res://scripts/runtime/town_runtime.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
const Interior = preload("res://scripts/interiors/runtime_interior_layer.gd")
const InteriorStore = preload("res://scripts/interiors/building_interior_store.gd")
const ExteriorStore = preload("res://scripts/buildings/building_exterior_store.gd")

class EntranceRendererStub extends Node2D:
	var playable: Dictionary = {}
	func set_playable_entrances(keys: Dictionary) -> void: playable = keys.duplicate(true)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var interiors := InteriorStore.new().load_from_town(path)
	var exteriors := ExteriorStore.new().load_from_town(path)
	var features: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("data/map_features.json")))
	var collisions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("data/building_collisions.json")))
	assert(interiors.ok and exteriors.ok)
	# Bypass full town startup; exercise real E input and saved pub geometry.
	var runtime := Node2D.new()
	root.add_child(runtime)
	runtime.set_script(Runtime)
	runtime.set_process(false)
	runtime.set_process_unhandled_input(false)
	runtime.collision_data = collisions
	runtime.building_interior_data = interiors.data
	runtime.building_exterior_data = exteriors.data
	runtime.renderer = EntranceRendererStub.new()
	runtime.add_child(runtime.renderer)
	runtime.player = Player.new()
	runtime.add_child(runtime.player)
	runtime.player.set_physics_process(false)
	runtime.interior_layer = Interior.new()
	runtime.add_child(runtime.interior_layer)
	runtime._build_runtime_interior_entrances(features.features, collisions.projection, 8.0)
	assert(not runtime.renderer.playable.is_empty(), "Playable entrance keys were not given to the renderer.")
	var pub: Dictionary = {}
	for entrance in runtime.interior_entrances:
		if entrance.building_name == "The Pub": pub = entrance
	assert(not pub.is_empty(), "The Pub has no linked runtime entrance.")
	var arrow := Vector2(pub.world_position)
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	runtime.player.position = arrow + Vector2(30,0)
	assert(runtime._nearest_interior_entrance().is_empty())
	runtime._unhandled_input(key)
	assert(runtime.pending_entry_time > 0 and runtime.inside_building_id.is_empty())
	runtime.player.position = arrow + Vector2(27,0)
	runtime._process_pending_entry(0.1)
	assert(runtime.inside_building_id == pub.feature_id and runtime.pending_entry_time == 0.0, "Early E did not enter on reaching the normal usable radius.")
	assert(runtime.interior_layer.is_traversable(runtime.player.position, 4.0), "Pub arrival is obstructed.")
	runtime._process_pending_entry(0.1)
	assert(runtime.inside_building_id == pub.feature_id, "One buffered press caused a second interaction.")
	# Reset only fixture state; no persisted player or town changes.
	runtime.inside_building_id = ""
	runtime.player.position = arrow + Vector2(30,0)
	runtime._request_outdoor_entry()
	runtime._process_pending_entry(0.5)
	runtime.player.position = arrow
	runtime._process_pending_entry(0.1)
	assert(runtime.inside_building_id.is_empty(), "Expired E entered later without a fresh press.")
	for state in ["overview", "conversation_active", "occupied"]:
		runtime.pending_entry_time = 0.4
		runtime.set(state, true)
		runtime._process_pending_entry(0.1)
		assert(runtime.pending_entry_time == 0.0 and runtime.inside_building_id.is_empty())
		runtime.set(state, false)
	# Different map scales use the same real-metre interaction radius.
	for scale in [4.0, 16.0]:
		runtime.collision_data.runtime_scale.pixels_per_metre = scale
		runtime._build_runtime_interior_entrances(features.features, collisions.projection, scale)
		for entrance in runtime.interior_entrances:
			if entrance.building_name != "The Pub": continue
			runtime.player.position = Vector2(entrance.world_position) + Vector2(3.4 * scale,0)
			assert(not runtime._nearest_interior_entrance().is_empty())
	print("ENTRY PRESS GRACE PASSED: saved Albury pub, real E handler, early press, clear arrival, single use, expiry/cancellation and map-scale radius; town unchanged.")
	runtime.queue_free()
	quit(0)
