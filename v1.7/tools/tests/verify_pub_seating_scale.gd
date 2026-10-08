extends SceneTree

const Layer=preload("res://scripts/interiors/runtime_interior_layer.gd")
const Seating=preload("res://scripts/interiors/interior_seating.gd")
const Player=preload("res://scripts/runtime/runtime_player_character.gd")
const PoseArt=preload("res://scripts/npcs/creation/npc_pose_art.gd")
const Art=preload("res://scripts/runtime/runtime_actor_art.gd")
const Population=preload("res://scripts/runtime/runtime_population.gd")
class Harness:
	extends "res://scripts/runtime/town_runtime.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func frames() -> void:
	for _i in 5: await process_frame
func key(runtime) -> void:
	var event:=InputEventKey.new(); event.keycode=KEY_E; event.pressed=true; runtime._unhandled_input(event)
func run() -> void:
	var town:=ProjectSettings.globalize_path("res://../Test Maps/albury/albury")
	var file:=town.path_join("data/building_interiors.json"); var original:=FileAccess.get_sha256(file)
	var content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
	var floor_value: Dictionary=content.buildings["601183200"].floors[0]
	root.size=Vector2i(1100,760); root.content_scale_size=root.size
	var runtime:=Harness.new(); root.add_child(runtime)
	runtime.inside_building_id="601183200"; runtime.inside_floor_id=str(floor_value.id)
	runtime.interior_layer=Layer.new(); runtime.add_child(runtime.interior_layer)
	var layer=runtime.interior_layer; layer.floor_data=floor_value; layer.pixels_per_metre=8.0; layer.set_town_directory(town); layer.visible=true
	runtime.player=Player.new(); runtime.add_child(runtime.player); runtime.player.set_physics_process(false); runtime.player.z_index=3
	runtime.population=Population.new(); runtime.add_child(runtime.population); runtime.population.set_process(false)
	var comparison:=Player.new(); runtime.add_child(comparison); comparison.set_physics_process(false); comparison.z_index=3
	var camera:=Camera2D.new(); runtime.add_child(camera); camera.zoom=Vector2.ONE*7
	var supported:=0; var stools:=0; var blocked:=0
	for item in floor_value.furniture:
		if not Seating.Orientation.supported(item): continue
		var point: Vector2=Seating.Orientation.position(item)*8
		var found:=Vector2.INF
		for radius in [.65,.85,1.0,1.25,1.35]:
			for step in 64:
				var candidate: Vector2=point+Vector2.DOWN.rotated(TAU*step/64)*float(radius)*8
				if not layer.is_traversable(candidate,4): continue
				var reached:=Seating.nearest(layer,candidate,4)
				if not reached.is_empty() and reached.id==item.id: found=candidate; break
			if found!=Vector2.INF: break
		if found==Vector2.INF:
			var boundary_clear:=true
			for offset in [Vector2.ZERO,Vector2(4,0),Vector2(-4,0),Vector2(0,4),Vector2(0,-4)]:
				if not layer._inside_floor(point+offset): boundary_clear=false
			blocked+=1; print("Existing seat has no verified full-radius approach: ",item.id," (", "saved obstacles/approach" if boundary_clear else "floor boundary clearance", ")"); continue
		check(true,"Saved Pub approach checked")
		runtime.player.position=found; key(runtime)
		check(runtime.player.seated and runtime.seated_item.id==item.id,"E failed at saved Pub seat "+str(item.id))
		supported+=1
		if item.catalog_id=="bar_stool": stools+=1
		if OS.get_cmdline_user_args().has("--render") and item.id in ["furniture_18","furniture_41"]:
			for step in 32:
				var candidate:=point+Vector2.LEFT.rotated(TAU*step/32)*16
				if layer.is_traversable(candidate,4): comparison.position=candidate; break
			comparison.facing=runtime.player.facing
			comparison.queue_redraw()
			camera.position=point+Vector2(0,-3)
			await frames(); await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/pub_seating_%s_scale_revision2.png" % ["stool" if item.catalog_id=="bar_stool" else "chair"]))
		key(runtime); check(not runtime.player.seated and layer.is_traversable(runtime.player.position,4),"Cannot stand at saved Pub seat "+str(item.id))
	var standing:=PoseArt.artwork({"npc_asset":"player"},{},"",Vector2.RIGHT,"idle",0)
	var sitting:=PoseArt.artwork({"npc_asset":"player"},{},"",Vector2.RIGHT,"sit",0)
	check(sitting.rig.seated,"Seated player does not use the new cutout style")
	check(is_equal_approx(sitting.rig.standing_scale,preload("res://scripts/npcs/rigging/npc_rig_art.gd").rest_scale(standing.rig,"front")),"Seated player body shrank relative to standing")
	check(original==FileAccess.get_sha256(file),"Saved pub changed during read-only check")
	print("PUB SEATING SCALE: %d checks, %d failures; %d accessible existing seats including %d bar stools; %d blocked by saved geometry" % [checks,failures,supported,stools,blocked])
	runtime.free(); quit(1 if failures else 0)
