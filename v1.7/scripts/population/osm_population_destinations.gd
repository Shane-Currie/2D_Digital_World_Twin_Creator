class_name OsmPopulationDestinations
extends RefCounted

## Converts OSM uses attached directly to building footprints into optional
## NPC/NPR destinations, then links each one to the nearest imported pedestrian
## node. This is deterministic and never invents an entrance or building use.

const SOURCE_ATTRIBUTION := "© OpenStreetMap contributors"
const MAX_ROUTE_LINK_METRES := 250.0
const GRID_CELL_METRES := 250.0

const RESIDENTIAL_BUILDINGS := [
	"apartments", "bungalow", "cabin", "detached", "dormitory", "house",
	"residential", "semidetached_house", "static_caravan", "terrace"
]
const EDUCATION_AMENITIES := ["college", "kindergarten", "school", "university"]
const HEALTH_AMENITIES := ["clinic", "dentist", "doctors", "hospital", "pharmacy", "veterinary"]
const HOSPITALITY_AMENITIES := ["bar", "biergarten", "cafe", "fast_food", "food_court", "nightclub", "pub", "restaurant"]
const CIVIC_AMENITIES := [
	"arts_centre", "community_centre", "courthouse", "fire_station", "library",
	"place_of_worship", "police", "post_office", "social_facility", "townhall"
]


func build(features: Array, navigation: Dictionary, place_information: Dictionary = {}) -> Dictionary:
	var pedestrian: Dictionary = navigation.get("pedestrian", {})
	var node_grid := _node_grid(pedestrian.get("nodes", []))
	var place_by_feature: Dictionary = {}
	for record_value in place_information.get("places", []):
		var record: Dictionary = record_value
		place_by_feature[str(record.get("feature_id", ""))] = record
	var destinations: Array[Dictionary] = []
	var counts: Dictionary = {}
	var too_far := 0
	for feature_value in features:
		var feature: Dictionary = feature_value
		if str(feature.get("kind", "")) not in ["building", "fixed_footprint"]:
			continue
		var classification := classify_tags(feature.get("tags", {}))
		if classification.is_empty():
			continue
		var centre := _feature_centre(feature.get("points", []))
		if centre == Vector2.INF:
			continue
		var nearest := _nearest_node(centre, node_grid)
		if nearest.is_empty() or float(nearest.distance_metres) > MAX_ROUTE_LINK_METRES:
			too_far += 1
			continue
		var feature_id := str(feature.get("id", ""))
		var place: Dictionary = place_by_feature.get(feature_id, {})
		var destination := {
			"id": "osm_destination:%s" % feature_id,
			"feature_id": feature_id,
			"name": str(place.get("name", _safe_name(feature.get("tags", {})))),
			"category": str(classification.category),
			"category_source_tag": str(classification.source_tag),
			"location": {"longitude": centre.x, "latitude": centre.y},
			"pedestrian_node_id": int(nearest.id),
			"route_link_distance_metres": snappedf(float(nearest.distance_metres), 0.1),
			"source_attribution": SOURCE_ATTRIBUTION,
			"information_scope": "osm_tags_on_this_footprint",
			"entrance_status": "not_mapped_or_not_selected"
		}
		destinations.append(destination)
		counts[destination.category] = int(counts.get(destination.category, 0)) + 1
	return {
		"ok": true,
		"data": {
			"schema_version": 1,
			"kind": "osm_population_destinations",
			"source_attribution": SOURCE_ATTRIBUTION,
			"destinations": destinations,
			"statistics": {
				"destination_count": destinations.size(),
				"category_counts": counts,
				"tagged_footprints_without_nearby_pedestrian_route": too_far
			},
			"assumptions": {
				"building_use": "direct_osm_footprint_tags_only",
				"route_link": "nearest_pedestrian_node_within_%d_metres" % int(MAX_ROUTE_LINK_METRES),
				"entrances": "not_inferred"
			}
		}
	}


