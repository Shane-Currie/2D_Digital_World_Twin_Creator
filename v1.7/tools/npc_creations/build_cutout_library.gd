extends SceneTree

## Build only the shared versioned library, never user creations or towns.
const Rig=preload("res://scripts/npcs/rigging/npc_rig_data.gd")
const Source=preload("res://scripts/npcs/rigging/npc_rig_starter.gd")
const Store=preload("res://scripts/npcs/creation/npc_creation_store.gd")
const ROOT: String="res://assets/actors/cutout_v16/"

func _initialize() -> void: call_deferred("build")
func build() -> void:
	var rigs: Dictionary={}; var descriptions: Dictionary={}
	var items:=Store.built_ins(); items.append({"id":"player","gender":"man","age_group":"young","skin_tone_group":"light"}); items.append(Store.morpheus())
	var jackets: Array=["#356c9b","#52714d","#796458","#397e84","#a35264","#776284","#bc723b","#467290","#807556","#b48b3f","#4c8066","#5b779b","#a85845","#4c7f89","#947548","#986553","#7c638f","#448688"]
	for index in items.size():
		var item: Dictionary=items[index]
		var description: Dictionary=item.duplicate(true)
		description.skin={"light":"#e8bb94","medium":"#b67d53","dark":"#704b34"}[item.skin_tone_group]
		description.hair="#a6a298" if item.age_group=="older" else {"light":"#5c3f29","medium":"#39291f","dark":"#241e1b"}[item.skin_tone_group]
		description.jacket=jackets[index%18]; description.jacket_shadow="#"+Color(description.jacket).darkened(.32).to_html()
		description.trousers="#435364"; description.trouser_highlight="#657485"
		if item.id=="player":
			description.hair="#5c3f29"; description.jacket="#b73e35"; description.jacket_shadow="#782a2c"
			description.trousers="#376e9b"; description.trouser_highlight="#6794b7"
		if item.id=="morpheus":
			description.jacket="#282d2b"; description.jacket_shadow="#161c1b"; description.glasses=true
			description.trousers="#303831"; description.trouser_highlight="#49534b"; description.hair="#211d18"
		var rig:=Rig.new_rig(); rig.source_asset=str(item.id); rig.stride_degrees=22.0
		if item.gender=="woman":
			for view in Rig.VIEWS:
				rig.views[view].parts.head.size=[34 if view in ["left","right"] else 42,52]
				rig.views[view].parts.head.pivot=[.5,.72]
		for view in Rig.VIEWS:
			var folder: String=ROOT+str(item.id)+"/"
			if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK: push_error("Could not create library folder"); quit(1); return
			for part in Rig.PARTS:
				var image:=Image.new()
				if image.load_svg_from_string(Source.svg(part,view,description))!=OK: push_error("Bad cutout source"); quit(1); return
				var path: String=folder+view+"_"+part+".png"
				if image.save_png(ProjectSettings.globalize_path(path))!=OK: push_error("Could not save body part"); quit(1); return
				rig.views[view].parts[part].image=path
		rigs[str(item.id)]=rig; descriptions[str(item.id)]=description
	var file:=FileAccess.open(ROOT+"library.json",FileAccess.WRITE)
	if file==null: push_error("Could not save library"); quit(1); return
	file.store_string(JSON.stringify({"style":"illustrated-cutout","source":"npc_rig_starter.gd","rigs":rigs,"appearances":descriptions},"\t")); file.close()
	print("CUTOUT LIBRARY: %d characters, %d separate view/part files" % [rigs.size(),rigs.size()*40]); quit()
