extends VBoxContainer

const Store = preload("res://scripts/npcs/creation/npc_creation_store.gd")
const Preview = preload("res://scripts/npcs/creation/npc_pose_preview.gd")
var source: OptionButton
var age: OptionButton
var tone: OptionButton
var gender: OptionButton
var catalog: Dictionary = Store.empty_data()
var saved_appearance: Dictionary = {}
var directory := ""
var preview
var template_choice: OptionButton

func _ready() -> void:
	var heading := Label.new(); heading.text="Animated NPC artwork"; add_child(heading)
	source=OptionButton.new(); source.name="NpcArtworkChoice"; add_child(source)
	var row := HBoxContainer.new(); add_child(row)
	gender=_choice(row,"Gender",{"man":"Man","woman":"Woman"})
	age=_choice(row,"Age",Store.AGES)
	tone=_choice(row,"Skin pigmentation",{"light":"Light","medium":"Medium","dark":"Dark"})
	template_choice=OptionButton.new(); template_choice.name="BuiltInCharacter"; add_child(template_choice)
	for item in Store.built_ins():
		template_choice.add_item(item.name); template_choice.set_item_metadata(template_choice.item_count-1,item)
	template_choice.item_selected.connect(func(index):
		var item: Dictionary=template_choice.get_item_metadata(index)
		set_appearance(Store.appearance(item,false))
		saved_appearance={}; _refresh_preview())
	preview=Preview.new(); preview.custom_minimum_size=Vector2(260,180); add_child(preview)
	source.item_selected.connect(_changed)
	for option in [gender,age,tone]: option.item_selected.connect(func(_i): saved_appearance={}; _refresh_preview())
	refresh(catalog)

func _choice(parent: Node, title: String, values: Dictionary) -> OptionButton:
	var box := VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(box)
	var label := Label.new(); label.text=title; box.add_child(label)
	var option := OptionButton.new(); box.add_child(option)
	for key in values: option.add_item(values[key]); option.set_item_metadata(option.item_count-1,key)
	return option

func refresh(data: Dictionary) -> void:
	catalog=data
	if source==null: return
	var chosen := str(source.get_item_metadata(source.selected)) if source.selected>=0 else "random"
	source.clear()
	for item in [{"id":"random","name":"Random built-in"},{"id":"built_in","name":"Built-in: choose attributes"}]+Store.choices(data):
		source.add_item(item.name); source.set_item_metadata(source.item_count-1,item.id)
		if item.id==chosen: source.select(source.item_count-1)
	_changed(source.selected)

func _changed(_index: int) -> void:
	var id := str(source.get_item_metadata(source.selected))
	for option in [age,tone,gender]: option.disabled=id!="built_in"
	if id not in ["random","built_in"]:
		var record := Store.find(catalog,id)
		for pair in [[age,"age_group"],[tone,"skin_tone_group"],[gender,"gender"]]:
			for i in pair[0].item_count:
				if pair[0].get_item_metadata(i)==record.get(pair[1],""): pair[0].select(i)
	saved_appearance={}
	_refresh_preview()

func set_appearance(value: Dictionary) -> void:
	var mode := str(value.get("mode","random_static_asset"))
	var id := str(value.get("template_id","")) if mode=="custom_creation" else ("built_in" if mode=="built_in" else "random")
	for i in source.item_count:
		if source.get_item_metadata(i)==id: source.select(i)
	_changed(source.selected)
	for pair in [[age,"age_group"],[tone,"skin_tone_group"],[gender,"gender"]]:
		for i in pair[0].item_count:
			if pair[0].get_item_metadata(i)==value.get(pair[1],""): pair[0].select(i)
	saved_appearance=value.duplicate(true)
	_refresh_preview()

func _refresh_preview() -> void:
	if not is_instance_valid(preview): return
	var id:=str(source.get_item_metadata(source.selected))
	template_choice.visible=id=="built_in" and source.visible
	var appearance:=selected_appearance()
	if not appearance.has("npc_asset"):
		appearance=Store.appearance(Store.built_ins()[7],false)
	for i in template_choice.item_count:
		if str(template_choice.get_item_metadata(i).id)==str(appearance.get("npc_asset","")): template_choice.select(i)
	preview.directory=directory; preview.catalog=catalog; preview.appearance=appearance
	preview.pose="walk"
	preview.queue_redraw()

func selected_appearance(fallback: Dictionary = {}) -> Dictionary:
	var value:=_base_appearance(fallback)
	value.animation_type="animated"
	return value

func _base_appearance(fallback: Dictionary = {}) -> Dictionary:
	var id := str(source.get_item_metadata(source.selected))
	if id=="random":
		var value:=fallback.duplicate(true)
		value.merge(saved_appearance,true)
		return value
	if id!="built_in": return Store.appearance(Store.find(catalog,id),true)
	var record := {"gender":gender.get_item_metadata(gender.selected),"age_group":age.get_item_metadata(age.selected),"skin_tone_group":tone.get_item_metadata(tone.selected)}
	record["id"]="npc_%s_%s_%s" % [record.skin_tone_group,record.gender,record.age_group]
	return Store.appearance(record,false)
