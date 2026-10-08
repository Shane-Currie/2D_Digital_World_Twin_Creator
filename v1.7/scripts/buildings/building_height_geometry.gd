extends RefCounted

## Visual geometry only. Ground collision polygons never enter this module.
const Pieces = preload("res://scripts/land_cover/land_cover.gd")
const SharedWalls = preload("res://scripts/buildings/building_shared_walls.gd")
const CAMERA_FACING_DIRECTION := Vector2(-0.38, 1.0)
const MAX_VISUAL_FLOORS := 10

static func build(outer: PackedVector2Array, holes: Array, floors: int, pixels_per_metre: float, obstacles: Array = [], map_bounds: Rect2 = Rect2()) -> Dictionary:
	var typed_holes: Array[PackedVector2Array] = []
	for hole in holes: typed_holes.append(hole)
	var ground := Pieces.pieces(outer, typed_holes)
	var bounds := polygon_bounds(outer)
	var visual_floors := clampi(floors, 1, MAX_VISUAL_FLOORS)
	# Fit a solid prism into the source footprint. The visible base and roof
	# have matching shapes; EVERY vertical corner rises by the same vector.
	# The original ground outline still owns collisions/entrances. It forms a
	# low foundation around the fitted solid, not an oversized displaced roof.
	var rise_height := minf(pixels_per_metre*(1.2+visual_floors*1.2),minf(bounds.size.y*0.30,bounds.size.x*0.18/absf(CAMERA_FACING_DIRECTION.x)))
	var depth := Vector2(absf(CAMERA_FACING_DIRECTION.x),1.0)*rise_height
	var roof_bounds := Rect2(bounds.position+Vector2(depth.x,0),bounds.size-depth)
	var roof: Array[PackedVector2Array] = []
	for piece in ground:
		var projected := PackedVector2Array()
		for point in piece: projected.append(_roof_point(point,bounds,roof_bounds))
		roof.append_array(clip_to_ground(projected,ground))
	# Concave wings must not disappear into their empty bounding-box notch.
	for attempt in 6:
		if _pieces_area(roof) >= _pieces_area(ground)*0.45: break
		depth *= 0.7
		roof_bounds = Rect2(bounds.position+Vector2(depth.x,0),bounds.size-depth)
		roof.clear()
		for piece in ground:
			var projected := PackedVector2Array()
			for point in piece: projected.append(_roof_point(point,bounds,roof_bounds))
			roof.append_array(clip_to_ground(projected,ground))
	var visual_bounds := bounds
	var rise := Vector2(depth.x,-depth.y)
	var fitted_base: Array[PackedVector2Array] = []
	for piece in ground:
		var projected := PackedVector2Array()
		for point in piece: projected.append(_roof_point(point,bounds,roof_bounds)-rise)
		fitted_base.append_array(clip_to_ground(projected,ground))
	var rings: Array = [outer]
	rings.append_array(holes)
	var walls: Array = []
	var projected_roof := roof.duplicate()
	var hidden_corners: Array = []
	for ring_index in rings.size():
		var ring: PackedVector2Array = rings[ring_index]
		var signed_area := 0.0
		for edge_index in ring.size(): signed_area += (ring[edge_index]-ring[0]).cross(ring[(edge_index+1)%ring.size()]-ring[0])
		for index in ring.size():
			var a: Vector2 = ring[index]
			var b: Vector2 = ring[(index + 1) % ring.size()]
			if a.distance_to(b) < 0.01: continue
			var repeats := maxf(1.0, a.distance_to(b) / maxf(0.01, pixels_per_metre * 5.0))
			var outward := Vector2((b-a).y, -(b-a).x).normalized()
			if signed_area < 0.0: outward = -outward
			if ring_index > 0: outward = -outward # Courtyard-facing ground facade.
			var facing_camera := outward.dot(CAMERA_FACING_DIRECTION) > 0.01
			var top_a := _roof_point(a,bounds,roof_bounds)
			var top_b := _roof_point(b,bounds,roof_bounds)
			var base_a := top_a-rise
			var base_b := top_b-rise
			var patches: Array = []
			if facing_camera:
				var face_depth := rise.length()
				# Cropping fewer rows is preferable to squashing ten storeys into
				# a tiny facade on a narrow footprint. Saved floors are untouched.
				var rows := mini(visual_floors,maxi(1,floori(face_depth/maxf(0.01,pixels_per_metre*1.8))))
				# Party-wall occlusion applies to the camera-facing LEFT side;
				# front shop facades must not disappear because a neighbour meets
				# their endpoint or an overlapping source polygon crosses them.
				var side_neighbours: Array = obstacles if outward.x < -absf(outward.y) else []
				for section in SharedWalls.sections(a,b,outward,side_neighbours):
					var start := float(section.start)
					var end := float(section.end)
					var first := base_a.lerp(base_b,start)
					var second := base_a.lerp(base_b,end)
					var upper_first := top_a.lerp(top_b,start)
					var upper_second := top_a.lerp(top_b,end)
					var visible_fraction := clampf(1.0-float(section.neighbour_floors)/maxi(1,floors),0.0,1.0)
					var lower_first := upper_first.lerp(first,visible_fraction)
					var lower_second := upper_second.lerp(second,visible_fraction)
					if visible_fraction < 1.0:
						# Fill the hidden side with roof, not a visible dark wall or
						# a false grass gap between attached buildings.
						var hidden := clip_to_ground(PackedVector2Array([first,second,lower_second,lower_first]),ground)
						for existing in roof: hidden = subtract_polygon(hidden,existing)
						roof.append_array(hidden)
						# Where a party wall meets the front, its hidden corner must
						# become front facade, not a roof-coloured diagonal wedge.
						if start < 0.0001: hidden_corners.append({"base":first,"ground":a,"lower":lower_first,"side_a":a,"side_b":b})
						if end > 0.9999: hidden_corners.append({"base":second,"ground":b,"lower":lower_second,"side_a":a,"side_b":b})
					if visible_fraction > 0.001:
						var quad := PackedVector2Array([lower_first,lower_second,upper_second,upper_first])
						var uvs := PackedVector2Array([Vector2(repeats*start,rows*visible_fraction),Vector2(repeats*end,rows*visible_fraction),Vector2(repeats*end,0),Vector2(repeats*start,0)])
						patches.append({"quad":quad,"uvs":uvs})
				# Rotated/irregular outlines can leave a low foundation reveal
				# between the mapped front edge and fitted base. Continue the
				# facade material there, rather than leaving a grey join gap.
				if outward.x >= -absf(outward.y):
					var skirt := PackedVector2Array([a,b,base_b,base_a])
					if polygon_area(skirt)>0.01:
						patches.append({"quad":skirt,"uvs":PackedVector2Array([Vector2(0,rows),Vector2(repeats,rows),Vector2(repeats,rows-0.15),Vector2(0,rows-0.15)])})
			walls.append({"a":a,"b":b,"base_a":base_a,"base_b":base_b,"top_a":top_a,"top_b":top_b,"outward":outward,"facing_camera":facing_camera,"patches":patches,"surfaces":[]})
	_join_hidden_corners(walls,hidden_corners,roof,projected_roof,ground)
	# Shared-wall roof fills are included before final separation and clipping.
	var facade_domain: Array[PackedVector2Array] = ground.duplicate()
	for piece in roof: facade_domain = subtract_polygon(facade_domain,piece)
	for obstacle in obstacles:
		for guarded in Geometry2D.offset_polygon(obstacle.points,0.05): facade_domain = subtract_polygon(facade_domain,guarded)
	if map_bounds.has_area():
		var boundary := PackedVector2Array([map_bounds.position,Vector2(map_bounds.end.x,map_bounds.position.y),map_bounds.end,Vector2(map_bounds.position.x,map_bounds.end.y)])
		var inside: Array[PackedVector2Array] = []
		for piece in facade_domain: inside.append_array(clip_to_ground(piece,[boundary]))
		facade_domain = inside
	for wall in walls:
		for patch in wall.patches: wall.surfaces.append_array(clipped_surfaces(patch.quad,patch.uvs,facade_domain))
		wall.erase("patches")
	walls.sort_custom(func(a, b): return (a.a.y + a.b.y) < (b.a.y + b.b.y))
	return {"ground":ground,"base":fitted_base,"roof":roof,"roof_edges":_roof_edges(roof),"roof_bounds":roof_bounds,"visual_bounds":visual_bounds,"walls":walls,"rise":rise,"projection":"fitted_prism","offset":-depth,"roof_scale":roof_bounds.size/bounds.size,"visual_floors":visual_floors,"total_floors":floors}

