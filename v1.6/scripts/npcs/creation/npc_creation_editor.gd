extends VBoxContainer

signal changed
const Store = preload("res://scripts/npcs/creation/npc_creation_store.gd")
const Picker = preload("res://scripts/npcs/creation/npc_appearance_picker.gd")
const Preview = preload("res://scripts/npcs/creation/npc_pose_preview.gd")
const Rig = preload("res://scripts/npcs/rigging/npc_rig_data.gd")
const RigEditor = preload("res://scripts/npcs/rigging/npc_rig_editor.gd")
var frame_workspace: VBoxContainer
var rig_editor
var rig_workspace: VBoxContainer
var rig_button: Button
var frames_button: Button
var test_button: Button
var directory := ""
var data: Dictionary = Store.empty_data()
var selected_id := ""
var list: OptionButton
var name_edit: LineEdit
var attributes
var pose: OptionButton
var direction: OptionButton
var seat_anchor: SpinBox
var status: Label
var preview
var dialog: FileDialog
var loading := false
var remove_button: Button
var creation_in_use: Callable

func setup(town_directory: String, catalog: Dictionary) -> void:
	directory=town_directory; data=catalog.duplicate(true)
	var help := Label.new(); help.text="Animated NPCs use walking motion at the current character scale. Inspect all 18 human identities, create editable body parts, or upload your own walking frames."; help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(help)
	var row := HBoxContainer.new(); add_child(row)
	list=OptionButton.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(list); list.item_selected.connect(_select)
	var button := Button.new(); button.text="New frame animation"; button.custom_minimum_size=Vector2(170,40); row.add_child(button); button.pressed.connect(_new)
	remove_button=Button.new(); remove_button.text="Delete item"; row.add_child(remove_button); remove_button.pressed.connect(_remove_creation)
	var new_rig:=Button.new(); new_rig.text="New Animated NPC"; row.add_child(new_rig); new_rig.pressed.connect(_new_rig)
	name_edit=LineEdit.new(); name_edit.placeholder_text="Creation name"; name_edit.max_length=80; add_child(name_edit)
	attributes=Picker.new(); add_child(attributes); attributes.source.hide()
	attributes.preview.hide(); attributes.template_choice.hide()
	name_edit.text_changed.connect(func(_s): _flush())
	for option in [attributes.gender,attributes.age,attributes.tone]: option.item_selected.connect(func(_i): _flush())
	var modes:=HBoxContainer.new(); add_child(modes)
	frames_button=Button.new(); frames_button.text="Sprite frames"; modes.add_child(frames_button); frames_button.pressed.connect(_set_rig_mode.bind(false))
	rig_button=Button.new(); rig_button.text="Body parts"; modes.add_child(rig_button); rig_button.pressed.connect(_set_rig_mode.bind(true))
	test_button=Button.new(); test_button.text="Test walking"; modes.add_child(test_button); test_button.pressed.connect(_test_walking)
	frame_workspace=VBoxContainer.new(); add_child(frame_workspace)
	var views := HBoxContainer.new(); frame_workspace.add_child(views)
	pose=OptionButton.new(); views.add_child(pose)
	for p in Store.POSES: pose.add_item({"idle":"Standing","walk":"Walking frames","sit":"Sitting on a seat"}[p]); pose.set_item_metadata(pose.item_count-1,p)
	direction=OptionButton.new(); views.add_child(direction)
	for d in Store.DIRECTIONS: direction.add_item(d.capitalize()); direction.set_item_metadata(direction.item_count-1,d)
	pose.item_selected.connect(func(_i): _refresh_preview()); direction.item_selected.connect(func(_i): _refresh_preview())
	button=Button.new(); button.text="Upload images…"; button.custom_minimum_size=Vector2(150,36); views.add_child(button); button.pressed.connect(_upload)
	button=Button.new(); button.text="Clear these frames"; button.custom_minimum_size=Vector2(170,36); views.add_child(button); button.pressed.connect(_clear_frames)
	var anchor_row := HBoxContainer.new(); frame_workspace.add_child(anchor_row)
	var anchor_label := Label.new(); anchor_label.text="Sitting hip anchor (% from top)"; anchor_row.add_child(anchor_label)
	seat_anchor=SpinBox.new(); seat_anchor.min_value=35; seat_anchor.max_value=75; seat_anchor.step=1; seat_anchor.value=58; anchor_row.add_child(seat_anchor); seat_anchor.value_changed.connect(func(_v): _flush())
	preview=Preview.new(); preview.custom_minimum_size=Vector2(300,260); frame_workspace.add_child(preview)
	rig_workspace=VBoxContainer.new(); add_child(rig_workspace)
	rig_editor=RigEditor.new(); rig_workspace.add_child(rig_editor)
	rig_editor.changed.connect(_rig_changed)
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	dialog=FileDialog.new(); dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILES; dialog.filters=PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg ; NPC images"]); add_child(dialog); dialog.files_selected.connect(_import)
	_refresh_list(); _select(list.selected)

