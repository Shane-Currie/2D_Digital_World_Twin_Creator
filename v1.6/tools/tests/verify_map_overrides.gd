extends SceneTree

const MapOverrideStoreScript = preload("res://scripts/editor/map_override_store.gd")
const CollisionBuilderScript = preload("res://scripts/collisions/building_collision_builder.gd")


func _initialize() -> void:
	var store = MapOverrideStoreScript.new()
	var bounds := {"west": 149.0, "south": -35.01, "east": 149.01, "north": -35.0}
	var features: Array = [
		{
			"id": "way/house-1", "kind": "building", "tags": {"building": "house"},
			"points": [[149.001, -35.009], [149.002, -35.009], [149.002, -35.008], [149.001, -35.008], [149.001, -35.009]],
			"holes": []
		},
		{
			"id": "way/lake-1", "kind": "water", "tags": {"natural": "water"},
			"points": [[149.004, -35.008], [149.008, -35.008], [149.008, -35.004], [149.004, -35.004], [149.004, -35.008]],
			"holes": []
		},
		{
			"id": "way/road-1", "kind": "road", "tags": {"highway": "residential"},
			"points": [[149.003, -35.006], [149.009, -35.006]], "holes": []
		}
	]
	var data: Dictionary = store.empty_data(features, bounds)
	data.hidden_feature_ids = ["way/house-1"]
	data.zones = [
		{
			"id": "zone_0001", "mode": "allowed_ground",
			"points": [[149.005, -35.007], [149.007, -35.007], [149.007, -35.005], [149.005, -35.005], [149.005, -35.007]],
			"applies_to": ["player", "vehicle", "npc", "npr"], "source": "creator_authored"
		},
		{
			"id": "zone_0002", "mode": "blocked_water",
			"points": [[149.002, -35.004], [149.003, -35.004], [149.003, -35.003], [149.002, -35.003], [149.002, -35.004]],
			"applies_to": ["player", "vehicle", "npc", "npr"], "source": "creator_authored"
		}
	]

	var applied: Dictionary = store.apply(features, data)
	assert(applied.ok)
	assert(features[1].holes.is_empty(), "Applying corrections changed the raw OSM feature array.")
	assert(applied.features.filter(func(feature): return str(feature.id) == "way/house-1").is_empty(), "The hidden building remained active.")
	var corrected_water: Dictionary = applied.features.filter(func(feature): return str(feature.id) == "way/lake-1")[0]
	assert(corrected_water.holes.size() == 1, "Passable ground was not cut from mapped water.")
	assert(applied.features.any(func(feature): return str(feature.id) == "creator:zone_0002" and str(feature.kind) == "water"), "Blocked water was not added as collision geometry.")
	assert(int(applied.statistics.hidden_features) == 1)
	assert(int(applied.statistics.blocked_water_zones) == 1)
	assert(int(applied.statistics.applied_allowed_ground_zones) == 1)
	assert(int(applied.statistics.unresolved_overrides) == 0)

	var collisions: Dictionary = CollisionBuilderScript.new().build(applied.features, bounds)
	assert(collisions.ok)
	assert(collisions.data.buildings.is_empty(), "A hidden building still generated collision.")
	assert(collisions.data.water_areas.size() == 2, "Corrected and creator-authored water were not both generated.")
	var lake_collision: Dictionary = collisions.data.water_areas.filter(func(area): return str(area.id) == "way/lake-1")[0]
	assert(lake_collision.holes_metres.size() == 1, "Passable ground did not reach runtime water collision data.")

	var test_town := ProjectSettings.globalize_path("res://tools/tests/output/map-overrides-town")
	var save_result: Dictionary = store.save_to_town(test_town, data, features, bounds)
	assert(save_result.ok)
	var loaded: Dictionary = store.load_from_town(test_town, features, bounds)
	assert(loaded.ok and loaded.data.hidden_feature_ids == ["way/house-1"])
	assert(loaded.data.zones.size() == 2, "Saved correction zones did not reload.")
	assert(str(loaded.data.source_fingerprint) == store.source_fingerprint(features, bounds), "The saved OSM fingerprint is not deterministic.")

	var changed_features: Array = features.duplicate(true)
	changed_features.pop_front()
	var changed_load: Dictionary = store.load_from_town(test_town, changed_features, bounds)
	assert(changed_load.ok and not changed_load.warnings.is_empty(), "An OSM source change was not reported for review.")
	var changed_apply: Dictionary = store.apply(changed_features, changed_load.data)
	assert(int(changed_apply.statistics.unresolved_overrides) == 1, "A missing stable feature ID was not reported.")

	print("MAP OVERRIDES PASSED: building hide/restore data, water block/passable zones, persistence and source-change review.")
	quit(0)