static func _join_hidden_corners(walls: Array, corners: Array, roof: Array[PackedVector2Array], projected_roof: Array[PackedVector2Array], ground: Array[PackedVector2Array]) -> void:
	for corner in corners:
		var base: Vector2 = corner.base
		var lower: Vector2 = corner.lower
		var seam := Geometry2D.get_closest_point_to_segment(lower,corner.side_a,corner.side_b)
		# Include the low foundation reveal at rotated party-wall corners.
		# Endpoint matching still uses the fitted prism's common corner.
		var triangle := PackedVector2Array([corner.ground])
		if base.distance_to(corner.ground)>0.01: triangle.append(base)
		triangle.append(lower)
		triangle.append(seam)
		if polygon_area(triangle) < 0.01: continue
		for wall in walls:
			if not wall.facing_camera or wall.outward.x < -absf(wall.outward.y) or wall.patches.is_empty(): continue
			var endpoint := 0 if base.distance_to(wall.base_a) < 0.01 else (1 if base.distance_to(wall.base_b) < 0.01 else -1)
			if endpoint < 0: continue
			# Continue the adjoining front's window rows through the corner.
			# Never cut the actual projected roof or change the ground boundary.
			var patch: Dictionary = wall.patches[0]
			var reference := PackedVector2Array([patch.quad[endpoint],patch.quad[1-endpoint],patch.quad[3-endpoint]])
			var reference_uv := PackedVector2Array([patch.uvs[endpoint],patch.uvs[1-endpoint],patch.uvs[3-endpoint]])
			var joined := clip_to_ground(triangle,ground)
			for piece in projected_roof: joined = subtract_polygon(joined,piece)
			for piece in joined:
				var mapped_uv := PackedVector2Array()
				for point in piece: mapped_uv.append(_triangle_uv(point,reference,reference_uv))
				wall.patches.append({"quad":piece,"uvs":mapped_uv})
				var remaining := subtract_polygon(roof,piece)
				roof.assign(remaining)
			break

