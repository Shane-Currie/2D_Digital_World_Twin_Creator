class_name OsmImporter
extends RefCounted

## Reads ordinary OpenStreetMap XML files without changing the originals.
## Keeps roads, structures and environmental geometry from standard OSM tags.
## All classification is deterministic and map-independent; no town coordinates or
## model-generated interpretation are used.
const LandCoverScript = preload("res://scripts/land_cover/land_cover.gd")

func parse_files(file_paths: PackedStringArray) -> Dictionary:
	if file_paths.is_empty():
		return {"ok": false, "message": "Choose at least one .osm file."}

	var nodes_by_id: Dictionary = {}
	var node_tags_by_id: Dictionary = {}
	var ways_by_id: Dictionary = {}
	var relations_by_id: Dictionary = {}
	var declared_bounds: Dictionary = {}
	var warnings: Array[String] = []

	for file_path in file_paths:
		var result := _read_file(file_path, nodes_by_id, node_tags_by_id, ways_by_id, relations_by_id, declared_bounds)
		if not result.ok:
			return result
		if result.message != "":
			warnings.append(result.message)

	var features: Array[Dictionary] = []
	var building_count := 0
	var road_count := 0
	var land_cover_count := 0
	var water_area_count := 0
	var waterway_count := 0
	var overhead_structure_count := 0
	var bridge_road_count := 0
	var tunnel_road_count := 0
	var incomplete_water_relation_count := 0
	var inferred_clipped_water_area_count := 0
	var inferred_coastal_water_area_count := 0
	var unresolved_water_relation_count := 0
	var west := INF
	var south := INF
	var east := -INF
	var north := -INF
	var relation_member_ways: Dictionary = {}
	var inferred_water_keys: Dictionary = {}

	for relation_value in relations_by_id.values():
		var relation: Dictionary = relation_value
		var relation_tags: Dictionary = relation.tags
		if str(relation_tags.get("type", "")) != "multipolygon":
			continue
		var relation_kind := _area_kind(relation_tags)
		if relation_kind.is_empty():
			continue
		var outer_references: Array[String] = []
		var inner_references: Array[String] = []
		var missing_way_count := 0
		var missing_outer_way_count := 0
		var missing_inner_way_count := 0
		var way_member_count := 0
		for member_value in relation.members:
			var member: Dictionary = member_value
			if member.type != "way":
				continue
			way_member_count += 1
			if relation_kind != "land_cover":
				relation_member_ways[member.reference + ":" + relation_kind] = true
			if not ways_by_id.has(member.reference):
				missing_way_count += 1
				if member.role == "inner":
					missing_inner_way_count += 1
				else:
					missing_outer_way_count += 1
			if member.role == "inner":
				inner_references.append(member.reference)
			else:
				outer_references.append(member.reference)
		# A partial harbour/lake relation cannot safely become a solid collision
		# area. Record it explicitly rather than joining whichever fragments happen
		# to be present in a bounded export.
		if relation_kind == "water" and missing_way_count > 0:
			incomplete_water_relation_count += 1
		if relation_kind == "water" and missing_outer_way_count > 0:
			var water_name := str(relation_tags.get("name", "water relation %s" % relation.id))
			var clipped_areas := _infer_clipped_water_areas(outer_references, ways_by_id, nodes_by_id, declared_bounds)
			if clipped_areas.is_empty():
				unresolved_water_relation_count += 1
				warnings.append("%s is incomplete: %d of %d OSM boundary ways are missing. Its local water side was ambiguous, so it was not made blocking." % [water_name, missing_way_count, way_member_count])
			else:
				for clipped_index in clipped_areas.size():
					var clipped_points: Array = clipped_areas[clipped_index]
					var clipped_key := _polygon_identity(clipped_points)
					if inferred_water_keys.has(clipped_key):
						continue
					inferred_water_keys[clipped_key] = true
					features.append({
						"id": "relation:%s:clipped:%d" % [relation.id, clipped_index],
						"kind": "water", "tags": relation_tags, "node_ids": [],
						"points": clipped_points, "holes": [],
						"geometry_quality": "clipped_osm_boundary_inference"
					})
					water_area_count += 1
					inferred_clipped_water_area_count += 1
					for location in clipped_points:
						west = minf(west, location.x)
						east = maxf(east, location.x)
						south = minf(south, location.y)
						north = maxf(north, location.y)
				warnings.append("%s was clipped by this OSM export. Creator Studio reconstructed %d local water section(s) from its supplied shoreline and map boundary; review them in the preview." % [water_name, clipped_areas.size()])
			continue
		if relation_kind == "water" and missing_inner_way_count > 0:
			var inner_water_name := str(relation_tags.get("name", "water relation %s" % relation.id))
			warnings.append("%s has a complete water edge, but %d inner island/land boundary members are absent from this export. The outer water remains safely blocking; those uncertain inner patches stay water until a more complete export is used." % [inner_water_name, missing_inner_way_count])
		var outer_rings := _assemble_rings(outer_references, ways_by_id, nodes_by_id)
		var inner_rings := _assemble_rings(inner_references, ways_by_id, nodes_by_id)
		if relation_kind == "land_cover" and (missing_way_count > 0 or _has_missing_nodes(outer_references + inner_references, ways_by_id, nodes_by_id) or _assemble_chains(outer_references, ways_by_id, nodes_by_id).size() != outer_rings.size() or _assemble_chains(inner_references, ways_by_id, nodes_by_id).size() != inner_rings.size()):
			warnings.append("Land cover relation %s has incomplete boundaries and was omitted. Re-export with complete members to show this area." % relation.id)
			continue
		if outer_rings.is_empty():
			warnings.append("%s relation %s could not be joined into a closed outer shape." % [relation_kind.capitalize(), relation.id])
			if relation_kind == "water":
				incomplete_water_relation_count += 1
			continue
		for outer_index in outer_rings.size():
			if relation_kind == "land_cover":
				for reference in outer_references:
					relation_member_ways[reference + ":land_cover:" + LandCoverScript.classify(relation_tags)] = true
			var outer: Dictionary = outer_rings[outer_index]
			var holes: Array[Array] = []
			var outer_polygon := PackedVector2Array(outer.points)
			for inner_value in inner_rings:
				var inner: Dictionary = inner_value
				if not inner.points.is_empty() and Geometry2D.is_point_in_polygon(inner.points[0], outer_polygon):
					holes.append(inner.points)
			var feature_id := "relation:%s" % relation.id
			if outer_rings.size() > 1:
				feature_id += ":%d" % outer_index
			features.append({
				"id": feature_id,
				"kind": relation_kind,
				"tags": relation_tags,
				"node_ids": outer.node_ids,
				"points": outer.points,
				"holes": holes,
				"source_relation_id": relation.id
			})
			match relation_kind:
				"building": building_count += 1
				"overhead_structure": overhead_structure_count += 1
				"water": water_area_count += 1
				"land_cover": land_cover_count += 1
			for location in outer.points:
				west = minf(west, location.x)
				east = maxf(east, location.x)
				south = minf(south, location.y)
				north = maxf(north, location.y)

	# OSM coastline ways are deliberately open: land is on one side and ocean on
	# the other. Join the local shoreline and close it only against this export's
	# declared rectangle, using the same mapped-land evidence as clipped harbour
	# relations. This supplies the ocean fill that a coastline polyline alone lacks.
	var coastline_references: Array[String] = []
	for way_value in ways_by_id.values():
		var coastline_way: Dictionary = way_value
		if str(coastline_way.tags.get("natural", "")).to_lower() == "coastline":
			coastline_references.append(str(coastline_way.id))
	var coastal_areas := _infer_clipped_water_areas(coastline_references, ways_by_id, nodes_by_id, declared_bounds)
	for coastal_index in coastal_areas.size():
		var coastal_points: Array = coastal_areas[coastal_index]
		var coastal_key := _polygon_identity(coastal_points)
		if inferred_water_keys.has(coastal_key):
			continue
		inferred_water_keys[coastal_key] = true
		features.append({
			"id": "coastline:clipped:%d" % coastal_index,
			"kind": "water", "tags": {"natural": "water", "water": "ocean", "source": "osm_coastline"},
			"node_ids": [], "points": coastal_points, "holes": [],
			"geometry_quality": "clipped_osm_coastline_inference"
		})
		water_area_count += 1
		inferred_coastal_water_area_count += 1
	if inferred_coastal_water_area_count > 0:
		warnings.append("Creator Studio filled %d coastal ocean section(s) from supplied OSM coastline ways and the map export boundary." % inferred_coastal_water_area_count)

	for way_value in ways_by_id.values():
		var way: Dictionary = way_value
		var tags: Dictionary = way.tags
		var closed: bool = way.node_ids.size() >= 4 and way.node_ids[0] == way.node_ids[way.node_ids.size() - 1]
		var kind := _way_kind(tags, closed)
		if kind in ["building", "overhead_structure", "water", "land_cover"]:
			var member_key := str(way.id) + ":" + kind + (":" + LandCoverScript.classify(tags) if kind == "land_cover" else "")
			if relation_member_ways.has(member_key):
				continue
		if kind.is_empty():
			continue
		if kind == "land_cover" and _has_missing_nodes([str(way.id)], ways_by_id, nodes_by_id):
			warnings.append("Land cover way %s has missing boundary points and was omitted." % way.id)
			continue

		var points: Array[Vector2] = []
		for node_id in way.node_ids:
			if nodes_by_id.has(node_id):
				var location: Vector2 = nodes_by_id[node_id]
				points.append(location)
				west = minf(west, location.x)
				east = maxf(east, location.x)
				south = minf(south, location.y)
				north = maxf(north, location.y)

		var minimum_points := 3 if kind in ["building", "overhead_structure", "water"] else 2
		if points.size() < minimum_points:
			continue
		match kind:
			"building": building_count += 1
			"overhead_structure": overhead_structure_count += 1
			"water": water_area_count += 1
			"land_cover": land_cover_count += 1
			"waterway", "coastline": waterway_count += 1
			"road":
				road_count += 1
				if _tag_enabled(tags.get("bridge", "")):
					bridge_road_count += 1
				if _tag_enabled(tags.get("tunnel", "")):
					tunnel_road_count += 1
		var feature_node_tags: Dictionary = {}
		if kind == "road":
			for node_id in way.node_ids:
				if node_tags_by_id.has(node_id):
					feature_node_tags[node_id] = node_tags_by_id[node_id]
		features.append({
			"id": way.id,
			"kind": kind,
			"tags": tags,
			"node_ids": way.node_ids.duplicate(),
			"node_tags": feature_node_tags,
			"points": points,
			"holes": []
		})

	if features.is_empty():
		return {
			"ok": false,
			"message": "No building footprints or roads were found in the selected files."
		}

	var output_bounds := declared_bounds.duplicate(true) if not declared_bounds.is_empty() else {"west": west, "south": south, "east": east, "north": north}
	return {
		"ok": true,
		"message": "",
		"features": features,
		"bounds": output_bounds,
		"statistics": {
			"source_files": file_paths.size(),
			"osm_nodes": nodes_by_id.size(),
			"osm_ways": ways_by_id.size(),
			"osm_relations": relations_by_id.size(),
			"buildings": building_count,
			"roads": road_count,
			"land_cover_areas": land_cover_count,
			"water_areas": water_area_count,
			"linear_waterways_and_coastlines": waterway_count,
			"overhead_structures": overhead_structure_count,
			"bridge_roads": bridge_road_count,
			"tunnel_roads": tunnel_road_count,
			"incomplete_water_relations": incomplete_water_relation_count,
			"inferred_clipped_water_areas": inferred_clipped_water_area_count,
			"inferred_coastal_water_areas": inferred_coastal_water_area_count,
			"unresolved_water_relations": unresolved_water_relation_count
		},
		"warnings": warnings
	}


