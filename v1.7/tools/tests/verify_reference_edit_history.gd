extends SceneTree

## Temp towns only: Undo must restore text as well as fixed-name metadata.
const Town = preload("res://scripts/npcs/town_knowledge_store.gd")
const Locations = preload("res://scripts/npcs/locations/location_notes_store.gd")

class FailedMetadataLocations:
	extends "res://scripts/npcs/locations/location_notes_store.gd"
	var metadata_attempted := false
	func save_to_town(_directory: String, _data: Dictionary) -> Dictionary:
		metadata_attempted = true
		return {"ok": false, "message": "Fixture-only forced metadata failure."}

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAILED: " + message)

func _write(path: String, value: String) -> void:
	assert(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file.close()

func _run() -> void:
	create_timer(45).timeout.connect(func(): printerr("REFERENCE HISTORY TIMED OUT"); quit(1))
	var directory := ProjectSettings.globalize_path("res://tools/tests/output/reference-history-%s" % OS.get_process_id())
	_write(directory.path_join("town.json"), "{}")
	var source_a := directory.path_join("upload-a.txt")
	var source_b := directory.path_join("upload-b.txt")
	_write(source_a, "Albury town information A.")
	_write(source_b, "Albury town information B.")
	var source_a_hash := FileAccess.get_sha256(source_a)
	var source_b_hash := FileAccess.get_sha256(source_b)
	var town := Town.new()
	var imported_a := town.import_custom_text(directory, source_a, Town.empty_data())
	_check(imported_a.ok, "Town A import")
	var snapshot_a := town.load_from_town(directory)
	var invalid_wikipedia: Dictionary = snapshot_a.data.duplicate(true)
	invalid_wikipedia.wikipedia.url = "not a Wikipedia URL"
	var before_bad_import := FileAccess.get_file_as_string(directory.path_join("data/" + Town.FILE_NAME))
	var rejected_import := town.import_custom_text(directory, source_b, invalid_wikipedia)
	_check(not rejected_import.ok, "Town replacement rejects invalid Wikipedia metadata")
	_check(FileAccess.get_file_as_string(directory.path_join("data/" + Town.FILE_NAME)) == before_bad_import, "Failed town import preserves prior metadata")
	_check(town.load_from_town(directory).custom_text == snapshot_a.custom_text, "Failed town import preserves the previous stable-name text copy")
	_check(invalid_wikipedia.wikipedia.url == "not a Wikipedia URL" and invalid_wikipedia.custom_text == snapshot_a.data.custom_text, "Failed import does not mutate the caller's draft")
	var imported_b := town.import_custom_text(directory, source_b, imported_a.data)
	_check(imported_b.ok and town.load_from_town(directory).custom_text.contains(" B."), "Town B replaces fixed-name copy")
	var restored_a := town.restore_reference(directory, snapshot_a.data, snapshot_a.custom_text)
	_check(restored_a.ok and town.load_from_town(directory).custom_text == snapshot_a.custom_text, "Town Undo restores exact reopened text")
	_check(town.load_from_town(directory).data == snapshot_a.data, "Town Undo restores metadata")
	var owned_town: String = directory.path_join(snapshot_a.data.custom_text.relative_path)
	var town_hash := FileAccess.get_sha256(owned_town)
	var removed := town.remove_custom_text(directory, snapshot_a.data)
	_check(removed.ok and town.load_from_town(directory).custom_text.is_empty(), "Town removal detaches reference")
	_check(FileAccess.file_exists(owned_town) and FileAccess.get_sha256(owned_town) == town_hash, "Town removal keeps copied text")
	_check(town.restore_reference(directory, snapshot_a.data, snapshot_a.custom_text).ok and town.load_from_town(directory).custom_text.contains(" A."), "Undo town removal restores reference")
	_check(town.restore_reference(directory, imported_b.data, imported_b.custom_text).ok and town.load_from_town(directory).custom_text == imported_b.custom_text + "\n", "Town import-result buffer uses stored final newline")
	_check(town.restore_reference(directory, Town.empty_data(), "stale unreferenced buffer").ok and town.load_from_town(directory).custom_text.is_empty(), "Empty town reference detaches without writing stale text")
	_check(FileAccess.file_exists(owned_town), "Empty restore keeps town copy")
	var town_meta := directory.path_join("data/" + Town.FILE_NAME)
	var town_meta_before := FileAccess.get_file_as_string(town_meta)
	var town_text_before := FileAccess.get_file_as_string(owned_town)
	var unsafe: Dictionary = snapshot_a.data.duplicate(true)
	unsafe.custom_text.relative_path = "../unsafe.txt"
	_check(not town.restore_reference(directory, unsafe, snapshot_a.custom_text).ok, "Town unsafe path rejected")
	_check(not town.restore_reference(directory, snapshot_a.data, "Wrong snapshot text").ok, "Town fingerprint mismatch rejected")
	_check(not town.restore_reference(directory, snapshot_a.data, "x".repeat(Town.MAX_CUSTOM_BYTES + 1)).ok, "Oversized town text rejected")
	_check(not town.restore_reference(directory, snapshot_a.data, "binary" + String.chr(1)).ok, "Binary town text rejected")
	_check(not town.restore_reference(directory, snapshot_a.data, "").ok, "Missing town text rejected")
	_check(not town.restore_reference(directory, {"custom_text": "bad"}, snapshot_a.custom_text).ok, "Invalid town snapshot structure rejected")
	_check(not town.restore_reference(directory.path_join("missing"), snapshot_a.data, snapshot_a.custom_text).ok, "Missing town rejected")
	_check(FileAccess.get_file_as_string(town_meta) == town_meta_before and FileAccess.get_file_as_string(owned_town) == town_text_before, "Rejected town restores make no writes")

	var locations := Locations.new()
	var location_a := locations.import_text(directory, source_a, "pub", "The Pub", Locations.empty_data())
	_check(location_a.ok, "Location A import")
	var location_snapshot := locations.load_from_town(directory)
	var second_location := locations.import_text(directory, source_b, "cafe", "Cafe", location_a.data)
	_check(second_location.ok, "Second venue import")
	var all_snapshot := locations.load_from_town(directory)
	_check(locations.import_text(directory, source_b, "pub", "The Pub", second_location.data).ok and locations.load_from_town(directory).texts.pub.contains(" B."), "Venue copy overwritten by replacement")
	var restored_locations := locations.restore_references(directory, all_snapshot.data, all_snapshot.texts)
	_check(restored_locations.ok and locations.load_from_town(directory).texts == all_snapshot.texts, "Multi-venue Undo restores correct text for every ID")
	_check(locations.load_from_town(directory).data == all_snapshot.data, "Multi-venue Undo restores metadata")
	var failed_location_store := FailedMetadataLocations.new()
	var before_failed_location_save := FileAccess.get_file_as_string(directory.path_join("data/" + Locations.FILE_NAME))
	var failed_location_import := failed_location_store.import_text(directory, source_b, "pub", "Changed Pub", all_snapshot.data)
	_check(not failed_location_import.ok and failed_location_store.metadata_attempted, "Forced metadata failure occurs after location copy staging")
	_check(FileAccess.get_file_as_string(directory.path_join("data/" + Locations.FILE_NAME)) == before_failed_location_save, "Failed venue import preserves previous metadata")
	_check(locations.load_from_town(directory).texts.pub == all_snapshot.texts.pub, "Failed venue import rolls back the replaced owned text")
	_check(locations.load_from_town(directory).texts.cafe == all_snapshot.texts.cafe, "Failed venue import preserves unrelated location text")
	_check(all_snapshot.data.locations.pub.name == "The Pub", "Failed venue import preserves the caller's metadata draft")
	var detached: Dictionary = all_snapshot.data.duplicate(true)
	detached.locations.erase("pub")
	_check(locations.save_to_town(directory, detached).ok and not locations.load_from_town(directory).texts.has("pub"), "Venue removal detaches")
	var pub_copy := directory.path_join("data/location_notes/pub.txt")
	var cafe_copy := directory.path_join("data/location_notes/cafe.txt")
	_check(FileAccess.file_exists(pub_copy), "Venue detach keeps copy")
	_check(locations.restore_references(directory, all_snapshot.data, all_snapshot.texts).ok and locations.load_from_town(directory).texts.pub == location_snapshot.texts.pub, "Undo venue removal restores text")
	_check(locations.restore_references(directory, Locations.empty_data(), all_snapshot.texts).ok and locations.load_from_town(directory).texts.is_empty(), "Empty location snapshot ignores unused buffers")
	_check(FileAccess.file_exists(pub_copy) and FileAccess.file_exists(cafe_copy), "Empty location restore preserves unused copies")
	var location_meta := directory.path_join("data/" + Locations.FILE_NAME)
	var location_meta_before := FileAccess.get_file_as_string(location_meta)
	var pub_before := FileAccess.get_file_as_string(pub_copy)
	var cafe_before := FileAccess.get_file_as_string(cafe_copy)
	unsafe = all_snapshot.data.duplicate(true)
	unsafe.locations.pub.relative_path = "../unsafe.txt"
	_check(not locations.restore_references(directory, unsafe, all_snapshot.texts).ok, "Location unsafe path rejected")
	unsafe = all_snapshot.data.duplicate(true)
	unsafe.locations["CON"] = {"relative_path": "data/location_notes/CON.txt"}
	_check(not locations.restore_references(directory, unsafe, all_snapshot.texts).ok, "Reserved Windows location ID rejected")
	_check(not locations.restore_references(directory, all_snapshot.data, {"pub": all_snapshot.texts.pub}).ok, "Missing referenced venue text rejects whole batch")
	var bad_texts: Dictionary = all_snapshot.texts.duplicate(true)
	bad_texts.cafe = "wrong fingerprint"
	_check(not locations.restore_references(directory, all_snapshot.data, bad_texts).ok, "Mismatched second venue rejects whole batch")
	bad_texts.cafe = "x".repeat(Locations.MAX_BYTES + 1)
	_check(not locations.restore_references(directory, all_snapshot.data, bad_texts).ok, "Oversized venue text rejected")
	bad_texts.cafe = "binary" + String.chr(1)
	_check(not locations.restore_references(directory, all_snapshot.data, bad_texts).ok, "Binary venue text rejected")
	_check(not locations.restore_references(directory, all_snapshot.data, {"pub": 3, "cafe": all_snapshot.texts.cafe}).ok, "Non-text venue buffer rejected")
	_check(not locations.restore_references(directory.path_join("missing"), all_snapshot.data, all_snapshot.texts).ok, "Missing venue town rejected")
	_check(FileAccess.get_file_as_string(location_meta) == location_meta_before and FileAccess.get_file_as_string(pub_copy) == pub_before and FileAccess.get_file_as_string(cafe_copy) == cafe_before, "Rejected venue batches make no writes")
	_check(FileAccess.get_sha256(source_a) == source_a_hash and FileAccess.get_sha256(source_b) == source_b_hash, "All original source uploads remain unchanged")
	print("REFERENCE EDIT HISTORY: %d checks, %d failures; disposable fixture %s" % [checks, failures, directory])
	quit(0 if failures == 0 else 1)
