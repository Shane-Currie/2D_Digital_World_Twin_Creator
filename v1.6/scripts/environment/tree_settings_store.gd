extends RefCounted

## Optional town-wide artwork selection. OSM positions and clearance stay intact.
const FILE_NAME := "data/environment_settings.json"
const BUILT_INS := {"mapped":"Mapped / mixed trees", "broadleaf":"Broadleaf", "eucalypt":"Gum tree (eucalypt)", "conifer":"Conifer"}
const MAX_BYTES := 8 * 1024 * 1024
const MAX_DIMENSION := 2048

static func defaults() -> Dictionary:
	return {"schema_version":1,"kind":"environment_settings","tree_style":"mapped","custom_trees":[]}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema_version") != 1 or data.get("kind") != "environment_settings": return false
	if not data.get("custom_trees") is Array or data.custom_trees.size()>32: return false
	var ids := BUILT_INS.keys()
	for item in data.custom_trees:
		if not item is Dictionary: return false
		var digest := str(item.get("sha256",""))
		if digest.length()!=64 or not digest.is_valid_hex_number(false) or digest != digest.to_lower(): return false
		if item.get("id") != "custom_"+digest or ids.has(item.id): return false
		if item.get("relative_path") != "assets/environment/trees/"+digest+".png": return false
		if not item.get("name") is String or item.name.strip_edges().is_empty() or item.name.length()>80: return false
		ids.append(item.id)
	return ids.has(data.get("tree_style"))

func load_from_town(directory: String) -> Dictionary:
	var data := defaults()
	var path := directory.path_join(FILE_NAME)
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not valid(parsed): return {"ok":false,"data":data,"message":"Tree settings need attention. Existing files are preserved; mapped trees remain available."}
		data = parsed
	return {"ok":true,"data":data,"message":"Tree settings loaded."}

func save(directory: String, data: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(directory.path_join("town.json")): return {"ok":false,"message":"Choose a saved town project first."}
	if not valid(data): return {"ok":false,"message":"Tree settings are invalid; previous settings were preserved."}
	var path := directory.path_join(FILE_NAME)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return {"ok":false,"message":"Cannot create the tree settings folder."}
	var pending := path+".pending-%s" % Time.get_ticks_usec()
	var file := FileAccess.open(pending,FileAccess.WRITE)
	if file == null: return {"ok":false,"message":"Cannot save tree settings."}
	file.store_string(JSON.stringify(data,"\t")+"\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(pending,path) != OK: return {"ok":false,"message":"Cannot finish saving tree settings; previous settings were preserved."}
	return {"ok":true,"message":"Trees saved. Reopen Play test to see the selected artwork."}

static func read_image(path: String, digest: String = "") -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"ok":false,"message":"The tree image could not be opened."}
	if file.get_length()>MAX_BYTES: return {"ok":false,"message":"Tree PNG images must be under 8 MB."}
	var bytes := file.get_buffer(file.get_length())
	if not digest.is_empty() and FileAccess.get_sha256(path)!=digest: return {"ok":false,"message":"The copied tree image changed; upload it again."}
	# Check dimensions before decoding, avoiding excessive decompression allocation.
	if bytes.size()<33 or bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or bytes.slice(12,16).get_string_from_ascii()!="IHDR": return {"ok":false,"message":"Choose a valid transparent PNG tree image."}
	var width := 0
	var height := 0
	for index in range(16,20): width = (width<<8)|int(bytes[index])
	for index in range(20,24): height = (height<<8)|int(bytes[index])
	if width<1 or height<1 or width>MAX_DIMENSION or height>MAX_DIMENSION: return {"ok":false,"message":"Tree images must be between 1 and 2048 pixels on each side."}
	var image := Image.new()
	if image.load_png_from_buffer(bytes)!=OK: return {"ok":false,"message":"The PNG image is damaged or unsupported."}
	if image.detect_alpha()==Image.ALPHA_NONE or not image.get_used_rect().has_area(): return {"ok":false,"message":"Use visible tree artwork with a transparent background, not a solid rectangle or empty image."}
	return {"ok":true,"image":image.get_region(image.get_used_rect()),"message":"Tree image ready."}

func import_image(directory: String, source: String, name_value: String) -> Dictionary:
	var previous := load_from_town(directory)
	if not previous.ok: return previous
	if not FileAccess.file_exists(directory.path_join("town.json")): return {"ok":false,"message":"Choose a saved town project first."}
	if source.get_extension().to_lower()!="png": return {"ok":false,"message":"Choose a transparent PNG tree image."}
	var checked := read_image(source)
	if not checked.ok: return checked
	var name_clean := name_value.strip_edges()
	if name_clean.is_empty(): name_clean=source.get_file().get_basename()
	if name_clean.length()>80: return {"ok":false,"message":"Use a tree name under 80 characters."}
	var digest := FileAccess.get_sha256(source)
	var id := "custom_"+digest
	var data: Dictionary = previous.data.duplicate(true)
	if not data.custom_trees.any(func(item): return item.id==id):
		if data.custom_trees.size()>=32: return {"ok":false,"message":"This town already has 32 custom tree images."}
		data.custom_trees.append({"id":id,"name":name_clean,"sha256":digest,"relative_path":"assets/environment/trees/"+digest+".png"})
	var destination := directory.path_join("assets/environment/trees/"+digest+".png")
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir())!=OK: return {"ok":false,"message":"Cannot create the tree artwork folder."}
	if source!=destination and DirAccess.copy_absolute(source,destination)!=OK: return {"ok":false,"message":"Cannot copy the tree image; previous selection is preserved."}
	data.tree_style=id
	return save(directory,data)

func selected_texture(directory: String, data: Dictionary) -> Texture2D:
	for item in data.custom_trees:
		if item.id != data.tree_style: continue
		var checked := read_image(directory.path_join(item.relative_path),item.sha256)
		if checked.ok: return ImageTexture.create_from_image(checked.image)
		push_warning(checked.message+" Using mapped tree artwork instead.")
	return null
