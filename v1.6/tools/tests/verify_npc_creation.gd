extends SceneTree

const Store = preload("res://scripts/npcs/creation/npc_creation_store.gd")
const PoseArt = preload("res://scripts/npcs/creation/npc_pose_art.gd")
const Preview = preload("res://scripts/npcs/creation/npc_pose_preview.gd")
const Population = preload("res://scripts/runtime/runtime_population.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func frames() -> void:
	for _i in 5: await process_frame
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("NPC creator test timed out"); quit(2))
	root.size=Vector2i(1366,900); root.content_scale_size=root.size
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/npc-creation-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temporary.path_join("data"))
	var file := FileAccess.open(temporary.path_join("town.json"),FileAccess.WRITE); file.store_string('{"town_id":"npc-fixture","display_name":"NPC test"}'); file.close()
	check(Store.load_from_town(temporary).ok,"Older towns without a custom catalogue failed")
	check(Store.built_ins().size()==18,"Expected all eighteen built-in identities")
	for item in Store.built_ins():
		check(Store.AGES.has(item.age_group) and item.gender in Store.GENDERS and item.skin_tone_group in Store.TONES,"Built-in attributes missing: "+str(item.id))
		for facing in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
			var sprite := PoseArt.artwork(Store.appearance(item,false),Store.empty_data(),"",facing,"sit",0)
			check(not sprite.is_empty() and sprite.get("pose",false) and sprite.get("rig",{}).get("seated",false),"Seated cutout age/tone/gender view missing: "+str(item.id))
	var generic := Population.new()
	generic.graphs={"person":{"nodes":{0:Vector2.ZERO},"adjacency":{},"all_ids":[0],"cbd_ids":[0]}}
	generic.skin_tone_distribution={"light_percent":100,"medium_percent":0,"dark_percent":0}
	generic._add_population("person",18,0,30)
	check(generic.agents.size()==18 and generic.agents.filter(func(a):return a.gender=="man").size()==9,"Generic population gender balance changed")
	check(generic.agents.all(func(a):return a.age_group in Store.AGES and a.skin_tone_group=="light" and a.npc_asset=="npc_light_%s_%s" % [a.gender,a.age_group]),"Generic population attributes/artwork mismatch")
	generic.free()
	var data := Store.empty_data()
	data.creations.append({"id":"test_upload","name":"Uploaded Test","gender":"woman","age_group":"older","skin_tone_group":"medium","seat_anchor_y":.58,"poses":{}})
	var source := ProjectSettings.globalize_path("res://assets/actors/npc_medium_woman_older_v3.png")
	var other := ProjectSettings.globalize_path("res://assets/actors/npc_medium_woman_adult_v3.png")
	var hash := FileAccess.get_sha256(source)
	var imported := Store.import_frames(temporary,data,"test_upload","idle","front",PackedStringArray([source]))
	check(imported.ok,"Standing image import failed")
	data=imported.data
	imported=Store.import_frames(temporary,data,"test_upload","walk","left",PackedStringArray([source,other]))
	check(imported.ok and imported.data.creations[0].poses.walk.left.size()==2,"Multi-frame import failed")
	data=imported.data
	check(FileAccess.get_sha256(source)==hash,"Import changed the original image")
	check(Store.validate(data,temporary).ok and Store.save_to_town(temporary,data).ok,"Custom catalogue validation/save failed")
	var reloaded: Dictionary = Store.load_from_town(temporary).data.creations[0]
	check(reloaded.poses.walk.left==data.creations[0].poses.walk.left and reloaded.gender=="woman" and reloaded.age_group=="older" and is_equal_approx(reloaded.seat_anchor_y,.58),"Custom catalogue reopen changed frames/attributes")
	check(not Store.safe_path("assets/npcs/../outside.png") and not Store.safe_path("C:/outside.png"),"Image path escape accepted")
	check(not Store.import_frames(temporary,data,"test_upload","walk","front",PackedStringArray(["res://scripts/runtime/runtime_actor_art.gd"])).ok,"Script upload accepted")
	var invalid := data.duplicate(true); invalid.creations[0].gender="unknown"
	check(not Store.validate(invalid).ok,"Unsupported gender accepted")
	invalid=data.duplicate(true); invalid.creations[0].poses.idle="invalid"
	check(not Store.validate(invalid).ok,"Malformed nested pose crashed or passed validation")
	var appearance := Store.appearance(data.creations[0],true)
	var frame1 := PoseArt.artwork(appearance,data,temporary,Vector2.LEFT,"walk",.01)
	var frame2 := PoseArt.artwork(appearance,data,temporary,Vector2.LEFT,"walk",.15)
	check(not frame1.is_empty() and frame1.texture!=frame2.texture,"Uploaded animation did not change frame")
	check(not PoseArt.artwork(appearance,data,temporary,Vector2.UP,"idle",0).is_empty(),"Missing direction did not use front fallback")
	check(not PoseArt.artwork(appearance,data,temporary,Vector2.DOWN,"sit",0).pose,"Missing sitting images were presented as a seated pose")
	check(PoseArt.sitting_rect(appearance,data).position.y<0 and PoseArt.sitting_rect(appearance,data).end.y>0,"Sitting pose is not hip-anchored")
	var studio = load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=temporary
	studio.imported_town=studio.importer.parse_files(PackedStringArray(["res://tools/tests/fixtures/tiny_town.osm"]))
	var feature: Dictionary = studio.imported_town.features.filter(func(v): return v.kind=="building")[0]
	var interior_result: Dictionary = studio.building_interior_store.create_blank_ground_floor(studio.building_interior_store.empty_data(),feature)
	check(interior_result.ok and studio.building_interior_store.save_to_town(temporary,interior_result.data).ok,"Interior fixture invalid")
	studio._show_personas_page(); await frames()
	check(is_instance_valid(studio.npc_creation_editor) and studio.npc_tools_navigation.pages.has("creation"),"NPC creator tile is absent")
	studio.npc_tools_navigation.open_page("storyline"); await frames()
	var picker = studio.npc_appearance_picker
	for i in picker.source.item_count:
		if picker.source.get_item_metadata(i)=="test_upload": picker.source.select(i); picker._changed(i)
	check(picker.selected_appearance().template_id=="test_upload" and picker.gender.disabled,"Custom creation did not retain its biological attributes")
	studio.npc_tools_navigation.open_page("generic"); studio.npc_tools_navigation.open_page("storyline")
	check(picker.selected_appearance().get("template_id","")=="test_upload","Switching tools discarded artwork choice")
	var floor_value: Dictionary = interior_result.data.buildings[str(feature.id)].floors[0]
	studio.storyline_coordinate_edit.text=preload("res://scripts/npcs/storyline_npc_store.gd").format_interior_location(str(feature.id),"ground_floor",Vector2(floor_value.width_metres*.5,floor_value.height_metres*.5))
	studio.storyline_name_edit.text="Custom resident"
	studio._place_storyline_npc()
	check(studio.storyline_npc_data.npcs.size()==1 and studio.storyline_npc_data.npcs[0].appearance.template_id=="test_upload","Custom storyline placement lost selected creation")
	studio._save_persona_library(); studio.message_dialog.hide()
	check(studio.section_save_succeeded,"NPC section Save failed")
	var saved: Dictionary = studio.storyline_npc_store.load_from_town(temporary,{},[],{},interior_result.data)
	if not saved.ok: push_error(str(saved)); quit(1); return
	check(saved.ok and saved.data.npcs[0].appearance.skin_tone_group=="medium","Saved custom NPC did not reopen")
	studio._select_placed_npc_for_edit(0)
	for i in picker.source.item_count:
		if picker.source.get_item_metadata(i)=="built_in": picker.source.select(i); picker._changed(i)
	check(not studio._current_placement_draft().is_empty() and studio._section_is_dirty(),"Appearance-only edit lost unsaved protection")
	picker.set_appearance(saved.data.npcs[0].appearance)
	var pop = Population.new(); pop.set_storyline_npcs(saved.data); pop.npc_creation_data=data; pop.npc_artwork_directory=temporary
	pop.graphs={"person":{"nodes":{}}}
	pop._add_storyline_npcs({},8.0)
	check(pop.agents.size()==1 and pop.agents[0].appearance.template_id=="test_upload","Runtime lost custom character artwork")
	pop.free()
	studio.npc_tools_navigation.open_page("npr"); check(not picker.visible,"Robot placement exposes human attributes")
	studio.npc_tools_navigation.open_page("trader"); check(picker.visible,"Trader appearance picker missing")
	studio.npc_tools_navigation.open_page("creation"); await frames()
	var editor = studio.npc_creation_editor
	for i in editor.list.item_count:
		if editor.list.get_item_metadata(i)=="morpheus": editor.list.select(i); editor._select(i)
	check(editor.selected_id=="morpheus" and editor.name_edit.editable,"Morpheus missing or name is not editable")
	editor.name_edit.text="My mentor"; editor._flush()
	check(Store.find(editor.data,"morpheus").name=="My mentor","Morpheus rename failed")
	check(Store.save_to_town(temporary,editor.data).ok and Store.find(Store.load_from_town(temporary).data,"morpheus").name=="My mentor","Morpheus name did not persist")
	check(editor.list.get_item_text(editor.list.selected)=="My mentor","Renamed chooser label stale")
	editor.data=Store.empty_data(); editor._refresh_list(); editor._select(editor.list.selected)
	editor._import(PackedStringArray([source]))
	check(Store.find(editor.data,"morpheus").poses.get("idle",{}).get("front",[]).size()==1,"Unedited bundled Morpheus upload failed")
	editor._new(); var new_id: String=editor.selected_id
	editor._remove_creation()
	check(not editor.data.creations.any(func(item):return str(item.id)==new_id),"Unfinished custom creation could not be deleted")
	editor.data=data.duplicate(true); editor.selected_id="test_upload"; editor._refresh_list(); editor._select(editor.list.selected)
	editor._remove_creation()
	check(Store.find(editor.data,"test_upload").has("poses"),"Referenced creation removed")
	editor.data=Store.empty_data(); editor.selected_id="morpheus"; editor._refresh_list(); editor._select(editor.list.selected)
	editor.name_edit.text="Morpheus"; editor._flush()
	if OS.get_cmdline_user_args().has("--render"):
		await frames(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/npc_creator_revision3_v16.png"))
	studio.free(); await frames()
	if OS.get_cmdline_user_args().has("--render"): await seating_pictures()
	print("NPC CREATION CHECKS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

func seating_pictures() -> void:
	root.size=Vector2i(1100,750); root.content_scale_size=root.size
	var background := ColorRect.new(); background.color=Color("#1c3027"); background.size=Vector2(1100,750); root.add_child(background)
	var title := Label.new(); title.position=Vector2(30,20); title.text="SEATED NPC ALIGNMENT · ACTUAL GAME CHAIR AND TOILET"; title.add_theme_font_size_override("font_size",22); root.add_child(title)
	var note := Label.new(); note.position=Vector2(30,714); note.text="Production furniture renderer · 8 px/m · directional seated poses; autonomous NPC sitting remains pending"; root.add_child(note)
	var previews: Array = []
	for row in 2:
		for i in 4:
			var preview := Preview.new(); preview.position=Vector2(10+i*272,70+row*320); preview.size=Vector2(265,300); preview.pose="sit"; preview.frozen=true
			preview.appearance=Store.appearance(Store.morpheus(),true) if row==0 else Store.appearance(Store.built_ins()[11],false)
			preview.seat_id="toilet" if row==1 else "dining_chair"
			preview.facing=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][i]
			root.add_child(preview); previews.append(preview)
	await frames(); await RenderingServer.frame_post_draw
	check(previews[0].seat.item.catalog_id=="dining_chair" and previews[0].seat.item.width_metres==.5,"Preview replaced the actual chair or scale")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/npc_seated_four_views_revision3_v16.png"))
	for node in previews+[title,note,background]: node.free()
