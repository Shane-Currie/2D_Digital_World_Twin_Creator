extends SceneTree

const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")
const Art=preload("res://scripts/npcs/rigging/npc_rig_art.gd")
const Importer=preload("res://scripts/npcs/rigging/npc_rig_import.gd")
const Store=preload("res://scripts/npcs/creation/npc_creation_store.gd")
const PoseArt=preload("res://scripts/npcs/creation/npc_pose_art.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func frames() -> void:
	for _i in 6: await process_frame
func mouse(canvas,point: Vector2,pressed: bool,button: int=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new(); event.position=point; event.button_index=button; event.pressed=pressed; canvas._gui_input(event)
func run() -> void:
	create_timer(60).timeout.connect(func():push_error("Rig test timed out");quit(2))
	root.size=Vector2i(1366,1000); root.content_scale_size=root.size; root.gui_embed_subwindows=true
	var temporary:=ProjectSettings.globalize_path("res://tools/tests/output/npc-rig-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temporary.path_join("data"))
	var file:=FileAccess.open(temporary.path_join("town.json"),FileAccess.WRITE); file.store_string('{"town_id":"rig-fixture","display_name":"Rig test"}'); file.close()
	var studio=load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=temporary
	studio.imported_town=studio.importer.parse_files(PackedStringArray(["res://tools/tests/fixtures/tiny_town.osm"]))
	studio._show_personas_page(); studio.npc_tools_navigation.open_page("creation"); await frames()
	var editor=studio.npc_creation_editor
	editor._new_rig(); await frames()
	var item: Dictionary=editor._item(); var rig: Dictionary=item.rig
	check(editor.rig_workspace.visible and editor.test_button.visible,"Rig workflow/test button absent")
	check(Rig.validate(rig).ok and Store.validate(editor.data,temporary).ok,"Starter data invalid")
	for view in Rig.VIEWS:
		check(Rig.count_parts(rig,view)==10,"Incomplete starter "+view)
		for part in Rig.PARTS: check(Importer.image_valid(temporary.path_join(rig.views[view].parts[part].image),rig.views[view].parts[part].get("region",[])),"Invalid starter image "+view+part)
	check(Store.built_ins().size()==18,"Legacy catalogue changed")
	check(PoseArt.artwork(Store.appearance(item,true),editor.data,temporary,Vector2.DOWN,"walk",.1).has("rig"),"Production renderer did not choose rig")
	check(not PoseArt.artwork(Store.appearance(item,true),editor.data,temporary,Vector2.DOWN,"sit",.1).pose,"Absent seated art incorrectly marked seated")
	editor.name_edit.text="My walking character"; editor._flush()
	check(editor._item().name=="My walking character","Name not editable")
	check(Store.save_to_town(temporary,editor.data).ok,"Save failed")
	var reopened:=Store.load_from_town(temporary)
	check(reopened.ok,"Reopen invalid: "+str(reopened.get("message","")))
	if not reopened.ok: studio.free(); quit(1); return
	check(Store.find(reopened.data,item.id).rig==JSON.parse_string(JSON.stringify(rig)),"Reopen changed skeleton")
	var bad:=rig.duplicate(true); bad.views.front.parts.head.image="assets/npcs/../escape.png"
	check(not Rig.validate(bad).ok,"Path escape accepted")
	bad=rig.duplicate(true); bad.views.left.parts.erase("head")
	check(not Rig.validate(bad).ok,"Malformed optional view accepted")
	bad=rig.duplicate(true); bad.views.front.parts.head.pivot=[2,0]
	check(not Rig.validate(bad).ok,"Invalid image pivot accepted")
	bad=rig.duplicate(true); bad.views.back.parts.head.image=""
	check(Art.chosen_view(bad,"back")=="front","Incomplete direction did not fall back")
	var rest:=Art.transforms(rig,"left",0,false)
	var walking:=Art.transforms(rig,"left",.25/rig.walk_cycles_per_second,true)
	check(walking.head==rest.head and walking.torso==rest.torso,"Walking distorts face/torso")
	check(walking.left_thigh.get_rotation()*walking.right_thigh.get_rotation()<0,"Legs do not move opposite ways")
	check(not walking.left_upper_arm.is_equal_approx(rest.left_upper_arm),"Arms do not swing")
	check(walking.left_shin.origin.is_equal_approx(walking.left_thigh*Vector2(rig.views.left.parts.left_shin.position[0],rig.views.left.parts.left_shin.position[1])),"Knee detached from parent thigh")
	check(Art.layout(rig,"front",0,false)==Art.layout(rig,"front",2,false),"Idle pose moves")
	check(Art.layout(rig,"left",0,true)!=Art.layout(rig,"left",.25/rig.walk_cycles_per_second,true),"Walking frames are identical")
	var bounds:=Rect2(); var first:=true
	for piece in Art.layout(rig,"front",0,false).pieces:
		for point in piece.points:
			if first: bounds=Rect2(point,Vector2.ZERO); first=false
			else: bounds=bounds.expand(point)
	check(is_equal_approx(bounds.size.y,13.75) and bounds.size.x<=7.5 and is_zero_approx(bounds.end.y),"Rig differs from existing shared character scale/foot anchor")
	var source: String=temporary.path_join("head.png")
	var upload_fixture:=Image.create(32,32,false,Image.FORMAT_RGBA8); upload_fixture.fill(Color.WHITE); upload_fixture.save_png(source)
	var hash:=FileAccess.get_sha256(source)
	var imported:=Importer.import_parts(temporary,item.id,rig,"front",PackedStringArray([source]),"head")
	check(imported.ok and FileAccess.get_sha256(source)==hash,"Upload did not copy safely")
	check(not Importer.import_parts(temporary,"../escape",rig,"front",PackedStringArray([source]),"head").ok,"ID escape accepted")
	check(not Importer.import_parts(temporary,item.id,rig,"front",PackedStringArray(["res://scripts/npcs/rigging/npc_rig_data.gd"]),"head").ok,"Script accepted as image")
	check(not Importer.import_parts(temporary,item.id,rig,"front",PackedStringArray([source,source])).ok,"Duplicate batch accepted")
	var canvas=editor.rig_editor.canvas; canvas.size=Vector2(360,340)
	var head: Vector2=canvas.canvas_transform()*Art.transforms(rig,"front",0,false).head.origin
	mouse(canvas,head,true)
	var motion:=InputEventMouseMotion.new(); motion.position=head+Vector2(15,0); canvas._gui_input(motion)
	check(canvas.draft.views.front.parts.head.position!=rig.views.front.parts.head.position,"Joint drag did not move draft")
	studio._cancel_section_selection()
	check(canvas.draft.is_empty() and editor._item().rig==rig,"Header Cancel committed draft")
	mouse(canvas,head,true); canvas._gui_input(motion); mouse(canvas,motion.position,false)
	check(editor._item().rig.views.front.parts.head.position!=rig.views.front.parts.head.position,"Drag release did not commit")
	await frames(); studio._undo_section_edit(); await frames()
	check(editor._item().rig==rig,"Undo did not restore joint layout")
	editor._rig_changed(rig); editor.rig_editor.setup(rig,temporary,item.id)
	mouse(canvas,head,true,MOUSE_BUTTON_RIGHT); canvas._gui_input(motion); mouse(canvas,motion.position,false,MOUSE_BUTTON_RIGHT)
	check(is_equal_approx(editor._item().rig.views.front.parts.head.rotation_degrees,9),"Right-drag rotation wrong")
	editor._rig_changed(rig); editor.rig_editor.setup(rig,temporary,item.id)
	editor._test_walking(); await frames()
	var test
	for child in editor.get_children():
		if child is Window and child.title.begins_with("NPC walking test"): test=child
	check(is_instance_valid(test),"Self-test window did not open")
	if is_instance_valid(test):
		var old: Vector2=test.agent.position; test._process(.25)
		check(Vector2(test.agent.position).distance_to(old)>2,"Test NPC not walking")
		check(test.population.npc_creation_data.creations[0].rig==rig,"Walking test uses different skeleton")
		check(is_instance_valid(test.player) and test.player.get_script()==preload("res://scripts/runtime/runtime_player_character.gd"),"Scale comparison not actual player")
		var start: Vector2=test.player.position
		var press:=InputEventKey.new(); press.keycode=KEY_W; press.physical_keycode=KEY_W; press.pressed=true; Input.parse_input_event(press)
		for _i in 4: await physics_frame
		press.pressed=false; Input.parse_input_event(press); await physics_frame
		check(test.player.position.y<start.y,"WASD does not move player in the self-test")
		test.player.position=Vector2(0,5)
		var views_seen: Dictionary={}
		for _i in 4:
			test._process(5); views_seen[preload("res://scripts/runtime/runtime_actor_art.gd").direction_column(Vector2.RIGHT.rotated(test.agent.angle))]=true
		check(views_seen.size()==4,"Self-test does not turn through four directions")
		if OS.get_cmdline_user_args().has("--render"):
			test.agent.position=Vector2(-12,5); test.agent.angle=PI/2; test.agent.phase=.18; test.set_process(false)
			await frames(); await RenderingServer.frame_post_draw
			test.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/npc_body_parts_walking_test_v16.png"))
		test.free(); await frames()
	studio._save_persona_library(); studio.message_dialog.hide()
	check(studio.section_save_succeeded and Store.load_from_town(temporary).ok,"Top Save did not persist rig")
	canvas.get_parent().queue_sort(); await frames()
	for size in [Vector2i(1366,1000),Vector2i(1024,768)]:
		root.size=size; root.content_scale_size=size; await frames()
		check(canvas.size.x>=280 and canvas.get_global_rect().end.x<=root.size.x+1,"Rig canvas outside viewport")
		for field in editor.rig_editor.controls.values(): check(field.size.y<=60 and field.get_global_rect().end.x<=root.size.x+1,"Rig field oversized/outside viewport")
	if OS.get_cmdline_user_args().has("--render"):
		root.size=Vector2i(1366,1000); root.content_scale_size=root.size; await frames()
		studio.persona_page_scroll.scroll_vertical=310; await frames(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/npc_body_parts_editor_v16.png"))
	print("RIG FIXTURE: "+temporary)
	studio.free(); await frames()
	if OS.get_cmdline_user_args().has("--render"): await pub_picture(editor.data if is_instance_valid(editor) else reopened.data,temporary)
	print("NPC RIG CHECKS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

func pub_picture(catalog: Dictionary,directory: String) -> void:
	# Read the real saved pub, but put the disposable character only in memory.
	var town:=ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var path:=town.path_join("data/building_interiors.json")
	var original:=FileAccess.get_sha256(path)
	var content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var floor_value: Dictionary=content.buildings["601183200"].floors[0]
	var layer=preload("res://scripts/interiors/runtime_interior_layer.gd").new()
	root.add_child(layer); layer.floor_data=floor_value; layer.pixels_per_metre=8; layer.set_town_directory(town); layer.visible=true; layer.queue_redraw()
	var center:=Vector2.INF
	for y in range(16,int(floor_value.height_metres*8)-16,8):
		for x in range(40,int(floor_value.width_metres*8)-40,8):
			var candidate:=Vector2(x,y); var clear:=true
			for offset in [-32,-16,0,16,32]:
				if not layer.is_traversable(candidate+Vector2(offset,0),4): clear=false; break
			if clear: center=candidate; break
		if center!=Vector2.INF: break
	check(center!=Vector2.INF,"No clear full-radius comparison row in saved Pub")
	if center==Vector2.INF: layer.free(); return
	var population=preload("res://scripts/runtime/runtime_population.gd").new(); root.add_child(population); population.set_process(false); population.z_index=3
	population.npc_creation_data=catalog; population.npc_artwork_directory=directory
	population.set_active_interior("601183200",floor_value.id)
	var facing: Array[Vector2]=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]
	for index in 4:
		population.agents.append({"kind":"person","space":"interior","building_id":"601183200","floor_id":floor_value.id,"position":center+Vector2(-32+index*16,0),"angle":facing[index].angle(),"phase":.18,"moving":true,"appearance":Store.appearance(catalog.creations[0],true)})
	var player=preload("res://scripts/runtime/runtime_player_character.gd").new(); root.add_child(player); player.set_physics_process(false); player.position=center+Vector2(32,0); player.z_index=3
	var camera:=Camera2D.new(); root.add_child(camera); camera.zoom=Vector2.ONE*7; camera.position=center+Vector2(0,-4)
	root.size=Vector2i(1100,760); root.content_scale_size=root.size
	var ui:=CanvasLayer.new(); root.add_child(ui)
	var label:=Label.new(); label.position=Vector2(20,16); label.text="BODY-PARTS WALKING · FRONT / LEFT / RIGHT / BACK / CURRENT PLAYER\nActual saved Albury Pub floor · existing character scale · read-only test"; ui.add_child(label)
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/npc_body_parts_pub_v16.png"))
	check(original==FileAccess.get_sha256(path),"Saved Pub was modified")
	layer.free(); population.free(); player.free(); camera.free(); ui.free()
