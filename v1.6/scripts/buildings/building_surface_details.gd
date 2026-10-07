extends RefCounted

## Cached artwork layout, independent of collisions, town names and the LLM.
const Geometry = preload("res://scripts/buildings/building_height_geometry.gd")

static func rectangle(bounds: Rect2) -> PackedVector2Array:
	return PackedVector2Array([bounds.position, Vector2(bounds.end.x,bounds.position.y), bounds.end, Vector2(bounds.position.x,bounds.end.y)])

static func roof_equipment(mesh: Dictionary, pixels_per_metre: float) -> Rect2:
	# Whole equipment + shadow + clearance must fit the visible roof UNION.
	# Never stretch a unit with the building's bounding box or crop half a fan.
	var size := Vector2(1.8,2.0)*pixels_per_metre
	var bounds: Rect2 = mesh.roof_bounds
	var candidates: Array[Vector2] = [bounds.get_center()]
	# Put equipment near the visible front roof edge, not at a distant centre.
	# Try both sides of each roof edge; full containment decides the inside.
	for edge in mesh.get("roof_edges",[]):
		var tangent: Vector2 = edge.a.direction_to(edge.b)
		var normal := Vector2(-tangent.y,tangent.x)
		var inset := absf(normal.x)*size.x*0.5+absf(normal.y)*size.y*0.5+pixels_per_metre*0.4
		for fraction in [0.5,0.25,0.75]:
			var edge_point: Vector2 = edge.a.lerp(edge.b,fraction)
			candidates.append(edge_point+normal*inset)
			candidates.append(edge_point-normal*inset)
	for y in range(1,6):
		for x in range(1,6): candidates.append(bounds.position+bounds.size*Vector2(x/6.0,y/6.0))
	var front := Geometry.CAMERA_FACING_DIRECTION.normalized()
	candidates.sort_custom(func(a: Vector2,b: Vector2): return a.dot(front)>b.dot(front))
	for centre in candidates:
		var placed := Rect2(centre-size*0.5,size)
		var remainder: Array[PackedVector2Array] = [rectangle(placed.grow(pixels_per_metre*0.3))]
		for piece in mesh.roof:
			remainder = Geometry.subtract_polygon(remainder,piece)
			if remainder.is_empty(): break
		if Geometry._pieces_area(remainder) < 0.01: return placed
	return Rect2() # A small/awkward roof is better left clear.

static func blank_door_bays(wall: Dictionary, doors: Array) -> Array:
	# Erase COMPLETE repeating window bays touched by a door, not just the
	# pixels behind the door. Reuse original facade UVs for the blank material.
	var cells: Dictionary = {}
	for surface in wall.surfaces:
		var indices := Geometry2D.triangulate_polygon(surface.points)
		for offset in range(0,indices.size(),3):
			var triangle := PackedVector2Array()
			var uv_triangle := PackedVector2Array()
			for corner in 3:
				triangle.append(surface.points[indices[offset+corner]])
				uv_triangle.append(surface.uvs[indices[offset+corner]])
			for door in doors:
				for door_surface in door.surfaces:
					for overlap in Geometry2D.intersect_polygons(triangle,door_surface.points):
						if Geometry.polygon_area(overlap) < 0.001: continue
						var uv_points := PackedVector2Array()
						for point in overlap: uv_points.append(Geometry._triangle_uv(point,triangle,uv_triangle))
						var uv_bounds := Geometry.polygon_bounds(uv_points)
						for y in range(floori(uv_bounds.position.y+0.0001),ceili(uv_bounds.end.y-0.0001)):
							for x in range(floori(uv_bounds.position.x+0.0001),ceili(uv_bounds.end.x-0.0001)): cells[Vector2i(x,y)] = true
	var result: Array = []
	for surface in wall.surfaces:
		var indices := Geometry2D.triangulate_polygon(surface.points)
		for offset in range(0,indices.size(),3):
			var triangle := PackedVector2Array()
			var uv_triangle := PackedVector2Array()
			for corner in 3:
				triangle.append(surface.points[indices[offset+corner]])
				uv_triangle.append(surface.uvs[indices[offset+corner]])
			for cell in cells:
				for uv_piece in Geometry2D.intersect_polygons(uv_triangle,rectangle(Rect2(Vector2(cell),Vector2.ONE))):
					var points := PackedVector2Array()
					for uv in uv_piece: points.append(Geometry._triangle_uv(uv,uv_triangle,triangle))
					# Triangulate in small UV coordinates before translating to large
					# map coordinates. Thin shared-edge slivers can fail world triangulation.
					var triangles := Geometry2D.triangulate_polygon(uv_piece)
					for part in range(0,triangles.size(),3):
						var draw_points := PackedVector2Array()
						var draw_uvs := PackedVector2Array()
						for corner in 3:
							draw_points.append(points[triangles[part+corner]])
							draw_uvs.append(uv_piece[triangles[part+corner]])
						if Geometry.polygon_area(draw_points) > 0.001: result.append({"points":draw_points,"uvs":draw_uvs})
	return result
