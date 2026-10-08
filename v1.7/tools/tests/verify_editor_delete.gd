extends SceneTree

const Store = preload("res://scripts/interiors/building_interior_store.gd")
const Deletion = preload("res://scripts/app/navigation/editor_item_deletion.gd")
const Personas = preload("res://scripts/npcs/persona_store.gd")
const Npcs = preload("res://scripts/npcs/storyline_npc_store.gd")
var studio: Control
var baseline: Dictionary
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
func frames() -> void:
	for i in 5: await process_frame
func key(echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=KEY_DELETE; event.pressed=true; event.echo=echo
	return event
func reset() -> void:
	studio.interior_data=baseline.duplicate(true)
	studio._refresh_interior_designer_controls("ground_floor")
	studio._clear_editor_delete_selection()
	studio.section_history.reset(studio._section_snapshot())
	studio.section_saved_snapshot=studio.section_history.current.duplicate(true)
func capture() -> void:
	if not OS.get_cmdline_user_args().has("--render"): return
	studio.message_dialog.hide(); await frames(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/editor_delete_header.png"))==OK,"Header screenshot failed")
func run() -> void:
	create_timer(45).timeout.connect(func(): push_error("DELETE TEST TIMEOUT"); quit(2))
	root.size=Vector2i(1366,768); root.content_scale_size=root.size
	directory=ProjectSettings.globalize_path("res://tools/tests/output/editor-delete-%s" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var file:=FileAccess.open(directory.path_join("town.json"),FileAccess.WRITE)
	file.store_string('{"town_id":"delete-fixture","display_name":"Delete fixture"}'); file.close()
	var feature: Dictionary={"id":"delete_fixture","kind":"building","points":[Vector2(146,-36),Vector2(146.0003,-36),Vector2(146.0003,-36.0004),Vector2(146,-36.0004),Vector2(146,-36)],"tags":{"building":"yes"}}
	var store:=Store.new()
	baseline=store.create_blank_ground_floor(store.empty_data(),feature).data
	var floor: Dictionary=baseline.buildings.delete_fixture.floors[0]
	floor.width_metres=20; floor.height_metres=15; floor.boundary_metres=[[0,0],[20,0],[20,15],[0,15]]
	baseline=store.place_furniture(baseline,"delete_fixture","ground_floor","sofa",Vector2(7,7),30).data
	baseline=store.place_furniture(baseline,"delete_fixture","ground_floor","dining_table",Vector2(12,8),0).data
	baseline=store.add_wall(baseline,"delete_fixture","ground_floor",Vector2(16,.1),Vector2(16,14.9)).data
	baseline=store.add_wall_door(baseline,"delete_fixture","ground_floor","wall_1",Vector2(16,7),1.2).data
	baseline=store.add_room_label(baseline,"delete_fixture","ground_floor","Side room",Vector2(18,5)).data
	baseline=store.add_upper_floor(baseline,"delete_fixture").data
	baseline=store.add_stair_pair(baseline,"delete_fixture","ground_floor",Vector2(3,11),"floor_1",Vector2(3,11)).data
	check(store.save_to_town(directory,baseline).ok,"Delete fixture save failed")
	studio=load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=directory; studio.last_created_directory=directory
	studio.imported_town={"ok":true,"features":[feature],"bounds":{"west":145.99,"east":146.01,"south":-36.01,"north":-35.99},"warnings":[],"statistics":{}}
	studio._show_interior_designer_page(); await frames()
	studio.interior_tools_navigation.open_page("furniture"); await frames()
	# Compare Undo against the canonical data actually loaded by the editor.
	baseline=studio.interior_data.duplicate(true)
	check(studio.top_delete_button.text=="Delete item","Header must be labelled Delete item")
	check(not studio.top_delete_button.visible,"Delete visible without explicit selection")
	studio.interior_floor_canvas.selected_furniture_id="furniture_1"
	studio.interior_floor_canvas.furniture_selected.emit("furniture_1")
	check(studio.top_delete_button.visible,"Mouse selection did not show header Delete")
	await capture()
	studio.interior_floor_canvas.grab_focus()
	studio._unhandled_key_input(key())
	check(studio.interior_data.buildings.delete_fixture.floors[0].furniture.size()==1 and studio.interior_data.buildings.delete_fixture.floors[0].furniture[0].id=="furniture_2","Delete key removed wrong furniture")
	check(not studio.top_delete_button.visible and not studio.message_dialog.visible,"Delete did not clear header selection or opened modal")
	studio._undo_section_edit(); await frames()
	check(studio.interior_data==baseline,"Undo did not restore deleted item")
	for kind in ["furniture","wall","door","room","stairs"]:
		reset()
		var ids: Dictionary={"furniture":"furniture_1","wall":"wall_1","door":"door_1","room":"room_1","stairs":"stairs_1"}
		studio._select_editor_item(kind,ids[kind],"wall_1" if kind=="door" else "")
		check(studio.top_delete_button.visible,"Header absent for selected "+kind)
		studio.top_delete_button.pressed.emit()
		check(studio.interior_data!=baseline,"Header Delete made no edit for "+kind)
		studio._undo_section_edit(); await frames()
		check(studio.interior_data==baseline,"Undo failed for "+kind)
	reset()
	studio._select_editor_item("furniture","furniture_1")
	studio._unhandled_key_input(key(true))
	check(studio.interior_data==baseline,"Held Delete repeated deletion")
	studio.interior_furniture_search_edit.grab_focus(); studio._unhandled_key_input(key())
	check(studio.interior_data==baseline,"Text field Delete removed selected object")
	var text:=TextEdit.new(); studio.add_child(text); text.grab_focus(); studio._unhandled_key_input(key())
	check(studio.interior_data==baseline,"Text editor Delete removed selected object")
	text.queue_free(); await frames()
	studio.top_cancel_button.pressed.emit()
	check(not studio.top_delete_button.visible,"Cancel left Delete action visible")
	studio._select_editor_item("furniture","furniture_1")
	studio.interior_floor_option.select(1); studio._on_interior_floor_selected(1)
	check(not studio.top_delete_button.visible and studio._current_editor_delete_selection().is_empty() and not studio._delete_editor_item(),"Stale selection/header survived floor change")
	reset(); studio._select_editor_item("furniture","missing")
	check(not studio.top_delete_button.visible and not studio._delete_editor_item(),"Unknown item was deletable")
	var placements:=Npcs.new().add_interior_npc(Npcs.empty_data(),{"space":"interior","building_id":"delete_fixture","floor_id":"ground_floor","x_metres":10,"y_metres":12},"delete-fixture",Personas.recommended_data(),"Trader test")
	check(placements.ok,"Character deletion fixture failed")
	studio.storyline_npc_data=placements.data
	studio.interior_trader_data={"schema_version":1,"traders":{str(placements.npc.id):{"enabled":true,"offers":[]}}}
	studio.interior_floor_canvas.npc_selected.emit(str(placements.npc.id))
	check(studio.top_delete_button.visible and studio._delete_editor_item() and studio.storyline_npc_data.npcs.is_empty() and studio.interior_trader_data.traders.is_empty(),"Character deletion left placement/stock profile")
	studio._undo_section_edit(); await frames()
	check(studio.storyline_npc_data.npcs.size()==1 and studio.interior_trader_data.traders.size()==1,"Character/stock Undo failed")
	var paired:=baseline.duplicate(true)
	paired["building_connections"]=[{"id":"link_1","from":{"building_id":"delete_fixture"},"to":{"building_id":"next_door"}}]
	var removed:=Deletion.remove(paired,{}, {}, {"kind":"connection","id":"link_1","building_id":"delete_fixture","floor_id":"ground_floor"})
	check(removed.ok and removed.data.building_connections.is_empty() and paired.building_connections.size()==1,"Connecting-door deletion did not remove pair non-mutatingly")
	reset()
	studio.storyline_npc_data=Npcs.empty_data(); studio.interior_trader_data={"schema_version":1,"traders":{}}
	studio._select_editor_item("furniture","furniture_1"); studio._delete_editor_item(); studio._save_active_section()
	check(studio.section_save_succeeded and store.load_from_town(directory).data.buildings.delete_fixture.floors[0].furniture.size()==1,"Delete -> Save -> reopen failed")
	studio.queue_free(); await frames()
	print("EDITOR DELETE %s: %d checks" % ["PASSED" if failures==0 else "FAILED",checks])
	quit(0 if failures==0 else 1)
