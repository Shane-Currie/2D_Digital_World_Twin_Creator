extends VBoxContainer

signal changed(rig: Dictionary)
const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")
const Importer=preload("res://scripts/npcs/rigging/npc_rig_import.gd")
const Canvas=preload("res://scripts/npcs/rigging/npc_rig_canvas.gd")
var rig: Dictionary=Rig.new_rig()
var directory: String=""
var creation_id: String=""
var view_choice: OptionButton
var part_choice: OptionButton
var canvas
var summary: Label
var status: Label
var controls: Dictionary={}
var playing: CheckBox
var joints: CheckBox
var mirror: CheckBox
var dialog: FileDialog
var import_context: Dictionary={}
var busy:=false

func _ready() -> void:
	add_theme_constant_override("separation",8)
	var help:=Label.new(); help.text="1. Choose a view. 2. Upload separate pieces (or replace the starter). 3. Drag joints to align, then Preview walking. Left/right refer to the character's limbs. Forearms include hands; shins include feet."; help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(help)
	var row:=HBoxContainer.new(); add_child(row)
	view_choice=OptionButton.new(); row.add_child(view_choice)
	for view in Rig.VIEWS: view_choice.add_item(view.capitalize())
	view_choice.item_selected.connect(func(_index):canvas.cancel_drag();_refresh())
	playing=CheckBox.new(); playing.text="Walk preview"; playing.custom_minimum_size.x=155; row.add_child(playing)
	playing.toggled.connect(func(value):canvas.walking=value)
	joints=CheckBox.new(); joints.text="Show joints"; joints.custom_minimum_size.x=140; joints.button_pressed=true; row.add_child(joints)
	joints.toggled.connect(func(value):canvas.show_joints=value)
	summary=Label.new(); summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(summary)
	row=HBoxContainer.new(); add_child(row)
	part_choice=OptionButton.new(); part_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(part_choice)
	for index in Rig.PARTS.size(): part_choice.add_item(Rig.LABELS[index])
	part_choice.item_selected.connect(func(_index):canvas.cancel_drag();_refresh_controls())
	button(row,"Upload part…",func():_choose_upload(false))
	button(row,"Import view…",func():_choose_upload(true))
	var split:=HBoxContainer.new(); add_child(split)
	var settings:=VBoxContainer.new(); settings.custom_minimum_size.x=205; split.add_child(settings)
	for field in [["width","Width",1,120,1],["height","Height",1,120,1],["pivot_x","Pivot across (%)",0,100,1],["pivot_y","Pivot down (%)",0,100,1],["angle","Rotation (°)",-180,180,1],["layer","Layer",0,20,1],["speed","Walk cycles/sec",.5,3,.1],["stride","Stride (°)",0,40,1]]:
		var line:=HBoxContainer.new(); settings.add_child(line)
		var label:=Label.new(); label.text=field[1]; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; line.add_child(label)
		var value:=SpinBox.new(); value.min_value=field[2]; value.max_value=field[3]; value.step=field[4]; value.custom_minimum_size.x=82; line.add_child(value)
		controls[field[0]]=value; value.value_changed.connect(func(_number):_edit_fields())
	mirror=CheckBox.new(); mirror.text="Mirror selected image"; settings.add_child(mirror); mirror.toggled.connect(func(_value):_edit_fields())
	button(settings,"Reset view layout",_reset_layout)
	button(settings,"Clear selected part",_clear_part)
	canvas=Canvas.new(); canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL; canvas.focus_mode=Control.FOCUS_ALL; split.add_child(canvas)
	canvas.selected.connect(func(key):playing.set_pressed_no_signal(false);part_choice.select(Rig.PARTS.find(key));_refresh_controls())
	canvas.edited.connect(func(value):rig=value;_refresh_controls();changed.emit(rig.duplicate(true)))
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	dialog=FileDialog.new(); dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.filters=PackedStringArray(["*.png, *.webp ; Transparent body-part images"]); add_child(dialog)
	dialog.files_selected.connect(_import)
	dialog.file_selected.connect(func(path):_import(PackedStringArray([path])))
	_refresh()

func button(parent: Control,caption: String,callback: Callable) -> void:
	var value:=Button.new(); value.text=caption; value.pressed.connect(callback); parent.add_child(value)

func setup(value: Dictionary,town_directory: String,id: String) -> void:
	directory=town_directory; creation_id=id; rig=value.duplicate(true)
	canvas.cancel_drag(); playing.set_pressed_no_signal(false); canvas.walking=false
	_refresh()

