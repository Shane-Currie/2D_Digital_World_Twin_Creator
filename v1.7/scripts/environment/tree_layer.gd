extends Node2D

## Stream artwork near the camera; trunk queries do not depend on camera visibility.
const Clearance = preload("res://scripts/buildings/building_visual_clearance.gd")
const Geometry = preload("res://scripts/buildings/building_height_geometry.gd")
const TreeSettings = preload("res://scripts/environment/tree_settings_store.gd")
const CELL_SIZE := 512.0
const MAX_CACHED_CELLS := 96
const MAX_VISIBLE_TREES := 1400
var world
var clearance = Clearance.new()
var mapped_cells: Dictionary = {}
var mapped_positions: Dictionary = {}
var generated_cells: Dictionary = {}
var textures: Array = []
var visible_trees: Array = []
var rejected_mapped := 0
var selected_style := "mapped"
var custom_texture: Texture2D
var roadside_cells: Dictionary = {}
var safe_starts: Array[Vector2] = []

func setup(renderer, town_directory: String = "") -> void:
	world = renderer
	var town_path := town_directory.path_join("town.json")
	if FileAccess.file_exists(town_path):
		var town: Variant = JSON.parse_string(FileAccess.get_file_as_string(town_path))
		if town is Dictionary and town.get("starting_location") is Dictionary:
			var start: Dictionary = town.starting_location
			for location in [start,start.get("vehicle",{})]:
				if location.has("latitude") and location.has("longitude"):
					safe_starts.append(world._world(world.ProjectionScript.value_to_location(location)))
	var store := TreeSettings.new()
	var settings := store.load_from_town(town_directory)
	if not town_directory.is_empty():
		if not settings.ok: push_warning(settings.message)
		selected_style=settings.data.tree_style
		custom_texture=store.selected_texture(town_directory,settings.data)
	for name in ["broadleaf","eucalypt","conifer"]: textures.append(load("res://assets/environment/trees/%s.svg" % name))
	var wind := ShaderMaterial.new()
	wind.shader = load("res://scripts/environment/tree_wind.gdshader")
	wind.set_shader_parameter("pixels_per_metre",world.pixels_per_metre)
	material = wind
	for building in world.ground_buildings:
		for piece in Geometry.Pieces.pieces(building.outer,building.holes): clearance.add_polygon(piece)
	for paths in [world.road_paths,world.sidewalk_paths]:
		for path in paths: clearance.add_path(path,world.pixels_per_metre)
	# Entrances are resolved before trees. Preserve their clear approach so a
	# newly generated verge tree cannot block an already accepted doorway.
	var automatic: Variant = world.get("automatic_door_status")
	if automatic is Dictionary:
		for entry in automatic.values():
			if entry.is_empty(): continue
			_guard_entrance(PackedVector2Array([entry.point,entry.outside,entry.route]))
	var exteriors: Variant = world.get("building_exterior_data")
	if exteriors is Dictionary:
		for building in exteriors.get("buildings",{}).values():
			for door in building.get("doors",[]):
				if not door.has("outside_longitude") or not door.has("outside_latitude"): continue
				_guard_entrance(PackedVector2Array([world._world(world.ProjectionScript.value_to_location(door)),world._world(Vector2(float(door.outside_longitude),float(door.outside_latitude)))]))
	for area in world.parking_areas:
		for piece in area.pieces: clearance.add_polygon(piece)
	for area in world.water_areas:
		for piece in area.pieces: clearance.add_polygon(piece)
	# Grass sports surfaces must stay playable, not become a tree plantation.
	for feature in world.features:
		if str(feature.get("kind",""))!="land_cover": continue
		if str(feature.tags.get("leisure","")) not in ["pitch","track","playground"]: continue
		var holes: Array[PackedVector2Array] = []
		for values in feature.get("holes",[]): holes.append(world._polygon(values))
		for piece in Geometry.Pieces.pieces(world._polygon(feature.points),holes): clearance.add_polygon(piece)
	_index_roadside_segments()
	# Preserve individually mapped trees and rows from imported OSM.
	for feature in world.features:
		if str(feature.get("kind","")) == "tree" and not feature.get("points",[]).is_empty():
			_add_mapped(world._world(world.ProjectionScript.value_to_location(feature.points[0])),feature.tags,str(feature.id))
	for feature in world.features:
		if str(feature.get("kind","")) == "tree_row":
			var points: PackedVector2Array = world._polygon(feature.points)
			for index in range(points.size()-1):
				var distance := points[index].distance_to(points[index+1])
				var count := mini(5000,maxi(1,ceili(distance/(world.pixels_per_metre*9.0))))
				for part in count: _add_mapped(points[index].lerp(points[index+1],float(part)/count),feature.tags,"%s:%d:%d" % [feature.id,index,part])
	refresh()

