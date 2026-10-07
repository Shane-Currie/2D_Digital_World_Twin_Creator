extends SceneTree

const Store = preload("res://scripts/interiors/building_interior_store.gd")
const Connections = preload("res://scripts/interiors/connections/building_connections.gd")
const Layer = preload("res://scripts/interiors/runtime_interior_layer.gd")
const Runtime = preload("res://scripts/runtime/town_runtime.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
var failures := 0
var checks := 0
var features: Array = []
var data: Dictionary = {}
var temporary := ""

class GroundStub extends Node2D:
	func is_ground_traversable(_point: Vector2, _clearance := 0.0) -> bool: return true

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames() -> void:
	for count in 4: await process_frame
func feature(id: String, x: float, y := 0.0, width := 10.0, height := 12.0) -> Dictionary:
	var geo: Array = []
	for point in [Vector2(x,y), Vector2(x+width,y),Vector2(x+width,y+height),Vector2(x,y+height),Vector2(x,y)]:
		geo.append(Connections.unproject(point,[146.915,-36.08]))
	return {"kind":"building","id":id,"points":geo,"holes":[],"tags":{"name":"The Pub" if id=="a" else "Next-door lounge"}}
func door_at(y: float, id := "") -> Dictionary:
	var floor := Connections.floor_for(data,"a","ground_floor")
	return Connections.set_door(data,features,"a","ground_floor","b","ground_floor",Vector2(float(floor.width_metres),y),id)

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Connection test timed out."); quit(2))
	root.size = Vector2i(1200,800)
	var store := Store.new()
	features = [feature("a",0),feature("b",10)]
	data = store.empty_data()
	for value in features: data = store.create_blank_ground_floor(data,value).data
	var before := data.duplicate(true)
	check(Connections.shared_segments(features[0],features[1]).size()==1,"Exactly shared wall not recognised.")
	var vector_features: Array = features.duplicate(true)
	for value in vector_features:
		value["precise_points"] = value.points.duplicate(true)
		var vectors: Array[Vector2] = []
		for point in value.points: vectors.append(Vector2(float(point[0]),float(point[1])))
		value.points=vectors
	check(Connections.shared_segments(vector_features[0],vector_features[1]).size()==1,"Creator vector representation failed precise adjacency.")
	var vector_gap: Dictionary = feature("b",10.01)
	vector_gap["precise_points"] = vector_gap.points.duplicate(true)
	var gap_vectors: Array[Vector2] = []
	for point in vector_gap.points: gap_vectors.append(Vector2(float(point[0]),float(point[1])))
	vector_gap.points=gap_vectors
	check(Connections.shared_segments(vector_features[0],vector_gap).is_empty(),"Creator float vectors concealed a real gap.")
	var malformed: Dictionary = features[1].duplicate(true)
	malformed["precise_points"] = 42
	check(Connections.shared_segments(features[0],malformed).is_empty(),"Malformed precise coordinate data crashed or connected.")
	var imported: Dictionary = load("res://scripts/towns/osm_importer.gd").new().parse_files(PackedStringArray(["res://tools/tests/fixtures/tiny_town.osm"]))
	var imported_building: Dictionary = imported.features.filter(func(value): return str(value.kind)=="building")[0]
	check(imported_building.precise_points[0]==[146.003,-36.006],"OSM importer discarded original double coordinates.")
	for gap in [0.01,0.1,1.0,4.0]:
		check(Connections.shared_segments(features[0],feature("b",10+gap)).is_empty(),"A real %.2f m gap was accepted." % gap)
	check(Connections.shared_segments(features[0],feature("b",10,12)).is_empty(),"Corner-only contact accepted.")
	check(Connections.shared_segments(features[0],feature("b",0)).is_empty(),"Overlapping duplicate accepted.")
	var reversed: Dictionary = features[1].duplicate(true)
	reversed.points.reverse()
	check(Connections.shared_segments(features[0],reversed).size()==1,"Reversed winding rejected.")
	check(Connections.shared_segments(features[0],feature("b",10,4,10,5)).size()==1,"Partial shared wall rejected.")
	var rotated: Array = features.duplicate(true)
	for value in rotated:
		for i in value.points.size():
			value.points[i] = Connections.unproject(Connections.project(value.points[i],[146.915,-36.08]).rotated(0.3),[146.915,-36.08])
	check(Connections.shared_segments(rotated[0],rotated[1]).size()==1,"Rotated shared wall rejected.")
	var rotated_data := store.empty_data()
	for value in rotated: rotated_data = store.create_blank_ground_floor(rotated_data,value).data
	var rotated_segment: Dictionary = Connections.shared_segments(rotated[0],rotated[1])[0]
	var rotated_anchor: Array = [(float(rotated_segment.start[0])+float(rotated_segment.finish[0]))*.5,(float(rotated_segment.start[1])+float(rotated_segment.finish[1]))*.5]
	var rotated_pair := Connections.set_door(rotated_data,rotated,"a","ground_floor","b","ground_floor",Connections.local_point(rotated[0],rotated_data.buildings.a.floors[0],rotated_anchor))
	check(rotated_pair.ok and Connections.validate(rotated_pair.data,rotated).ok,"Rotated saved floor mapping failed.")
	var added := door_at(6)
	check(added.ok,"Shared-wall paired placement failed: %s" % added)
	if not added.ok: quit(1); return
	data = added.data
	check(data.buildings==before.buildings,"Connecting a door reshaped/furnished a floor.")
	check(store.validate(data).ok and Connections.validate(data,features).ok,"Canonical paired door rejected.")
	var pair: Dictionary = data.building_connections[0]
	check(Connections.position(pair.from).distance_to(Connections.wall_position(pair.from))==1 and Connections.position(pair.to).distance_to(Connections.wall_position(pair.to))==1,"Arrival inset incorrect.")
	check(Connections.endpoints(data,"a","ground_floor").size()==1 and Connections.endpoints(data,"b","ground_floor").size()==1,"Reciprocal endpoints missing.")
	var bad := data.duplicate(true)
	bad.building_connections.append({"id":"broken","from":42,"to":{}})
	check(not Connections.validate(bad,features).ok,"Malformed later pair crashed or passed.")
	bad = data.duplicate(true)
	bad.building_connections[0].to.x_metres = NAN
	check(not Connections.validate(bad,features).ok,"Non-finite endpoint accepted.")
	check(not Connections.validate(data,[features[0],feature("b",10.01)]).ok,"Saved door over a new gap accepted.")
	check(not Connections.propose(data,features,"a","ground_floor","b","missing",Vector2(10,6)).ok,"Missing floor accepted.")
	bad = data.duplicate(true)
	bad.buildings.b.floors[0].level = 1
	check(not Connections.validate(bad,features).ok,"Mismatched floor levels accepted.")
	var upstairs: Dictionary = store.add_upper_floor(store.add_upper_floor(data,"a").data,"b").data
	check(Connections.set_door(upstairs,features,"a","floor_1","b","floor_1",Vector2(float(upstairs.buildings.a.floors[1].width_metres),6)).ok,"Matching upper floors cannot connect.")
	var arrival := Connections.position(pair.to)
	check(not store.place_furniture(data,"b","ground_floor","dining_chair",arrival,0).ok,"Furniture obstructed existing door.")
	check(not store.add_wall(data,"b","ground_floor",arrival-Vector2(0.8,0),arrival+Vector2(2,0)).ok,"Wall obstructed existing door.")
	check(not store.set_entry_spawn(data,"b","entrance_1",arrival).ok,"Outside arrival obstructed connecting door.")
	var npc := {"space":"interior","building_id":"b","floor_id":"ground_floor","x_metres":arrival.x,"y_metres":arrival.y}
	check(not store.validate_location(data,npc).ok,"NPC placement obstructed connecting door.")
	check(not Connections.validate(data,features,[{"location":npc}]).ok,"Existing NPC on destination accepted.")
	bad = data.duplicate(true)
	bad.buildings.b.floors[0].furniture.append({"id":"bad","catalog_id":"dining_chair","x_metres":arrival.x,"y_metres":arrival.y,"width_metres":1,"depth_metres":1,"collision":true})
	check(not Connections.validate(bad,features).ok,"Occupied furniture arrival accepted.")
	bad = data.duplicate(true)
	bad.buildings.b.floors[0].holes_metres=[[[.8,5.8],[1.2,5.8],[1.2,6.2],[.8,6.2]]]
	check(not Connections.validate(bad,features).ok,"Courtyard in arrival accepted.")
	data.building_connections[0].locked = true
	var moved := door_at(8,str(pair.id))
	check(moved.ok and bool(moved.data.building_connections[0].locked),"Dragging lost lock or failed.")
	check(moved.ok and absf(float(moved.data.building_connections[0].to.y_metres)-8)<0.05,"Drag did not move both sides.")
	check(not door_at(-3,str(pair.id)).ok,"Invalid drag accepted.")
	data.building_connections[0].locked = false
	var resized: Dictionary = store.resize_floor(data,"a","ground_floor",1.5)
	check(resized.ok and Connections.validate(resized.data,features).ok,"Resized connected floor rejected.")
	check(resized.ok and resized.data.building_connections[0].to==pair.to,"Resizing moved the other building's door.")
	check(not store.add_stair_pair(store.add_upper_floor(data,"b").data,"b","ground_floor",arrival,"floor_1",Vector2(5,6)).ok,"Stairs obstructed connecting arrival.")
	data = store.set_entry_spawn(data,"a","entrance_1",Vector2(2,2)).data
	data = store.set_entry_spawn(data,"b","entrance_1",Vector2(7,2)).data
	data = store.place_furniture(data,"a","ground_floor","bar_counter",Vector2(4,9),0).data
	data = store.place_furniture(data,"b","ground_floor","sofa",Vector2(6,9),0).data
	temporary = ProjectSettings.globalize_path("res://tools/tests/output/connections-%s" % OS.get_process_id())
	check(store.save_to_town(temporary,data).ok,"Paired door could not save.")
	var reloaded: Dictionary = store.load_from_town(temporary)
	check(reloaded.ok and Connections.validate(reloaded.data,features).ok and reloaded.data.building_connections[0].id==pair.id and Connections.position(reloaded.data.building_connections[0].from).distance_to(Connections.position(pair.from))<.001,"Save/reload lost paired door.")
	var fixture := FileAccess.open(temporary.path_join("connection_fixture.json"),FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"data":data,"features":features},"  ")); fixture.close()
	print("CONNECTION FIXTURE: ",temporary.path_join("connection_fixture.json"))
	await runtime_checks()
	await gui_checks()
	albury_shared_wall_check()
	print("BUILDING CONNECTIONS %s: %d checks" % ["PASSED" if failures==0 else "FAILED",checks])
	quit(0 if failures==0 else 1)

