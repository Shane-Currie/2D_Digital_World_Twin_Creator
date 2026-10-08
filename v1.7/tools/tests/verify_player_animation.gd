extends SceneTree

const Player=preload("res://scripts/runtime/runtime_player_character.gd")
const Settings=preload("res://scripts/settings/game_settings_store.gd")
const Library=preload("res://scripts/npcs/rigging/npc_animated_library.gd")
const RigArt=preload("res://scripts/npcs/rigging/npc_rig_art.gd")
const Actor=preload("res://scripts/runtime/runtime_actor_art.gd")
var checks:=0
var failures:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func frames() -> void:
	for _i in 4: await process_frame
func write_json(path: String,value: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()
func different_pixels(a: Image,b: Image) -> int:
	var count:=0
	for x in a.get_width():
		for y in a.get_height():
			if a.get_pixel(x,y)!=b.get_pixel(x,y): count+=1
	return count

func run() -> void:
	create_timer(50).timeout.connect(func():push_error("Player animation timed out");quit(2))
	var directory:=ProjectSettings.globalize_path("res://tools/tests/output/player-animation-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	write_json(directory.path_join("town.json"),{"town_id":"player-animation"})
	var settings:=Settings.recommended_settings()
	check(settings.character_art=={"npc_type":"animated","player_type":"animated"},"Player is static by default")
	settings.character_art={"npc_type":"static","player_type":"static"}
	write_json(directory.path_join("game_settings.json"),settings)
	var old_hash:=FileAccess.get_sha256(directory.path_join("game_settings.json"))
	var loaded:=Settings.load_from_town(directory)
	check(loaded.ok and loaded.settings.character_art=={"npc_type":"animated","player_type":"animated"},"Legacy player setting freezes animation")
	check(FileAccess.get_sha256(directory.path_join("game_settings.json"))==old_hash,"Loading settings rewrites town")
	check(Settings.save_to_town(directory,settings).ok and Settings.load_from_town(directory).settings.character_art.player_type=="animated" and settings.character_art.player_type=="static","Player Save migration fails/mutates caller")
	settings.character_art.erase("player_type"); write_json(directory.path_join("game_settings.json"),settings)
	check(Settings.load_from_town(directory).settings.character_art.player_type=="animated","Missing player flag not migrated")
	var rig:=Library.for_actor("player")
	check(not rig.is_empty(),"Player walking parts missing")
	var viewport:=SubViewport.new(); viewport.size=Vector2i(260,260); viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport.world_2d=World2D.new(); root.add_child(viewport)
	var player:=Player.new(); viewport.add_child(player); player.set_physics_process(false)
	player.scale=Vector2.ONE*10
	var origin:=Vector2(130,195)
	check(player.art_type=="animated" and player.art_scale==1 and Actor.GROUND_CHARACTER_DRAW_SIZE==Vector2(7.5,13.75),"Player default/physical scale changed")
	var collision: CircleShape2D=player.get_child(0).shape
	check(collision.radius==4,"Player collision radius changed")
	# Old callers cannot silently freeze the walking renderer.
	player.art_type="static"
	for i in 4:
		var facing: Vector2=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][i]
		var view: String=["front","left","right","back"][i]
		player.position=origin; player.animation_time=0; player.interior_mode=i%2==1
		var before_position:=player.global_position
		player._move_on_foot(facing,.25/1.4)
		check(player.walking and player.global_position.distance_to(before_position)>0 and player.facing==facing and player.animation_time>0,"Player does not walk/advance animation in "+view)
		# Centre only the capture; animation time comes from actual movement.
		player.position=origin; player.queue_redraw(); await frames()
		var first: Image
		if OS.get_cmdline_user_args().has("--render"):
			await RenderingServer.frame_post_draw; first=viewport.get_texture().get_image()
		var first_pose:=RigArt.layout(rig,view,player.animation_time,player.walking)
		player._move_on_foot(facing,.5/1.4); player.position=origin; player.queue_redraw(); await frames()
		check(first_pose!=RigArt.layout(rig,view,player.animation_time,player.walking),"Player gait is frozen in "+view)
		if OS.get_cmdline_user_args().has("--render"):
			await RenderingServer.frame_post_draw
			check(different_pixels(first,viewport.get_texture().get_image())>40,"Actual player pixels do not animate in "+view)
			first.save_png(directory.path_join("walking_"+view+".png"))
		var walking_time:=player.animation_time
		player._move_on_foot(Vector2.ZERO,1.0/60); player.position=origin; await frames()
		check(not player.walking and player.animation_time==walking_time,"Idle player keeps walking")
		var rest: Image
		if OS.get_cmdline_user_args().has("--render"):
			await RenderingServer.frame_post_draw; rest=viewport.get_texture().get_image()
		player._move_on_foot(Vector2.ZERO,.2); player.queue_redraw(); await frames()
		if OS.get_cmdline_user_args().has("--render"):
			await RenderingServer.frame_post_draw
			check(different_pixels(rest,viewport.get_texture().get_image())==0,"Idle player changes animation")
	player.actor_motion=func(from: Vector2,_to: Vector2,_radius: float,_crossing):return from
	var blocked_time:=player.animation_time
	player._move_on_foot(Vector2.RIGHT,.2)
	check(not player.walking and player.animation_time==blocked_time,"Blocked player keeps walking")
	player.walking=true; player.controls_enabled=false; player._physics_process(.2)
	check(not player.walking and player.animation_time==blocked_time,"Conversation-paused player animates walking")
	player.controls_enabled=true; player.active=false; player.walking=true; player._physics_process(.2)
	check(not player.walking and player.animation_time==blocked_time,"Inactive/in-car player animates walking")
	player.active=true
	player.seated=true; player._move_on_foot(Vector2.DOWN,.2)
	check(player.animation_time==blocked_time and not player.walking,"Sitting player animates walking")
	var studio=load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=directory; studio._show_game_settings_page(); studio.settings_tools_navigation.open_page("characters"); await frames()
	check(studio._settings_from_controls().character_art.player_type=="animated","Editor Save restores static player")
	check(not static_player_control(studio),"Editor still offers static player")
	studio.free(); viewport.free()
	print("PLAYER ANIMATION FIXTURE: "+directory)
	print("PLAYER ANIMATION: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

func static_player_control(node: Node) -> bool:
	if node is OptionButton:
		for i in node.item_count:
			if node.get_item_text(i).contains("Static main character"): return true
	for child in node.get_children():
		if static_player_control(child): return true
	return false
