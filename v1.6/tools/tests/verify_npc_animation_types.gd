extends SceneTree

const Library=preload("res://scripts/npcs/rigging/npc_animated_library.gd")
const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")
const RigArt=preload("res://scripts/npcs/rigging/npc_rig_art.gd")
const Actor=preload("res://scripts/runtime/runtime_actor_art.gd")
const Store=preload("res://scripts/npcs/creation/npc_creation_store.gd")
const Pose=preload("res://scripts/npcs/creation/npc_pose_art.gd")
const Settings=preload("res://scripts/settings/game_settings_store.gd")
const Importer=preload("res://scripts/npcs/rigging/npc_rig_import.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func frames() -> void:
	for _i in 7: await process_frame
func write_json(path: String,value: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()

class Sheet:
	extends Node2D
	var phase:=.25/1.4
	var facing:=Vector2.DOWN
	var grid:=true
	func _draw() -> void:
		draw_rect(Rect2(0,0,1366,1000),Color("#23372f"))
		var font:=ThemeDB.fallback_font
		draw_string(font,Vector2(30,36),"ILLUSTRATED CUTOUT CHARACTER LIBRARY",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("#eef0db"))
		draw_string(font,Vector2(30,65),"Animated NPCs · legacy placements (left) and current placements (right)",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#b5d4c7"))
		var identities=Store.built_ins()
		for i in identities.size() if grid else 1:
			var item: Dictionary=identities[i] if grid else identities[7]
			var x: float=25+(i%6)*222 if grid else 270
			var y: float=95+(i/6)*281 if grid else 120
			draw_rect(Rect2(x,y,208,264),Color("#34483d"))
			draw_string(font,Vector2(x+10,y+23),str(item.skin_tone_group).capitalize()+" · "+str(item.gender).capitalize(),HORIZONTAL_ALIGNMENT_LEFT,192,15,Color("#fff2c9"))
			draw_string(font,Vector2(x+10,y+46),Store.AGES[item.age_group],HORIZONTAL_ALIGNMENT_LEFT,192,14,Color("#c6dccf"))
			var appearance:=Store.appearance(item,false)
			for side in 2:
				appearance.animation_type="static" if side==0 else "animated"
				var point:=Vector2(x+57+side*95,y+215)
				Pose.draw_actor(self,appearance,{},"",point,facing,"walk",phase,10)
				draw_string(font,Vector2(x+27+side*95,y+249),"Migrated" if side==0 else "Animated",HORIZONTAL_ALIGNMENT_LEFT,85,13,Color("#d0dfd3"))

class ProductionSheet:
	extends "res://scripts/runtime/runtime_population.gd"
	var test_phase:=.25/1.4
	func _draw() -> void:
		for i in 3:
			var agent: Dictionary={"phase":test_phase,"angle":PI/2,"moving":true,"npc_role":["generic","storyline","trader"][i],"appearance":{"npc_asset":"npc_medium_man_adult","animation_type":"static"}}
			_draw_person(agent,Vector2(20+i*30,30))
			agent.moving=false
			_draw_person(agent,Vector2(20+i*30,55))

func run() -> void:
	create_timer(80).timeout.connect(func():push_error("Animation types timed out");quit(2))
	root.size=Vector2i(1366,1000); root.content_scale_size=root.size; root.gui_embed_subwindows=true
	var temporary:=ProjectSettings.globalize_path("res://tools/tests/output/npc-animation-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temporary.path_join("data"))
	write_json(temporary.path_join("town.json"),{"town_id":"animation-fixture","display_name":"Matching character test"})
	var ids: Array=Store.built_ins().map(func(item):return str(item.id)); ids.append("player")
	check(ids.size()==19,"Library must contain eighteen identities + player")
	for asset in ids:
		var rig:=Library.for_actor(asset)
		check(not rig.is_empty(),"Missing matching skeleton "+asset)
		if rig.is_empty(): continue
		var appearance: Dictionary={"npc_asset":asset,"animation_type":"animated"}
		for view_index in 4:
			var view: String=Rig.VIEWS[view_index]
			var facing: Vector2=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][view_index]
			var rest:=RigArt.transforms(rig,view,0,false)
			var walking:=RigArt.transforms(rig,view,.25/1.4,true)
			check(walking.head==rest.head and walking.torso==rest.torso,"Face/torso warped "+asset+view)
			check(walking.left_thigh!=rest.left_thigh and walking.right_upper_arm!=rest.right_upper_arm,"No limb motion "+asset+view)
			var frame:=RigArt.layout(rig,view,0,false); var union:=Rect2(); var first:=true
			for piece in frame.pieces:
				check(Importer.image_valid(piece.image),"Body-part image invalid "+asset+view+piece.part)
				check(piece.region.is_empty() and str(piece.image).begins_with("res://assets/actors/cutout_v16/"),"Old sprite strips still used "+asset+view+piece.part)
				for point in piece.points:
					if first: union=Rect2(point,Vector2.ZERO); first=false
					else: union=union.expand(point)
			check(is_equal_approx(union.size.y,Actor.GROUND_CHARACTER_DRAW_SIZE.y) and union.size.x<=Actor.GROUND_CHARACTER_DRAW_SIZE.x and is_zero_approx(union.end.y),"Scale/feet changed "+asset+view)
			check(RigArt.layout(rig,view,0,false)==RigArt.layout(rig,view,2,false),"Static rest pose changes "+asset+view)
			check(Pose.artwork(appearance,{},"",facing,"walk",.18).has("rig"),"Animated renderer missing "+asset+view)
			appearance.animation_type="static"
			check(Pose.artwork(appearance,{},"",facing,"walk",.18).rig==rig,"Static NPC uses wrong style "+asset+view)
			check(Pose.artwork(appearance,{},"",facing,"sit",.18).rig.seated,"Seated NPC uses old style "+asset+view)
			appearance.animation_type="animated"
	check(Library.for_actor("npc_light_man_invalid").is_empty(),"Unknown age accepted")
	var descriptions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Library.FILE_NAME)).appearances
	check(descriptions.player.skin=="#e8bb94" and descriptions.player.hair=="#5c3f29" and descriptions.player.jacket=="#b73e35" and descriptions.player.trousers=="#376e9b","Player colours do not match request")
	check(not Library.install(temporary,"../escape","player").ok,"Unsafe copied asset ID accepted")
	var settings:=Settings.recommended_settings()
	write_json(temporary.path_join("game_settings.json"),settings)
	settings.erase("character_art"); write_json(temporary.path_join("game_settings.json"),settings)
	check(Settings.load_from_town(temporary).settings.character_art=={"npc_type":"animated","player_type":"animated"},"Missing settings not migrated")
	settings.character_art={"npc_type":"static","player_type":"static"}
	write_json(temporary.path_join("game_settings.json"),settings)
	var old_hash:=FileAccess.get_sha256(temporary.path_join("game_settings.json"))
	check(Settings.load_from_town(temporary).settings.character_art.npc_type=="animated" and FileAccess.get_sha256(temporary.path_join("game_settings.json"))==old_hash,"Old static settings not migrated read-only")
	check(Settings.save_to_town(temporary,settings).ok and Settings.load_from_town(temporary).settings.character_art.npc_type=="animated" and settings.character_art.npc_type=="static","Save migration mutates caller or retains static")
	settings.character_art={"npc_type":"animated","player_type":"animated"}
	check(Settings.save_to_town(temporary,settings).ok and Settings.load_from_town(temporary).settings.character_art==settings.character_art,"Animated choices do not persist")
	var invalid:=settings.duplicate(true); invalid.character_art.npc_type="anything"
	check(not Settings.validate(invalid).passed,"Invalid type accepted")
	invalid=settings.duplicate(true); invalid.character_art=[]
	check(not Settings.validate(invalid).passed,"Malformed type group accepted")
	var studio=load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=temporary; studio.last_created_directory=temporary
	studio.imported_town=studio.importer.parse_files(PackedStringArray(["res://tools/tests/fixtures/tiny_town.osm"]))
	studio._show_game_settings_page(); studio.settings_tools_navigation.open_page("characters"); await frames()
	check(studio._settings_from_controls().character_art=={"npc_type":"animated","player_type":"animated"},"Editor does not use animated humans/player")
	studio._save_game_settings(); studio.message_dialog.hide()
	check(Settings.load_from_town(temporary).settings.character_art=={"npc_type":"animated","player_type":"animated"},"Header Save freezes player")
	if OS.get_cmdline_user_args().has("--render"):
		await frames(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/character_artwork_settings_v16.png"))
	studio._show_personas_page(); studio.npc_tools_navigation.open_page("creation"); await frames()
	var editor=studio.npc_creation_editor
	check(not has_static_npc_option(studio),"Static NPC control still offered")
	editor.selected_id=str(Store.built_ins()[10].id); editor._refresh_list(); editor._select(editor.list.selected)
	editor._refresh_preview(); editor._sync_mode()
	check(editor.test_button.visible and editor.preview.appearance.animation_type=="animated","Built-in animated test unavailable")
	editor._test_walking(); await frames()
	var practice: Window
	for child in editor.get_children():
		if child is Window and child.title.begins_with("NPC walking test"): practice=child
	check(is_instance_valid(practice),"Built-in self-test missing")
	if is_instance_valid(practice):
		check(practice.player.art_type=="animated" and practice.agent.appearance.npc_asset==editor.selected_id,"Test uses wrong identity/player")
		if OS.get_cmdline_user_args().has("--render"):
			practice.agent.position=Vector2(-13,6); practice.agent.angle=PI/2; practice.agent.phase=.25/1.4; practice.set_process(false)
			practice.player.position=Vector2(8,6); practice.player.facing=Vector2.LEFT
			practice.player.walking=true; practice.player.animation_time=.25/1.4; practice.player.set_physics_process(false)
			practice.player.queue_redraw(); practice.population.queue_redraw(); await frames(); await RenderingServer.frame_post_draw
			practice.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/matching_animated_walking_test_v16.png"))
		practice.free()
	editor._new_rig(); await frames()
	var creation: Dictionary=editor._item()
	check(creation.rig.source_asset==Store.built_ins()[10].id and creation.age_group==Store.built_ins()[10].age_group,"Matching creation changes identity")
	check(Store.validate(editor.data,temporary).ok,"Copied matching artwork invalid")
	var source: String=Library.for_actor(creation.rig.source_asset).views.front.parts.head.image
	check(FileAccess.get_sha256(source)==FileAccess.get_sha256(temporary.path_join(creation.rig.views.front.parts.head.image)),"Copied body part differs")
	editor.name_edit.text="My named Animated NPC"; editor._flush()
	check(Store.save_to_town(temporary,editor.data).ok and Store.load_from_town(temporary).ok,"Creation Save/reopen failed")
	var snapshot: Dictionary=editor.snapshot_state(); editor.name_edit.text="Changed name"; editor._flush(); editor.restore_state(snapshot)
	check(editor.preview.appearance.animation_type=="animated" and editor.name_edit.text=="My named Animated NPC","History loses animation/name")
	var image:=Image.create(32,32,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); image.save_png(temporary.path_join("replacement.png"))
	var legacy_regions: Dictionary=creation.rig.duplicate(true); legacy_regions.views.front.parts.head.region=[0,0,20,20]
	var replaced:=Importer.import_parts(temporary,creation.id,legacy_regions,"front",PackedStringArray([temporary.path_join("replacement.png")]),"head")
	check(replaced.ok and not replaced.rig.views.front.parts.head.has("region") and replaced.rig.views.front.parts.torso==creation.rig.views.front.parts.torso,"Part replacement damages other artwork/retains old region")
	var picker=preload("res://scripts/npcs/creation/npc_appearance_picker.gd").new(); root.add_child(picker); await frames()
	var old_appearance:=Store.appearance(Store.built_ins()[0],false); old_appearance.animation_type="static"
	picker.set_appearance(old_appearance)
	check(picker.selected_appearance().animation_type=="animated" and old_appearance.animation_type=="static","Picker does not migrate old type or mutates input")
	picker.template_choice.item_selected.emit(15)
	check(picker.selected_appearance().animation_type=="animated" and picker.selected_appearance().npc_asset==Store.built_ins()[15].id,"Selecting identity loses animated override")
	var placed:=picker.selected_appearance(); picker.set_appearance(placed)
	check(picker.selected_appearance()==placed,"Reopen changes explicit NPC type")
	picker.source.select(0); picker._changed(0)
	var random_draft:=picker.selected_appearance()
	picker.set_appearance(random_draft)
	check(picker.selected_appearance().animation_type=="animated","Random artwork draft loses animation")
	var random_actor:=picker.selected_appearance(Store.appearance(Store.built_ins()[3],false))
	check(random_actor.animation_type=="animated" and random_actor.npc_asset==Store.built_ins()[3].id,"Random choice loses appearance defaults")
	random_actor.animation_type="static"; picker.set_appearance({})
	check(picker.selected_appearance(random_actor).animation_type=="animated","Random choice retains old static override")
	picker.free()
	for viewport_size in [Vector2i(1366,1000),Vector2i(1024,768)]:
		root.size=viewport_size; root.content_scale_size=viewport_size; await frames()
		check(editor.name_edit.size.y<=60 and editor.name_edit.get_global_rect().end.x<=viewport_size.x+1,"Creation name oversized")
	if OS.get_cmdline_user_args().has("--render"):
		root.size=Vector2i(1366,1000); root.content_scale_size=root.size; studio.persona_page_scroll.scroll_vertical=0
		await frames(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/animated_only_npc_editor_v16.png"))
	await legacy_placements(temporary,creation)
	studio.free(); await frames()
	if OS.get_cmdline_user_args().has("--render"):
		var sheet:=Sheet.new(); root.add_child(sheet); sheet.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		await frames(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/animated_only_npc_library_v16.png"))
		var before:=root.get_texture().get_image()
		sheet.phase=.75/1.4; sheet.queue_redraw(); await frames(); await RenderingServer.frame_post_draw
		var after:=root.get_texture().get_image(); var left_changed:=0; var right_changed:=0
		for i in 18:
			var x: int=25+(i%6)*222; var y: int=95+floori(i/6.0)*281
			for px in range(x+15,x+97):
				for py in range(y+60,y+228):
					if before.get_pixel(px,py)!=after.get_pixel(px,py): left_changed+=1
			for px in range(x+109,x+205):
				for py in range(y+60,y+228):
					if before.get_pixel(px,py)!=after.get_pixel(px,py): right_changed+=1
		check(left_changed>100 and right_changed>100,"Legacy or current human artwork failed to animate")
		sheet.free()
		await production_animation_picture()
	print("ANIMATION FIXTURE: "+temporary)
	print("NPC ANIMATION TYPES: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

func has_static_npc_option(node: Node) -> bool:
	if node is Button and node.text.contains("Static NPC"): return true
	if node is OptionButton:
		for i in node.item_count:
			if node.get_item_text(i).contains("Static NPC"): return true
	for child in node.get_children():
		if has_static_npc_option(child): return true
	return false

func legacy_placements(directory: String, creation: Dictionary) -> void:
	var placed_store=preload("res://scripts/npcs/storyline_npc_store.gd").new()
	var original: Dictionary=placed_store.empty_data()
	for role in ["generic","storyline","trader"]:
		var appearance:=Store.appearance(Store.built_ins()[7],false)
		if role=="trader": appearance=Store.appearance(creation,true)
		if role!="storyline": appearance.animation_type="static"
		else: appearance.erase("animation_type")
		original.npcs.append({"id":role+"_fixture","npc_role":role,"actor_kind":"npc","display_name":role.capitalize()+" Name","persona_id":role+"_persona","appearance":appearance,"location":{"space":"outdoors","latitude":-36.081,"longitude":146.919},"behaviour":{"stationary":true},"trade":{"inventory":[{"item_id":"beer","quantity":10,"price_keks":5}]}})
	original.npcs.append({"id":"npr_fixture","npc_role":"npr","actor_kind":"npr","display_name":"NPR-001","persona_id":"robot","appearance":{"mode":"random_static_asset","npc_asset":"npr"},"location":{"space":"outdoors","latitude":-36.081,"longitude":146.919}})
	var path:=directory.path_join("data/storyline_npcs.json")
	write_json(path,original)
	# Compare reopened JSON with JSON, not int-valued draft dictionaries.
	var disk_original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var original_hash:=FileAccess.get_sha256(path)
	var loaded: Dictionary=placed_store.load_from_town(directory)
	check(loaded.ok,"Legacy human/NPR placements fail to load")
	if not loaded.ok: return
	check(FileAccess.get_sha256(path)==original_hash,"Loading placements rewrites files")
	for i in 3:
		var expected: Dictionary=disk_original.npcs[i].duplicate(true); expected.appearance.animation_type="animated"
		check(loaded.data.npcs[i]==expected,"Migration changes role/name/persona/artwork/location/stock")
	check(loaded.data.npcs[3]==original.npcs[3],"Human migration changes NPR")
	var population=preload("res://scripts/runtime/runtime_population.gd").new()
	population.set_storyline_npcs(original)
	var runtime_json: Dictionary=JSON.parse_string(JSON.stringify(population.storyline_npc_data))
	check(runtime_json.npcs==loaded.data.npcs,"Direct runtime placements retain legacy flags or change identities")
	population.free()
	check(placed_store.save_to_town(directory,original).ok,"Migrated placement Save failed")
	var reopened: Dictionary=placed_store.load_from_town(directory)
	check(reopened.ok and reopened.data.npcs==loaded.data.npcs,"Reopening changed migrated NPCs")
	check(original.npcs[0].appearance.animation_type=="static","Save mutates caller draft")

func production_animation_picture() -> void:
	var panel:=ColorRect.new(); panel.color=Color("#34483d"); panel.size=Vector2(1366,1000); root.add_child(panel)
	var sheet:=ProductionSheet.new(); sheet.position=Vector2(70,100); sheet.scale=Vector2.ONE*10; root.add_child(sheet); sheet.set_process(false)
	sheet.npc_art_type="static" # Simulate an old caller; it must not suppress walking.
	var title:=Label.new(); title.position=Vector2(30,20); title.text="Generic / Storyline / Trader · moving above, stationary below"; root.add_child(title)
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/animated_only_runtime_v16.png"))
	var before:=root.get_texture().get_image(); sheet.test_phase=.75/1.4; sheet.queue_redraw()
	await frames(); await RenderingServer.frame_post_draw
	var after:=root.get_texture().get_image()
	for i in 3:
		var changed:=0; var idle_changed:=0; var x:=270+i*300
		for px in range(x-55,x+55):
			for py in range(255,405):
				if before.get_pixel(px,py)!=after.get_pixel(px,py): changed+=1
			for py in range(505,655):
				if before.get_pixel(px,py)!=after.get_pixel(px,py): idle_changed+=1
		check(changed>100 and idle_changed==0,"Production moving/stationary animation failed for role "+str(i))
	sheet.free(); panel.free(); title.free()

func player_picture() -> void:
	var background:=ColorRect.new(); background.color=Color("#23372f"); background.size=Vector2(1366,1000); root.add_child(background)
	var heading:=Label.new(); heading.position=Vector2(30,20); heading.text="PLAYER · BROWN HAIR / RED JACKET / BLUE JEANS"; heading.add_theme_font_size_override("font_size",24); root.add_child(heading)
	var note:=Label.new(); note.position=Vector2(30,60); note.text="Current game scale · separate cutout parts · four views"; root.add_child(note)
	var objects: Array=[background,heading,note]
	for row in 3:
		for view in 4:
			var x: float=20+view*335; var y: float=105+row*290
			var label:=Label.new(); label.position=Vector2(x+10,y); label.text=Rig.VIEWS[view].capitalize()+" · "+["Static player","Animated player","Actual game chair"][row]; root.add_child(label); objects.append(label)
			var facing: Vector2=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][view]
			if row<2:
				var player=preload("res://scripts/runtime/runtime_player_character.gd").new(); root.add_child(player); objects.append(player)
				player.position=Vector2(x+163,y+230); player.scale=Vector2.ONE*13
				player.art_type="static" if row==0 else "animated"; player.facing=facing; player.walking=true; player.animation_time=.25/1.4
				player.set_physics_process(false); player.queue_redraw()
			else:
				var preview=preload("res://scripts/npcs/creation/npc_pose_preview.gd").new(); preview.position=Vector2(x,y+35); preview.size=Vector2(315,240)
				preview.appearance={"npc_asset":"player"}; preview.pose="sit"; preview.facing=facing; preview.frozen=true; root.add_child(preview); objects.append(preview)
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/cutout_player_views_v16.png"))
	for item in objects: item.free()