static func classify_tags(tags: Dictionary) -> Dictionary:
	var amenity := str(tags.get("amenity", "")).to_lower()
	var healthcare := str(tags.get("healthcare", "")).to_lower()
	var building := str(tags.get("building", "")).to_lower()
	var tourism := str(tags.get("tourism", "")).to_lower()
	var landuse := str(tags.get("landuse", "")).to_lower()
	if amenity in EDUCATION_AMENITIES or building in ["college", "kindergarten", "school", "university"]:
		return {"category": "education", "source_tag": "amenity=%s" % amenity if amenity in EDUCATION_AMENITIES else "building=%s" % building}
	if not healthcare.is_empty() or amenity in HEALTH_AMENITIES or building in ["hospital", "clinic"]:
		return {"category": "health", "source_tag": "healthcare=%s" % healthcare if not healthcare.is_empty() else ("amenity=%s" % amenity if amenity in HEALTH_AMENITIES else "building=%s" % building)}
	if tags.has("shop") or building in ["retail", "supermarket"] or landuse == "retail":
		return {"category": "retail", "source_tag": "shop=%s" % str(tags.get("shop", "yes")) if tags.has("shop") else ("building=%s" % building if building in ["retail", "supermarket"] else "landuse=retail")}
	if amenity in HOSPITALITY_AMENITIES or tourism in ["hotel", "hostel", "motel", "guest_house"]:
		return {"category": "hospitality", "source_tag": "amenity=%s" % amenity if amenity in HOSPITALITY_AMENITIES else "tourism=%s" % tourism}
	if tags.has("office") or building in ["office", "commercial"] or landuse == "commercial":
		return {"category": "office", "source_tag": "office=%s" % str(tags.get("office", "yes")) if tags.has("office") else ("building=%s" % building if building in ["office", "commercial"] else "landuse=commercial")}
	if amenity in CIVIC_AMENITIES or building in ["civic", "public", "government"]:
		return {"category": "civic", "source_tag": "amenity=%s" % amenity if amenity in CIVIC_AMENITIES else "building=%s" % building}
	if tags.has("leisure") or tourism in ["attraction", "gallery", "museum", "theme_park", "zoo"]:
		return {"category": "recreation", "source_tag": "leisure=%s" % str(tags.get("leisure", "yes")) if tags.has("leisure") else "tourism=%s" % tourism}
	if tags.has("industrial") or tags.has("craft") or building in ["factory", "industrial", "warehouse"] or landuse == "industrial":
		return {"category": "industrial", "source_tag": "industrial=%s" % str(tags.get("industrial", "yes")) if tags.has("industrial") else ("craft=%s" % str(tags.craft) if tags.has("craft") else ("building=%s" % building if building in ["factory", "industrial", "warehouse"] else "landuse=industrial"))}
	if tags.has("public_transport") or str(tags.get("railway", "")).to_lower() in ["halt", "station"] or building == "train_station":
		return {"category": "transport", "source_tag": "public_transport=%s" % str(tags.get("public_transport", "yes")) if tags.has("public_transport") else ("railway=%s" % str(tags.railway) if tags.has("railway") else "building=train_station")}
	if building in RESIDENTIAL_BUILDINGS or landuse == "residential":
		return {"category": "residential", "source_tag": "building=%s" % building if building in RESIDENTIAL_BUILDINGS else "landuse=residential"}
	return {}


func _node_grid(nodes: Array) -> Dictionary:
	var cells: Dictionary = {}
	for node_value in nodes:
		var node: Dictionary = node_value
		var location := Vector2(float(node.get("longitude", 0.0)), float(node.get("latitude", 0.0)))
		var metres := _metres(location)
		var cell := Vector2i(floori(metres.x / GRID_CELL_METRES), floori(metres.y / GRID_CELL_METRES))
		cells.get_or_add(cell, []).append({"id": int(node.get("id", -1)), "location": location})
	return cells


func _nearest_node(location: Vector2, cells: Dictionary) -> Dictionary:
	var metres := _metres(location)
	var cell := Vector2i(floori(metres.x / GRID_CELL_METRES), floori(metres.y / GRID_CELL_METRES))
	var best: Dictionary = {}
	var best_distance := INF
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			for node_value in cells.get(Vector2i(x, y), []):
				var node: Dictionary = node_value
				var distance := _distance_metres(location, node.location)
				if distance < best_distance:
					best_distance = distance
					best = {"id": int(node.id), "distance_metres": distance}
	return best


func _feature_centre(points: Array) -> Vector2:
	if points.is_empty():
		return Vector2.INF
	var first := _location(points[0])
	var west := first.x
	var east := first.x
	var south := first.y
	var north := first.y
	for value in points:
		var point := _location(value)
		west = minf(west, point.x)
		east = maxf(east, point.x)
		south = minf(south, point.y)
		north = maxf(north, point.y)
	return Vector2((west + east) * 0.5, (south + north) * 0.5)


func _location(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2(float(value[0]), float(value[1]))


func _metres(location: Vector2) -> Vector2:
	return Vector2(location.x * 111320.0 * cos(deg_to_rad(location.y)), location.y * 110540.0)


func _distance_metres(first: Vector2, second: Vector2) -> float:
	var mean_latitude := deg_to_rad((first.y + second.y) * 0.5)
	var dx := (second.x - first.x) * 111320.0 * cos(mean_latitude)
	var dy := (second.y - first.y) * 110540.0
	return Vector2(dx, dy).length()


func _safe_name(tags: Dictionary) -> String:
	var name := str(tags.get("name", tags.get("addr:housename", ""))).strip_edges()
	return name if not name.is_empty() else "Unnamed %s destination" % str(classify_tags(tags).get("category", "mapped"))
