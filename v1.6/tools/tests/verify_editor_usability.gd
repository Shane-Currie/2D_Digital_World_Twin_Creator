extends SceneTree

const Connections = preload("res://scripts/interiors/connections/building_connections.gd")
const Footprints = preload("res://scripts/editor/building_footprint_editor.gd")
const Overrides = preload("res://scripts/editor/map_override_store.gd")
const Store = preload("res://scripts/interiors/building_interior_store.gd")
const Stairs = preload("res://scripts/interiors/stairs/interior_stairs.gd")
const Loader = preload("res://scripts/content/project_loader.gd")
var checks := 0
var failures := 0
var studio: Control
var output := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames() -> void:
	for i in 5: await process_frame
func rectangle(x: float, y: float, w: float, h: float) -> Array:
	var result: Array = []
	for p in [Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h),Vector2(x,y)]: result.append(Connections.unproject(p,[146.9,-36.0]))
	return result
func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--render"): return
	studio.message_dialog.hide()
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/" + name + ".png"))

func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Usability check timed out"); quit(2))
	root.size = Vector2i(1366,768)
	root.content_scale_size = root.size
	output = ProjectSettings.globalize_path("res://tools/tests/output/editor-usability-%s" % OS.get_process_id())
	var bounds := {"west":146.898,"east":146.902,"south":-36.002,"north":-35.998}
	var overrides := Overrides.new()
	var proposal := Footprints.propose(overrides.empty_data([],bounds),rectangle(0,0,12,15),"New test building",[],bounds)
	check(proposal.ok and overrides.validate(proposal.data).ok,"Custom footprint creation failed")
	var custom: Dictionary = proposal.feature
	check(not Footprints.propose(proposal.data,rectangle(0,0,4,4),"",[custom],bounds).ok,"Overlapping footprint allowed")
	check(not Footprints.propose(proposal.data,rectangle(30,0,1,8),"",[],bounds).ok,"Undersized footprint allowed")
	var road := {"kind":"road","id":"road","points":[Connections.unproject(Vector2(-10,7),[146.9,-36.0]),Connections.unproject(Vector2(30,7),[146.9,-36.0])],"tags":{"highway":"residential"}}
	check(not Footprints.propose({},rectangle(0,0,12,15),"",[road],bounds).ok,"Footprint covered a road")
	check(overrides.save_to_town(output,proposal.data,[],bounds).ok,"Footprint could not save")
	var town_file := FileAccess.open(output.path_join("town.json"),FileAccess.WRITE)
	town_file.store_string('{"town_id":"usability-fixture","display_name":"Editor test"}'); town_file.close()
	var saved: Dictionary = overrides.load_from_town(output,[],bounds)
	var effective: Dictionary = overrides.apply([],saved.data)
	check(saved.ok and effective.ok and effective.features.size()==1 and effective.features[0].precise_points==custom.precise_points,"Footprint precision/save/apply lost")
	var store := Store.new()
	var interior: Dictionary = store.create_blank_ground_floor(store.empty_data(),effective.features[0]).data
	interior = store.add_upper_floor(interior,custom.id).data
	var paired := store.add_stair_pair(interior,custom.id,"ground_floor",Vector2(6,7),"floor_1",Vector2(6,7),90,90)
	check(paired.ok and Stairs.validate(paired.data.buildings[custom.id]).ok,"Rotated paired stairs invalid")
	var record: Dictionary = paired.data.buildings[custom.id]
	var rotated: Dictionary = store.move_stair_endpoint(paired.data,custom.id,"stairs_1","from",Vector2(6,7),45)
	check(rotated.ok and float(rotated.data.buildings[custom.id].stairs[0].from.rotation_degrees)==45 and float(rotated.data.buildings[custom.id].stairs[0].to.rotation_degrees)==90,"Rotating one end changed its partner")
	var narrow: Dictionary = record.floors[0].duplicate(true)
	narrow.boundary_metres=[[0,0],[3,0],[3,2],[0,2]]
	check(Stairs.fits(narrow,Vector2(1.5,1),[],"",90) and not Stairs.fits(narrow,Vector2(1.5,1),[],"",0),"Stair clearance ignores rotation")
	check(store.save_to_town(output,interior).ok,"Fixture interior could not save")
	studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio); await frames()
	studio.loaded_project_directory = output
	studio.imported_town = {"ok":true,"features":[],"bounds":bounds,"warnings":[],"statistics":{}}
	studio.current_town_name = "Editor test"
	studio._show_interior_designer_page(); await frames()
	check(studio.interior_eligible_features.size()==1 and str(studio.interior_selected_feature.id)==custom.id,"Custom footprint missing from interior selector")
	for page in ["flooring","furniture","walls","doors","rooms","stairs","connections"]:
		studio.interior_tools_navigation.open_page(page); await frames()
		var rect: Rect2 = studio.interior_floor_canvas.get_global_rect()
		check(rect.size.x>=360 and rect.size.y>=280 and rect.end.x<=root.size.x+1 and rect.end.y<=root.size.y+1,"Map unavailable/cut off in " + page + ": " + str(rect))
	studio.interior_tools_navigation.open_page("flooring")
	studio.interior_floor_material_option.select(1)
	await frames()
	var painted_rect: Rect2 = studio.interior_floor_canvas.get_global_rect()
	check(painted_rect.end.x<=root.size.x+1 and painted_rect.size.x>=360,"Texture thumbnail pushed the floor map off screen: " + str(painted_rect))
	studio._begin_interior_floor_painting()
	var old: Dictionary = studio.interior_data.duplicate(true)
	studio._on_interior_floor_paint_requested([Vector2(5,5)],false)
	studio._record_section_edit()
	check(studio.interior_data!=old,"Floor painting made no edit")
	studio.top_undo_button.pressed.emit(); await frames()
	check(studio.interior_data==old,"Header Undo did not restore floor painting")
	studio.interior_tools_navigation.open_page("stairs")
	studio.interior_stair_auto.button_pressed = true
	studio._begin_interior_stairs()
	studio._on_interior_stair_point(Vector2(6,7))
	check(studio.interior_stair_pending.is_empty() and studio.interior_data.buildings[custom.id].stairs.size()==1,"Auto matching stairs did not complete in one click")
	var stairs: Dictionary = studio.interior_data.buildings[custom.id].stairs[0]
	check(stairs.from.x_metres==stairs.to.x_metres and stairs.from.y_metres==stairs.to.y_metres,"Auto stairs not vertically aligned")
	studio.interior_floor_canvas.stair_selected_id = str(stairs.id)
	studio._on_interior_stair_rotation(str(stairs.id),"to",90)
	check(float(studio.interior_data.buildings[custom.id].stairs[0].to.rotation_degrees)==90,"Editor stair rotation failed")
	studio._begin_interior_stairs()
	studio.top_cancel_button.pressed.emit()
	check(studio.interior_stair_pending.is_empty() and not studio.interior_floor_canvas.placing_stair and studio.interior_floor_canvas.stair_selected_id.is_empty(),"Header Cancel left stair tool selected")
	var original_stairs: Dictionary = studio.interior_data.duplicate(true)
	studio._refresh_interior_designer_controls("floor_1")
	studio._begin_interior_stairs()
	studio._on_interior_stair_point(Vector2(9,11))
	check(studio.interior_stair_pending.is_empty() and studio.interior_data.buildings[custom.id].stairs.size()==2,"Automatic placement from upstairs to lower floor failed")
	studio.interior_data=original_stairs.duplicate(true)
	var blocked := store.place_furniture(studio.interior_data,custom.id,"ground_floor","dining_chair",Vector2(3,3),0)
	check(blocked.ok,"Could not prepare blocked lower-floor fixture")
	studio.interior_data=blocked.data
	studio._refresh_interior_designer_controls("floor_1")
	studio._begin_interior_stairs(); studio._on_interior_stair_point(Vector2(3,3))
	check(not studio.interior_stair_pending.is_empty() and studio.interior_data.buildings[custom.id].stairs.size()==1 and studio._selected_interior_floor_id()=="ground_floor","Blocked automatic stairs partially committed instead of allowing retry")
	studio.top_cancel_button.pressed.emit()
	check(studio.interior_stair_pending.is_empty() and not studio.interior_floor_canvas.placing_stair,"Blocked automatic placement could not cancel")
	studio.interior_data=original_stairs
	studio._refresh_interior_designer_controls("ground_floor")
	studio.interior_tools_navigation.open_page("flooring")
	studio.interior_floor_option.select(0)
	studio._on_interior_floor_selected(0)
	studio.interior_floor_material_option.select(1)
	studio._on_interior_floor_paint_requested([Vector2(5,5)],true)
	studio._begin_interior_floor_painting()
	await capture("editor_floor_paint_revision4")
	studio.interior_tools_navigation.open_page("furniture")
	await capture("editor_furniture_revision4")
	root.size = Vector2i(1024,768); root.content_scale_size=root.size; await frames()
	var small: Rect2 = studio.interior_floor_canvas.get_global_rect()
	check(small.size.x>=280 and small.end.x<=1025,"Small-window map escaped viewport: " + str(small))
	root.size = Vector2i(1366,768)
	root.content_scale_size=root.size
	var albury := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var albury_file := albury.path_join("data/building_interiors.json")
	var hash_before := FileAccess.get_sha256(albury_file)
	var loaded := Loader.new().load_project(albury)
	check(loaded.ok,"Saved Albury cannot load for UI check")
	if loaded.ok:
		studio.loaded_project_directory = albury
		studio.imported_town = loaded.import_result
		studio.current_town_name = "Albury"
		studio._show_interior_designer_page(); studio.message_dialog.hide(); await frames()
		var pub_index := -1
		for i in studio.interior_eligible_features.size():
			if str(studio.interior_eligible_features[i].id)=="601183200": pub_index=i
		check(pub_index>=0,"Pub missing from actual selector")
		if pub_index>=0:
			studio.interior_building_option.select(pub_index)
			studio._on_interior_building_selected(pub_index)
			studio.interior_tools_navigation.open_page("connections")
			var next_index := -1
			for i in studio.interior_connection_target.item_count:
				if str(studio.interior_connection_target.get_item_metadata(i).building_id)=="601183201": next_index=i
			check(next_index>=0,"Actual editor omitted Pub neighbour601183201")
			if next_index>=0:
				studio.interior_connection_target.select(next_index)
				check(studio.interior_connection_target.get_item_text(next_index).contains("601183201"),"Neighbour ID not visible")
				studio._refresh_connection_actions()
				if not studio.interior_data.buildings.has("601183201"): studio._create_connection_neighbour()
				check(not studio.interior_connection_add.disabled,"201 not connectable after creating ground floor")
				var source: Dictionary = studio.interior_data.duplicate(true)
				var pub: Dictionary = studio.interior_selected_feature
				var other := Connections.feature_for(studio.interior_connection_features,"601183201")
				var created := false
				for segment in Connections.shared_segments(pub,other):
					for fraction in [.25,.5,.75]:
						var geo: Array = [lerpf(segment.start[0],segment.finish[0],fraction),lerpf(segment.start[1],segment.finish[1],fraction)]
						var point := Connections.local_point(pub,Connections.floor_for(studio.interior_data,pub.id,"ground_floor"),geo)
						if studio._connection_point_valid(point): studio._place_connection(point); created=true; break
					if created: break
				check(created,"Actual editor could not place Pub-to201 door on a clear wall")
				studio._record_section_edit()
				await frames()
				studio.interior_tools_navigation.page_scroll.scroll_vertical = 95
				await capture("editor_albury_next_door_revision4")
				studio.interior_data=source # In-memory only, no Save to user's Albury.
	check(FileAccess.get_sha256(albury_file)==hash_before,"Read-only Albury check wrote user interior")
	studio.queue_free(); await frames()
	print("EDITOR USABILITY %s: %d checks" % ["PASSED" if failures==0 else "FAILED",checks])
	quit(0 if failures==0 else 1)