func _has_missing_nodes(references: Array, ways: Dictionary, nodes: Dictionary) -> bool:
	for reference in references:
		if not ways.has(reference):
			return true
		for node_id in ways[reference].node_ids:
			if not nodes.has(node_id):
				return true
	return false


func _area_kind(tags: Dictionary) -> String:
	if tags.has("building"):
		return "overhead_structure" if str(tags.get("building", "")).to_lower() == "roof" else "building"
	if _is_water_area(tags):
		return "water"
	if not LandCoverScript.classify(tags).is_empty():
		return "land_cover"
	return ""


func _way_kind(tags: Dictionary, closed: bool) -> String:
	if tags.has("building"):
		return "overhead_structure" if str(tags.get("building", "")).to_lower() == "roof" else "building"
	if tags.has("highway"):
		return "road"
	if closed and _is_water_area(tags):
		return "water"
	if closed and not LandCoverScript.classify(tags).is_empty():
		return "land_cover"
	var waterway := str(tags.get("waterway", "")).to_lower()
	if waterway in ["river", "stream", "canal", "drain", "ditch"]:
		return "waterway"
	if str(tags.get("natural", "")).to_lower() == "coastline":
		return "coastline"
	return ""


func _is_water_area(tags: Dictionary) -> bool:
	var natural := str(tags.get("natural", "")).to_lower()
	var landuse := str(tags.get("landuse", "")).to_lower()
	var waterway := str(tags.get("waterway", "")).to_lower()
	var leisure := str(tags.get("leisure", "")).to_lower()
	return natural == "water" or tags.has("water") or landuse == "reservoir" or waterway == "riverbank" or leisure == "swimming_pool"


