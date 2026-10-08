extends SceneTree

## Actual toolbar/form regression checks using disposable content, never user towns.
const Personas = preload("res://scripts/npcs/persona_store.gd")
const Knowledge = preload("res://scripts/npcs/town_knowledge_store.gd")
const Trees = preload("res://scripts/environment/tree_settings_store.gd")
const Lore = preload("res://scripts/npcs/lore/game_lore_store.gd")
const Interiors = preload("res://scripts/interiors/building_interior_store.gd")
var studio: Control
var directory := ""
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames() -> void:
	for i in 5: await process_frame
func write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)
func run() -> void:
	create_timer(60).timeout.connect(func(): push_error("EDITOR HISTORY TIMEOUT"); quit(2))
	root.size=Vector2i(1366,768); root.content_scale_size=root.size
	directory=ProjectSettings.globalize_path("res://tools/tests/output/editor-history-%s" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory.path_join("data"))
	write(directory.path_join("town.json"), '{"town_id":"history-fixture","display_name":"History fixture"}')
	var feature := {"id":"test_building","kind":"building","points":[Vector2(146,-36),Vector2(146.0003,-36),Vector2(146.0003,-36.0004),Vector2(146,-36.0004),Vector2(146,-36)],"tags":{"building":"yes"}}
	var interior := Interiors.new().create_blank_ground_floor(Interiors.new().empty_data(),feature)
	check(interior.ok and Interiors.new().save_to_town(directory,interior.data).ok,"History fixture interior")
	studio=load("res://scenes/creator_studio.tscn").instantiate(); root.add_child(studio); await frames()
	studio.loaded_project_directory=directory
	studio.last_created_directory=directory
	studio.imported_town={"ok":true,"features":[feature],"bounds":{"west":145.99,"east":146.01,"south":-36.01,"north":-35.99},"warnings":[],"statistics":{}}
	studio._show_inventory_page(); await frames()
	check(not studio._section_is_dirty(),"Fresh inventory starts dirty")
	check(not studio.inventory_editor.save_button.visible and studio.top_cancel_button.visible,"Inventory header actions / duplicate Save")
	var old_name: String=studio.inventory_editor.name_edit.text
	studio.inventory_editor.name_edit.text="Updated coins"
	studio._record_section_edit()
	check(studio._section_is_dirty() and not studio.top_undo_button.disabled,"Inventory edit missing history")
	studio._save_active_section(); await frames()
	check(not studio._section_is_dirty(),"Successful inventory Save stayed dirty")
	studio._undo_section_edit(); await frames()
	check(studio.inventory_editor.name_edit.text==old_name,"Undo after Save restored the edited form instead of old form")
	studio._save_active_section()
	var catalogue: Dictionary = studio.inventory_editor.store.load_from_town(directory)
	check(catalogue.ok and catalogue.data.items[0].display_name==old_name,"Undo -> Save -> reopen item failed")
	studio.inventory_editor.name_edit.text="Guard save"
	studio._record_section_edit()
	var saved_navigation := [false]
	studio._request_section_navigation(func(): saved_navigation[0]=true)
	studio._save_before_leaving(); studio.section_leave_dialog.hide(); await frames()
	check(saved_navigation[0] and not studio._section_is_dirty(),"Save-and-leave did not persist or navigate")
	studio._undo_section_edit(); studio._save_active_section(); await frames()
	studio.inventory_editor.name_edit.text="Discard this"
	studio._record_section_edit()
	var called := [false]
	studio._request_section_navigation(func(): called[0]=true)
	check(not called[0] and studio.section_leave_dialog.visible,"Dirty navigation did not offer Save/Discard/Stay")
	studio.section_leave_dialog.hide() # Stay, no navigation.
	check(studio.inventory_editor.name_edit.text=="Discard this","Stay lost edits")
	studio._discard_before_leaving(); await frames()
	check(called[0] and studio.inventory_editor.name_edit.text==old_name,"Discard did not restore baseline")
	studio._show_personas_page(); await frames()
	check(studio.npc_tools_navigation.pages.has("human_personas") and studio.npc_tools_navigation.pages.has("robot_personas") and studio.npc_tools_navigation.pages.has("stock"),"Single-purpose NPC tiles missing")
	studio.npc_tools_navigation.open_page("human_personas")
	studio._new_npc_persona(); studio._record_section_edit()
	var first_id: String=studio._option_id(studio.persona_option)
	studio.persona_name_edit.text="First custom"; studio._record_section_edit()
	studio._new_npc_persona(); studio.persona_name_edit.text="Second custom"; studio._record_section_edit()
	var second_id: String=studio._option_id(studio.persona_option)
	studio._save_active_section(); await frames()
	check(not studio._section_is_dirty(),"Persona Save left dirty state")
	studio._delete_selected_persona(); studio._record_section_edit()
	check(Personas.find_persona(studio.persona_data,second_id).is_empty(),"Persona delete did not remove draft")
	studio._undo_section_edit(); await frames()
	check(studio._option_id(studio.persona_option)==second_id and studio.persona_name_edit.text=="Second custom","Persona Undo left stale selector/form")
	studio.persona_name_edit.text="Restored second"; studio._record_section_edit(); studio._save_active_section()
	var saved_personas := Personas.new().load_from_town(directory)
	check(Personas.find_persona(saved_personas.data,first_id).name=="First custom" and Personas.find_persona(saved_personas.data,second_id).name=="Restored second","Saving after Undo overwrote the wrong persona")
	studio.npc_tools_navigation.open_page("robot_personas")
	check(studio.persona_actor_filter=="npr" and studio.persona_new_npr_button.visible,"Robot persona tile did not filter")
	studio.npc_tools_navigation.open_page("generic")
	check(studio.npc_placement_panel.get_parent()==studio.npc_tools_navigation.pages.generic and studio.npc_persona_panel.get_parent()!=studio.npc_tools_navigation.pages.generic,"Placement still contains persona editing")
	check(not studio._section_is_dirty(),"Opening a tool without editing reported unsaved changes")
	studio.wikipedia_url_edit.text="https://en.wikipedia.org/wiki/Albury"
	studio._record_section_edit()
	check(studio._section_is_dirty(),"Unapplied Wikipedia URL was not guarded")
	studio._undo_section_edit(); await frames()
	check(studio.wikipedia_url_edit.text.is_empty() and not studio._section_is_dirty(),"Wikipedia URL Undo failed")
	# Stock form must not flush stale edits into a restored snapshot.
	studio.storyline_npc_data.npcs.append({"id":"storyline_npc_001","npc_role":"trader","display_name":"Fixture trader","persona_id":"friendly_local","appearance":{"mode":"random_static_asset","npc_asset":"npc_medium_man_adult","gender":"man","age_group":"adult","skin_tone_group":"medium"},"location":{"space":"interior","building_id":"test_building","floor_id":"ground_floor","x_metres":10.0,"y_metres":10.0}})
	studio.trader_editor.data.traders["storyline_npc_001"]={"enabled":true,"trade_role":"Barkeep","persona_id":"friendly_local","offers":[{"item_id":"bananas","stock":5,"price_keks":3}]}
	studio._refresh_storyline_npc_controls(); studio.npc_tools_navigation.open_page("stock")
	studio.trader_editor._select_offer(0)
	studio.section_history.reset(studio._section_snapshot())
	studio.trader_editor.price_spin.value=9; studio._record_section_edit()
	studio._undo_section_edit(); await frames()
	check(studio.trader_editor.price_spin.value==3 and studio.trader_editor.data.traders.storyline_npc_001.offers[0].price_keks==3,"Trader Undo was overwritten by stale form")
	studio._save_active_section(); await frames()
	var trader_file = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("data/trader_npcs.json")))
	check(trader_file is Dictionary and trader_file.traders.storyline_npc_001.offers[0].price_keks==3,"Trader Undo -> Save did not persist old price")
	# A late placement-validation failure must not leave earlier persona writes.
	var old_persona_bytes := FileAccess.get_file_as_bytes(directory.path_join("data/personas.json"))
	var old_placement_bytes := FileAccess.get_file_as_bytes(directory.path_join("data/storyline_npcs.json"))
	studio.persona_name_edit.text="Should not reach disk"
	studio.storyline_npc_data.npcs[0].appearance={}
	studio._save_active_section(); await frames()
	check(not studio.section_save_succeeded and FileAccess.get_file_as_bytes(directory.path_join("data/personas.json"))==old_persona_bytes and FileAccess.get_file_as_bytes(directory.path_join("data/storyline_npcs.json"))==old_placement_bytes,"Failed multi-file Save left partial NPC changes")
	studio._discard_before_leaving(); await frames()
	check(not studio._section_is_dirty(),"Discard after failed Save did not restore drafts")
	studio.message_dialog.hide()
	studio._show_interior_designer_page(); await frames()
	var before_interior := FileAccess.get_file_as_bytes(directory.path_join("data/building_interiors.json"))
	studio.interior_data.buildings.test_building.floors[0].name="Should not reach disk"
	studio.interior_trader_data.traders.storyline_npc_001.offers[0].item_id="missing_item"
	studio._save_active_section(); await frames()
	check(not studio.section_save_succeeded and FileAccess.get_file_as_bytes(directory.path_join("data/building_interiors.json"))==before_interior,"Failed multi-file Save left a partial interior layout")
	studio._discard_before_leaving(); await frames(); studio.message_dialog.hide()
	check(not studio._section_is_dirty(),"Discard after failed interior Save failed")
	studio._show_game_settings_page(); await frames()
	check(not studio._section_is_dirty(),"Fresh settings started dirty")
	studio.settings_tools_navigation.open_page("lore")
	studio.game_lore_editor.import_file(Lore.EXAMPLE_PATH); await frames()
	check(not Lore.new().load_from_town(directory).data.lore.is_empty(),"Lore fixture missing")
	studio._undo_section_edit(); await frames()
	check(Lore.new().load_from_town(directory).data.lore.is_empty(),"Global Undo did not persist lore restore")
	studio._show_advanced_map_editor_page(); await frames()
	studio.editor_tools_navigation.open_page("trees")
	var original: String = Trees.new().load_from_town(directory).data.tree_style
	for i in studio.tree_settings_editor.style_option.item_count:
		if studio.tree_settings_editor.style_option.get_item_metadata(i)=="eucalypt": studio.tree_settings_editor._select_style(i); break
	await frames(); studio._undo_section_edit(); await frames()
	check(Trees.new().load_from_town(directory).data.tree_style==original,"Global Undo did not persist tree restore")
	studio.editor_tools_navigation.open_page("tree_upload")
	check(studio.tree_settings_editor.upload_group.visible and not studio.tree_settings_editor.style_group.visible,"Tree upload still grouped with type")
	studio.queue_free(); await frames()
	print("EDITOR HISTORY %s: %d checks" % ["PASSED" if failures==0 else "FAILED",checks])
	quit(0 if failures==0 else 1)
