extends SceneTree

const Store = preload("res://scripts/interiors/building_interior_store.gd")
const Stairs = preload("res://scripts/interiors/stairs/interior_stairs.gd")
var studio: Control
var canvas: Control
var baseline: Dictionary
var directory := ""
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames() -> void:
	for i in 4: await process_frame
func mouse(point: Vector2, button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=canvas._metres_to_screen(point); event.button_index=button; event.pressed=pressed
	canvas._gui_input(event)
func turn(point: Vector2, pixels: float) -> void:
	var event := InputEventMouseMotion.new()
	event.position=canvas._metres_to_screen(point)+Vector2(pixels,0)
	event.relative=Vector2(pixels,0); event.button_mask=MOUSE_BUTTON_MASK_RIGHT
	canvas._gui_input(event)
func reset(floor_id := "ground_floor") -> void:
	studio.interior_data=baseline.duplicate(true)
	studio._refresh_interior_designer_controls(floor_id)
	canvas.cancel_selection()
	studio.section_history.reset(studio._section_snapshot())
	studio.section_saved_snapshot=studio.section_history.current.duplicate(true)
func pair() -> Dictionary: return studio.interior_data.buildings.rotation_fixture.stairs[0]
func capture() -> void:
	if not OS.get_cmdline_user_args().has("--render"): return
	studio.message_dialog.hide(); await frames(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/stairs_held_rotation.png"))==OK,"Rotation screenshot failed")
func run() -> void:
	create_timer(50).timeout.connect(func(): push_error("ROTATION TEST TIMEOUT"); quit(2))
	root.size=Vector2i(1366,768); root.content_scale_size=root.size
	directory=ProjectSettings.globalize_path("res://tools/tests/output/stair-rotation-%s" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var file:=FileAccess.open(directory.path_join("town.json"),FileAccess.WRITE)
	file.store_string('{"town_id":"rotation-fixture","display_name":"Rotation fixture"}'); file.close()
	var feature: Dictionary={"id":"rotation_fixture","kind":"building","points":[Vector2(146,-36),Vector2(146.0003,-36),Vector2(146.0003,-36.0004),Vector2(146,-36.0004),Vector2(146,-36)],"tags":{"building":"yes"}}
	var store:=Store.new()
	baseline=store.create_blank_ground_floor(store.empty_data(),feature).data
	var floor: Dictionary=baseline.buildings.rotation_fixture.floors[0]
	floor.width_metres=20; floor.height_metres=16; floor.boundary_metres=[[0,0],[20,0],[20,16],[0,16]]
	baseline=store.add_upper_floor(baseline,"rotation_fixture").data
	baseline=store.add_stair_pair(baseline,"rotation_fixture","ground_floor",Vector2(6,8),"floor_1",Vector2(6,8)).data
	check(store.save_to_town(directory,baseline).ok,"Rotation fixture save failed")
	studio=load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=directory; studio.last_created_directory=directory
	studio.imported_town={"ok":true,"features":[feature],"bounds":{"west":145.99,"east":146.01,"south":-36.01,"north":-35.99},"warnings":[],"statistics":{}}
	studio._show_interior_designer_page(); await frames()
	studio.interior_tools_navigation.open_page("stairs"); await frames()
	canvas=studio.interior_floor_canvas
	baseline=studio.interior_data.duplicate(true); reset()
	var point:=Vector2(6,8)
	# Right press on the artwork selects it, then previews several motions.
	mouse(point,MOUSE_BUTTON_RIGHT,true)
	check(canvas.stair_selected_id=="stairs_1" and studio.top_delete_button.visible,"Right press did not select the stair")
	check(studio.interior_data==baseline,"Right press rotated before release")
	for delta in [30.0,15.0,-5.0]:
		turn(point,delta); await frames()
		check(studio.interior_data==baseline,"Held rotation committed a partial edit")
	check(is_equal_approx(float(canvas.stair_rotation_gesture.rotation_degrees),40) and canvas.preview_valid,"Held rotation did not accumulate mouse movement")
	check(canvas.stair_preview==point,"Rotation moved the stair centre")
	await capture()
	mouse(point,MOUSE_BUTTON_RIGHT,false); await frames()
	check(is_equal_approx(Stairs.rotation(pair().from),40) and is_zero_approx(Stairs.rotation(pair().to)),"Release did not rotate only the selected endpoint")
	check(Stairs.position(pair().from)==point and Stairs.position(pair().to)==point,"Rotation moved an endpoint")
	check(canvas.stair_rotation_gesture.is_empty() and is_equal_approx(studio.interior_stair_rotation.value,40),"Release left gesture/angle controls stale")
	check(studio.section_history.previous.size()==1,"One held rotation must create one Undo step")
	studio._undo_section_edit(); await frames()
	check(studio.interior_data==baseline,"Undo did not restore the entire rotation")
	reset(); mouse(point,MOUSE_BUTTON_RIGHT,true); mouse(point,MOUSE_BUTTON_RIGHT,false); await frames()
	check(is_equal_approx(Stairs.rotation(pair().from),90),"Quick right-click lost its 90-degree turn")
	reset(); mouse(point,MOUSE_BUTTON_RIGHT,true); turn(point,55)
	studio._cancel_section_selection(); mouse(point,MOUSE_BUTTON_RIGHT,false); await frames()
	check(studio.interior_data==baseline and canvas.stair_rotation_gesture.is_empty(),"Cancel did not abandon held rotation")
	reset(); mouse(point,MOUSE_BUTTON_RIGHT,true); turn(point,55)
	studio.interior_floor_option.select(1); studio._on_interior_floor_selected(1)
	mouse(point,MOUSE_BUTTON_RIGHT,false); await frames()
	check(studio.interior_data==baseline and canvas.stair_rotation_gesture.is_empty(),"Floor switch committed stale rotation")
	reset(); mouse(point,MOUSE_BUTTON_RIGHT,true); turn(point,-30); mouse(point,MOUSE_BUTTON_RIGHT,false); await frames()
	check(is_equal_approx(Stairs.rotation(pair().from),330),"Negative rotation did not wrap")
	# Boundary-safe upright stair becomes unsafe when rotated across the edge.
	reset(); studio.interior_data=store.move_stair_endpoint(baseline,"rotation_fixture","stairs_1","from",Vector2(.85,8),0).data
	studio._refresh_interior_designer_controls("ground_floor")
	var blocked_baseline: Dictionary=studio.interior_data.duplicate(true)
	mouse(Vector2(.85,8),MOUSE_BUTTON_RIGHT,true); turn(Vector2(.85,8),90)
	check(not canvas.preview_valid and studio.interior_data==blocked_baseline,"Invalid angle preview did not reject the floor edge")
	mouse(Vector2(.85,8),MOUSE_BUTTON_RIGHT,false); await frames()
	check(studio.interior_data==blocked_baseline and canvas.invalid_position!=Vector2.INF and not studio.message_dialog.visible,"Blocked release changed stairs or opened a modal")
	# Placement previews use the same gesture but cannot commit a half-pair.
	reset(); canvas.stair_rotation_degrees=0; studio.interior_stair_rotation.set_value_no_signal(0)
	studio._begin_interior_stairs()
	mouse(Vector2(10,10),MOUSE_BUTTON_RIGHT,true); turn(Vector2(10,10),35)
	check(canvas.placing_stair and is_equal_approx(float(canvas.stair_rotation_gesture.rotation_degrees),35) and studio.interior_data==baseline,"Placement rotation altered canonical stairs")
	mouse(Vector2(10,10),MOUSE_BUTTON_RIGHT,false)
	check(canvas.placing_stair and is_equal_approx(canvas.stair_rotation_degrees,35) and studio.interior_data==baseline,"Placement release lost angle or committed a half-pair")
	studio._cancel_section_selection()
	# The down endpoint rotates independently and persists through Save/reopen.
	reset("floor_1"); mouse(point,MOUSE_BUTTON_RIGHT,true); turn(point,70)
	check(not bool(canvas.stair_rotation_gesture.up),"Downstairs platform preview changed into an up arrow")
	mouse(point,MOUSE_BUTTON_RIGHT,false); await frames()
	check(is_equal_approx(Stairs.rotation(pair().to),70) and is_zero_approx(Stairs.rotation(pair().from)),"Upper endpoint changed its partner")
	studio._save_active_section()
	var loaded:=store.load_from_town(directory)
	check(studio.section_save_succeeded and loaded.ok and is_equal_approx(Stairs.rotation(loaded.data.buildings.rotation_fixture.stairs[0].to),70),"Held rotation did not Save/reopen")
	studio.queue_free(); await frames()
	print("STAIR ROTATION DRAG %s: %d checks" % ["PASSED" if failures==0 else "FAILED",checks])
	quit(0 if failures==0 else 1)