func _tag_enabled(value: Variant) -> bool:
	var text := str(value).to_lower()
	return not text.is_empty() and text not in ["no", "false", "0"]


func _infer_clipped_water_areas(references: Array[String], ways_by_id: Dictionary, nodes_by_id: Dictionary, bounds: Dictionary) -> Array[Array]:
	var result: Array[Array] = []
	if bounds.is_empty():
		return result
	for chain_value in _assemble_chains(references, ways_by_id, nodes_by_id):
		var chain: Dictionary = chain_value
		if bool(chain.closed):
			continue
		for clipped_value in _clip_chain_to_bounds(chain.points, bounds):
			var clipped: PackedVector2Array = clipped_value
			if clipped.size() < 2 or not _point_on_bounds(clipped[0], bounds) or not _point_on_bounds(clipped[clipped.size() - 1], bounds):
				continue
			var clockwise := _closed_candidate(clipped, _boundary_path(clipped[clipped.size() - 1], clipped[0], bounds, true))
			var counter_clockwise := _closed_candidate(clipped, _boundary_path(clipped[clipped.size() - 1], clipped[0], bounds, false))
			if clockwise.size() < 3 or counter_clockwise.size() < 3:
				continue
			var clockwise_score := _land_score(clockwise, ways_by_id, nodes_by_id)
			var counter_score := _land_score(counter_clockwise, ways_by_id, nodes_by_id)
			var selected := PackedVector2Array()
			if clockwise_score != counter_score:
				selected = clockwise if clockwise_score < counter_score else counter_clockwise
			else:
				var clockwise_area := absf(_signed_area(clockwise))
				var counter_area := absf(_signed_area(counter_clockwise))
				var bounds_area := (float(bounds.east) - float(bounds.west)) * (float(bounds.north) - float(bounds.south))
				var smaller := clockwise if clockwise_area < counter_area else counter_clockwise
				if absf(_signed_area(smaller)) <= bounds_area * 0.45:
					selected = smaller
			if selected.size() >= 3:
				result.append(Array(selected))
	return result


