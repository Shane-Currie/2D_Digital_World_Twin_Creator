extends SceneTree

## Repeatable diagnostic for one saved town. It does not alter town files.
## Pass --play-town <directory>; run without --headless to include drawing.
const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 180


func _initialize() -> void:
	call_deferred("_measure_town")


func _measure_town() -> void:
	var packed: PackedScene = load("res://scenes/runtime/town_runtime.tscn")
	var runtime: Node2D = packed.instantiate()
	root.add_child(runtime)
	if runtime.get("player") == null or runtime.get("population") == null:
		printerr("PERFORMANCE CHECK FAILED: supply --play-town with a generated playable town.")
		quit(1)
		return
	for _frame in WARMUP_FRAMES:
		await process_frame
	runtime.population.benchmark_agent_updates = true
	var normal := await _sample_frames()
	runtime.population.benchmark_agent_updates = false
	var agent_update_ms_by_kind: Dictionary = {}
	for kind in runtime.population.benchmark_update_usec:
		agent_update_ms_by_kind[kind] = snappedf(float(runtime.population.benchmark_update_usec[kind]) / 1000.0 / SAMPLE_FRAMES, 0.01)
	runtime.population.visible = false
	var population_hidden := await _sample_frames()
	runtime.population.set_process(false)
	var without_population := await _sample_frames()
	runtime.renderer.visible = false
	var without_population_or_map := await _sample_frames()
	print("RUNTIME PERFORMANCE: " + JSON.stringify({
		"town": str(runtime.town.get("display_name", "")),
		"agent_count": runtime.population.agents.size(),
		"agent_update_ms_by_kind": agent_update_ms_by_kind,
		"normal": normal,
		"population_hidden": population_hidden,
		"population_paused": without_population,
		"population_paused_and_map_hidden": without_population_or_map,
		"note": "Diagnostic comparisons; later phases intentionally remove work and are not gameplay modes."
	}))
	quit(0)


func _sample_frames() -> Dictionary:
	var total_process_ms := 0.0
	var total_physics_ms := 0.0
	var total_fps := 0.0
	var total_draw_calls := 0.0
	var started := Time.get_ticks_usec()
	for _frame in SAMPLE_FRAMES:
		await process_frame
		total_process_ms += float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		total_physics_ms += float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		total_fps += float(Performance.get_monitor(Performance.TIME_FPS))
		total_draw_calls += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return {
		"sample_frames": SAMPLE_FRAMES,
		"wall_seconds": snappedf(float(Time.get_ticks_usec() - started) / 1000000.0, 0.001),
		"average_fps": snappedf(total_fps / SAMPLE_FRAMES, 0.1),
		"average_process_ms": snappedf(total_process_ms / SAMPLE_FRAMES, 0.01),
		"average_physics_ms": snappedf(total_physics_ms / SAMPLE_FRAMES, 0.01),
		"average_draw_calls": roundi(total_draw_calls / SAMPLE_FRAMES)
	}
