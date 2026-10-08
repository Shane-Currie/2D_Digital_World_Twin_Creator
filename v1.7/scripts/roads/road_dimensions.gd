class_name RoadDimensions
extends RefCounted

## Converts ordinary OSM road tags into conservative real-world dimensions.
## Explicit width wins, followed by lane count. Documented road-class defaults
## keep sparse maps usable without pretending the inferred value came from OSM.

const WALKING_HIGHWAYS := ["footway", "path", "pedestrian", "cycleway", "steps", "bridleway"]
const DEFAULT_SIDEWALK_HIGHWAYS := ["primary", "secondary", "tertiary", "residential", "unclassified"]


static func full_width_metres(tags: Dictionary) -> float:
	var explicit_width := _first_number(tags.get("width", ""))
	if explicit_width > 0.5:
		return clampf(explicit_width, 1.0, 40.0)
	var estimated_width := _first_number(tags.get("est_width", ""))
	if estimated_width > 0.5:
		return clampf(estimated_width, 1.0, 40.0)
	var highway := str(tags.get("highway", "")).to_lower()
	if highway in WALKING_HIGHWAYS:
		return _walking_width_metres(highway)
	var service := str(tags.get("service", "")).to_lower()
	if highway == "service":
		if service == "driveway":
			return 3.2
		if service == "alley":
			return 3.0
		if service == "parking_aisle":
			return 6.0
		return 4.5
	if highway == "living_street":
		return 5.0
	if highway == "track":
		return 3.2
	var lanes := lane_count(tags)
	var lane_width := 3.5 if highway in ["motorway", "motorway_link", "trunk", "trunk_link"] else (3.25 if highway in ["primary", "primary_link", "secondary", "secondary_link"] else 3.0)
	var shoulders := 1.0 if highway in ["motorway", "motorway_link", "trunk", "trunk_link"] else 0.0
	return clampf(float(lanes) * lane_width + shoulders, 3.0, 40.0)


static func half_width_metres(tags: Dictionary) -> float:
	return full_width_metres(tags) * 0.5


static func lane_count(tags: Dictionary) -> int:
	var lanes_value := _first_number(tags.get("lanes", ""))
	if lanes_value >= 1.0:
		return clampi(roundi(lanes_value), 1, 12)
	var highway := str(tags.get("highway", "")).to_lower()
	if highway in WALKING_HIGHWAYS or highway in ["service", "living_street", "track"]:
		return 1
	return 2


static func is_walkway(tags: Dictionary) -> bool:
	return str(tags.get("highway", "")).to_lower() in WALKING_HIGHWAYS


static func sidewalk_sides(tags: Dictionary) -> Array[String]:
	if is_walkway(tags):
		return []
	var general := str(tags.get("sidewalk", "")).to_lower()
	if general in ["no", "none", "separate"]:
		return []
	if general in ["both", "yes"]:
		return ["left", "right"]
	if general in ["left", "right"]:
		return [general]
	var result: Array[String] = []
	for side in ["left", "right"]:
		var value := str(tags.get("sidewalk:%s" % side, "")).to_lower()
		if value in ["yes", "both"]:
			result.append(side)
	if not result.is_empty():
		return result
	var highway := str(tags.get("highway", "")).to_lower()
	if highway == "living_street":
		return []
	return ["left", "right"] if highway in DEFAULT_SIDEWALK_HIGHWAYS else []


static func sidewalk_width_metres(tags: Dictionary) -> float:
	var explicit := _first_number(tags.get("sidewalk:width", ""))
	return clampf(explicit, 1.0, 5.0) if explicit > 0.5 else 1.8


static func width_source(tags: Dictionary) -> String:
	if _first_number(tags.get("width", "")) > 0.5:
		return "osm_width"
	if _first_number(tags.get("est_width", "")) > 0.5:
		return "osm_estimated_width"
	if _first_number(tags.get("lanes", "")) >= 1.0:
		return "osm_lanes"
	return "road_class_default"


static func _walking_width_metres(highway: String) -> float:
	match highway:
		"cycleway": return 2.5
		"pedestrian": return 4.0
		"steps": return 2.0
		"footway": return 1.8
		_: return 1.5


static func _first_number(value: Variant) -> float:
	var source := str(value).strip_edges().replace(",", ".")
	var numeric := ""
	var started := false
	for character in source:
		if character >= "0" and character <= "9" or character in [".", "-"]:
			numeric += character
			started = true
		elif started:
			break
	return float(numeric) if numeric.is_valid_float() else 0.0