func _assemble_chains(references: Array[String], ways_by_id: Dictionary, nodes_by_id: Dictionary) -> Array[Dictionary]:
	var remaining: Array[Array] = []
	for reference in references:
		if ways_by_id.has(reference):
			var node_ids: Array = ways_by_id[reference].node_ids.duplicate()
			if node_ids.size() >= 2:
				remaining.append(node_ids)
	var chains: Array[Dictionary] = []
	while not remaining.is_empty():
		var chain: Array = remaining.pop_front()
		var joined := true
		while chain.size() >= 2 and chain[0] != chain[chain.size() - 1] and joined:
			joined = false
			for index in remaining.size():
				var candidate: Array = remaining[index]
				if chain[chain.size() - 1] == candidate[0]:
					chain.append_array(candidate.slice(1))
				elif chain[chain.size() - 1] == candidate[candidate.size() - 1]:
					candidate.reverse()
					chain.append_array(candidate.slice(1))
				elif chain[0] == candidate[candidate.size() - 1]:
					var prefix: Array = candidate.slice(0, candidate.size() - 1)
					prefix.append_array(chain)
					chain = prefix
				elif chain[0] == candidate[0]:
					candidate.reverse()
					var prefix: Array = candidate.slice(0, candidate.size() - 1)
					prefix.append_array(chain)
					chain = prefix
				else:
					continue
				remaining.remove_at(index)
				joined = true
				break
		var points := PackedVector2Array()
		for node_id in chain:
			if nodes_by_id.has(node_id):
				points.append(nodes_by_id[node_id])
		if points.size() >= 2:
			chains.append({"points": points, "closed": chain[0] == chain[chain.size() - 1]})
	return chains


