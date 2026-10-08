extends SceneTree

const Loader=preload("res://scripts/content/project_loader.gd")
const Knowledge=preload("res://scripts/npcs/town_knowledge_store.gd")
const Traders=preload("res://scripts/npcs/traders/trader_store.gd")
var checks:=0
var failures:=0
var fields:=0
var pages:=0
var studio
var directory: String
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func frames() -> void:
	for _i in 5: await process_frame
func audit(node: Node,context: String) -> void:
	if node is Window: return
	if node is Button and not node is OptionButton and node.is_visible_in_tree():
		check(node.size.x>=32,"Action button collapsed: %s/%s" % [context,node.text])
	if node is Control and node.is_visible_in_tree() and (node is LineEdit or node is OptionButton or node is SpinBox):
		fields+=1
		check(node.size.y<=60,"Oversized field %s/%s: %s" % [context,node.name,node.size])
		check(node.get_global_rect().end.x<=root.size.x+1,"Field exceeds right viewport: %s/%s" % [context,node.name])
	for child in node.get_children(): audit(child,context)
func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--render"): return
	studio.message_dialog.hide(); await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/screenshots/"+name+".png"))
func run() -> void:
	create_timer(90).timeout.connect(func():push_error("Field audit timed out");quit(2))
	root.size=Vector2i(1366,900); root.content_scale_size=root.size
	directory=ProjectSettings.globalize_path("res://tools/tests/output/field-audit-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var file:=FileAccess.open(directory.path_join("town.json"),FileAccess.WRITE); file.store_string('{"town_id":"field-audit","display_name":"Field audit"}'); file.close()
	studio=load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=directory; studio.last_created_directory=directory
	studio.imported_town=studio.importer.parse_files(PackedStringArray(["res://tools/tests/fixtures/tiny_town.osm"]))
	var feature: Dictionary=studio.imported_town.features.filter(func(v):return v.kind=="building")[0]
	var created: Dictionary=studio.building_interior_store.create_blank_ground_floor(studio.building_interior_store.empty_data(),feature)
	check(created.ok and studio.building_interior_store.save_to_town(directory,created.data).ok,"Fixture interior failed")
	for size in [Vector2i(1366,900),Vector2i(1024,768)]:
		root.size=size; root.content_scale_size=size
		for section in ["welcome","town_import","game_settings","advanced_map_editor","building_creator","interior_designer","personas","inventory","system"]:
			studio.call("_show_%s_page" % section); await frames(); studio.message_dialog.hide()
			audit(studio.content_area,section); pages+=1
			var menus: Array=[]
			for name in ["npc_tools_navigation","settings_tools_navigation","editor_tools_navigation","building_tools_navigation","interior_tools_navigation"]:
				var menu=studio.get(name)
				if is_instance_valid(menu): menus.append(menu)
			for menu in menus:
				for id in menu.pages:
					menu.open_page(id); await frames(); audit(studio.content_area,section+"/"+str(id)); pages+=1
	studio._show_personas_page(); await frames()
	studio.npc_tools_navigation.open_page("knowledge"); await frames()
	var upload=studio.content_area.find_child("TownTextUpload",true,false)
	check(is_instance_valid(upload) and upload.is_visible_in_tree(),"Town text upload absent")
	check(upload.get_global_rect().end.y<root.size.y-25,"Town text upload pushed below viewport")
	upload.pressed.emit(); await frames()
	check(studio.town_text_dialog.visible,"Upload button does not open a picker"); studio.town_text_dialog.hide()
	var source:=directory.path_join("source-notes.txt")
	file=FileAccess.open(source,FileAccess.WRITE); file.store_string("Town reference test. A pub to enjoy a beer without judgement."); file.close()
	var hash:=FileAccess.get_sha256(source)
	studio._on_town_text_file_selected(source); studio._save_persona_library(); studio.message_dialog.hide(); await frames()
	check(studio.section_save_succeeded,"Town information Save failed")
	var reopened:=Knowledge.new().load_from_town(directory)
	check(reopened.ok and reopened.custom_text.contains("without judgement") and FileAccess.get_sha256(source)==hash,"Town notes did not reopen or source changed")
	await capture("town_information_compact_v16")
	studio._remove_town_text_file(); await frames()
	check(studio.town_custom_text.is_empty() and not studio.top_undo_button.disabled,"Removing town notes did not create an Undo step")
	studio.top_undo_button.pressed.emit(); await frames()
	check(studio.town_custom_text.contains("without judgement"),"Town text Undo did not restore notes")
	studio.npc_tools_navigation.open_page("generic"); await frames()
	var picker=studio.npc_appearance_picker
	check(picker.template_choice.item_count==18 and picker.preview.visible,"Generic artwork chooser/preview unfinished")
	for index in 18:
		picker.source.select(1); picker._changed(1)
		picker.template_choice.item_selected.emit(index)
		var wanted: Dictionary=picker.template_choice.get_item_metadata(index)
		check(picker.selected_appearance().npc_asset==wanted.id and picker.preview.appearance.npc_asset==wanted.id,"Generic visual choice did not select/preview identity")
	studio.npc_tools_navigation.open_page("trader"); await frames()
	var floor_value: Dictionary=created.data.buildings[str(feature.id)].floors[0]
	studio.storyline_coordinate_edit.text=preload("res://scripts/npcs/storyline_npc_store.gd").format_interior_location(str(feature.id),"ground_floor",Vector2(floor_value.width_metres*.5,floor_value.height_metres*.5))
	studio.storyline_name_edit.text="Test barkeep"; studio._place_storyline_npc(); await frames(); studio.message_dialog.hide()
	check(studio.storyline_npc_data.npcs.size()==1,"Trader fixture placement failed")
	studio.npc_tools_navigation.open_page("stock"); await frames()
	var editor=studio.trader_editor; editor.enabled_choice.button_pressed=true
	for row in [["beer",10,5],["bananas",7,2]]:
		for i in editor.item_choice.item_count:
			if editor.item_choice.get_item_metadata(i)==row[0]: editor.item_choice.select(i)
		editor.stock_spin.value=row[1]; editor.price_spin.value=row[2]; editor._save_offer(); await frames()
	check(editor.stock_rows.get_child_count()==2,"Added stock not listed below")
	var beer_row=editor.stock_rows.find_child("Stock_beer",false,false)
	check(is_instance_valid(beer_row),"Beer missing from inline list")
	if is_instance_valid(beer_row):
		beer_row.get_child(1).get_child(1).value=23
		beer_row.get_child(2).get_child(1).value=9
		await frames()
		var beer: Dictionary=editor.data.traders[editor.selected_id].offers.filter(func(v):return v.item_id=="beer")[0]
		check(beer.stock==23 and beer.price_keks==9,"Inline quantity/price not applied")
		studio._save_persona_library(); studio.message_dialog.hide(); await frames()
		var stock:=Traders.new().load_from_town(directory)
		check(stock.ok and stock.data.traders[editor.selected_id].offers[0].stock==23 and stock.data.traders[editor.selected_id].offers[0].price_keks==9,"Inline stock Save/reopen failed")
		editor._remove_stock(editor.selected_id,"beer"); await frames(); studio.top_undo_button.pressed.emit(); await frames()
		check(studio.trader_editor.stock_rows.get_child_count()==2,"Inline-stock Undo did not restore list")
	root.size=Vector2i(1366,900); root.content_scale_size=root.size
	studio.npc_tools_navigation.page_scroll.scroll_vertical=250; await capture("trader_stock_inline_v16")
	studio.npc_tools_navigation.open_page("generic"); picker=studio.npc_appearance_picker; picker.source.select(1); picker._changed(1); await frames()
	studio.npc_tools_navigation.page_scroll.scroll_vertical=210
	await capture("generic_npc_artwork_compact_v16")
	print("EDITOR FIELD AUDIT: %d checks, %d failures; %d fields across %d section/tool views at two sizes" % [checks,failures,fields,pages])
	studio.free(); quit(1 if failures else 0)