func _guard_entrance(points: PackedVector2Array) -> void:
	clearance.add_path({"points":points,"walkway":true,"half_width":world.pixels_per_metre*0.6},world.pixels_per_metre)

func _add_mapped(point: Vector2, tags: Dictionary, id: String) -> void:
	var size_metres := 5.5
	var diameter := str(tags.get("diameter_crown","")).trim_suffix("m").strip_edges()
	if diameter.is_valid_float(): size_metres = clampf(float(diameter),2.0,14.0)
	var variant := 2 if str(tags.get("leaf_type","")) == "needleleaved" else posmod(hash(id),2)
	var tree := _tree(point,size_metres,variant,id,"osm")
	var point_key := Vector2i((point/(world.pixels_per_metre*0.1)).round())
	if mapped_positions.has(point_key): return
	if not clear_artwork(tree.bounds): rejected_mapped += 1; return
	mapped_positions[point_key] = true
	mapped_cells.get_or_add(Vector2i((point/CELL_SIZE).floor()),[]).append(tree)

func _tree(point: Vector2, diameter: float, variant: int, id: String, source: String) -> Dictionary:
	var size: Vector2 = Vector2(diameter,diameter*1.18)*world.pixels_per_metre
	# Illustrative trunk radius, not the canopy or a surveyed trunk measurement.
	var radius: float = clampf(diameter*0.055,0.18,0.45)*world.pixels_per_metre
	return {"point":point,"radius":radius,"bounds":Rect2(point-Vector2(size.x*0.5,size.y*0.84),size),"variant":variant,"id":id,"source":source}

func clear_artwork(bounds: Rect2) -> bool:
	# The full crown, trunk, shadow and wind margin stay off access surfaces.
	var guarded := bounds.grow(world.pixels_per_metre*0.12)
	if not world.world_bounds.encloses(guarded): return false
	for start in safe_starts:
		if guarded.has_point(start): return false
	var polygon := _rectangle(guarded)
	for obstacle in clearance.query(guarded,"__foliage__"):
		for overlap in Geometry2D.intersect_polygons(polygon,obstacle.points):
			if Geometry.polygon_area(overlap) > 0.01: return false
	return true

func refresh() -> void:
	visible_trees.clear()
	if world.map_overview: queue_redraw(); return
	var bounds: Rect2 = world.draw_view_bounds
	# Wait for camera bounds rather than generating forests over an entire city.
	if not bounds.has_area(): queue_redraw(); return
	bounds = bounds.grow(world.pixels_per_metre*16.0).intersection(world.world_bounds)
	var low := Vector2i((bounds.position/CELL_SIZE).floor())
	var high := Vector2i((bounds.end/CELL_SIZE).floor())
	# Deliberately omit fine trees on very wide views; coloured woods remain.
	if (high.x-low.x+1)*(high.y-low.y+1) > MAX_CACHED_CELLS: queue_redraw(); return
	var active: Dictionary = {}
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := Vector2i(x,y)
			active[cell] = true
			for tree in trees_in_cell(cell):
				if visible_trees.size() >= MAX_VISIBLE_TREES: break
				if bounds.intersects(tree.bounds): visible_trees.append(tree)
	for cell in generated_cells.keys():
		if not active.has(cell) and generated_cells.size()>MAX_CACHED_CELLS: generated_cells.erase(cell)
	visible_trees.sort_custom(func(a,b): return a.point.y < b.point.y)
	queue_redraw()

func trees_in_cell(cell: Vector2i) -> Array:
	if not generated_cells.has(cell):
		# Both physics and artwork use the same deterministic placement cache.
		if generated_cells.size()>=MAX_CACHED_CELLS: generated_cells.erase(generated_cells.keys()[0])
		generated_cells[cell]=_forest_cell(cell)
	return mapped_cells.get(cell,[])+generated_cells[cell]

