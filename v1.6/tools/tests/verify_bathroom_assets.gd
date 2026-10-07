extends SceneTree

const Store = preload("res://scripts/interiors/building_interior_store.gd")
const Furniture = preload("res://scripts/interiors/interior_furniture_catalog.gd")
const Materials = preload("res://scripts/interiors/interior_floor_material_catalog.gd")
const Layer = preload("res://scripts/interiors/runtime_interior_layer.gd")
const Canvas = preload("res://scripts/interiors/interior_floor_canvas.gd")
const Player = preload("res://scripts/runtime/runtime_player_character.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("BATHROOM TEST TIMED OUT"); quit(1))
	var store = Store.new()
	var data: Dictionary = store.empty_data()
	var floor := {"id":"ground_floor","name":"Ground floor","level":0,"layout_source":"creator_blank_from_osm_footprint","survey_status":"not_surveyed","width_metres":12.0,"height_metres":8.0,"grid_metres":1.0,"footprint_scale":1.0,"boundary_metres":[[0,0],[12,0],[12,8],[0,8]],"holes_metres":[],"walls":[],"rooms":[],"furniture":[],"entry_links":[],"flooring":{"cell_size_metres":0.5,"cells":{}}}
	data.buildings["bathroom"]={"feature_id":"bathroom","name":"Bathroom asset test","floors":[floor]}
	var ids := ["toilet_cubicle","toilet_cubicle_grey","wall_urinal","trough_urinal"]
	var points := [Vector2(3,2.5),Vector2(5,2.5),Vector2(8,2.5),Vector2(10,2.5)]
	for index in ids.size():
		var definition: Dictionary = Furniture.definition(ids[index])
		check(Furniture.usage_categories(definition).has("Bathroom") and Furniture.usage_categories(definition).has("Pub"),"Bathroom fixture missing categories.")
		check(Furniture.thumbnail_texture(definition)!=null,"Bathroom icon missing.")
		var placed: Dictionary = store.place_furniture(data,"bathroom","ground_floor",ids[index],points[index],90 if index==2 else 0)
		check(placed.ok,"Bathroom furniture placement failed.")
		if placed.ok: data=placed.data
	check(not store.place_furniture(data,"bathroom","ground_floor","wall_urinal",Vector2(3,2.5),0).ok,"Overlapping bathroom fixtures accepted.")
	var material_ids := ["floor_bathroom_ceramic","floor_bathroom_slate","floor_bathroom_checker"]
	for index in material_ids.size():
		var cells: Array = []
		for y in range(1,16):
			for x in range(index*8,index*8+8): cells.append(Vector2(x*0.5+0.25,y*0.5+0.25))
		var painted: Dictionary = store.paint_flooring(data,"bathroom","ground_floor",material_ids[index],cells,false)
		check(painted.ok,"Bathroom tiles were rejected by floor painter.")
		if painted.ok: data=painted.data
		check(Materials.thumbnail_texture(Materials.definition(material_ids[index]))!=null,"Tile thumbnail missing.")
	var temporary := ProjectSettings.globalize_path("res://tools/tests/output/bathroom-%s" % OS.get_process_id())
	check(store.save_to_town(temporary,data).ok and store.load_from_town(temporary).data.buildings.bathroom.floors[0].furniture.size()==4,"Bathroom floor save/reload failed.")
	var layer = Layer.new()
	root.add_child(layer)
	layer.set_town_directory(temporary)
	var record: Dictionary = data.buildings.bathroom
	floor=record.floors[0]
	check(layer.open_floor(record,floor,{"spawn_x_metres":6,"spawn_y_metres":6},8).ok,"Bathroom play floor failed to open.")
	var canvas = Canvas.new()
	root.add_child(canvas)
	canvas.set_asset_root(temporary)
	for item in floor.furniture:
		check(layer._texture_for_item(item)!=null and canvas._texture_for_item(item)!=null,"Bundled art missing in editor or runtime.")
		var contact := Vector2(item.x_metres,item.y_metres)
		if str(item.catalog_id).begins_with("toilet_cubicle"): contact.x-=float(item.width_metres)*0.48
		check(not layer.is_traversable(contact*8,2),"Bathroom collision missing.")
		check(layer.furniture_at_world(Vector2(item.x_metres,item.y_metres)*8).get("object_type","")==item.object_type,"Bathroom object identification lost its type.")
	check(layer.is_traversable(Vector2(6,6)*8,2),"Bathroom corridor is blocked.")
	check(layer.floor_material_textures.size()==6,"Built-in tile images did not load alongside floorboards.")
	check(Furniture.definition("wall_urinal").size_metres==[0.55,0.9] and Furniture.definition("trough_urinal").size_metres==[2.8,0.45],"Urinal length was not doubled.")
	for index in range(2):
		var item: Dictionary = floor.furniture[index]
		var centre := Vector2(item.x_metres,item.y_metres)
		for step in range(11):
			check(layer.is_traversable((centre+Vector2(0,2.1-step*0.12))*8,4),"Default player's actual 4-world-unit clearance cannot enter cubicle.")
		check(not layer.is_traversable((centre+Vector2(0,-0.4))*8,2),"Cubicle toilet is not solid.")
		var rotated: Dictionary = item.duplicate(true)
		rotated.rotation_degrees=90
		check(not Furniture.blocks_point(rotated,centre+Vector2(0,0.9).rotated(PI/2),0.5),"Rotated cubicle doorway blocked.")
		check(Furniture.blocks_point(rotated,centre+Vector2(-0.56,0.3).rotated(PI/2),0.25),"Rotated cubicle partition lost collision.")
	canvas.free()
	# Use the real movement function, not a manually positioned demonstration.
	var player = Player.new()
	player.controls_enabled=false
	root.add_child(player)
	player.set_physics_process(false)
	player.set_interior_mode(true)
	player.set_ground_check(layer.is_traversable)
	player.walk_speed=9.6
	player.position=(points[0]+Vector2(0,2.1))*8
	player.z_index=5
	var overlay: CanvasLayer
	var heading: Label
	var camera: Camera2D
	if OS.get_cmdline_user_args().has("--render"):
		root.size=Vector2i(1100,760)
		camera = Camera2D.new()
		root.add_child(camera)
		camera.position=Vector2(6,4)*8
		camera.zoom=Vector2.ONE*9
		overlay = CanvasLayer.new()
		root.add_child(overlay)
		heading = Label.new()
		heading.position=Vector2(30,18)
		heading.add_theme_font_size_override("font_size",24)
		heading.text="BEFORE WALKING IN · revised bathroom assets\nLarger cubicles: 1.8 × 2.8 m · open doorway: approximately 1.14 m"
		overlay.add_child(heading)
		var note := Label.new()
		note.position=Vector2(30,688)
		note.text="Production movement + collision test · no manual placement inside\nLonger urinals: wall 0.9 m / trough 2.8 m · static open cubicle doors"
		note.add_theme_font_size_override("font_size",18)
		overlay.add_child(note)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/bathroom_cubicle_outside_revision2.png"))==OK,"Before-entry picture could not be saved.")
	for step in 60:
		await physics_frame
		player._move_on_foot(Vector2.UP,1.0/60.0)
	check(player.position.distance_to((points[0]+Vector2(0,0.9))*8)<0.8,"Actual player movement failed to enter the cubicle.")
	check(layer.is_traversable(player.position,4*player.art_scale),"Entered player is touching a solid cubicle part.")
	var entered: Vector2 = player.position
	for step in 50:
		await physics_frame
		player._move_on_foot(Vector2.UP,1.0/60.0)
	check(player.position.y>=points[0].y*8+0.7*8,"Player walked through the toilet.")
	player._move_on_foot(Vector2.ZERO,1.0/60.0)
	if OS.get_cmdline_user_args().has("--render"):
		heading.text="AFTER WALKING IN · actual player movement verified\nThe character walked through the opening; the toilet stops further movement"
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/bathroom_cubicle_inside_revision2.png"))==OK,"After-entry picture could not be saved.")
		for node in [camera,overlay]: node.free()
	# Reversing the walking direction leaves through the same clear opening.
	for step in 80:
		await physics_frame
		player._move_on_foot(Vector2.DOWN,1.0/60.0)
	check(player.position.y>entered.y+8,"Player cannot walk out of the cubicle.")
	player.free()
	layer.free()
	print("BATHROOM ASSETS: %d checks, %d failures." % [checks,failures])
	quit(1 if failures else 0)