func _refresh_list() -> void:
	list.clear()
	for item in Store.built_ins()+Store.choices(data):
		list.add_item(item.name); list.set_item_metadata(list.item_count-1,item.id)
		if str(item.id)==selected_id: list.select(list.item_count-1)

func _item() -> Dictionary:
	for item in Store.built_ins()+Store.choices(data):
		if str(item.id)==selected_id: return item
	return {}

func _select(index: int) -> void:
	loading=true
	selected_id=str(list.get_item_metadata(index))
	var item := _item(); name_edit.text=str(item.name)
	var editable := not selected_id.begins_with("npc_")
	name_edit.editable=editable
	remove_button.disabled=not editable or selected_id=="morpheus"
	attributes.set_appearance(Store.appearance(item,false))
	for option in [attributes.gender,attributes.age,attributes.tone]: option.disabled=not editable
	seat_anchor.value=float(item.get("seat_anchor_y",.58))*100; seat_anchor.editable=editable
	loading=false; _refresh_preview()
	_sync_mode()

func _new() -> void:
	if data.creations.size()>=100: status.text="Use at most 100 custom creations."; return
	selected_id="custom_"+str(Time.get_ticks_usec())
	data.creations.append({"id":selected_id,"name":"New character","gender":"man","age_group":"adult","skin_tone_group":"medium","seat_anchor_y":.58,"poses":{}})
	_refresh_list(); _select(list.selected); changed.emit()

func _new_rig() -> void:
	if data.creations.size()>=100: status.text="Use at most 100 custom creations."; return
	var id: String="cutout_"+str(Time.get_ticks_usec())
	var template:=_item()
	if not str(template.get("id","")).begins_with("npc_"): template=Store.built_ins()[0]
	var result:=preload("res://scripts/npcs/rigging/npc_animated_library.gd").install(directory,id,str(template.id))
	if not result.ok: status.text=result.message; return
	selected_id=id
	data.creations.append({"id":id,"name":"Animated "+str(template.name),"gender":template.gender,"age_group":template.age_group,"skin_tone_group":template.skin_tone_group,"seat_anchor_y":.58,"poses":{},"rig":result.rig})
	_refresh_list(); _select(list.selected); changed.emit()
	status.text="Ready to test: four views with ten separate pieces each. Replace parts, drag joints or press Test walking. Top Save keeps the character."

func _set_rig_mode(enabled: bool) -> void:
	if selected_id.begins_with("npc_"): return
	_flush()
	if selected_id=="morpheus" and not data.creations.any(func(item):return str(item.id)==selected_id): data.creations.append(Store.morpheus())
	for item in data.creations:
		if str(item.id)!=selected_id: continue
		if not item.has("rig"): item.rig=Rig.new_rig()
		item.rig.enabled=enabled
	_sync_mode(); changed.emit()

func _sync_mode() -> void:
	var item:=_item()
	var enabled: bool=bool(item.get("rig",{}).get("enabled",false))
	frame_workspace.visible=not enabled; rig_workspace.visible=enabled
	rig_button.disabled=selected_id.begins_with("npc_"); test_button.visible=true
	frames_button.disabled=not enabled
	if enabled: rig_editor.setup(item.rig,directory,selected_id)

func _rig_changed(value: Dictionary) -> void:
	for item in data.creations:
		if str(item.id)==selected_id: item.rig=value.duplicate(true)
	changed.emit()

func _test_walking() -> void:
	_flush()
	var item:=_item()
	if selected_id.begins_with("npc_"):
		var native_test=preload("res://scripts/npcs/rigging/npc_rig_test.gd").new(); add_child(native_test); native_test.setup(item,directory); native_test.popup_centered(); return
	var checked:=Rig.validate(item.get("rig",{}))
	if not bool(item.get("rig",{}).get("enabled",false)):
		checked=Store.validate(data,directory)
		if not checked.ok: status.text=checked.message; return
		var frames_test=preload("res://scripts/npcs/rigging/npc_rig_test.gd").new(); add_child(frames_test); frames_test.setup(item,directory); frames_test.popup_centered(); return
	if not checked.ok: status.text=checked.message; return
	for view in item.rig.views.values():
		for part in view.parts.values():
			if not part.image.is_empty() and not preload("res://scripts/npcs/rigging/npc_rig_import.gd").image_valid(directory.path_join(part.image),part.get("region",[])):
				status.text="Missing/invalid body-part image: "+part.image; return
	var test=preload("res://scripts/npcs/rigging/npc_rig_test.gd").new()
	add_child(test); test.setup(item,directory); test.popup_centered()