func selected_view() -> String: return Rig.VIEWS[view_choice.selected]
func selected_part() -> String: return Rig.PARTS[part_choice.selected]

func _refresh() -> void:
	var view:=selected_view()
	if not rig.views.has(view): rig.views[view]=Rig.template(view)
	canvas.rig=rig.duplicate(true); canvas.directory=directory; canvas.view=view
	_refresh_controls()

func _refresh_controls() -> void:
	busy=true
	var part: Dictionary=rig.views[selected_view()].parts[selected_part()]
	controls.width.value=part.size[0]; controls.height.value=part.size[1]
	controls.pivot_x.value=float(part.pivot[0])*100; controls.pivot_y.value=float(part.pivot[1])*100
	controls.angle.value=part.rotation_degrees; controls.layer.value=part.z_index
	controls.speed.value=rig.walk_cycles_per_second; controls.stride.value=rig.stride_degrees
	mirror.button_pressed=part.flip_h
	canvas.selected_part=selected_part(); canvas.rig=rig.duplicate(true); canvas.queue_redraw()
	var counts: Array[String]=[]
	for view in Rig.VIEWS: counts.append("%s %d/10" % [view.capitalize(),Rig.count_parts(rig,view)])
	summary.text=" · ".join(counts)+"\nAll ten Front parts are needed to save. Incomplete direction sets use Front in the game."
	for index in Rig.PARTS.size():
		var present: bool=not str(rig.views[selected_view()].parts[Rig.PARTS[index]].image).is_empty()
		part_choice.set_item_text(index,("✓ " if present else "— ")+Rig.LABELS[index])
	busy=false
	preload("res://scripts/app/navigation/compact_form.gd").apply(self)

func _edit_fields() -> void:
	if busy: return
	canvas.cancel_drag()
	var updated:=rig.duplicate(true)
	var part: Dictionary=updated.views[selected_view()].parts[selected_part()]
	part.size=[controls.width.value,controls.height.value]
	part.pivot=[controls.pivot_x.value/100,controls.pivot_y.value/100]
	part.rotation_degrees=controls.angle.value; part.z_index=int(controls.layer.value); part.flip_h=mirror.button_pressed
	updated.walk_cycles_per_second=controls.speed.value; updated.stride_degrees=controls.stride.value
	rig=updated; canvas.rig=rig.duplicate(true); canvas.queue_redraw(); changed.emit(rig.duplicate(true))

func _reset_layout() -> void:
	canvas.cancel_drag()
	var view:=selected_view(); var old_parts: Dictionary=rig.views[view].parts
	var source: String=str(rig.get("source_asset",""))
	var native:=preload("res://scripts/npcs/rigging/npc_animated_library.gd").for_actor(source) if not source.is_empty() else {}
	var template: Dictionary=native.views[view].duplicate(true) if not native.is_empty() else Rig.template(view)
	for part in Rig.PARTS:
		template.parts[part].image=old_parts[part].image
		if old_parts[part].has("region"): template.parts[part].region=old_parts[part].region.duplicate()
		else: template.parts[part].erase("region")
	rig.views[view]=template; _refresh(); changed.emit(rig.duplicate(true))

func _clear_part() -> void:
	canvas.cancel_drag(); rig.views[selected_view()].parts[selected_part()].image=""
	_refresh(); changed.emit(rig.duplicate(true))

func _choose_upload(batch: bool) -> void:
	import_context={"id":creation_id,"view":selected_view(),"part":"" if batch else selected_part()}
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILES if batch else FileDialog.FILE_MODE_OPEN_FILE
	dialog.title="Import named body parts for "+selected_view() if batch else "Upload "+Rig.LABELS[part_choice.selected]
	dialog.popup_centered_ratio(.75)
	status.text="Batch filenames: head, torso, left_upper_arm, left_forearm, right_upper_arm, right_forearm, left_thigh, left_shin, right_thigh, right_shin (.png/.webp). Optional front_/left_/right_/back_ prefix must match the selected view."

func _import(files: PackedStringArray) -> void:
	if str(import_context.get("id",""))!=creation_id or import_context.get("view","")!=selected_view():
		status.text="Character/view changed; no parts imported. Choose the target again."; return
	var result:=Importer.import_parts(directory,creation_id,rig,selected_view(),files,str(import_context.get("part","")))
	if not result.ok: status.text=result.message; return
	canvas.cancel_drag(); rig=result.rig; _refresh(); status.text=result.message; changed.emit(rig.duplicate(true))
