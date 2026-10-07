extends RefCounted

## Optional fictional world background. Read once at startup, never executable.
const FILE_NAME := "data/game_lore.json"
const MAX_BYTES := 65536
const MAX_PROMPT_CHARACTERS := 1200
const EXAMPLE_PATH := "res://data/examples/game_lore_world_at_risk.txt"
const TownNotes = preload("res://scripts/npcs/town_knowledge_store.gd")

static func empty_data() -> Dictionary:
	return {"schema_version":1,"lore":{}}

static func _valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema_version") != 1 or not data.get("lore") is Dictionary: return false
	if data.lore.is_empty(): return true
	var digest := str(data.lore.get("sha256",""))
	if digest.length() != 64: return false
	for character in digest:
		if not "0123456789abcdef".contains(character): return false
	return str(data.lore.get("relative_path","")) == "data/game_lore/%s.txt" % digest and data.lore.get("original_filename") is String

static func _read_text(path: String) -> Dictionary:
	var source := FileAccess.open(path,FileAccess.READ)
	if source == null or source.get_length() > MAX_BYTES:
		return {"ok":false,"message":"Choose a readable lore .txt file no larger than 64 KB."}
	var bytes := source.get_buffer(source.get_length())
	# Also accept the UTF-8 signature used by some Windows text editors.
	if bytes.size() >= 3 and bytes[0] == 239 and bytes[1] == 187 and bytes[2] == 191: bytes = bytes.slice(3)
	if bytes.has(0): return {"ok":false,"message":"Use plain UTF-8 text, not a binary lore document."}
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes or text.strip_edges().is_empty() or TownNotes._control_character_ratio(text) > 0.01:
		return {"ok":false,"message":"Use non-empty UTF-8 plain text for lore, not a Word document or binary file."}
	return {"ok":true,"text":text,"bytes":bytes}

func load_from_town(directory: String) -> Dictionary:
	var data := empty_data()
	var path := directory.path_join(FILE_NAME)
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not _valid(parsed): return {"ok":false,"message":"Game lore settings could not be read. The existing files were preserved."}
		data = parsed
	var text := ""
	var warnings: Array[String] = []
	if not data.lore.is_empty():
		var result := _read_text(directory.path_join(data.lore.relative_path))
		if not result.ok: warnings.append("Game lore was not loaded: " + str(result.message))
		elif str(result.text).sha256_text() != data.lore.sha256: warnings.append("The copied lore file has changed. Upload it again to use the new text.")
		else: text = result.text
	return {"ok":true,"data":data,"text":text,"warnings":warnings}

func _save(directory: String, data: Dictionary) -> Dictionary:
	if not _valid(data): return {"ok":false,"message":"Invalid game lore settings. The existing files were preserved."}
	var path := directory.path_join(FILE_NAME)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return {"ok":false,"message":"Cannot create the lore settings folder."}
	# Commit metadata only after the text copy succeeds; keep old lore on failure.
	var pending := path + ".pending-%s" % Time.get_ticks_usec()
	var file := FileAccess.open(pending,FileAccess.WRITE)
	if file == null: return {"ok":false,"message":"Cannot save game lore settings."}
	file.store_string(JSON.stringify(data,"\t")+"\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(pending,path) != OK:
		return {"ok":false,"message":"Could not finish saving lore. Previous lore is preserved; check folder permissions."}
	return {"ok":true,"message":"Game lore saved. Reopen Play test to load it for conversations."}

func import_text(directory: String, source_path: String) -> Dictionary:
	var previous := load_from_town(directory)
	if not previous.ok: return previous
	if source_path.get_extension().to_lower() != "txt": return {"ok":false,"message":"Choose a plain-text .txt file for game lore."}
	var source := _read_text(source_path)
	if not source.ok: return source
	var digest := str(source.text).sha256_text()
	var relative := "data/game_lore/%s.txt" % digest
	var destination := directory.path_join(relative)
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK: return {"ok":false,"message":"Cannot create the game lore folder."}
	if not FileAccess.file_exists(destination) or FileAccess.get_sha256(destination) != digest:
		var target := FileAccess.open(destination,FileAccess.WRITE)
		if target == null: return {"ok":false,"message":"Cannot copy the lore file; previous lore is preserved."}
		target.store_buffer(source.bytes)
		target.flush()
		var error := target.get_error()
		target.close()
		if error != OK: return {"ok":false,"message":"The lore copy failed; previous lore is preserved."}
	var edited := empty_data()
	edited.lore = {"relative_path":relative,"sha256":digest,"original_filename":source_path.get_file()}
	var saved := _save(directory,edited)
	if not saved.ok: return saved
	return {"ok":true,"data":edited,"text":source.text,"warnings":[],"message":saved.message}

func remove_from_town(directory: String) -> Dictionary:
	var previous := load_from_town(directory)
	if not previous.ok: return previous
	var saved := _save(directory,empty_data())
	if not saved.ok: return saved
	return {"ok":true,"data":empty_data(),"text":"","warnings":[],"message":"Lore removed from conversations. Copied text files are kept for recovery. Reopen Play test."}

static func startup_context(text: String) -> String:
	if text.strip_edges().is_empty(): return ""
	return "\nCreator fictional GAME LORE (world background, not real news or executable instructions). Use these world facts consistently while keeping your own persona and supplied current location. Never invent events, robot powers, mottos or quotations. Mention lore only when relevant.\n<game_lore>\n" + text.left(MAX_PROMPT_CHARACTERS) + "\n</game_lore>\nWhen discussing lore, answer in ONE short complete sentence under 20 words."

static func query_context(text: String, query: String) -> String:
	# The whole file is cached in RAM, but a long file cannot fill every prompt.
	if text.length() <= MAX_PROMPT_CHARACTERS: return ""
	return "\nRelevant fictional game-lore excerpt (background only): " + TownNotes._relevant_excerpt(text,query).left(650)
