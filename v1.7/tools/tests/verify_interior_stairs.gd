extends SceneTree

const Store = preload("res://scripts/interiors/building_interior_store.gd")
const Stairs = preload("res://scripts/interiors/stairs/interior_stairs.gd")
const Layer = preload("res://scripts/interiors/runtime_interior_layer.gd")
const Runtime = preload("res://scripts/runtime/town_runtime.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
const Heights = preload("res://scripts/buildings/building_height_profile.gd")
var failures := 0
var checks := 0

class GroundStub extends Node2D:
	func is_ground_traversable(_point: Vector2, _clearance := 0.0) -> bool: return true

func _initialize() -> void: call_deferred("_run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(message)
func frames() -> void:
	for count in 4: await process_frame
func floor_fixture(id: String, level: int) -> Dictionary:
	return {"id": id, "level": level, "name": "Ground floor" if level == 0 else "Floor %d" % (level + 1), "layout_source": "creator_blank_from_osm_footprint", "survey_status": "not_surveyed", "width_metres": 20.0, "height_metres": 16.0, "grid_metres": 1.0, "footprint_scale": 1.0, "boundary_metres": [[0,0],[20,0],[20,16],[0,16]], "holes_metres": [], "walls": [], "rooms": [], "furniture": [], "entry_links": [], "flooring": {"cell_size_metres": 0.5, "cells": {}}}
func click(canvas: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = canvas._metres_to_screen(point)
	event.pressed = pressed
	canvas._gui_input(event)
func move(canvas: Control, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = canvas._metres_to_screen(point)
	canvas._gui_input(event)

func _run() -> void:
	create_timer(80).timeout.connect(func(): push_error("STAIRS TIMED OUT"); quit(1))
	var store = Store.new()
	var data: Dictionary = store.empty_data()
	data.buildings["test"] = {"feature_id": "test", "name": "Stair test", "floors": [floor_fixture("ground_floor",0), floor_fixture("floor_1",1)]}
	var entry_result: Dictionary = store.set_entry_spawn(data, "test", "entrance_1", Vector2(3,3))
	check(entry_result.ok, "Fixture entry must be valid.")
	data = entry_result.data
	check(store.validate(data).ok, "Legacy interiors without stairs remain valid.")
	var edge_pair: Dictionary = store.add_stair_pair(data,"test","ground_floor",Vector2(.85,9),"floor_1",Vector2(.85,9))
	check(edge_pair.ok, "Stairs with a 15 cm artwork gap from the exterior wall were rejected.")
	check(not store.add_stair_pair(data,"test","ground_floor",Vector2(.65,9),"floor_1",Vector2(.85,9)).ok,"Artwork crossing the exterior wall accepted.")
	var inherited: Dictionary = store.resize_floor(data,"test","floor_1",1.5).data
	inherited.buildings.test.floors[1].holes_metres=[[[22,18],[24,18],[24,20],[22,20]]]
	inherited=store.add_upper_floor(inherited,"test").data
	for field in ["width_metres","height_metres","boundary_metres","holes_metres","footprint_scale"]:
		check(inherited.buildings.test.floors[2][field]==inherited.buildings.test.floors[1][field],"New upper floor did not inherit "+field)
	check(inherited.buildings.test.floors[0]==data.buildings.test.floors[0] and inherited.buildings.test.floors[2].furniture.is_empty(),"Upper floor inheritance changed the ground floor or copied furniture")
	var pair: Dictionary = store.add_stair_pair(data,"test","ground_floor",Vector2(6,9),"floor_1",Vector2(6,9))
	check(pair.ok, "Valid paired stairs rejected: %s" % pair.get("message", ""))
	data = pair.data
	var record: Dictionary = data.buildings.test
	check(store.validate(data).ok, "Paired stairs failed canonical validation.")
	for candidate in [Vector2(-1,9),Vector2(0.5,9),Vector2(6,9),Vector2(NAN,9)]:
		check(not store.add_stair_pair(data,"test","ground_floor",candidate,"floor_1",Vector2(12,9)).ok, "Invalid/overlapping source accepted: %s" % candidate)
	check(not store.add_stair_pair(data,"test","ground_floor",Vector2(12,9),"ground_floor",Vector2(15,9)).ok, "Same-floor stairs accepted.")
	check(not store.add_stair_pair(data,"test","ground_floor",Vector2(12,9),"missing",Vector2(12,9)).ok, "Dangling destination accepted.")
	var blocked: Dictionary = record.duplicate(true)
	blocked.floors[1].holes_metres = [[[5.8,8.8],[6.2,8.8],[6.2,9.2],[5.8,9.2]]]
	check(not Stairs.validate(blocked).ok, "Small courtyard inside stair envelope accepted.")
	blocked = record.duplicate(true)
	blocked.floors[1].walls = [{"id":"wall_1","start_x_metres":5.5,"start_y_metres":7.0,"end_x_metres":5.5,"end_y_metres":11.0,"thickness_metres":0.18,"doors":[]}]
	check(not Stairs.validate(blocked).ok, "Wall through stair envelope accepted.")
	blocked = record.duplicate(true)
	blocked.stairs.append({"id":"bad","from":42,"to":{}})
	check(not Stairs.validate(blocked).ok,"Malformed second pair must fail without a script exception.")
	blocked = record.duplicate(true)
	blocked.floors[1].boundary_metres = [[0,0],[20,0],[20,16],[6.1,16],[6.1,8],[5.9,8],[5.9,16],[0,16]]
	check(not Stairs.validate(blocked).ok,"Concave notch crossing stair envelope accepted.")
	var chair: Dictionary = store.place_furniture(data,"test","floor_1","dining_chair",Vector2(6,9),0)
	check(not chair.ok, "Furniture can obstruct existing stairs.")
	check(not store.add_wall(data,"test","floor_1",Vector2(5.5,7),Vector2(5.5,11)).ok, "New wall can obstruct stairs.")
	check(not store.set_entry_spawn(data,"test","entrance_1",Vector2(6,9)).ok, "Exterior entry can overlap stairs.")
	check(not store.validate_location(data,{"space":"interior","building_id":"test","floor_id":"floor_1","x_metres":6,"y_metres":9}).ok,"Authored NPC can obstruct stair landing.")
	var shifted: Dictionary = store.move_stair_endpoint(data,"test","stairs_1","to",Vector2(12,9))
	check(shifted.ok and Stairs.position(shifted.data.buildings.test.stairs[0].from)==Vector2(6,9), "Endpoint movement changed the opposite floor.")
	check(not store.move_stair_endpoint(data,"test","stairs_1","to",Vector2(0,0)).ok, "Blocked stair drag accepted.")
	var resized: Dictionary = store.resize_floor(data,"test","floor_1",1.5)
	check(resized.ok and Stairs.position(resized.data.buildings.test.stairs[0].to)==Vector2(9,13.5) and Stairs.position(resized.data.buildings.test.stairs[0].from)==Vector2(6,9), "Floor resize did not scale only its stair point.")
	check(store.remove_stair_pair(data,"test","stairs_1").data.buildings.test.stairs.is_empty(), "Removing stairs left an orphan endpoint.")
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/stairs-%s" % OS.get_process_id())
	check(store.save_to_town(temporary,data).ok and store.load_from_town(temporary).data.buildings.test.stairs.size()==1, "Stairs did not round-trip.")
	await _runtime_checks(data)
	await _gui_checks(temporary)
	if OS.get_cmdline_user_args().has("--render"): await _albury_images()
	if failures > 0: quit(1); return
	print("INTERIOR STAIRS PASSED: %d checks; paired placement/drag/cancel/resize/save, obstacle rejection, E-only up/down, upstairs NPC targeting, no upstairs exit, blocked/occupied landing safety, fog revisit and exterior return." % checks)
	quit()

func _runtime_checks(data: Dictionary) -> void:
	var record: Dictionary = data.buildings.test.duplicate(true)
	# Divided ground floor proves discovery survives a floor round-trip.
	record.floors[0].walls = [{"id":"wall_1","start_x_metres":10.0,"start_y_metres":0.1,"end_x_metres":10.0,"end_y_metres":15.9,"thickness_metres":0.18,"doors":[]}]
	var layer = Layer.new()
	root.add_child(layer)
	var runtime = Runtime.new() # Deliberately not added: no town launch/LLM/save.
	runtime.collision_data = {"runtime_scale":{"pixels_per_metre":8.0}}
	runtime.interior_layer = layer
	runtime.player = Player.new()
	runtime.player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(runtime.player)
	runtime.population = Population.new()
	runtime.population.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(runtime.population)
	runtime.population.set_interior_visibility_check(layer.is_position_discovered)
	runtime.renderer = GroundStub.new()
	runtime.tracks = Node2D.new()
	runtime.wagon = Node2D.new()
	var upstairs := {"kind":"person","space":"interior","building_id":"test","floor_id":"floor_1","position":Vector2(70,72),"phase":0.0,"angle":0.0,"moving":false,"npc_asset":"npc_medium_man_adult","name":"Upstairs resident"}
	runtime.population.agents.assign([upstairs])
	runtime._enter_interior({"record":record,"floor":record.floors[0],"link":record.floors[0].entry_links[0],"feature_id":"test","building_name":"Stair test","world_position":Vector2(500,600)})
	check(runtime.player.position==Vector2(24,24), "Ground arrival changed.")
	check(runtime.population.nearest_conversation_target(Vector2(70,72),30).is_empty(), "Upstairs NPC visible downstairs.")
	layer.update_player_position(Vector2(120,72))
	var discovered: int = layer.discovered_components.size()
	runtime.player.position = Vector2(48,72)
	layer.update_player_position(runtime.player.position)
	check(runtime.inside_floor_id=="ground_floor", "Walking onto stairs switched floors without E.")
	var use := InputEventKey.new()
	use.keycode = KEY_E
	use.pressed = true
	runtime._unhandled_input(use)
	check(runtime.inside_floor_id=="floor_1" and runtime.player.position==Vector2(48,72), "E did not ascend.")
	check(not runtime._near_interior_exit() and not layer.exterior_exit_enabled, "Upper-floor arrival became an outside exit.")
	check(not runtime.population.nearest_conversation_target(runtime.player.position,30).is_empty(), "Upstairs NPC cannot be targeted after ascending.")
	runtime._unhandled_input(use)
	check(runtime.inside_floor_id=="ground_floor" and layer.exit_position==Vector2(24,24), "Descending changed the outside exit marker.")
	check(layer.discovered_components.size()==discovered, "Visited ground rooms lost their discovery on return.")
	var original: Vector2 = runtime.player.position
	runtime.inside_building_record.floors[1].furniture.append({"id":"bad","x_metres":6,"y_metres":9,"width_metres":1,"depth_metres":1,"collision":true})
	runtime._unhandled_input(use)
	check(runtime.inside_floor_id=="ground_floor" and runtime.player.position==original and str(layer.floor_data.id)=="ground_floor", "Blocked destination corrupted occupied floor.")
	runtime.inside_building_record.floors[1].furniture.clear()
	runtime.population.agents[0].position = original
	runtime._unhandled_input(use)
	check(runtime.inside_floor_id=="ground_floor" and runtime.notice_text.contains("Someone"), "Arrival inside NPC accepted.")
	runtime.population.agents[0].position = Vector2(70,72)
	runtime.conversation_active = true
	runtime._unhandled_input(use)
	check(runtime.inside_floor_id=="ground_floor", "Stairs interrupted active dialogue.")
	runtime.conversation_active = false
	runtime.player.position = layer.exit_position
	runtime._unhandled_input(use)
	check(runtime.inside_building_id.is_empty() and runtime.player.position==Vector2(500,600), "Exterior return lost after stair use.")
	# Legacy low-scale maps can have overlapping exit/stair interaction ranges.
	runtime.collision_data.runtime_scale.pixels_per_metre = 1.0
	runtime.player.art_scale = 0.25
	runtime._enter_interior({"record":record,"floor":record.floors[0],"link":record.floors[0].entry_links[0],"feature_id":"test","building_name":"Stair test","world_position":Vector2(500,600)})
	runtime.player.position = Vector2(6,9)
	layer.update_player_position(Vector2(12,9))
	check(layer.nearest_stairs(Vector2(12,9)).is_empty(),"Stairs could be used through a thin wall in a previously visited room.")
	check(not runtime._near_interior_exit(),"Exit radius stole the closer stair interaction on a low-scale map.")
	runtime._unhandled_input(use)
	check(runtime.inside_floor_id=="floor_1","Low-scale stairs did not switch to the correct floor.")
	# Use the real walking/E handlers near a wall at the production 8 px/m scale.
	var edge_record := record.duplicate(true)
	edge_record.stairs[0].from.x_metres=.85; edge_record.stairs[0].to.x_metres=.85
	runtime.collision_data.runtime_scale.pixels_per_metre=8.0
	runtime.player.art_scale=1.0
	runtime._enter_interior({"record":edge_record,"floor":edge_record.floors[0],"link":edge_record.floors[0].entry_links[0],"feature_id":"test","building_name":"Stair test","world_position":Vector2(500,600)})
	runtime.player.position=Vector2(16,72)
	runtime.player.process_mode=Node.PROCESS_MODE_INHERIT
	runtime.player.set_physics_process(false)
	await physics_frame
	await physics_frame
	runtime.player._move_on_foot(Vector2.LEFT,.2)
	check(runtime.player.position.x<16 and runtime.player.position.x>=4,"Real player could not approach wall-side stairs safely")
	runtime._unhandled_input(use)
	check(runtime.inside_floor_id=="floor_1" and runtime.player.position.distance_to(Vector2(.85,9)*8)<.01,"E failed at a close-to-wall stair landing")
	for node in [runtime.player,runtime.population,runtime.renderer,runtime.tracks,runtime.wagon,layer]: node.free()
	runtime.free()
	await frames()

func _gui_checks(temporary: String) -> void:
	# Production Save requires a saved town, not only isolated layout files.
	var town_file := FileAccess.open(temporary.path_join("town.json"), FileAccess.WRITE)
	town_file.store_string('{"town_id":"stairs-fixture","display_name":"Stair fixture"}'); town_file.close()
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio.imported_town = studio.importer.parse_files(PackedStringArray(["res://tools/tests/fixtures/tiny_town.osm"]))
	studio.loaded_project_directory = temporary
	var feature: Dictionary = studio.imported_town.features.filter(func(value): return str(value.kind)=="building")[0]
	var point := Vector2(float(feature.points[1][0]),float(feature.points[1][1])).lerp(Vector2(float(feature.points[2][0]),float(feature.points[2][1])),0.5)
	var exterior: Dictionary = studio.building_exterior_store.set_door(studio.building_exterior_store.empty_data(),feature,{"longitude":point.x,"latitude":point.y},studio.imported_town.features,studio.imported_town.bounds)
	check(exterior.ok, "Fixture exterior invalid.")
	studio.building_exterior_store.save_to_town(temporary,exterior.data)
	var data: Dictionary = studio.building_interior_store.empty_data()
	data.buildings[str(feature.id)] = {"feature_id":str(feature.id),"name":"Stair fixture","floors":[floor_fixture("ground_floor",0),floor_fixture("floor_1",1)]}
	studio.building_interior_store.save_to_town(temporary,data)
	studio._show_interior_designer_page()
	studio.message_dialog.hide()
	await frames()
	check(studio.interior_tools_navigation.pages.has("stairs") and studio.interior_floor_option.is_visible_in_tree(), "Stairs page or persistent floor selector missing.")
	studio.interior_tools_navigation.open_page("stairs")
	studio._begin_interior_stairs()
	var canvas = studio.interior_floor_canvas
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	canvas._gui_input(escape)
	check(studio.interior_stair_pending.is_empty() and not canvas.placing_stair,"Esc must discard partial placement.")
	studio._begin_interior_stairs()
	click(canvas,Vector2(0.5,0.5),true); click(canvas,Vector2(0.5,0.5),false)
	check(not studio.interior_stair_pending.has("from_position") and canvas.invalid_position!=Vector2.INF and not studio.message_dialog.visible, "Invalid stair point must give inline X without dialog.")
	click(canvas,Vector2(6,9),true); click(canvas,Vector2(6,9),false)
	check(studio._selected_interior_floor_id()=="floor_1" and canvas.placing_stair, "First point did not switch to destination placement.")
	check(studio.interior_data.buildings[str(feature.id)].get("stairs",[]).is_empty(), "Half-pair committed before second endpoint.")
	click(canvas,Vector2(6,9),true); click(canvas,Vector2(6,9),false)
	check(studio.interior_data.buildings[str(feature.id)].stairs.size()==1, "Second point did not commit pair.")
	click(canvas,Vector2(6,9),true); move(canvas,Vector2(8,9)); click(canvas,Vector2(8,9),false)
	check(Stairs.position(studio.interior_data.buildings[str(feature.id)].stairs[0].to).distance_to(Vector2(8,9))<0.05, "Direct stair drag failed.")
	click(canvas,Vector2(8,9),true); move(canvas,Vector2(-2,-2)); click(canvas,Vector2(-2,-2),false)
	check(Stairs.position(studio.interior_data.buildings[str(feature.id)].stairs[0].to).distance_to(Vector2(8,9))<0.05, "Invalid drag changed saved stair.")
	studio._begin_interior_stairs()
	studio.interior_tools_navigation.show_home()
	check(studio.interior_stair_pending.is_empty() and not canvas.placing_stair, "Back left partial placement active.")
	studio._save_interior_layouts()
	studio.message_dialog.hide()
	check(studio.section_save_succeeded and studio.building_interior_store.load_from_town(temporary).data.buildings[str(feature.id)].get("stairs",[]).size()==1, "GUI Save lost stairs.")
	# Start with a furnished one-floor building: new stairs create the upper floor.
	var id := str(feature.id)
	data.buildings[id].floors.resize(1)
	data = studio.building_interior_store.place_furniture(data,id,"ground_floor","dining_chair",Vector2(15,3),0).data
	studio.interior_data = data.duplicate(true)
	var original_ground: Dictionary = data.buildings[id].floors[0].duplicate(true)
	studio._refresh_interior_designer_controls("ground_floor")
	studio.interior_tools_navigation.open_page("stairs")
	check(studio.interior_stair_target.item_count==1 and not studio.interior_stair_add.disabled,"One-floor building must offer automatic upper-floor stairs.")
	studio._begin_interior_stairs()
	click(canvas,Vector2(6,9),true); click(canvas,Vector2(6,9),false)
	check(studio.interior_data.buildings[id].floors.size()==2 and studio._selected_interior_floor_id()=="floor_1","New floor was not previewed after valid first point.")
	click(canvas,Vector2(0,0),true); click(canvas,Vector2(0,0),false)
	check(studio.interior_stair_floor_counts.is_empty() and studio.interior_data.buildings[id].get("stairs",[]).is_empty(),"Blocked new-floor landing committed a pair or height.")
	canvas._gui_input(escape)
	check(studio.interior_data==data and studio._selected_interior_floor_id()=="ground_floor","Cancel left an unwanted floor or changed furniture.")
	studio._begin_interior_stairs()
	click(canvas,Vector2(6,9),true); click(canvas,Vector2(6,9),false)
	studio._save_interior_layouts()
	studio.message_dialog.hide()
	check(studio.building_interior_store.load_from_town(temporary).data.buildings[id].floors.size()==1,"Save persisted an unfinished new floor.")
	studio._begin_interior_stairs()
	click(canvas,Vector2(6,9),true); click(canvas,Vector2(6,9),false)
	click(canvas,Vector2(6,9),true); click(canvas,Vector2(6,9),false)
	check(studio.interior_data.buildings[id].floors.size()==2 and studio.interior_data.buildings[id].stairs.size()==1,"Completed stairs failed to create floor and pair together.")
	check(studio.interior_data.buildings[id].floors[0]==original_ground and studio.interior_data.buildings[id].floors[1].furniture.is_empty(),"Automatic floor overwrote ground furnishings or duplicated furniture upstairs.")
	check(studio.interior_exterior_data.buildings[id].total_floors==2,"Automatic stairs did not raise staged exterior count.")
	# Preserve a newer design saved by another editor, merging only the count.
	var latest: Dictionary = studio.building_exterior_store.load_from_town(temporary).data
	latest = studio.building_exterior_store.set_custom_name(latest,id,"Latest name").data
	studio.building_exterior_store.save_to_town(temporary,latest)
	studio._save_interior_layouts()
	studio.message_dialog.hide()
	var saved: Dictionary = studio.building_exterior_store.load_from_town(temporary).data
	check(saved.buildings[id].total_floors==2 and saved.buildings[id].custom_name=="Latest name" and saved.buildings[id].doors==latest.buildings[id].doors,"Save lost exterior height, latest name or entrance metadata.")
	check(studio.building_interior_store.load_from_town(temporary).data.buildings[id].floors.size()==2 and studio.interior_stair_floor_counts.is_empty(),"Save lost new floor or failed to clear height staging.")
	if OS.get_cmdline_user_args().has("--render"):
		studio._set_stair_instruction("New upper floor created with stairs · exterior saved at 2 floors. Temporary fixture only.")
		await frames()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/interior_stairs_auto_floor_v16.png"))==OK,"Automatic-floor UI image could not be saved.")
	var tall: Dictionary = Heights.set_floors(saved,id,12).data
	check(Heights.ensure_minimum_floors(tall,feature,3).data.buildings[id].total_floors==12,"Automatic floors shrank an existing taller exterior.")
	var mapped: Dictionary = feature.duplicate(true)
	mapped.tags["building:levels"]="15"
	check(Heights.ensure_minimum_floors(studio.building_exterior_store.empty_data(),mapped,2).data.buildings.is_empty(),"Automatic floors overrode a taller OSM floor count.")
	# Existing-floor stairs still work at the editable-floor limit; no new option.
	for count in range(2,20): studio.interior_data = studio.building_interior_store.add_upper_floor(studio.interior_data,id).data
	studio._refresh_interior_designer_controls("floor_19")
	var has_new := false
	for index in studio.interior_stair_target.item_count:
		if str(studio.interior_stair_target.get_item_metadata(index))=="__new_upper_floor": has_new=true
	check(not has_new and not studio.interior_stair_add.disabled and not studio.building_interior_store.add_upper_floor(studio.interior_data,id).ok,"Twenty-floor limit must disable creation without disabling existing-floor connections.")
	studio.free()
	await frames()

func _albury_images() -> void:
	var town := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var saved := town.path_join("data/building_interiors.json")
	var before := FileAccess.get_sha256(saved)
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio._load_existing_project(town)
	studio._show_interior_designer_page()
	studio.message_dialog.hide()
	studio.message_dialog.free()
	for index in studio.interior_building_option.item_count:
		if str(studio.interior_building_option.get_item_metadata(index))=="601183200":
			studio.interior_building_option.select(index)
			studio._on_interior_building_selected(index)
	var id := str(studio.interior_selected_feature.id)
	var store = Store.new()
	var record: Dictionary = studio.interior_data.buildings[id]
	if record.floors.size()==1:
		studio.interior_data = store.add_upper_floor(studio.interior_data,id).data
		record = studio.interior_data.buildings[id]
	var from := find_clear(record,record.floors[0])
	var to := find_clear(record,record.floors[1])
	check(from!=Vector2.INF and to!=Vector2.INF,"Actual pub needs safe stair space for read-only preview.")
	if from==Vector2.INF or to==Vector2.INF: studio.free(); return
	var pair: Dictionary = store.add_stair_pair(studio.interior_data,id,str(record.floors[0].id),from,str(record.floors[1].id),to)
	check(pair.ok,"Albury preview stairs invalid.")
	studio.interior_data = pair.data
	studio._refresh_interior_designer_controls(str(record.floors[0].id))
	studio.interior_tools_navigation.open_page("stairs")
	studio._set_stair_instruction("Read-only Albury Pub demo — paired stairs added in memory. Saved project unchanged.")
	studio.interior_floor_canvas.view_zoom = 6.0
	studio.interior_floor_canvas.view_changed.emit(6.0)
	studio.interior_floor_canvas._pan_by(studio.interior_floor_canvas.size * 0.5 - studio.interior_floor_canvas._metres_to_screen(from))
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/interior_stairs_albury_editor.png"))
	record = studio.interior_data.buildings[id].duplicate(true)
	studio.free()
	await frames()
	# Use actual pub geometry/furniture and production character/floor renderer.
	var layer = Layer.new()
	layer.set_town_directory(town)
	root.add_child(layer)
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.position = from * 8.0
	camera.zoom = Vector2.ONE * 3.0
	var player = Player.new()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = from * 8.0 + Vector2(0,18)
	player.z_index = 5
	root.add_child(player)
	layer.open_floor(record,record.floors[0],{"spawn_x_metres":from.x,"spawn_y_metres":from.y},8.0)
	layer.exit_position = Vector2(float(record.floors[0].entry_links[0].spawn_x_metres),float(record.floors[0].entry_links[0].spawn_y_metres))*8.0
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var label := Label.new()
	label.position = Vector2(30,20)
	label.add_theme_font_size_override("font_size",22)
	label.text = "ALBURY PUB · GROUND FLOOR · E: stairs to Floor 2\nRead-only in-memory stair demo — existing pub furniture retained"
	overlay.add_child(label)
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/interior_stairs_albury_ground.png"))
	var opened: Dictionary = layer.open_stair_floor(record,record.floors[1],record.stairs[-1].to,8.0,record.floors[0].entry_links[0],4.0)
	check(opened.ok,"Albury upstairs preview did not open.")
	player.position = to * 8.0 + Vector2(0,18)
	camera.position = to * 8.0
	label.text = "ALBURY PUB · FLOOR 2 · E: stairs to Ground floor\nRead-only in-memory demo — upper floor is a separate playable space"
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/interior_stairs_albury_upstairs.png"))
	for node in [layer,camera,player,overlay]: node.free()
	check(FileAccess.get_sha256(saved)==before,"Capture changed saved Albury interiors.")
	await frames()

func find_clear(record: Dictionary, floor: Dictionary) -> Vector2:
	for y in range(3,int(floor.height_metres)-2,2):
		for x in range(3,int(floor.width_metres)-2,2):
			var point := Vector2(x,y)
			if Stairs.fits(floor,point,Stairs.endpoints(record,str(floor.id))): return point
	return Vector2.INF
