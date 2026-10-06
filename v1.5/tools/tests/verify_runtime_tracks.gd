extends SceneTree

const TracksScript = preload("res://scripts/runtime/runtime_tracks.gd")


func _initialize() -> void:
	var tracks = TracksScript.new()
	var actor := Node2D.new()
	actor.position = Vector2(100, 80)
	root.add_child(tracks)
	root.add_child(actor)
	var grass_test := func(_position: Vector2) -> bool: return true
	tracks.update_tracks(1.0, actor, true, false, grass_test)
	assert(tracks.marks.is_empty(), "Walking still left footprint marks.")
	tracks.update_tracks(1.0, actor, true, true, grass_test)
	assert(tracks.marks.size() == 2, "The wagon did not leave its paired tyre marks.")
	assert(tracks.marks.all(func(mark): return str(mark.kind) == "tire"), "A non-tyre track was created.")
	print("RUNTIME TRACKS PASSED: walking leaves no marks and driving still leaves paired tyre marks on grass.")
	quit(0)