func albury_shared_wall_check() -> void:
	var town := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var interior_path := town.path_join("data/building_interiors.json")
	var feature_path := town.path_join("data/map_features.json")
	if not FileAccess.file_exists(interior_path): return
	var source_hash := FileAccess.get_sha256(interior_path)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(interior_path))
	var mapped: Array = JSON.parse_string(FileAccess.get_file_as_string(feature_path)).features
	mapped = Connections.with_source_precision(town,mapped)
	check(mapped.any(func(value): return str(value.get("kind", "")) == "building" and not value.get("precise_points", []).is_empty()), "Older saved Albury could not recover OSM precision automatically.")
	var pub_id := ""
	for id in source.buildings:
		if str(source.buildings[id].get("name", "")) == "The Pub": pub_id = str(id); break
	check(not pub_id.is_empty(), "Actual Albury Pub not found for read-only check.")
	if pub_id.is_empty(): return
	var pub := Connections.feature_for(mapped,pub_id)
	var proposed: Dictionary = {}
	var neighbour_id := ""
	for neighbour in mapped:
		if str(neighbour.get("kind", "")) != "building": continue
		var segments := Connections.shared_segments(pub,neighbour)
		if segments.is_empty(): continue
		neighbour_id = str(neighbour.id)
		var local := source.duplicate(true)
		if not local.buildings.has(neighbour_id): local = Store.new().create_blank_ground_floor(local,neighbour).data
		var floor := Connections.floor_for(local,pub_id,"ground_floor")
		for segment in segments:
			for step in range(2,19):
				var fraction := float(step)/20
				var anchor: Array = [lerpf(float(segment.start[0]),float(segment.finish[0]),fraction),lerpf(float(segment.start[1]),float(segment.finish[1]),fraction)]
				proposed = Connections.set_door(local,mapped,pub_id,"ground_floor",neighbour_id,"ground_floor",Connections.local_point(pub,floor,anchor))
				if proposed.ok: break
			if proposed.get("ok",false): break
		if proposed.get("ok",false): break
	check(bool(proposed.get("ok",false)), "No clear connecting door on actual Pub shared walls: %s" % proposed)
	if proposed.get("ok",false):
		check(Connections.validate(proposed.data,mapped).ok and proposed.data.buildings[pub_id]==source.buildings[pub_id],"Actual Pub connection changed its furnished layout or failed mapped validation.")
		print("ALBURY SHARED WALL: ",pub_id," ↔ ",neighbour_id,"; read-only, no footprint/furniture edits.")
		var fixture := FileAccess.open(temporary.path_join("albury_connection_fixture.json"),FileAccess.WRITE)
		fixture.store_string(JSON.stringify({"data":proposed.data,"features":[pub,Connections.feature_for(mapped,neighbour_id)]},"  ")); fixture.close()
	check(FileAccess.get_sha256(interior_path)==source_hash,"Actual Albury interior file changed.")

