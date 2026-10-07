extends SceneTree

const Artwork = preload("res://scripts/buildings/building_artwork_settings.gd")
const Store = preload("res://scripts/buildings/building_exterior_store.gd")
const Geometry = preload("res://scripts/buildings/building_height_geometry.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition: failures+=1; push_error(message)

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("ARTWORK EDITOR TIMED OUT"); quit(1))
	var store := Store.new()
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/artwork-editor-%s" % OS.get_process_id())
	var id := "way/shape"
	var data := store.empty_data()
	data=Artwork.set_alignment(data,id,"roof",{"rotation_degrees":30.0}).data
	data=Artwork.set_alignment(data,id,"walls",{"scale_percent":125.0,"offset_x_percent":8.0}).data
	data=Artwork.set_alignment(data,id,"front",{"scale_percent":175.0}).data
	data=Artwork.set_material(data,id,"front","glass").data
	data=Artwork.set_material(data,id,"left","brick").data
	check(Artwork.alignment(data.buildings[id],"front").scale_percent==175.0,"Front alignment override lost.")
	check(Artwork.alignment(data.buildings[id],"left").scale_percent==125.0,"Left alignment must inherit default walls.")
	check(Artwork.material(data.buildings[id],"front")=="glass" and Artwork.material(data.buildings[id],"left")=="brick","Facade materials must remain independent.")
	check(store.validate(data).ok,"Optional artwork settings rejected.")
	check(store.save_to_town(temporary,data).ok and store.load_from_town(temporary).data.buildings[id].facades==data.buildings[id].facades,"Facade save/reload failed.")
	for invalid in [null,[],{"scale_percent":0},{"scale_percent":"150"},{"offset_x_percent":NAN},{"rotation_degrees":INF}]:
		var bad := data.duplicate(true)
		bad.buildings[id].facades.front.alignment=invalid
		check(not store.validate(bad).ok,"Invalid facade alignment accepted: %s" % [invalid])
	var wrong_face := data.duplicate(true)
	wrong_face.buildings[id].facades["unknown"]={}
	check(not store.validate(wrong_face).ok,"Unknown facade group accepted.")
	var uploaded := store.import_wall(temporary,data,id,ProjectSettings.globalize_path("res://assets/actors/car_sedan_blue_v3.png"),"front")
	check(uploaded.ok,"Safe facade image copy failed.")
	if not uploaded.ok: quit(1); return
	data=uploaded.data
	check(data.buildings[id].has("roof_alignment") and data.buildings[id].facades.front.has("wall"),"Facade upload changed the roof.")
	check(store.save_to_town(temporary,data).ok and store.load_from_town(temporary).ok,"Uploaded facade could not round-trip.")
	var unsafe := data.duplicate(true)
	unsafe.buildings[id].facades.front.wall.relative_path="../outside.png"
	check(not store.validate(unsafe).ok,"Unsafe facade path accepted.")
	unsafe.buildings[id].facades.front.wall.relative_path="assets/buildings/way_shape/missing.png"
	var saved_before := FileAccess.get_file_as_string(temporary.path_join("data/building_exteriors.json"))
	check(not store.save_to_town(temporary,unsafe).ok,"Missing facade image accepted.")
	check(FileAccess.get_file_as_string(temporary.path_join("data/building_exteriors.json"))==saved_before,"Failed save overwrote existing metadata.")
	var legacy: Dictionary = store.import_exterior(temporary,data,id,ProjectSettings.globalize_path("res://assets/actors/car_sedan_blue_v3.png")).data
	legacy=store.set_exterior_transform(legacy,id,135.0,-55.0,8.0,10.0).data
	legacy=Artwork.set_alignment(legacy,id,"left",{"rotation_degrees":15.0}).data
	check(Artwork.alignment(legacy.buildings[id],"roof").rotation_degrees==-55.0,"Facade editing reset legacy roof alignment.")
	var restored := Artwork.remove_override(legacy,id,"front")
	check(not restored.buildings[id].facades.has("front") and restored.buildings[id].facades.has("left") and restored.buildings[id].exterior==legacy.buildings[id].exterior,"Surface default reset changed other surfaces.")
	check(Artwork.aligned_uv(Vector2(1,1),{}).is_equal_approx(Vector2(1,1)),"Default UVs changed.")
	check(not Artwork.aligned_uv(Vector2(1,1),{"scale_percent":150.0}).is_equal_approx(Vector2(1,1)),"Texture scale has no effect.")
	# Real saved town, read-only. Only in-memory edits; never call Save here.
	var real := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var saved_path := real.path_join("data/building_exteriors.json")
	var original_hash := FileAccess.get_sha256(saved_path)
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio._load_existing_project(real)
	studio._show_building_creator_page()
	var original_geometry := JSON.stringify(studio.imported_town.features)
	var selected: Dictionary = studio.building_effective_features.filter(func(feature): return str(feature.id)=="601183200")[0]
	studio._on_building_creator_selected(selected)
	await process_frame
	studio.message_dialog.hide()
	# Remove the capture instance's child Window, not production warnings.
	studio.message_dialog.free()
	studio.building_artwork_buttons.front.pressed.emit()
	studio._on_building_artwork_material(3)
	studio.building_artwork_buttons.left.pressed.emit()
	studio._on_building_artwork_material(1)
	var preview = studio.building_artwork_preview
	var render_id: int = preview.renderer.get_instance_id()
	var mesh_hash := JSON.stringify(preview.renderer.building_height_meshes)
	var wall_resource: int = preview.renderer.building_facade_textures["601183200"].left.wall.get_instance_id()
	var left_rotation: float = studio.building_rotation_control.value
	var press := InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	preview._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative=Vector2(30,20)
	preview._gui_input(motion)
	press.pressed=false
	preview._gui_input(press)
	check(absf(studio.building_offset_x_control.value)>0.0,"Dragging preview did not align selected surface.")
	press.button_index=MOUSE_BUTTON_RIGHT
	press.pressed=true
	preview._gui_input(press)
	motion.relative=Vector2(20,0)
	preview._gui_input(motion)
	press.pressed=false
	preview._gui_input(press)
	check(studio.building_rotation_control.value>left_rotation,"Right-drag did not rotate selected surface.")
	var before_scale: float = studio.building_scale_control.value
	press.button_index=MOUSE_BUTTON_WHEEL_UP
	press.pressed=true
	preview._gui_input(press)
	check(studio.building_scale_control.value>before_scale,"Wheel did not resize texture.")
	check(preview.renderer.get_instance_id()==render_id and JSON.stringify(preview.renderer.building_height_meshes)==mesh_hash,"UV-only edits rebuilt geometry/preview.")
	check(preview.renderer.building_facade_textures["601183200"].left.wall.get_instance_id()==wall_resource,"UV-only edits reloaded facade texture.")
	var front_texture: String = preview.renderer.building_facade_textures["601183200"].front.wall.diffuse_texture.resource_path
	var left_texture: String = preview.renderer.building_facade_textures["601183200"].left.wall.diffuse_texture.resource_path
	check(front_texture.ends_with("glass_wall.svg") and left_texture.ends_with("brick_wall.svg"),"Production preview did not load different facade textures.")
	var before_view: float = preview.zoom
	preview.zoom_view(1.25)
	check(preview.zoom>before_view and studio.building_scale_control.value>before_scale,"View zoom changed texture scale.")
	preview.fit_view()
	check(is_equal_approx(preview.zoom,1.0) and studio.building_scale_control.value>before_scale,"Fit view changed texture size.")
	check(JSON.stringify(studio.imported_town.features)==original_geometry and FileAccess.get_sha256(saved_path)==original_hash,"Source geometry or saved Albury data changed.")
	check(studio.building_save_button.visible and studio.building_save_button.get_global_rect().position.y<300,"Top save button not visible.")
	studio.building_artwork_buttons.roof.pressed.emit()
	check(studio.building_rotation_control.value==-55.0,"Legacy Albury roof rotation reset while editing facades.")
	studio.building_artwork_buttons.front.pressed.emit()
	await process_frame
	if OS.get_cmdline_user_args().has("--render"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_artwork_editor_albury.png"))
		# Show both facade materials on a broad synthetic footprint with actual
		# production renderer. This is artwork editing, not a surveyed facade.
		var fixture := {"id":"demo","kind":"building","tags":{"building":"yes","building:levels":"4"},"points":[[149.001,-35.008],[149.0014,-35.008],[149.0014,-35.0084],[149.001,-35.0084],[149.001,-35.008]],"holes":[]}
		var demo: Dictionary = Artwork.set_material(store.empty_data(),"demo","front","glass").data
		demo=Artwork.set_material(demo,"demo","left","brick").data
		preview.selected_target="roof"
		preview.set_design(fixture,demo,{"west":149.0,"south":-35.01,"east":149.01,"north":-35.0},temporary)
		studio.hide()
		root.size=Vector2i(880,680)
		root.content_scale_size=Vector2i(880,680)
		preview.reparent(root,false)
		preview.position=Vector2(80,80)
		preview.size=Vector2(720,520)
		var caption := Label.new()
		caption.text="PRODUCTION RENDERER • ARTWORK EDITING FIXTURE\nFront: glass / left: brick • geometry unchanged"
		caption.position=Vector2(24,20)
		root.add_child(caption)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_artwork_facades_demo.png"))
	if failures>0: quit(1); return
	print("BUILDING ARTWORK EDITOR PASSED: optional/legacy settings, surface inheritance, independent textures/UVs, safe copies, save/reload, malformed/missing rejection, GUI mouse gestures/view zoom and cache reuse. Actual Albury checked read-only; no source/collision/door edits.")
	quit()