func _remove_creation() -> void:
	if selected_id.begins_with("npc_") or selected_id=="morpheus": return
	if creation_in_use.is_valid() and bool(creation_in_use.call(selected_id)):
		status.text="This artwork is assigned to a placed NPC. Change that NPC's artwork first."; return
	data.creations=data.creations.filter(func(item): return str(item.id)!=selected_id)
	selected_id=""; _refresh_list(); _select(0); changed.emit()

func _flush() -> void:
	if loading or selected_id.begins_with("npc_"): return
	var previous := data.duplicate(true)
	var values := {"name":name_edit.text.strip_edges(),"gender":attributes.gender.get_item_metadata(attributes.gender.selected),"age_group":attributes.age.get_item_metadata(attributes.age.selected),"skin_tone_group":attributes.tone.get_item_metadata(attributes.tone.selected),"seat_anchor_y":seat_anchor.value/100}
	var existing := _item()
	if values.keys().all(func(key): return existing.get(key)==values[key]): return
	if selected_id=="morpheus" and not data.creations.any(func(item): return str(item.id)==selected_id): data.creations.append(Store.morpheus())
	for item in data.creations:
		if str(item.id)!=selected_id: continue
		item.name=name_edit.text.strip_edges()
		item.gender=attributes.gender.get_item_metadata(attributes.gender.selected)
		item.age_group=attributes.age.get_item_metadata(attributes.age.selected)
		item.skin_tone_group=attributes.tone.get_item_metadata(attributes.tone.selected)
		item.seat_anchor_y=seat_anchor.value/100
	for i in list.item_count:
		if str(list.get_item_metadata(i))==selected_id: list.set_item_text(i,name_edit.text.strip_edges())
	_refresh_preview()
	if data!=previous: changed.emit()

func _refresh_preview() -> void:
	if preview==null: return
	var item := _item()
	preview.directory=directory; preview.catalog=data
	preview.appearance=Store.appearance(item,not selected_id.begins_with("npc_"))
	preview.appearance.animation_type="animated"
	preview.pose=str(pose.get_item_metadata(pose.selected)); preview.facing=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][direction.selected]
	if selected_id.begins_with("npc_"): preview.pose="walk"
	preview.queue_redraw()
	if bool(item.get("rig",{}).get("enabled",false)):
		status.text="Body-parts character · Test walking opens a safe practice scene with the normal player. Top Save keeps changes. Sitting uses separate uploaded seated frames; the walking skeleton does not generate a seated pose."
		return
	var frames: Array = item.get("poses",{}).get(preview.pose,{}).get(Store.DIRECTIONS[direction.selected],[])
	if selected_id.begins_with("npc_"):
		status.text="Animated NPC · "+item.name+" · separate illustrated body parts. Choose this artwork when placing a generic, storyline or trader NPC."; return
	status.text="%s · %s · %s · %d uploaded frames in this slot. Missing views use a standing fallback.\nUpload 1–8 individual transparent images per slot; filename order is animation order. Top Save keeps all changes. Sitting preview uses the game's actual dining chair at 8 px/m." % [Store.AGES[item.age_group],str(item.skin_tone_group).capitalize(),str(item.gender).capitalize(),frames.size()]

func _upload() -> void:
	if selected_id.begins_with("npc_"): status.text="Built-ins are read-only. Choose New frame animation or New Animated NPC to customise artwork."; return
	_flush()
	dialog.popup_centered_ratio(.75)

func _import(paths: PackedStringArray) -> void:
	if selected_id=="morpheus" and not data.creations.any(func(item): return str(item.id)==selected_id): data.creations.append(Store.morpheus())
	var result := Store.import_frames(directory,data,selected_id,str(pose.get_item_metadata(pose.selected)),str(direction.get_item_metadata(direction.selected)),paths)
	if not result.ok: status.text=result.message; return
	data=result.data; _refresh_preview(); status.text=result.message; changed.emit()

func _clear_frames() -> void:
	for item in data.creations:
		if str(item.id)!=selected_id: continue
		var p := str(pose.get_item_metadata(pose.selected))
		if item.poses.has(p): item.poses[p].erase(str(direction.get_item_metadata(direction.selected)))
	_refresh_preview(); changed.emit()

func snapshot_state() -> Dictionary:
	return {"data":data.duplicate(true),"id":selected_id}

func restore_state(value: Dictionary) -> void:
	data=value.data.duplicate(true); selected_id=str(value.id); _refresh_list(); _select(list.selected)
	_refresh_preview(); _sync_mode()
