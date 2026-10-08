extends SceneTree

## Disposable metadata-only Undo checks. Never opens or edits a user town.
const Trees = preload("res://scripts/environment/tree_settings_editor.gd")
const TreeStore = preload("res://scripts/environment/tree_settings_store.gd")
const Lore = preload("res://scripts/npcs/lore/game_lore_editor.gd")
const LoreStore = preload("res://scripts/npcs/lore/game_lore_store.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAILED: " + message)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()

func _metadata(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _run() -> void:
	create_timer(45).timeout.connect(func(): printerr("COMPONENT EDIT HISTORY TIMED OUT"); quit(1))
	var fixture := ProjectSettings.globalize_path("res://tools/tests/output/component-history-%s" % OS.get_process_id())
	var other := fixture.path_join("another-town")
	assert(DirAccess.make_dir_recursive_absolute(other) == OK)
	_write(fixture.path_join("town.json"), "{}")
	_write(other.path_join("town.json"), "{}")
	var tree_metadata := fixture.path_join(TreeStore.FILE_NAME)
	var tree_store := TreeStore.new()
	var tree := Trees.new()
	root.add_child(tree)
	_check(tree.snapshot_state().is_empty(), "Unconfigured tree state must not enter history")
	tree.configure(fixture)
	var original_tree := tree.snapshot_state()
	_check(not original_tree.is_empty() and original_tree.data == JSON.parse_string(JSON.stringify(TreeStore.defaults())), "Default tree snapshot")
	var unopened_tree := Trees.new()
	unopened_tree.configure(fixture)
	_check(unopened_tree.snapshot_state().is_empty() and not unopened_tree.restore_state(original_tree).ok, "Unopened tree component cannot restore metadata")
	unopened_tree.free()
	var tree_edits := [0]
	tree.edited.connect(func(): tree_edits[0] += 1)
	for index in tree.style_option.item_count:
		if tree.style_option.get_item_metadata(index) == "eucalypt": tree._select_style(index); break
	_check(tree_edits[0] == 1 and tree_store.load_from_town(fixture).data.tree_style == "eucalypt", "Tree selection signals a saved edit")
	_check(tree.restore_state(original_tree).ok, "Undo tree style")
	_check(tree_store.load_from_town(fixture).data == original_tree.data and tree.data == original_tree.data, "Tree Undo persists and refreshes")
	_check(tree_edits[0] == 1, "Tree restoration must not create another history entry")
	for index in tree.style_option.item_count:
		if tree.style_option.get_item_metadata(index) == "mapped": tree._select_style(index); break
	_check(tree_edits[0] == 1, "Unchanged tree selection does not signal an edit")
	tree.show_tool("style")
	_check(tree.style_group.visible and not tree.upload_group.visible, "Separate tree style page")
	tree.show_tool("upload")
	_check(not tree.style_group.visible and tree.upload_group.visible, "Separate tree upload page")
	tree.show_tool("all")
	_check(tree.style_group.visible and tree.upload_group.visible, "Legacy combined tree view")
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(4, 12):
		for y in range(2, 14): image.set_pixel(x, y, Color("60a46e"))
	var source := fixture.path_join("test-tree.png")
	assert(image.save_png(source) == OK)
	var original_source_hash := FileAccess.get_sha256(source)
	tree.name_edit.text = "Undo fixture tree"
	tree.import_image(source)
	var custom_tree := tree.snapshot_state()
	_check(tree_edits[0] == 2 and custom_tree.data.custom_trees.size() == 1, "Tree upload metadata enters history")
	var tree_copy: String = fixture.path_join(custom_tree.data.custom_trees[0].relative_path)
	_check(tree.restore_state(original_tree).ok, "Undo uploaded tree selection/catalogue")
	_check(FileAccess.file_exists(tree_copy) and FileAccess.get_sha256(tree_copy) == original_source_hash, "Undo keeps copied tree artwork")
	_check(FileAccess.get_sha256(source) == original_source_hash, "Undo keeps original artwork")
	_check(tree.restore_state(custom_tree).ok and tree.preview.texture != null, "Restored custom tree resolves retained copy")
	var tree_before_reject := _metadata(tree_metadata)
	_check(not tree.restore_state({"directory": other, "data": original_tree.data}).ok, "Tree cross-town snapshot rejected")
	_check(not tree.restore_state({"directory": fixture, "data": {"kind": "bad"}}).ok, "Invalid tree metadata rejected")
	_check(_metadata(tree_metadata) == tree_before_reject, "Rejected tree restores preserve current metadata")
	_check(tree.restore_state(original_tree).ok, "Return to built-in tree before altered-copy check")
	_write(tree_copy, "Altered disposable image copy")
	tree_before_reject = _metadata(tree_metadata)
	_check(not tree.restore_state(custom_tree).ok and _metadata(tree_metadata) == tree_before_reject, "Changed custom copy cannot become active through Undo")
	tree.configure(fixture.path_join("missing"))
	_check(tree.snapshot_state().is_empty() and not tree.restore_state(original_tree).ok, "Missing tree town has no usable history")
	tree.configure(fixture)
	var invalid_tree := '{"schema_version":1,"kind":"environment_settings","custom_trees":[],"tree_style":"bad"}'
	_write(tree_metadata, invalid_tree)
	tree.configure(fixture)
	_check(tree.snapshot_state().is_empty(), "Malformed tree metadata has no history snapshot")
	_check(not tree.restore_state(original_tree).ok and _metadata(tree_metadata) == invalid_tree, "Tree Undo preserves externally malformed metadata")

	var lore := Lore.new()
	root.add_child(lore)
	_check(lore.snapshot_state().is_empty(), "Unconfigured lore state must not enter history")
	lore.configure(fixture)
	var original_lore := lore.snapshot_state()
	_check(not original_lore.is_empty() and original_lore.data.lore.is_empty(), "Empty lore snapshot")
	var unopened_lore := Lore.new()
	unopened_lore.configure(fixture)
	_check(unopened_lore.snapshot_state().is_empty() and not unopened_lore.restore_state(original_lore).ok, "Unopened lore component cannot restore metadata")
	unopened_lore.free()
	var lore_edits := [0]
	lore.edited.connect(func(): lore_edits[0] += 1)
	var source_lore_a := fixture.path_join("lore-a.txt")
	var source_lore_b := fixture.path_join("lore-b.txt")
	_write(source_lore_a, "Robots offer counselling and never harm humans.")
	_write(source_lore_b, "A second fictional background for this test.")
	var lore_source_hash := FileAccess.get_sha256(source_lore_a)
	lore.import_file(source_lore_a)
	var saved_lore := lore.snapshot_state()
	var lore_copy: String = fixture.path_join(saved_lore.data.lore.relative_path)
	var lore_store := LoreStore.new()
	_check(lore_edits[0] == 1 and lore.preview.text.contains("counselling"), "Lore import signals a saved edit")
	lore.import_file(source_lore_b)
	var second_copy: String = fixture.path_join(lore.data.lore.relative_path)
	_check(lore_edits[0] == 2 and lore.preview.text.contains("second"), "Lore replacement signals a saved edit")
	_check(lore.restore_state(saved_lore).ok and lore.preview.text.contains("counselling"), "Undo lore replacement refreshes full text")
	_check(lore_store.load_from_town(fixture).data == saved_lore.data and lore_edits[0] == 2, "Lore restoration persists without a duplicate edited signal")
	_check(FileAccess.file_exists(second_copy) and FileAccess.file_exists(lore_copy), "Lore Undo keeps both content-addressed copies")
	lore._remove()
	_check(lore_edits[0] == 3 and lore_store.load_from_town(fixture).text.is_empty(), "Lore removal signals a saved edit")
	_check(lore.restore_state(saved_lore).ok and lore_store.load_from_town(fixture).text.contains("counselling"), "Undo lore removal persists for reopen")
	_check(FileAccess.get_sha256(source_lore_a) == lore_source_hash, "Lore original source unchanged")
	_check(lore.restore_state(original_lore).ok and lore.preview.text.is_empty(), "Undo lore import returns to optional empty state")
	lore._remove()
	_check(lore_edits[0] == 3, "Removing already-empty lore does not signal an edit")
	_check(FileAccess.file_exists(lore_copy) and FileAccess.file_exists(second_copy), "Empty lore restore never deletes copies")
	var lore_metadata := fixture.path_join(LoreStore.FILE_NAME)
	var lore_before_reject := _metadata(lore_metadata)
	_check(not lore.restore_state({"directory": other, "data": saved_lore.data}).ok, "Lore cross-town snapshot rejected")
	_check(not lore.restore_state({"directory": fixture, "data": {"schema_version": 1, "lore": {"relative_path": "../unsafe.txt"}}}).ok, "Unsafe lore metadata rejected")
	_check(_metadata(lore_metadata) == lore_before_reject, "Rejected lore restores preserve metadata")
	_write(lore_copy, "Altered disposable lore copy.")
	_check(not lore.restore_state(saved_lore).ok and _metadata(lore_metadata) == lore_before_reject, "Changed copied lore cannot be activated by Undo")
	lore.configure(fixture.path_join("missing"))
	_check(lore.snapshot_state().is_empty() and not lore.restore_state(saved_lore).ok, "Missing lore town has no usable history")
	var invalid_lore := '{"schema_version":1,"lore":{"relative_path":"../bad"}}'
	_write(lore_metadata, invalid_lore)
	lore.configure(fixture)
	_check(lore.snapshot_state().is_empty(), "Malformed lore metadata has no history snapshot")
	_check(not lore.restore_state(original_lore).ok and _metadata(lore_metadata) == invalid_lore, "Lore Undo preserves externally malformed metadata")
	tree.queue_free()
	lore.queue_free()
	await process_frame
	print("COMPONENT EDIT HISTORY: %d checks, %d failures; disposable fixture %s" % [checks, failures, fixture])
	quit(0 if failures == 0 else 1)
