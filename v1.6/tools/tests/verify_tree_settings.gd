extends SceneTree

const Store = preload("res://scripts/environment/tree_settings_store.gd")
const Importer = preload("res://scripts/towns/osm_importer.gd")
const Builder = preload("res://scripts/collisions/building_collision_builder.gd")
const Renderer = preload("res://scripts/runtime/runtime_world_renderer.gd")

func _initialize() -> void:
	call_deferred("_run")

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(text)
	file.close()

func _run() -> void:
	create_timer(40).timeout.connect(func(): push_error("TREE SETTINGS TIMED OUT"); quit(1))
	var directory := ProjectSettings.globalize_path("res://tools/tests/output/tree-settings-%s" % OS.get_process_id())
	assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
	_write(directory.path_join("town.json"),"{}")
	var store := Store.new()
	assert(store.load_from_town(directory).data.tree_style=="mapped")
	var data := Store.defaults()
	data.tree_style="eucalypt"
	assert(store.save(directory,data).ok and store.load_from_town(directory).data.tree_style=="eucalypt")
	var fixture := Importer.new().parse_files(["res://tools/tests/fixtures/environment_detail.osm"])
	var collisions := Builder.new().build(fixture.features,fixture.bounds)
	var world := Renderer.new()
	root.add_child(world)
	world.setup(fixture.features,collisions.data,fixture.bounds,{},directory)
	world.draw_view_bounds=world.world_bounds
	world.environment_visuals.refresh()
	var ids: Array = world.environment_visuals.trees.visible_trees.map(func(tree): return tree.id)
	assert(world.environment_visuals.trees.selected_style=="eucalypt")
	var picture: Image = load("res://assets/environment/trees/eucalypt.svg").get_image()
	var source := directory.path_join("custom.png")
	assert(picture.save_png(source)==OK)
	var digest := FileAccess.get_sha256(source)
	assert(store.import_image(directory,source,"My gum tree").ok)
	data=store.load_from_town(directory).data
	assert(data.tree_style=="custom_"+digest and FileAccess.get_sha256(source)==digest)
	assert(store.selected_texture(directory,data)!=null)
	world.queue_free()
	await process_frame
	world=Renderer.new()
	root.add_child(world)
	world.setup(fixture.features,collisions.data,fixture.bounds,{},directory)
	world.draw_view_bounds=world.world_bounds
	world.environment_visuals.refresh()
	assert(world.environment_visuals.trees.custom_texture!=null)
	assert(ids==world.environment_visuals.trees.visible_trees.map(func(tree): return tree.id),"Artwork changes must not move trees.")
	var metadata := FileAccess.get_file_as_string(directory.path_join(Store.FILE_NAME))
	var blank := Image.create(32,32,false,Image.FORMAT_RGBA8)
	blank.fill(Color.TRANSPARENT)
	assert(blank.save_png(directory.path_join("empty.png"))==OK)
	assert(not store.import_image(directory,directory.path_join("empty.png"),"").ok)
	blank.fill(Color.GREEN)
	assert(blank.save_png(directory.path_join("opaque.png"))==OK)
	assert(not store.import_image(directory,directory.path_join("opaque.png"),"").ok)
	assert(FileAccess.get_file_as_string(directory.path_join(Store.FILE_NAME))==metadata)
	var unsafe := data.duplicate(true)
	unsafe.custom_trees[0].relative_path="../outside.png"
	assert(not Store.valid(unsafe) and not store.save(directory,unsafe).ok)
	assert(FileAccess.get_file_as_string(directory.path_join(Store.FILE_NAME))==metadata)
	assert(store.import_image(directory,source,"Same artwork").ok)
	assert(store.load_from_town(directory).data.custom_trees.size()==1)
	# Missing/changed copies fall back safely without overwriting the metadata.
	var copy: String = directory.path_join(data.custom_trees[0].relative_path)
	_write(copy,"damaged")
	assert(store.selected_texture(directory,data)==null)
	assert(store.import_image(directory,source,"My gum tree").ok)
	world.queue_free()
	var studio = load("res://scenes/creator_studio.tscn").instantiate()
	root.add_child(studio)
	studio.loaded_project_directory=directory
	studio.imported_town=fixture
	studio.current_town_name="Tree settings test"
	studio._show_advanced_map_editor_page()
	studio.editor_tools_navigation.open_page("trees")
	var editor = studio.tree_settings_editor
	assert(editor.style_option.item_count==5 and editor.preview.texture!=null)
	editor._select_style(2)
	assert(store.load_from_town(directory).data.tree_style=="eucalypt")
	studio.editor_tools_navigation.show_home()
	studio.editor_tools_navigation.open_page("trees")
	assert(editor.data.tree_style=="eucalypt")
	if OS.get_cmdline_user_args().has("--render"):
		# Show the actual Albury settings, read-only, after fixture editing checks.
		studio._load_existing_project(ProjectSettings.globalize_path("res://../Test Maps/albury/albury"))
		studio._show_advanced_map_editor_page()
		studio.editor_tools_navigation.open_page("trees")
		assert(studio.tree_settings_editor.data.tree_style=="eucalypt")
		# Acknowledge the existing stable-ID map-change notice before the capture.
		studio.message_dialog.hide()
		root.size=Vector2i(1280,900)
		root.content_scale_size=Vector2i(1280,900)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/screenshots/environment_tree_settings.png")==OK)
	print("TREE SETTINGS PASSED: built-in gum selection, safe copied PNG import, dedup, transparent/opaque/path rejection, custom runtime artwork without position changes, changed-copy fallback, saved Creator preview and Back persistence.")
	quit()
