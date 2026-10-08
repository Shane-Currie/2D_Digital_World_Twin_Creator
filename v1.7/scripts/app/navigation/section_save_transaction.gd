extends RefCounted

## A failed multi-file Save restores only this section's owned metadata.
## No source maps, artwork, folders or unrelated files are removed.
const FILES := {
	"npcs": ["personas.json", "town_knowledge.json", "storyline_npcs.json", "trader_npcs.json", "npc_creations.json"],
	"interior": ["building_interiors.json", "building_exteriors.json", "interior_furniture_catalog.json", "interior_floor_materials.json", "storyline_npcs.json", "trader_npcs.json", "location_notes.json"]
}
var previous: Dictionary = {}

func begin(directory: String, section: String) -> Dictionary:
	previous.clear()
	if directory.is_empty() or not FILES.has(section): return {"ok": false, "message": "Choose a town before saving."}
	for filename in FILES[section]:
		var path := directory.path_join("data").path_join(filename).simplify_path()
		if DirAccess.dir_exists_absolute(path): return {"ok": false, "message": "Cannot save: a folder occupies " + filename + ". Existing files were not changed."}
		var exists := FileAccess.file_exists(path)
		var bytes := PackedByteArray()
		if exists:
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null: return {"ok": false, "message": "Cannot read the existing " + filename + ". Existing files were not changed."}
			bytes = file.get_buffer(file.get_length())
			if file.get_error() != OK: return {"ok": false, "message": "Cannot back up " + filename + ". Existing files were not changed."}
		previous[path] = {"exists": exists, "bytes": bytes}
	return {"ok": true}

func rollback() -> Dictionary:
	var failures: Array[String] = []
	for path in previous:
		var record: Dictionary = previous[path]
		if record.exists:
			if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path) == record.bytes: continue
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null: failures.append(path); continue
			file.store_buffer(record.bytes); file.flush()
			if file.get_error() != OK: failures.append(path)
		elif FileAccess.file_exists(path):
			# This exact owned file did not exist before this failed Save.
			if DirAccess.remove_absolute(path) != OK: failures.append(path)
	return {"ok": failures.is_empty(), "message": "Save failed; previous section files were restored. Your edits are still open." if failures.is_empty() else "Save failed and some files could not be restored. Keep this section open and retry; affected files: " + ", ".join(failures)}
