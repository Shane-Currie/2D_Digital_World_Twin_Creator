extends SceneTree

const Layer = preload("res://scripts/interiors/runtime_interior_layer.gd")
const Store = preload("res://scripts/interiors/building_interior_store.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
const Seating = preload("res://scripts/interiors/interior_seating.gd")
const Orientation = preload("res://scripts/npcs/creation/seat_orientation.gd")
const Preview = preload("res://scripts/npcs/creation/npc_pose_preview.gd")
const Art = preload("res://scripts/runtime/runtime_actor_art.gd")
class Harness:
	extends "res://scripts/runtime/town_runtime.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
class Ground:
	extends Node2D
	var world_bounds := Rect2(0,0,160,120)
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func frames() -> void:
	for _i in 4: await process_frame
func item(id: String, kind: String, point: Vector2, angle := 0.0) -> Dictionary:
	var definition := preload("res://scripts/interiors/interior_furniture_catalog.gd").definition(kind)
	return {"id":id,"catalog_id":kind,"object_type":definition.object_type,"x_metres":point.x,"y_metres":point.y,"width_metres":definition.size_metres[0],"depth_metres":definition.size_metres[1],"rotation_degrees":angle,"collision":true,"catalog_source":"built_in"}
func floor_fixture() -> Dictionary:
	return {"id":"ground_floor","name":"Ground floor","level":0,"width_metres":20.0,"height_metres":15.0,"boundary_metres":[[0,0],[20,0],[20,15],[0,15]],"holes_metres":[],"walls":[],"rooms":[],"furniture":[],"entry_links":[]}
func key(runtime, code: int) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.pressed=true; runtime._unhandled_input(event)
func mouse(canvas, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; canvas._gui_input(event)

func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("SEATING TIMEOUT"); quit(2))
	var runtime := Harness.new(); root.add_child(runtime)
	runtime.player=Player.new(); runtime.add_child(runtime.player); runtime.player.set_physics_process(false)
	runtime.population=Population.new(); runtime.population.set_process(false)
	runtime.interior_layer=Layer.new(); runtime.add_child(runtime.interior_layer)
	runtime.renderer=Ground.new(); runtime.camera=Camera2D.new(); runtime.add_child(runtime.camera)
	runtime.wagon=preload("res://scripts/runtime/runtime_player_vehicle.gd").new()
	runtime.map_buttons=HBoxContainer.new(); runtime.map_coordinates=Label.new(); runtime.map_copy_button=Button.new(); runtime.map_cursor_marker=Label.new()
	runtime.conversation_layer=preload("res://scripts/npcs/runtime_conversation_layer.gd").new()
	runtime.conversation_input=LineEdit.new(); runtime.conversation_send_button=Button.new(); runtime.conversation_end_button=Button.new()
	runtime.conversation_shop_button=Button.new()
	for control in [runtime.conversation_layer,runtime.conversation_input,runtime.conversation_send_button,runtime.conversation_end_button,runtime.conversation_shop_button]: runtime.add_child(control)
	runtime.inside_building_id="seat_test"; runtime.inside_floor_id="ground_floor"
	runtime.player.set_interior_mode(true)
	var layer = runtime.interior_layer
	layer.floor_data=floor_fixture(); layer.pixels_per_metre=8.0
	runtime.player.set_ground_check(layer.is_traversable)
	var chair := item("chair","dining_chair",Vector2(5,5))
	layer.floor_data.furniture=[chair]
	for angle in [0.0,90.0,180.0,270.0]:
		chair.seat_direction_degrees=angle
		layer.floor_data.furniture=[chair]
		runtime.player.position=Vector2(40,48)
		key(runtime,KEY_E)
		check(runtime.player.seated and not runtime.player.controls_enabled and runtime.player.position==Vector2(40,40),"E did not sit on the actual chair")
		check(runtime.player.facing.distance_to(Orientation.facing(chair))<.001,"Seat arrow did not set the seated view")
		var original: Vector2 = runtime.player.position
		runtime.player._move_on_foot(Vector2.RIGHT,.2)
		check(runtime.player.position==original,"WASD moved the seated player")
		var sprite := preload("res://scripts/npcs/creation/npc_pose_art.gd").artwork({"npc_asset":"player"},{},"",runtime.player.facing,"sit",0)
		check(not sprite.is_empty() and sprite.pose and sprite.get("rig",{}).get("seated",false),"Player sitting cutout profile missing")
		key(runtime,KEY_E)
		check(not runtime.player.seated and runtime.player.controls_enabled and layer.is_traversable(runtime.player.position,4),"E did not stand safely")
	check(not layer.is_traversable(Vector2(40,40),4),"Sitting disabled ordinary furniture collision")
	var stool:=item("stool","bar_stool",Vector2(10,5))
	var counter:=item("bar","bar_counter",Vector2(10,4.35))
	layer.floor_data.furniture=[stool,counter]
	runtime.player.position=Vector2(10,5.9)*8
	key(runtime,KEY_E)
	check(runtime.player.seated and runtime.seated_item.id=="stool","Bar stool beside a counter cannot be used")
	key(runtime,KEY_E)
	check(not runtime.player.seated and layer.is_traversable(runtime.player.position,4),"Cannot stand from a bar stool")
	check(not Seating.clear_route(layer,Vector2(10,3)*8,Vector2(10,5)*8,"stool",4),"Stool interaction crossed a solid bar counter")
	layer.floor_data.furniture=[chair]
	runtime.player.position=Vector2(40,48); key(runtime,KEY_E)
	key(runtime,KEY_M); key(runtime,KEY_M)
	check(runtime.player.seated and not runtime.player.controls_enabled,"Closing map reenabled seated movement")
	runtime.population.set_active_interior("seat_test","ground_floor")
	runtime.population.agents.assign([{"kind":"person","space":"interior","building_id":"seat_test","floor_id":"ground_floor","position":Vector2(55,40),"angle":0.0,"moving":false,"name":"Seated visitor"}])
	var seat_facing: Vector2 = runtime.player.facing
	runtime._start_conversation()
	check(runtime.conversation_active and runtime.player.facing==seat_facing,"Talking changed seat direction")
	runtime._end_conversation("Test end")
	runtime.population.agents.clear()
	check(runtime.player.seated and not runtime.player.controls_enabled,"Dialogue end reenabled seated movement")
	key(runtime,KEY_E)
	runtime.population.agents.assign([{"kind":"person","space":"interior","building_id":"seat_test","floor_id":"ground_floor","position":Vector2(40,40)}])
	runtime.player.position=Vector2(40,48); key(runtime,KEY_E)
	check(not runtime.player.seated and runtime.notice_text.contains("occupied"),"Sitting inside an NPC accepted")
	runtime.population.agents.clear()
	layer.floor_data.walls=[{"id":"wall","start_x_metres":0,"start_y_metres":5.5,"end_x_metres":20,"end_y_metres":5.5,"thickness_metres":.18,"doors":[]}]
	check(Seating.nearest(layer,Vector2(40,48)).is_empty(),"Seat selected through wall")
	layer.floor_data.walls=[]
	layer.floor_data.furniture=[chair,{"id":"gap_left","x_metres":4.0,"y_metres":5.5,"width_metres":1.5,"depth_metres":.2,"collision":true},{"id":"gap_right","x_metres":6.0,"y_metres":5.5,"width_metres":1.5,"depth_metres":.2,"collision":true}]
	check(Seating.nearest(layer,Vector2(40,48),4).is_empty(),"Seat reach crossed a slit narrower than player's body")
	layer.floor_data.furniture=[chair]
	check(Seating.nearest(layer,Vector2(100,100)).is_empty(),"Distant seat selected")
	runtime.player.position=Vector2(40,48); key(runtime,KEY_E)
	layer.floor_data.furniture.append({"id":"blocked","x_metres":5,"y_metres":5,"width_metres":6,"depth_metres":6,"collision":true})
	key(runtime,KEY_E)
	check(runtime.player.seated and runtime.notice_text.contains("no clear space"),"Blocked stand corrupted the seated state")
	layer.floor_data.furniture=[chair]
	key(runtime,KEY_E)
	check(not runtime.player.seated,"Standing did not retry after obstruction cleared")
	var toilet := item("toilet","toilet",Vector2(8,5),90.0)
	toilet.seat_direction_degrees=270.0
	layer.floor_data.furniture=[toilet]
	runtime.player.position=Vector2(8.8,5)*8
	key(runtime,KEY_E)
	check(runtime.player.seated and runtime.player.position.distance_to(Orientation.position(toilet)*8)<.001,"Toilet bowl seat anchor incorrect")
	check(Art.direction_column(runtime.player.facing)==2,"Toilet arrow ignored independent direction")
	key(runtime,KEY_E)
	check(not runtime.player.seated,"Cannot stand from toilet")
	var cubicle := item("cubicle","toilet_cubicle",Vector2(10,8))
	layer.floor_data.furniture=[cubicle]
	check(Seating.nearest(layer,Vector2(10.99,7.2)*8).is_empty(),"Cubicle side partition bypassed")
	runtime.player.position=Vector2(10,8.3)*8
	key(runtime,KEY_E)
	check(runtime.player.seated,"Accessible cubicle toilet cannot be used")
	key(runtime,KEY_E)
	check(not runtime.player.seated and layer.is_traversable(runtime.player.position,4),"Cubicle stand not safe")
	for node in [runtime.population,runtime.renderer,runtime.wagon,runtime.map_buttons,runtime.map_coordinates,runtime.map_copy_button,runtime.map_cursor_marker,runtime.conversation_layer,runtime.conversation_input,runtime.conversation_send_button,runtime.conversation_end_button,runtime.conversation_shop_button]: node.free()
	runtime.free(); await frames()
	await editor_checks()
	if OS.get_cmdline_user_args().has("--render"): await pictures()
	print("PLAYER SEATING: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

func editor_checks() -> void:
	root.size=Vector2i(1366,900); root.content_scale_size=root.size
	var directory := ProjectSettings.globalize_path("res://tools/tests/output/seating-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("town.json"),FileAccess.WRITE); file.store_string('{"town_id":"seat-test","display_name":"Seat test"}'); file.close()
	var feature := {"id":"seat_test","kind":"building","points":[Vector2(146,-36),Vector2(146.0003,-36),Vector2(146.0003,-36.0004),Vector2(146,-36.0004),Vector2(146,-36)],"tags":{"building":"yes"}}
	var store := Store.new()
	var data: Dictionary = store.create_blank_ground_floor(store.empty_data(),feature).data
	data.buildings.seat_test.floors=[floor_fixture()]
	data.buildings.seat_test.floors[0].furniture=[item("chair","dining_chair",Vector2(5,5)),item("toilet","toilet",Vector2(9,5))]
	check(store.save_to_town(directory,data).ok,"Seat fixture Save failed")
	var studio = load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=directory
	studio.imported_town={"ok":true,"features":[feature],"bounds":{"west":145.99,"east":146.01,"south":-36.01,"north":-35.99},"warnings":[],"statistics":{}}
	studio._show_interior_designer_page(); await frames(); studio.message_dialog.hide()
	studio.interior_tools_navigation.open_page("seat_direction"); await frames()
	var canvas = studio.interior_floor_canvas
	check(canvas.seat_direction_edit_enabled and canvas.size.y>400,"Seat direction tool or large map absent")
	for index in 2:
		var value: Dictionary = canvas.floor_data.furniture[index]
		mouse(canvas,canvas._metres_to_screen(Orientation.position(value)),true); mouse(canvas,canvas._metres_to_screen(Orientation.position(value)),false)
		check(canvas.selected_furniture_id==str(value.id),"Seat click did not select")
		mouse(canvas,canvas._seat_arrow_tip(value,Orientation.angle(value)),true)
		var target: Vector2 = canvas._metres_to_screen(Orientation.position(value))+Vector2.LEFT*48
		var move := InputEventMouseMotion.new(); move.position=target; canvas._gui_input(move)
		check(not studio.interior_data.buildings.seat_test.floors[0].furniture[index].has("seat_direction_degrees"),"Arrow preview changed canonical data")
		mouse(canvas,target,false); await frames()
		check(is_equal_approx(studio.interior_data.buildings.seat_test.floors[0].furniture[index].seat_direction_degrees,90),"Held arrow failed to set direction")
	studio.top_undo_button.pressed.emit(); await frames()
	check(not studio.interior_data.buildings.seat_test.floors[0].furniture[1].has("seat_direction_degrees"),"Seat direction Undo failed")
	studio._on_seat_direction_requested("toilet",270)
	studio._save_active_section(); await frames(); studio.message_dialog.hide()
	var reopened := store.load_from_town(directory)
	check(reopened.ok and reopened.data.buildings.seat_test.floors[0].furniture[1].seat_direction_degrees==270,"Seat angle Save/reopen failed")
	check(not Orientation.set_direction(data,"seat_test","ground_floor","chair",NAN).ok,"Nonfinite seat angle accepted")
	for angle in [359.99,-.01,720.0]:
		var wrapped := Orientation.set_direction(data,"seat_test","ground_floor","chair",angle)
		check(wrapped.ok and wrapped.data.buildings.seat_test.floors[0].furniture[0].seat_direction_degrees==0,"Wrapped arrow angle became invalid")
	var invalid: Dictionary = reopened.data.duplicate(true); invalid.buildings.seat_test.floors[0].furniture[1].seat_direction_degrees=360
	check(not store.validate(invalid).ok,"Noncanonical seat angle accepted")
	if OS.get_cmdline_user_args().has("--render"):
		await frames(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/seat_direction_editor_v16.png"))
	studio.free(); await frames()

func pictures() -> void:
	root.size=Vector2i(1100,700); root.content_scale_size=root.size
	var background := ColorRect.new(); background.color=Color("#253a2e"); background.size=Vector2(1100,700); root.add_child(background)
	var title := Label.new(); title.position=Vector2(20,12); title.text="PLAYER SITTING · FRONT / LEFT / RIGHT / BACK · ACTUAL GAME FURNITURE"; title.add_theme_font_size_override("font_size",19); root.add_child(title)
	for index in 4:
		var preview := Preview.new(); preview.pose="sit"; preview.frozen=true; preview.appearance={"npc_asset":"player"}
		preview.facing=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][index]
		preview.position=Vector2(10+index*272,60); preview.size=Vector2(265,290); root.add_child(preview)
		var toilet := Preview.new(); toilet.pose="sit"; toilet.frozen=true; toilet.appearance={"npc_asset":"player"}; toilet.seat_id="toilet"
		toilet.facing=preview.facing; toilet.position=Vector2(10+index*272,380); toilet.size=Vector2(265,290); root.add_child(toilet)
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/player_seated_chairs_toilets_v16.png"))