func runtime_checks() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var layer := Layer.new()
	stage.add_child(layer)
	var runtime := Runtime.new() # No game startup, local LLM or user saves.
	runtime.building_interior_data = data.duplicate(true)
	runtime.collision_data = {"runtime_scale":{"pixels_per_metre":8.0}}
	runtime.interior_layer = layer
	runtime.player = Player.new()
	runtime.player.process_mode = Node.PROCESS_MODE_DISABLED
	runtime.player.z_index = 5
	stage.add_child(runtime.player)
	runtime.population = Population.new()
	runtime.population.process_mode = Node.PROCESS_MODE_DISABLED
	runtime.population.z_index = 4
	stage.add_child(runtime.population)
	runtime.population.set_interior_visibility_check(layer.is_position_discovered)
	runtime.renderer = GroundStub.new(); runtime.tracks = Node2D.new(); runtime.wagon = Node2D.new()
	var resident := {"kind":"person","space":"interior","building_id":"b","floor_id":"ground_floor","position":Vector2(35,48),"phase":0.0,"angle":0.0,"moving":false,"npc_asset":"npc_medium_man_adult","name":"Lounge resident"}
	runtime.population.agents.assign([resident])
	var entrance := {"record":data.buildings.a,"floor":data.buildings.a.floors[0],"link":data.buildings.a.floors[0].entry_links[0],"feature_id":"a","building_name":"The Pub","world_position":Vector2(500,600)}
	runtime.interior_entrances = [{"record":data.buildings.b,"floor":data.buildings.b.floors[0],"link":data.buildings.b.floors[0].entry_links[0],"feature_id":"b","building_name":"Lounge","world_position":Vector2(900,600)}]
	runtime._enter_interior(entrance)
	var endpoint: Dictionary = data.building_connections[0].from
	runtime.player.position = Connections.position(endpoint)*8
	layer.update_player_position(runtime.player.position)
	check(runtime.inside_building_id=="a" and not runtime.population.nearest_conversation_target(Vector2(35,48),30).has("index"),"Entering door area changed buildings or exposed next-door NPC.")
	var use := InputEventKey.new(); use.keycode=KEY_E; use.pressed=true
	var discovery := layer.discovered_components.duplicate(true)
	if OS.get_cmdline_user_args().has("--render"):
		stage.position=Vector2(400,160); stage.scale=Vector2.ONE*5
		await runtime_image(stage,runtime,"connected_buildings_pub_revision2.png","The Pub — E at the shared-wall door")
	runtime._unhandled_input(use)
	check(runtime.inside_building_id=="b" and runtime.player.position.distance_to(Connections.position(data.building_connections[0].to)*8)<0.01,"E did not transfer directly to adjacent interior.")
	check(runtime.inside_building_name=="Next-door lounge" and runtime.inside_floor_id=="ground_floor","Active building context not updated.")
	check(not runtime.population.nearest_conversation_target(Vector2(35,48),30).is_empty(),"Destination NPC not available after transfer.")
	check(layer.exit_position==Vector2(56,16) and runtime.exterior_return_position==Vector2(900,600),"Destination outside entrance not selected.")
	if OS.get_cmdline_user_args().has("--render"): await runtime_image(stage,runtime,"connected_buildings_lounge_revision2.png","Next-door lounge — arrived indoors, not outside")
	runtime._unhandled_input(use)
	check(runtime.inside_building_id=="a" and runtime.exterior_return_position==Vector2(500,600) and layer.exit_position==Vector2(16,16),"Returning lost original outside entrance.")
	check(layer.discovered_components==discovery,"Return lost room discovery.")
	layer.connection_endpoints[0].locked=true
	runtime._unhandled_input(use)
	check(runtime.inside_building_id=="a" and runtime.notice_text.contains("locked"),"Locked door transferred player.")
	layer.connection_endpoints[0].locked=false
	runtime.conversation_active=true; runtime._unhandled_input(use)
	check(runtime.inside_building_id=="a","Door interrupted active dialogue.")
	runtime.conversation_active=false
	# A previously seen connecting door must not work through an internal wall.
	layer.floor_data.walls=[{"id":"wall_test","start_x_metres":6,"start_y_metres":0,"end_x_metres":6,"end_y_metres":12,"thickness_metres":.18,"doors":[]}]
	check(layer.nearest_connection(Vector2(5.9,6)*8).is_empty(),"Connecting door could be used through an internal wall.")
	layer.floor_data.walls.clear()
	runtime.population.agents[0].position=Connections.position(data.building_connections[0].to)*8
	runtime._unhandled_input(use)
	check(runtime.inside_building_id=="a" and runtime.notice_text.contains("Someone"),"Player transferred inside destination NPC.")
	runtime.population.agents[0].position=Vector2(35,48)
	runtime.building_interior_data.buildings.b.floors[0].furniture.append({"x_metres":1,"y_metres":6,"width_metres":2,"depth_metres":2,"collision":true})
	runtime._unhandled_input(use)
	check(runtime.inside_building_id=="a" and str(layer.floor_data.id)=="ground_floor","Blocked destination mutated occupied state.")
	runtime.building_interior_data=data.duplicate(true)
	runtime.interior_entrances.clear()
	runtime.interior_outside_routes.erase("b")
	runtime._unhandled_input(use)
	check(runtime.inside_building_id=="b" and not layer.exterior_exit_enabled and runtime.inside_exterior_link.is_empty(),"Connected-only building invented an outside exit.")
	runtime._unhandled_input(use)
	check(runtime.inside_building_id=="a","Connected-only building stranded player.")
	runtime.player.position=layer.exit_position
	runtime._unhandled_input(use)
	check(runtime.inside_building_id.is_empty() and runtime.player.position==Vector2(500,600),"Outside return failed after reciprocal travel.")
	for node in [runtime.renderer,runtime.tracks,runtime.wagon]: node.free()
	stage.free(); runtime.free()
	await frames()

