extends SceneTree

const BuildingInformationScript = preload("res://scripts/places/osm_building_information.gd")


func _initialize() -> void:
	var campus := {
		"id": "relation:700:0",
		"kind": "building",
		"tags": {
			"building": "yes", "amenity": "school", "name": "Example\nCollege",
			"addr:housenumber": "12", "addr:street": "Learning Road",
			"addr:suburb": "Testville", "addr:county": "Example County", "addr:country": "AU", "operator": "Example Education",
			"building:levels": "3", "wheelchair": "yes"
		},
		"points": _ring(0, 0, 100, 100),
		"holes": [_ring(40, 40, 60, 60)]
	}
	var shop := {
		"id": "701",
		"kind": "building",
		"tags": {"building": "retail", "shop": "bakery", "name": "Campus Bakery"},
		"points": _ring(10, 10, 30, 30),
		"holes": []
	}
	var unknown := {
		"id": "702",
		"kind": "building",
		"tags": {"building": "yes"},
		"points": _ring(120, 0, 150, 30),
		"holes": []
	}
	var underground := {
		"id": "703", "kind": "building", "tags": {"building": "yes", "location": "underground", "name": "Basement"},
		"points": _ring(160, 0, 190, 30), "holes": []
	}
	var features := [campus, shop, unknown, underground]
	var service = BuildingInformationScript.new()
	var built: Dictionary = service.build(features)
	assert(built.ok)
	assert(built.data.statistics.building_footprints == 4)
	assert(built.data.statistics.named_buildings == 3)
	assert(built.data.statistics.specifically_classified_buildings == 2)
	var campus_record: Dictionary = built.data.places[0]
	assert(campus_record.name == "Example College", "Imported line breaks were not safely flattened.")
	assert(campus_record.category == "School")
	assert(campus_record.address == "12 Learning Road, Testville, Example County, AU")
	assert(campus_record.operator == "Example Education")
	assert(campus_record.source_reference == "OSM relation 700")
	assert(campus_record.source_attribution == "© OpenStreetMap contributors")
	assert(built.data.places[2].category == "Building type not mapped in OSM")

	service.setup_spatial_index(features, built.data, func(value: Variant) -> Vector2:
		if value is Vector2:
			return value
		return Vector2(float(value[0]), float(value[1]))
	)
	assert(service.building_at(Vector2(15, 15)).name == "Campus Bakery", "The smallest visible overlapping footprint was not selected.")
	assert(service.building_at(Vector2(80, 80)).name == "Example College")
	assert(service.building_at(Vector2(50, 50)).is_empty(), "A courtyard hole incorrectly selected the surrounding building.")
	assert(service.building_at(Vector2(135, 15)).category == "Building type not mapped in OSM")
	assert(service.building_at(Vector2(175, 15)).is_empty(), "An underground-only building became selectable on the surface.")
	var hover_text := "\n".join(PackedStringArray(BuildingInformationScript.brief_popup_lines(campus_record)))
	var pinned_text := "\n".join(PackedStringArray(BuildingInformationScript.detailed_popup_lines(campus_record)))
	assert(hover_text.contains("© OpenStreetMap contributors") and hover_text.contains("Click to keep open"))
	assert(pinned_text.contains("PINNED") and pinned_text.contains("Click empty ground to close"))
	print("BUILDING INFORMATION PASSED: direct OSM tags, truthful unknowns, attribution, relation IDs, overlap selection, courtyard holes and hover/pin text.")
	quit(0)


func _ring(left: float, top: float, right: float, bottom: float) -> Array:
	return [Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom), Vector2(left, top)]