static func _roof_edges(roof: Array[PackedVector2Array]) -> Array:
	# Startup-only outline detection; never repeat polygon comparisons per frame.
	var edges: Array = []
	for piece in roof:
		for index in piece.size():
			var a := piece[index]
			var b := piece[(index+1)%piece.size()]
			var midpoint := (a+b)*0.5
			var neighbours := 0
			for candidate in roof:
				if Geometry2D.is_point_in_polygon(midpoint,candidate): neighbours += 1
			if neighbours <= 1: edges.append({"a":a,"b":b})
	return edges

static func _roof_point(point: Vector2, ground_bounds: Rect2, roof_bounds: Rect2) -> Vector2:
	return roof_bounds.position+(point-ground_bounds.position)*roof_bounds.size/ground_bounds.size

static func subtract_polygon(source: Array[PackedVector2Array], cut: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for piece in source:
		if not polygon_bounds(piece).intersects(polygon_bounds(cut),true): result.append(piece); continue
		var rings: Array[PackedVector2Array] = []
		rings.assign(Geometry2D.clip_polygons(piece,cut))
		rings.sort_custom(func(a,b): return polygon_area(a)>polygon_area(b))
		var outers: Array[PackedVector2Array] = []
		var holes_by_outer: Array = []
		for ring in rings:
			var parent := -1
			for index in outers.size():
				if Geometry2D.is_point_in_polygon(ring[0],outers[index]): parent = index; break
			if parent >= 0: holes_by_outer[parent].append(ring)
			else: outers.append(ring); holes_by_outer.append([])
		for index in outers.size():
			var holes: Array[PackedVector2Array] = []
			holes.assign(holes_by_outer[index])
			result.append_array(Pieces.pieces(outers[index],holes))
	return result

static func _pieces_area(pieces: Array[PackedVector2Array]) -> float:
	var result := 0.0
	for piece in pieces: result += polygon_area(piece)
	return result

static func polygon_area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	if polygon.is_empty(): return result
	for index in polygon.size(): result += (polygon[index]-polygon[0]).cross(polygon[(index+1)%polygon.size()]-polygon[0])
	return absf(result) * 0.5

static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty(): return Rect2()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	return bounds

static func clip_to_ground(polygon: PackedVector2Array, ground: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for floor_piece in ground:
		if not polygon_bounds(polygon).intersects(polygon_bounds(floor_piece), true): continue
		for clipped in Geometry2D.intersect_polygons(polygon, floor_piece):
			if not Geometry2D.triangulate_polygon(clipped).is_empty(): result.append(clipped)
	return result

static func clipped_surfaces(polygon: PackedVector2Array, uvs: PackedVector2Array, ground: Array[PackedVector2Array]) -> Array:
	# Cache clipped textured faces once. UVs retain the original art coordinates.
	var result: Array = []
	var indices := Geometry2D.triangulate_polygon(polygon)
	for index in range(0, indices.size(), 3):
		var triangle := PackedVector2Array([polygon[indices[index]], polygon[indices[index+1]], polygon[indices[index+2]]])
		var triangle_uv := PackedVector2Array([uvs[indices[index]], uvs[indices[index+1]], uvs[indices[index+2]]])
		for clipped in clip_to_ground(triangle, ground):
			# Triangulate relative to the face, not kilometres from the origin.
			# Return triangles so drawing never re-triangulates thin world slivers.
			var local := PackedVector2Array()
			for point in clipped: local.append(point-clipped[0])
			var clipped_indices := Geometry2D.triangulate_polygon(local)
			var centre := Vector2.ZERO
			for point in clipped: centre+=point
			centre/=clipped.size()
			# Guard domain-boundary vertices against large-coordinate float
			# rounding. Internal triangulation seams are not inset.
			for vertex in clipped.size():
				var near_boundary := false
				for domain in ground:
					for edge in domain.size():
						var nearest := Geometry2D.get_closest_point_to_segment(clipped[vertex],domain[edge],domain[(edge+1)%domain.size()])
						if nearest.distance_squared_to(clipped[vertex])<0.0001: near_boundary=true; break
					if near_boundary: break
				if near_boundary: clipped[vertex]=clipped[vertex].move_toward(centre,0.004)
			for part in range(0,clipped_indices.size(),3):
				var points := PackedVector2Array()
				for vertex in 3: points.append(clipped[clipped_indices[part+vertex]])
				if polygon_area(points)<0.001: continue
				var mapped_uv := PackedVector2Array()
				for point in points: mapped_uv.append(_triangle_uv(point,triangle,triangle_uv))
				result.append({"points":points,"uvs":mapped_uv})
	return result

static func _triangle_uv(point: Vector2, triangle: PackedVector2Array, uvs: PackedVector2Array) -> Vector2:
	var first := triangle[1] - triangle[0]
	var second := triangle[2] - triangle[0]
	var relative := point - triangle[0]
	var denominator := first.cross(second)
	if absf(denominator) < 0.000001: return uvs[0]
	var weight_b := relative.cross(second) / denominator
	var weight_c := first.cross(relative) / denominator
	return uvs[0] * (1.0 - weight_b - weight_c) + uvs[1] * weight_b + uvs[2] * weight_c