func trunk_segment_clear(first: Vector2, second: Vector2, actor_radius: float = 0.0) -> bool:
	var bounds := Rect2(first,second-first).abs().grow(actor_radius+0.45*world.pixels_per_metre)
	var low := Vector2i((bounds.position/CELL_SIZE).floor())
	var high := Vector2i((bounds.end/CELL_SIZE).floor())
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for tree in trees_in_cell(Vector2i(x,y)):
				var nearest := Geometry2D.get_closest_point_to_segment(tree.point,first,second)
				if nearest.distance_squared_to(tree.point)<pow(tree.radius+actor_radius,2): return false
	return true

func _forest_cell(cell: Vector2i) -> Array:
	var trees := _cover_cell(cell,"wood",9.0,"woodland_decoration")
	trees.append_array(_cover_cell(cell,"grass",24.0,"grass_decoration"))
	trees.append_array(_roadside_cell(cell))
	return trees

func _cover_cell(cell: Vector2i, category: String, spacing_metres: float, source: String) -> Array:
	var trees: Array = []
	var bounds := Rect2(Vector2(cell)*CELL_SIZE,Vector2.ONE*CELL_SIZE)
	var spacing: float = world.pixels_per_metre*spacing_metres
	var low := Vector2i((bounds.position/spacing).floor())
	var high := Vector2i((bounds.end/spacing).ceil())
	for y in range(low.y,high.y):
		for x in range(low.x,high.x):
			var id := "%s:%d:%d" % [category,x,y]
			var seed := absi(hash(id))
			var point := (Vector2(x,y)+Vector2(0.25+posmod(seed,50)/100.0,0.25+posmod(seed/53,50)/100.0))*spacing
			if Vector2i((point/CELL_SIZE).floor()) != cell: continue
			if world.land_cover.category_at(point) != category: continue
			# Roadside sampling fits narrow verges separately; do not double-plant.
			if category=="grass" and _near_road(point): continue
			var diameter: float = (4.5 if category=="wood" else 3.0)+posmod(seed,20)*0.1
			var tree := _tree(point,diameter,posmod(seed/11,2),id,source)
			if not clear_artwork(tree.bounds) or not _inside_cover(tree.bounds,category) or _near_mapped(tree.bounds): continue
			trees.append(tree)
	return trees

func _inside_cover(bounds: Rect2, category: String) -> bool:
	for point in _rectangle(bounds):
		if world.land_cover.category_at(point) != category: return false
	var centre := bounds.get_center()
	var candidates: Array = world.land_cover.cells.get(Vector2i((centre/world.land_cover.cell_size).floor()),[])
	for area in candidates:
		if area.category != category or not area.bounds.encloses(bounds): continue
		var remainder: Array[PackedVector2Array] = [_rectangle(bounds)]
		for piece in area.pieces: remainder = Geometry.subtract_polygon(remainder,piece)
		if Geometry._pieces_area(remainder)<0.01: return true
	return false

func _near_mapped(bounds: Rect2) -> bool:
	var low := Vector2i((bounds.position/CELL_SIZE).floor())-Vector2i.ONE
	var high := Vector2i((bounds.end/CELL_SIZE).floor())+Vector2i.ONE
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for tree in mapped_cells.get(Vector2i(x,y),[]):
				if bounds.intersects(tree.bounds): return true
	return false

func _index_roadside_segments() -> void:
	var allowed: Dictionary = {}
	for feature in world.features:
		if str(feature.get("kind",""))=="road" and str(feature.tags.get("highway","")) in ["primary","secondary","tertiary","residential","living_street","unclassified"]: allowed[str(feature.id)]=true
	var along: Dictionary = {}
	for segment in world.road_segments:
		if not allowed.has(segment.path_id) or segment.walkway or segment.bridge or segment.tunnel or segment.layer!=0: continue
		var length: float = segment.a.distance_to(segment.b)
		if length<0.01: continue
		var record := {"a":segment.a,"b":segment.b,"length":length,"start":float(along.get(segment.path_id,0.0)),"half_width":segment.half_width,"id":segment.path_id}
		along[segment.path_id]=record.start+length
		var bounds := Rect2(segment.a,segment.b-segment.a).abs().grow(segment.half_width+12.0*world.pixels_per_metre)
		var low := Vector2i((bounds.position/CELL_SIZE).floor())
		var high := Vector2i((bounds.end/CELL_SIZE).floor())
		for y in range(low.y,high.y+1):
			for x in range(low.x,high.x+1): roadside_cells.get_or_add(Vector2i(x,y),[]).append(record)