func runtime_image(stage: Node2D, runtime: Node, filename: String, title: String) -> void:
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var header := Label.new(); header.text=title; header.position=Vector2(70,35); header.add_theme_font_size_override("font_size",24); overlay.add_child(header)
	var help := Label.new(); help.text="Focused runtime test • original footprints stay separate\nGreen door: press E to transfer directly indoors\nFurniture and outside exits remain building-specific"; help.position=Vector2(70,700); overlay.add_child(help)
	stage.visible=true; runtime.player.show()
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/"+filename))
	overlay.free()

func click(canvas: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=canvas._metres_to_screen(point); canvas._gui_input(event)
func move(canvas: Control, point: Vector2) -> void:
	var event := InputEventMouseMotion.new(); event.position=canvas._metres_to_screen(point); canvas._gui_input(event)

func gui_checks() -> void:
	if OS.get_cmdline_user_args().has("--render"): root.size=Vector2i(1440,1000)
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio.imported_town = studio.importer.parse_files(PackedStringArray(["res://tools/tests/fixtures/tiny_town.osm"]))
	studio.imported_town.features=features.duplicate(true)
	studio.loaded_project_directory=temporary
	studio._show_interior_designer_page(); studio.message_dialog.hide()
	await frames()
	check(studio.interior_tools_navigation.pages.has("connections"),"Connecting doors tool missing.")
	studio.interior_tools_navigation.open_page("connections")
	check(studio.interior_connection_target.item_count==1 and not studio.interior_connection_add.disabled,"Shared neighbour not offered.")
	var canvas = studio.interior_floor_canvas
	var pair: Dictionary = studio.interior_data.building_connections[0]
	click(canvas,Connections.wall_position(pair.from),true)
	move(canvas,Vector2(Connections.wall_position(pair.from).x,8))
	click(canvas,Vector2(Connections.wall_position(pair.from).x,8),false)
	check(absf(float(studio.interior_data.building_connections[0].to.y_metres)-8)<.05,"GUI drag did not move reciprocal endpoint.")
	var retained: Dictionary = studio.interior_data.duplicate(true)
	click(canvas,Connections.wall_position(studio.interior_data.building_connections[0].from),true)
	move(canvas,Vector2(-2,-2)); click(canvas,Vector2(-2,-2),false)
	check(studio.interior_data==retained and not studio.message_dialog.visible and canvas.invalid_position!=Vector2.INF,"Invalid drag changed state or showed popup.")
	studio._toggle_connection_lock()
	check(bool(studio.interior_data.building_connections[0].locked),"GUI lock failed.")
	studio._toggle_connection_lock()
	if OS.get_cmdline_user_args().has("--render"):
		await frames(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/connected_buildings_editor_revision2.png"))
	studio._remove_connection()
	check(studio.interior_data.building_connections.is_empty(),"Removal left an orphan endpoint.")
	canvas.placing_connection=true
	click(canvas,Vector2(float(studio.interior_data.buildings.a.floors[0].width_metres),6),true)
	check(studio.interior_data.building_connections.size()==1,"GUI click did not place paired door.")
	canvas.placing_connection=true
	studio.interior_tools_navigation.show_home()
	check(not canvas.placing_connection and not canvas.connection_edit_enabled,"Back left door placement active.")
	check(Connections.validate(studio.interior_data,features).ok,"GUI canonical door invalid.")
	check(studio.building_interior_store.save_to_town(temporary,studio.interior_data).ok,"GUI-edited pair could not save.")
	studio._save_interior_layouts(); studio.message_dialog.hide()
	var saved: Dictionary = studio.building_interior_store.load_from_town(temporary)
	check(saved.ok and saved.data.building_connections.size()==1 and Connections.validate(saved.data,features).ok,"Top Save lost the connecting pair.")
	# Explicitly create an adjoining-only blank interior; never overwrite one.
	studio.interior_data.buildings.erase("b")
	studio.interior_data.building_connections.clear()
	studio._refresh_interior_designer_controls()
	studio.interior_tools_navigation.open_page("connections")
	check(not studio.interior_connection_create.disabled and studio.interior_connection_add.disabled,"Uncreated neighbour does not offer explicit floor creation.")
	studio._create_connection_neighbour()
	check(studio.interior_data.buildings.has("b") and not studio.interior_connection_add.disabled,"Neighbour ground floor creation failed.")
	var preserved: Dictionary = studio.interior_data.duplicate(true)
	studio._create_connection_neighbour()
	check(studio.interior_data==preserved,"Creating neighbour overwrote its floor.")
	studio._on_interior_building_selected(studio.interior_eligible_features.size()-1)
	check(str(studio.interior_selected_feature.id)=="b" and not studio.interior_floor_canvas.placing_connection,"Neighbour interior unavailable or old placement survived building change.")
	studio.queue_free(); await frames()
