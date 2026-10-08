extends SceneTree

## Temporary fixture writes only; actual Albury is loaded read-only for images.
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(condition: bool, message: String) -> void:
	if not condition: failures+=1; push_error(message)

func mouse(canvas: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=point
	event.pressed=pressed
	canvas._gui_input(event)

func drag(canvas: Control, first: Vector2, last: Vector2) -> void:
	mouse(canvas,first,true)
	var event := InputEventMouseMotion.new()
	event.position=last
	event.relative=last-first
	canvas._gui_input(event)
	mouse(canvas,last,false)

func frames() -> void:
	for count in 4: await process_frame

func _run() -> void:
	create_timer(60).timeout.connect(func(): push_error("DOOR EDITOR TIMED OUT"); quit(1))
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/door-editor-%s" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temporary.path_join("data"))
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio.imported_town=studio.importer.parse_files(PackedStringArray(["res://tools/tests/fixtures/tiny_town.osm"]))
	studio.loaded_project_directory=temporary
	studio.current_town_name="Door editor fixture"
	studio._show_building_creator_page()
	var feature: Dictionary=studio.imported_town.features.filter(func(item): return item.kind=="building")[0]
	studio._on_building_creator_selected(feature)
	var original_geometry := JSON.stringify(studio.imported_town.features)
	await frames()
	check(studio.building_tools_navigation.pages.size()==4,"Building tool hub must contain four separate pages.")
	check(studio.building_map_workspace.visible and not studio.building_artwork_workspace.visible,"Hub should show the town map only.")
	for dimensions in [Vector2i(1280,800),Vector2i(1100,720)]:
		root.size=dimensions
		root.content_scale_size=dimensions
		await frames()
		var map_rect: Rect2=studio.building_map_canvas.get_global_rect()
		check(map_rect.size.y>=220 and map_rect.end.y<=dimensions.y-10,"Town map is cut off at %s: %s" % [dimensions,map_rect])
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	studio.building_tools_navigation.open_page("entrances")
	await frames()
	var map=studio.building_map_canvas
	map.zoom_in()
	map.zoom_in()
	var edge := Vector2(feature.points[0][0],feature.points[0][1]).lerp(Vector2(feature.points[1][0],feature.points[1][1]),0.5)
	var moved := edge+Vector2(0.0003,0)
	studio._begin_building_door_placement()
	mouse(map,map._geographic_to_screen(edge),true)
	mouse(map,map._geographic_to_screen(edge),false)
	var record: Dictionary=studio.building_exterior_data.buildings[str(feature.id)]
	check(record.doors.size()==1,"Click-release failed to place a wall-snapped door.")
	if record.doors.is_empty(): quit(1); return
	var entrance_id: String=record.doors[0].id
	studio._create_building_link_floor()
	await frames()
	check(studio.building_entry_workspace.visible and studio.building_link_dirty,"Blank floor/link workspace was not opened.")
	var entry=studio.building_entry_canvas
	var floor: Dictionary=entry.floor_data
	var arrival := Vector2(floor.width_metres*0.4,floor.height_metres*0.4)
	drag(entry,entry._metres_to_screen(arrival),entry._metres_to_screen(arrival+Vector2(1,2)))
	check(studio.building_link_status.text.begins_with("✓"),"Interior arrival did not link on release.")
	var linked: Dictionary=studio.building_link_data.buildings[str(feature.id)].floors[0].entry_links[0]
	check(linked.exterior_entrance_id==entrance_id and absf(linked.spawn_x_metres-arrival.x-1)<0.02,"Interior link ID/drag arrival incorrect.")
	var next_arrival := arrival+Vector2(4,6)
	drag(entry,entry._metres_to_screen(Vector2(linked.spawn_x_metres,linked.spawn_y_metres)),entry._metres_to_screen(next_arrival))
	linked=studio.building_link_data.buildings[str(feature.id)].floors[0].entry_links[0]
	check(absf(linked.spawn_y_metres-next_arrival.y)<0.02,"Existing arrival marker could not be dragged directly.")
	var before_bad := JSON.stringify(studio.building_link_data)
	studio._on_building_entry_spawn(Vector2(-5,-5))
	check(JSON.stringify(studio.building_link_data)==before_bad and entry.invalid_position!=Vector2.INF,"Invalid entry changed data or failed to show X.")
	studio._show_building_workspace("map")
	drag(map,map._geographic_to_screen(edge),map._geographic_to_screen(moved))
	record=studio.building_exterior_data.buildings[str(feature.id)]
	check(record.doors[0].id==entrance_id and absf(record.doors[0].longitude-moved.x)<0.000001,"Dragging a map doorway lost identity or failed to move.")
	check(JSON.stringify(studio.building_link_data)==before_bad,"Outside movement changed the independent interior arrival.")
	var original_view: Vector2=map.view_center_ratio
	drag(map,Vector2(25,25),Vector2(60,50))
	check(not map.view_center_ratio.is_equal_approx(original_view),"Dragging empty space should still pan.")
	# Production facade artwork can be dragged without moving roof UVs.
	studio._show_building_workspace("door_art")
	await frames()
	var preview=studio.building_artwork_preview
	var art: Dictionary=preview.renderer.building_door_art["%s:0" % str(feature.id)]
	check(not art.surfaces.is_empty(),"Test door must be visible on the camera-facing facade.")
	var anchor: Vector2=art.anchor*preview.renderer.scale+preview.renderer.position
	var intended: Vector2=preview.renderer._world(moved+Vector2(0.00015,0))*preview.renderer.scale+preview.renderer.position
	drag(preview,anchor,intended)
	record=studio.building_exterior_data.buildings[str(feature.id)]
	# Geographic Vector2 uses single precision; check within about one metre.
	check(record.doors[0].id==entrance_id and absf(record.doors[0].longitude-moved.x-0.00015)<0.00001,"Facade artwork drag did not move its actual entrance.")
	check(not record.has("roof_alignment"),"Door drag incorrectly edited roof UVs.")
	# A completely obstructed map must reject a drag without changing the door.
	var guard := feature.duplicate(true)
	guard.id="blocked"
	guard.points=[[146.002,-36.007],[146.006,-36.007],[146.006,-36.003],[146.002,-36.003],[146.002,-36.007]]
	studio.building_effective_features.append(guard)
	var before_door := JSON.stringify(record.doors)
	studio._on_building_dragged_door(0,{"longitude":moved.x,"latitude":moved.y})
	check(JSON.stringify(studio.building_exterior_data.buildings[str(feature.id)].doors)==before_door and not map.rejected_door_location.is_empty(),"Blocked approach must preserve original door and show red X.")
	studio.building_effective_features.pop_back()
	studio._save_building_designs()
	studio.message_dialog.hide()
	var exterior_save: Dictionary = studio.building_exterior_store.load_from_town(temporary)
	var interior_save: Dictionary = studio.building_interior_store.load_from_town(temporary)
	check(exterior_save.ok and interior_save.ok and interior_save.data.buildings[str(feature.id)].floors[0].entry_links[0].exterior_entrance_id==entrance_id,"Save/reload did not persist both sides of the entry link.")
	var runtime = load("res://scripts/runtime/town_runtime.gd").new()
	runtime.renderer=preview.renderer
	runtime.building_exterior_data=exterior_save.data
	runtime.building_interior_data=interior_save.data
	runtime._build_runtime_interior_entrances(studio.imported_town.features,preview.renderer.projection,preview.renderer.pixels_per_metre)
	check(runtime.interior_entrances.size()==1 and runtime.interior_entrances[0].link.exterior_entrance_id==entrance_id,"Runtime did not recognise linked GUI doorway as playable.")
	runtime.free()
	check(JSON.stringify(studio.imported_town.features)==original_geometry,"Door edits changed OSM geometry.")
	# Back returns to map while keeping unsaved edits.
	studio.building_tools_navigation.show_home()
	check(studio.building_map_workspace.visible and not studio.building_artwork_workspace.visible,"Back did not restore the map-only workspace.")
	studio.building_tools_navigation.open_page("entrances")
	studio._remove_selected_building_entrance()
	check(studio.building_link_data.buildings[str(feature.id)].floors[0].entry_links.is_empty(),"Explicit doorway removal left stale links for migration to misassign.")
	if OS.get_cmdline_user_args().has("--render"):
		var real := ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
		var saved_path := real.path_join("data/building_exteriors.json")
		var original_hash := FileAccess.get_sha256(saved_path)
		studio._load_existing_project(real)
		studio._show_building_creator_page()
		studio.message_dialog.hide()
		studio.message_dialog.free()
		var pub: Dictionary=studio.building_effective_features.filter(func(item): return str(item.id)=="601183200")[0]
		studio._on_building_creator_selected(pub)
		studio.building_map_canvas.view_zoom=7.0
		studio.building_map_canvas.view_changed.emit(7.0)
		var ring: PackedVector2Array=studio.building_map_canvas._screen_polygon(pub.points)
		studio.building_map_canvas._pan_by(studio.building_map_canvas.size*0.5-studio.building_map_canvas._polygon_bounds(ring).get_center())
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_creator_map_hub.png"))
		studio.building_tools_navigation.open_page("entrances")
		studio._show_building_workspace("door_art")
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_creator_door_drag.png"))
		studio._begin_building_interior_link()
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/building_creator_interior_link.png"))
		check(FileAccess.get_sha256(saved_path)==original_hash,"Actual Albury was changed by image capture.")
	studio.free()
	await process_frame
	if failures>0: quit(1); return
	print("BUILDING DOOR EDITOR PASSED: full-height map at two window sizes, persistent four-page hub, map/facade click-drag, safe rejection, interior arrival dragging, stable links, save/reload and runtime playable-entry recognition. Albury captures read-only.")
	quit()