func _clip_chain_to_bounds(points: PackedVector2Array, bounds: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	for index in range(points.size() - 1):
		var clipped := _clip_segment(points[index], points[index + 1], bounds)
		if clipped.size() != 2:
			if current.size() >= 2:
				result.append(current)
			current = PackedVector2Array()
			continue
		if current.is_empty() or not current[current.size() - 1].is_equal_approx(clipped[0]):
			if current.size() >= 2:
				result.append(current)
			current = PackedVector2Array([clipped[0]])
		current.append(clipped[1])
	if current.size() >= 2:
		result.append(current)
	return result


func _clip_segment(first: Vector2, second: Vector2, bounds: Dictionary) -> PackedVector2Array:
	var delta := second - first
	var t_min := 0.0
	var t_max := 1.0
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [first.x - float(bounds.west), float(bounds.east) - first.x, first.y - float(bounds.south), float(bounds.north) - first.y]
	for index in 4:
		if is_zero_approx(float(p[index])):
			if float(q[index]) < 0.0:
				return PackedVector2Array()
			continue
		var ratio := float(q[index]) / float(p[index])
		if float(p[index]) < 0.0:
			t_min = maxf(t_min, ratio)
		else:
			t_max = minf(t_max, ratio)
		if t_min > t_max:
			return PackedVector2Array()
	return PackedVector2Array([first + delta * t_min, first + delta * t_max])


func _boundary_path(from: Vector2, to: Vector2, bounds: Dictionary, clockwise: bool) -> PackedVector2Array:
	if not clockwise:
		var reverse_path := _boundary_path(to, from, bounds, true)
		reverse_path.reverse()
		return reverse_path
	var width := float(bounds.east) - float(bounds.west)
	var height := float(bounds.north) - float(bounds.south)
	var perimeter := 2.0 * (width + height)
	var from_t := _boundary_position(from, bounds)
	var to_t := _boundary_position(to, bounds)
	if to_t <= from_t:
		to_t += perimeter
	var result := PackedVector2Array()
	for corner in [width, width + height, 2.0 * width + height, perimeter, perimeter + width, perimeter + width + height]:
		if float(corner) > from_t and float(corner) < to_t:
			result.append(_boundary_point(fmod(float(corner), perimeter), bounds))
	result.append(to)
	return result


func _boundary_position(point: Vector2, bounds: Dictionary) -> float:
	var west := float(bounds.west)
	var south := float(bounds.south)
	var east := float(bounds.east)
	var north := float(bounds.north)
	var distances := [absf(point.y - south), absf(point.x - east), absf(point.y - north), absf(point.x - west)]
	var edge := distances.find(distances.min())
	if edge == 0:
		return clampf(point.x - west, 0.0, east - west)
	if edge == 1:
		return east - west + clampf(point.y - south, 0.0, north - south)
	if edge == 2:
		return east - west + north - south + clampf(east - point.x, 0.0, east - west)
	return 2.0 * (east - west) + north - south + clampf(north - point.y, 0.0, north - south)


func _boundary_point(position: float, bounds: Dictionary) -> Vector2:
	var west := float(bounds.west)
	var south := float(bounds.south)
	var east := float(bounds.east)
	var north := float(bounds.north)
	var width := east - west
	var height := north - south
	if position <= width:
		return Vector2(west + position, south)
	position -= width
	if position <= height:
		return Vector2(east, south + position)
	position -= height
	if position <= width:
		return Vector2(east - position, north)
	return Vector2(west, north - (position - width))


func _closed_candidate(chain: PackedVector2Array, closure: PackedVector2Array) -> PackedVector2Array:
	var result := chain.duplicate()
	result.append_array(closure)
	if result.size() > 2 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


func _point_on_bounds(point: Vector2, bounds: Dictionary) -> bool:
	# OSM coordinates are held in Vector2 (32-bit components), so values near
	# longitude 151 can be rounded by roughly one metre. This tolerance only
	# recognises points produced by our bounds clipper; it does not extend or
	# invent shoreline geometry.
	const EPSILON := 0.00002
	return absf(point.x - float(bounds.west)) <= EPSILON or absf(point.x - float(bounds.east)) <= EPSILON or absf(point.y - float(bounds.south)) <= EPSILON or absf(point.y - float(bounds.north)) <= EPSILON


func _land_score(polygon: PackedVector2Array, ways_by_id: Dictionary, nodes_by_id: Dictionary) -> int:
	var score := 0
	for way_value in ways_by_id.values():
		var way: Dictionary = way_value
		var tags: Dictionary = way.tags
		var weight := 0
		if tags.has("building") and str(tags.get("building", "")).to_lower() != "roof":
			weight = 12
		elif tags.has("highway") and not _tag_enabled(tags.get("bridge", "")) and not _tag_enabled(tags.get("tunnel", "")):
			weight = 1
		if weight == 0:
			continue
		var centre := Vector2.ZERO
		var count := 0
		for node_id in way.node_ids:
			if nodes_by_id.has(node_id):
				centre += nodes_by_id[node_id]
				count += 1
		if count > 0 and Geometry2D.is_point_in_polygon(centre / float(count), polygon):
			score += weight
	return score


func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size():
		var next := (index + 1) % polygon.size()
		area += polygon[index].x * polygon[next].y - polygon[next].x * polygon[index].y
	return area * 0.5


func _polygon_identity(points: Array) -> String:
	var west := INF
	var south := INF
	var east := -INF
	var north := -INF
	for point in points:
		west = minf(west, point.x)
		south = minf(south, point.y)
		east = maxf(east, point.x)
		north = maxf(north, point.y)
	return "%.6f,%.6f,%.6f,%.6f,%d" % [west, south, east, north, points.size()]


func _read_file(file_path: String, nodes_by_id: Dictionary, node_tags_by_id: Dictionary, ways_by_id: Dictionary, relations_by_id: Dictionary, declared_bounds: Dictionary) -> Dictionary:
	if file_path.get_extension().to_lower() != "osm":
		return {"ok": false, "message": "%s is not an .osm file." % file_path.get_file()}
	if not FileAccess.file_exists(file_path):
		return {"ok": false, "message": "The file could not be found: %s" % file_path}

	var parser := XMLParser.new()
	var open_error := parser.open(file_path)
	if open_error != OK:
		return {"ok": false, "message": "%s is not readable OpenStreetMap XML." % file_path.get_file()}

	var current_way_id := ""
	var current_node_id := ""
	var current_node_tags: Dictionary = {}
	var current_node_ids: Array[String] = []
	var current_tags: Dictionary = {}
	var current_relation_id := ""
	var current_relation_members: Array[Dictionary] = []
	var current_relation_tags: Dictionary = {}

	while parser.read() == OK:
		var node_type := parser.get_node_type()
		var node_name := ""
		if node_type == XMLParser.NODE_ELEMENT or node_type == XMLParser.NODE_ELEMENT_END:
			node_name = parser.get_node_name()
		if node_type == XMLParser.NODE_ELEMENT:
			if node_name == "bounds":
				var min_lon := parser.get_named_attribute_value_safe("minlon")
				var min_lat := parser.get_named_attribute_value_safe("minlat")
				var max_lon := parser.get_named_attribute_value_safe("maxlon")
				var max_lat := parser.get_named_attribute_value_safe("maxlat")
				if min_lon.is_valid_float() and min_lat.is_valid_float() and max_lon.is_valid_float() and max_lat.is_valid_float():
					var file_bounds := {"west": min_lon.to_float(), "south": min_lat.to_float(), "east": max_lon.to_float(), "north": max_lat.to_float()}
					if declared_bounds.is_empty():
						declared_bounds.merge(file_bounds)
					else:
						declared_bounds.west = minf(float(declared_bounds.west), float(file_bounds.west))
						declared_bounds.south = minf(float(declared_bounds.south), float(file_bounds.south))
						declared_bounds.east = maxf(float(declared_bounds.east), float(file_bounds.east))
						declared_bounds.north = maxf(float(declared_bounds.north), float(file_bounds.north))
			elif node_name == "node":
				var node_id := parser.get_named_attribute_value_safe("id")
				var latitude_text := parser.get_named_attribute_value_safe("lat")
				var longitude_text := parser.get_named_attribute_value_safe("lon")
				if node_id != "" and latitude_text.is_valid_float() and longitude_text.is_valid_float():
					nodes_by_id[node_id] = Vector2(longitude_text.to_float(), latitude_text.to_float())
					current_node_id = node_id
					current_node_tags = {}
					if parser.is_empty():
						current_node_id = ""
			elif node_name == "way":
				current_node_id = ""
				current_way_id = parser.get_named_attribute_value_safe("id")
				current_node_ids = []
				current_tags = {}
			elif node_name == "relation":
				current_node_id = ""
				current_relation_id = parser.get_named_attribute_value_safe("id")
				current_relation_members = []
				current_relation_tags = {}
			elif current_way_id != "" and node_name == "nd":
				var reference := parser.get_named_attribute_value_safe("ref")
				if reference != "":
					current_node_ids.append(reference)
			elif current_way_id != "" and node_name == "tag":
				var key := parser.get_named_attribute_value_safe("k")
				if key != "":
					current_tags[key] = parser.get_named_attribute_value_safe("v")
			elif current_relation_id != "" and node_name == "member":
				current_relation_members.append({
					"type": parser.get_named_attribute_value_safe("type"),
					"reference": parser.get_named_attribute_value_safe("ref"),
					"role": parser.get_named_attribute_value_safe("role")
				})
			elif current_relation_id != "" and node_name == "tag":
				var relation_key := parser.get_named_attribute_value_safe("k")
				if relation_key != "":
					current_relation_tags[relation_key] = parser.get_named_attribute_value_safe("v")
			elif current_node_id != "" and node_name == "tag":
				var node_key := parser.get_named_attribute_value_safe("k")
				if node_key != "":
					current_node_tags[node_key] = parser.get_named_attribute_value_safe("v")
		elif node_type == XMLParser.NODE_ELEMENT_END and node_name == "node" and current_node_id != "":
			if not current_node_tags.is_empty():
				node_tags_by_id[current_node_id] = current_node_tags.duplicate()
			current_node_id = ""
		elif node_type == XMLParser.NODE_ELEMENT_END and node_name == "way" and current_way_id != "":
			ways_by_id[current_way_id] = {
				"id": current_way_id,
				"node_ids": current_node_ids.duplicate(),
				"tags": current_tags.duplicate()
			}
			current_way_id = ""
		elif node_type == XMLParser.NODE_ELEMENT_END and node_name == "relation" and current_relation_id != "":
			relations_by_id[current_relation_id] = {
				"id": current_relation_id,
				"members": current_relation_members.duplicate(true),
				"tags": current_relation_tags.duplicate()
			}
			current_relation_id = ""

	return {"ok": true, "message": ""}


func _assemble_rings(references: Array[String], ways_by_id: Dictionary, nodes_by_id: Dictionary) -> Array[Dictionary]:
	var remaining: Array[Array] = []
	for reference in references:
		if ways_by_id.has(reference):
			var node_ids: Array = ways_by_id[reference].node_ids.duplicate()
			if node_ids.size() >= 2:
				remaining.append(node_ids)
	var rings: Array[Dictionary] = []
	while not remaining.is_empty():
		var chain: Array = remaining.pop_front()
		var joined := true
		while chain.size() >= 2 and chain[0] != chain[chain.size() - 1] and joined:
			joined = false
			for index in remaining.size():
				var candidate: Array = remaining[index]
				if chain[chain.size() - 1] == candidate[0]:
					chain.append_array(candidate.slice(1))
				elif chain[chain.size() - 1] == candidate[candidate.size() - 1]:
					candidate.reverse()
					chain.append_array(candidate.slice(1))
				elif chain[0] == candidate[candidate.size() - 1]:
					var prefix: Array = candidate.slice(0, candidate.size() - 1)
					prefix.append_array(chain)
					chain = prefix
				elif chain[0] == candidate[0]:
					candidate.reverse()
					var reversed_prefix: Array = candidate.slice(0, candidate.size() - 1)
					reversed_prefix.append_array(chain)
					chain = reversed_prefix
				else:
					continue
				remaining.remove_at(index)
				joined = true
				break
		if chain.size() < 4 or chain[0] != chain[chain.size() - 1]:
			continue
		var points: Array[Vector2] = []
		for node_id in chain:
			if nodes_by_id.has(node_id):
				points.append(nodes_by_id[node_id])
		if points.size() >= 4:
			rings.append({"node_ids": chain, "points": points})
	return rings