func _near_road(point: Vector2) -> bool:
	for segment in roadside_cells.get(Vector2i((point/CELL_SIZE).floor()),[]):
		if Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b).distance_to(point)<=segment.half_width+12.0*world.pixels_per_metre: return true
	return false

func _roadside_cell(cell: Vector2i) -> Array:
	var spacing: float = world.pixels_per_metre*24.0
	var minimum_gap: float = world.pixels_per_metre*18.0
	var cell_bounds := Rect2(Vector2(cell)*CELL_SIZE,Vector2.ONE*CELL_SIZE)
	# Regenerate the same neighbourhood regardless of camera/cache visitation order.
	var query := cell_bounds.grow(minimum_gap)
	var low := Vector2i((query.position/CELL_SIZE).floor())
	var high := Vector2i((query.end/CELL_SIZE).floor())
	var candidates: Dictionary = {}
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for segment in roadside_cells.get(Vector2i(x,y),[]):
				var direction: Vector2 = segment.a.direction_to(segment.b)
				var normal := Vector2(-direction.y,direction.x)
				var start := INF
				var end := -INF
				for corner in _rectangle(query):
					var distance: float = (corner-segment.a).dot(direction)
					start=minf(start,distance); end=maxf(end,distance)
				start=maxf(0.0,start); end=minf(segment.length,end)
				var phase: float = posmod(hash(segment.id),24)*world.pixels_per_metre
				var position_along: float = ceil((segment.start+start-phase)/spacing)*spacing+phase
				while position_along<=segment.start+end:
					var base: Vector2 = segment.a+direction*(position_along-segment.start)
					for side in [-1,1]:
						var id := "verge:%s:%d:%d" % [segment.id,roundi(position_along/spacing),side]
						if candidates.has(id): continue
						for offset in [3.0,4.5,6.0,8.0,10.0]:
							var point: Vector2 = base+normal*side*(segment.half_width+offset*world.pixels_per_metre)
							var tree := _tree(point,2.8,posmod(hash(id),2),id,"roadside_decoration")
							if not _grassy_verge(tree.bounds) or not clear_artwork(tree.bounds) or _near_mapped(tree.bounds): continue
							if query.has_point(point): candidates[id]=tree
							break
					position_along+=spacing
	var ordered: Array = candidates.values()
	ordered.sort_custom(func(a,b): return a.id<b.id)
	var accepted: Array = []
	var trees: Array = []
	for tree in ordered:
		if accepted.any(func(other): return tree.point.distance_to(other.point)<minimum_gap): continue
		accepted.append(tree)
		if cell_bounds.has_point(tree.point): trees.append(tree)
	return trees

func _grassy_verge(bounds: Rect2) -> bool:
	# Untagged road edges use the game's grass fallback, not an OSM grass assertion.
	for point in _rectangle(bounds):
		if world.land_cover.category_at(point) not in ["","grass"]: return false
	var low := Vector2i((bounds.position/world.land_cover.cell_size).floor())
	var high := Vector2i((bounds.end/world.land_cover.cell_size).floor())
	var visited: Dictionary = {}
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for area in world.land_cover.cells.get(Vector2i(x,y),[]):
				if visited.has(area.id) or area.category in ["grass","building"]: continue
				visited[area.id]=true
				for piece in area.pieces:
					if not Geometry2D.intersect_polygons(_rectangle(bounds),piece).is_empty(): return false
	return true

static func _rectangle(bounds: Rect2) -> PackedVector2Array:
	return PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])

func _draw() -> void:
	for tree in visible_trees:
		var shade := 0.94+posmod(hash(tree.id),12)/100.0
		var variant: int = tree.variant
		if selected_style=="broadleaf": variant=0
		elif selected_style=="eucalypt": variant=1
		elif selected_style=="conifer": variant=2
		var texture: Texture2D = custom_texture if custom_texture!=null else textures[variant]
		var bounds: Rect2 = tree.bounds
		if custom_texture!=null:
			# Keep uploaded artwork proportions; the original clearance envelope remains safe.
			var size := texture.get_size()
			size *= minf(bounds.size.x/size.x,bounds.size.y/size.y)
			bounds=Rect2(Vector2(bounds.get_center().x-size.x*0.5,bounds.end.y-size.y),size)
		draw_texture_rect(texture,bounds,false,Color(shade,shade,shade,1.0))
