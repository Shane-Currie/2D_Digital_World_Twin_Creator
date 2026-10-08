extends SceneTree

const Store = preload("res://scripts/interiors/building_interior_store.gd")
const Catalog = preload("res://scripts/interiors/interior_furniture_catalog.gd")
const Library = preload("res://scripts/interiors/interior_furniture_library.gd")
const Runtime = preload("res://scripts/interiors/runtime_interior_layer.gd")
var studio: Control
var checks := 0
var failures := 0
var directory := ""
var baseline: Dictionary = {}
var item_id := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames() -> void:
	for i in 5: await process_frame
func item(data: Dictionary) -> Dictionary:
	for value in data.buildings.resize_fixture.floors[0].furniture:
		if str(value.id)==item_id: return value
	return {}
func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	event.position=studio.interior_floor_canvas._metres_to_screen(point)
	studio.interior_floor_canvas._gui_input(event)
func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=studio.interior_floor_canvas._metres_to_screen(point)
	studio.interior_floor_canvas._gui_input(event)
func reset() -> void:
	studio.interior_data=baseline.duplicate(true)
	studio._refresh_interior_designer_controls("ground_floor")
	studio.interior_floor_canvas.selected_furniture_id=item_id
	studio._record_section_edit()
func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--render"): return
	studio.message_dialog.hide()
	await frames(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/"+name+".png"))==OK,"Resize screenshot failed")

func run() -> void:
	create_timer(60).timeout.connect(func(): push_error("RESIZE TIMEOUT"); quit(2))
	root.size=Vector2i(1366,768); root.content_scale_size=root.size
	directory=ProjectSettings.globalize_path("res://tools/tests/output/furniture-resize-%s" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var town := FileAccess.open(directory.path_join("town.json"),FileAccess.WRITE)
	town.store_string('{"town_id":"resize-fixture","display_name":"Object resize test"}'); town.close()
	var feature := {"id":"resize_fixture","kind":"building","points":[Vector2(146,-36),Vector2(146.0003,-36),Vector2(146.0003,-36.0004),Vector2(146,-36.0004),Vector2(146,-36)],"tags":{"building":"yes"}}
	var store := Store.new()
	baseline=store.create_blank_ground_floor(store.empty_data(),feature).data
	var floor: Dictionary=baseline.buildings.resize_fixture.floors[0]
	floor.width_metres=20.0; floor.height_metres=15.0
	floor.boundary_metres=[[0,0],[20,0],[20,15],[0,15]]
	baseline=store.place_furniture(baseline,"resize_fixture","ground_floor","sofa",Vector2(7,7),30).data
	item_id=str(baseline.buildings.resize_fixture.floors[0].furniture[0].id)
	baseline=store.place_furniture(baseline,"resize_fixture","ground_floor","dining_table",Vector2(13,9),0).data
	check(store.save_to_town(directory,baseline).ok,"Resize fixture cannot save")
	studio=load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=directory; studio.last_created_directory=directory
	studio.imported_town={"ok":true,"features":[feature],"bounds":{"west":145.99,"east":146.01,"south":-36.01,"north":-35.99},"warnings":[],"statistics":{}}
	studio._show_interior_designer_page(); await frames()
	studio.interior_tools_navigation.open_page("furniture"); await frames()
	reset()
	await capture("furniture_corner_handles_before")
	for corner in 4:
		reset()
		var canvas=studio.interior_floor_canvas
		var original:=item(studio.interior_data).duplicate(true)
		var corners: Array=canvas._furniture_corners(original)
		var anchor: Vector2=corners[(corner+2)%4]
		var sign_value: Vector2=canvas.RESIZE_SIGNS[corner]
		var dimensions:=Vector2(3.2,1.6) if corner%2==0 else Vector2(1.4,0.6)
		var target:=anchor+(dimensions*sign_value).rotated(deg_to_rad(30))
		mouse(corners[corner],true); motion(target)
		check(canvas.object_drag_kind=="furniture_resize" and canvas.preview_valid,"Corner %d did not start a valid resize" % corner)
		check(item(studio.interior_data)==original,"Preview modified saved object before release")
		mouse(target,false); await frames()
		var resized:=item(studio.interior_data)
		check(is_equal_approx(resized.width_metres,dimensions.x) and is_equal_approx(resized.depth_metres,dimensions.y),"Corner %d saved wrong dimensions" % corner)
		check(canvas._furniture_corners(resized)[(corner+2)%4].distance_to(anchor)<0.012,"Opposite corner moved during rotated resize")
		check(resized.id==original.id and resized.catalog_id==original.catalog_id and resized.rotation_degrees==30 and resized.collision,"Resize changed ID, type, rotation or collision")
	studio.top_undo_button.pressed.emit(); await frames()
	check(item(studio.interior_data)==item(baseline),"Resize Undo failed")
	reset()
	var start: Vector2=studio.interior_floor_canvas._furniture_corners(item(baseline))[2]
	mouse(start,true); motion(Vector2(30,30))
	check(not studio.interior_floor_canvas.preview_valid,"Blocked resize preview not red")
	mouse(Vector2(30,30),false); await frames()
	check(item(studio.interior_data)==item(baseline) and not studio.message_dialog.visible,"Blocked resize changed object or displayed modal")
	reset(); mouse(start,true); motion(start+Vector2(1,1))
	studio.top_cancel_button.pressed.emit(); await frames()
	check(item(studio.interior_data)==item(baseline) and studio.interior_floor_canvas.object_drag_kind.is_empty(),"Cancel committed a resize")
	reset()
	var resized:=store.resize_furniture(baseline,"resize_fixture","ground_floor",item_id,Vector2(7,7),Vector2(3.2,1.6))
	check(resized.ok,"Safe backend resize failed")
	studio._on_interior_furniture_resize_requested(item_id,Vector2(7,7),Vector2(3.2,1.6)); await frames()
	await capture("furniture_corner_handles_after")
	studio._save_active_section(); await frames(); studio.message_dialog.hide()
	var reopened:=store.load_from_town(directory)
	check(reopened.ok and item(reopened.data).width_metres==3.2 and item(reopened.data).depth_metres==1.6,"Resized size not persisted")
	var layer:=Runtime.new(); root.add_child(layer)
	var opened:=layer.open_floor(reopened.data.buildings.resize_fixture,reopened.data.buildings.resize_fixture.floors[0],{"spawn_x_metres":2,"spawn_y_metres":2},8)
	check(opened.ok,"Runtime resize fixture cannot open")
	var within:=Vector2(7,7)+Vector2(1.3,0).rotated(deg_to_rad(30))
	var outside:=Vector2(7,7)+Vector2(1.9,0).rotated(deg_to_rad(30))
	check(not layer.is_traversable(within*8,0) and layer.is_traversable(outside*8,0),"Runtime collision did not grow with the resized artwork")
	layer.queue_free()
	check(not store.resize_furniture(baseline,"resize_fixture","ground_floor",item_id,Vector2(7,7),Vector2(NAN,1)).ok and not store.resize_furniture(baseline,"resize_fixture","ground_floor",item_id,Vector2(7,7),Vector2(21,1)).ok,"Invalid resize accepted")
	var hole_floor:=baseline.duplicate(true)
	hole_floor.buildings.resize_fixture.floors[0].holes_metres=[[[5,5],[6,5],[6,6],[5,6]]]
	check(not store.resize_furniture(hole_floor,"resize_fixture","ground_floor",item_id,Vector2(6,6),Vector2(5,5)).ok,"Resize covered an interior courtyard")
	# A real imported PNG keeps its reference; resizing does not alter the file.
	var library:=Library.new()
	var source:=ProjectSettings.globalize_path("res://assets/interiors/flooring/floorboards_light_oak.png")
	var source_hash:=FileAccess.get_sha256(source)
	var imported:=library.import_creation(directory,library.empty_data(),source,"Custom object","object",1,1,"Residential")
	check(imported.ok,"Custom artwork fixture import failed")
	if imported.ok:
		var placed:=store.place_furniture(baseline,"resize_fixture","ground_floor",str(imported.definition.id),Vector2(4,11),15,imported.definition)
		var changed:=store.resize_furniture(placed.data,"resize_fixture","ground_floor",placed.furniture_id,Vector2(4,11),Vector2(2,2))
		check(changed.ok and changed.data.buildings.resize_fixture.floors[0].furniture[-1].image_path==imported.definition.image_path,"Custom image reference lost during resize")
		check(FileAccess.get_sha256(source)==source_hash,"Resizing changed the source upload")
	studio.queue_free(); await frames()
	print("FURNITURE RESIZE %s: %d checks" % ["PASSED" if failures==0 else "FAILED",checks])
	quit(0 if failures==0 else 1)
