extends RefCounted

## Shared tag table is also read by the Node CLI. Missing tags mean unknown.
static var rules: Array = []

static func classify(tags: Dictionary) -> String:
	# An elevated podium or underground paved area is not ground cover.
	for key in ["layer", "level"]:
		var value := str(tags.get(key, "0"))
		if value.is_valid_float() and float(value) != 0.0: return ""
	for key in ["bridge", "tunnel", "indoor"]:
		if str(tags.get(key, "")).to_lower() not in ["", "no", "false", "0"]: return ""
	if str(tags.get("location", "")).to_lower() == "underground": return ""
	_load_rules()
	for rule in rules:
		for key in rule.tags:
			if str(tags.get(key, "")).to_lower() in rule.tags[key]:
				return rule.category
	return ""

static func colour(category: String) -> Color:
	_load_rules()
	for rule in rules:
		if rule.category == category:
			return Color(rule.colour)
	return Color("#8fb56d")

static func _load_rules() -> void:
	if rules.is_empty():
		rules = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/land_cover/rules.json")).rules

static func pieces(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if Geometry2D.triangulate_polygon(outer).is_empty():
		return result
	if holes.is_empty():
		result.append(outer)
		return result
	# Slice at every vertex height. Within a strip, boundary edges are straight
	# and cannot exchange order: alternating crossings describe filled trapezoids.
	# This keeps holes transparent without navigation baking (which can fail on
	# real parks with narrow gaps) or painting over underlying land-cover areas.
	var rings: Array[PackedVector2Array] = [outer]
	rings.append_array(holes)
	var heights: Array[float] = []
	var edges: Array[Dictionary] = []
	for ring in rings:
		for index in ring.size():
			var a := ring[index]
			var b := ring[(index + 1) % ring.size()]
			heights.append(a.y)
			if a.y != b.y: edges.append({"a": a, "b": b})
	heights.sort()
	for index in range(heights.size() - 1):
		var top := heights[index]
		var bottom := heights[index + 1]
		if bottom <= top: continue
		var middle := (top + bottom) * 0.5
		var crossings: Array[Dictionary] = []
		for edge in edges:
			if middle > minf(edge.a.y, edge.b.y) and middle < maxf(edge.a.y, edge.b.y):
				crossings.append({"edge":edge,"x":_edge_x(edge,middle)})
		crossings.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.x < b.x)
		for pair in range(0,crossings.size() - 1,2):
			var left: Dictionary = crossings[pair].edge
			var right: Dictionary = crossings[pair + 1].edge
			var corners := [Vector2(_edge_x(left,top),top),Vector2(_edge_x(right,top),top),Vector2(_edge_x(right,bottom),bottom),Vector2(_edge_x(left,bottom),bottom)]
			var piece := PackedVector2Array()
			for corner in corners:
				if piece.is_empty() or piece[piece.size() - 1] != corner: piece.append(corner)
			if piece.size() > 2 and piece[0] == piece[piece.size() - 1]: piece.remove_at(piece.size() - 1)
			if piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty(): result.append(piece)
	return result

static func _edge_x(edge: Dictionary, y: float) -> float:
	return float(edge.a.x) + (y - float(edge.a.y)) * (float(edge.b.x) - float(edge.a.x)) / (float(edge.b.y) - float(edge.a.y))
