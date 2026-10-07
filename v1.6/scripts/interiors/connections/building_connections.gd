extends RefCounted

## Paired indoor doors on actual shared OSM walls. Geometry never moves the
## imported footprints; interiors remain separate spaces with stable IDs.
const Furniture = preload("res://scripts/interiors/interior_furniture_catalog.gd")
const Stairs = preload("res://scripts/interiors/stairs/interior_stairs.gd")
const WALL_EPSILON := 0.001 # Numerical precision only, not a permitted gap.
const DOOR_WIDTH := 1.2
const ARRIVAL_INSET := 1.0
const CLEARANCE := 0.6
const MAX_CONNECTIONS := 200

static func position(endpoint: Dictionary) -> Vector2:
	return Vector2(float(endpoint.get("x_metres", INF)),float(endpoint.get("y_metres", INF)))

static func wall_position(endpoint: Dictionary) -> Vector2:
	return Vector2(float(endpoint.get("wall_x_metres", INF)),float(endpoint.get("wall_y_metres", INF)))

static func normal(endpoint: Dictionary) -> Vector2:
	return Vector2(float(endpoint.get("normal_x", 0)),float(endpoint.get("normal_y", 0)))

static func floor_for(data: Dictionary, building_id: String, floor_id: String) -> Dictionary:
	for floor in data.get("buildings", {}).get(building_id, {}).get("floors", []):
		if floor is Dictionary and str(floor.get("id", "")) == floor_id: return floor
	return {}

static func feature_for(features: Array, id: String) -> Dictionary:
	for feature in features:
		if feature is Dictionary and str(feature.get("kind", "")) == "building" and str(feature.get("id", "")) == id: return feature
	return {}

static func ring(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values: result.append(Vector2(float(value[0]),float(value[1])))
	if result.size()>1 and result[0]==result[-1]: result.remove_at(result.size()-1)
	return result

static func geometry_points(feature: Dictionary) -> Array:
	var precise = feature.get("precise_points", [])
	if not precise is Array: return []
	return precise if not precise.is_empty() else feature.get("points", [])

static func geometry_valid(feature: Dictionary) -> bool:
	var points := geometry_points(feature)
	if points.size() < 3: return false
	for point in points:
		if not point is Vector2 and (not point is Array or point.size() != 2): return false
		if not point[0] is float and not point[0] is int: return false
		if not point[1] is float and not point[1] is int: return false
		if not is_finite(float(point[0])) or not is_finite(float(point[1])) or absf(float(point[0]))>180 or absf(float(point[1]))>=90: return false
	return true


static func with_source_precision(town_directory: String, features: Array) -> Array:
	var result: Array = features.duplicate(true)
	var requested: Dictionary = {}
	for feature in result:
		if not feature.get("precise_points", []) is Array:
			feature["precise_points"] = []
			feature["shared_geometry_unverified"] = true
			continue
		if str(feature.get("kind", "")) != "building" or not feature.get("precise_points", []).is_empty(): continue
		for id in feature.get("node_ids", []): requested[str(id)] = true
	if requested.is_empty(): return result
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(town_directory.path_join("town.json"))) if FileAccess.file_exists(town_directory.path_join("town.json")) else {}
	var nodes: Dictionary = {}
	if metadata is Dictionary:
		for relative in metadata.get("source", {}).get("files", []):
			var path := str(relative).replace("\\", "/")
			if not path.begins_with("source_osm/") or path.contains("..") or not path.ends_with(".osm"): continue
			var parser := XMLParser.new()
			if parser.open(town_directory.path_join(path)) != OK: continue
			while parser.read() == OK:
				if parser.get_node_type() != XMLParser.NODE_ELEMENT or parser.get_node_name() != "node": continue
				var id := parser.get_named_attribute_value_safe("id")
				if not requested.has(id): continue
				var x := parser.get_named_attribute_value_safe("lon")
				var y := parser.get_named_attribute_value_safe("lat")
				if x.is_valid_float() and y.is_valid_float(): nodes[id] = [x.to_float(), y.to_float()]
	for feature in result:
		if bool(feature.get("shared_geometry_unverified", false)): continue
		if str(feature.get("kind", "")) != "building" or not feature.get("precise_points", []).is_empty() or feature.get("node_ids", []).is_empty(): continue
		var precise: Array = []
		for id in feature.node_ids:
			if nodes.has(str(id)): precise.append(nodes[str(id)])
		if precise.size() == feature.get("points", []).size(): feature["precise_points"] = precise
		else: feature["shared_geometry_unverified"] = true
	return result


static func origin(feature: Dictionary) -> Variant:
	# Keep geographic arithmetic in double-precision scalars. Vector2's float
	# storage can erase a real centimetre gap at Australian longitudes.
	return geometry_points(feature)[0]

static func project(point: Variant, reference: Variant) -> Vector2:
	return Vector2((float(point[0])-float(reference[0]))*111320.0*cos(deg_to_rad(float(reference[1]))),-(float(point[1])-float(reference[1]))*110540.0)

static func unproject(point: Vector2, reference: Variant) -> Array:
	return [float(reference[0])+point.x/(111320.0*cos(deg_to_rad(float(reference[1])))),float(reference[1])-point.y/110540.0]

static func local_point(feature: Dictionary, floor: Dictionary, geographic: Variant) -> Vector2:
	if not geometry_valid(feature): return Vector2.INF
	# Existing interiors were generated from float-vector geographic vertices.
	# Map the precise shared-edge fraction into those saved local boundaries,
	# rather than rebuilding or shifting a furnished legacy floor.
	var values := geometry_points(feature)
	var legacy := ring(feature.get("points", []))
	var bounds := Rect2(legacy[0], Vector2.ZERO)
	for point in legacy: bounds = bounds.expand(point)
	var centre := bounds.get_center()
	var minimum := Vector2(INF, INF)
	for point in legacy: minimum = minimum.min(project(point, centre))
	var reference: Variant = origin(feature)
	var requested := project(geographic, reference)
	for i in values.size() - 1 if values[0] == values[-1] else values.size():
		var a := project(values[i], reference)
		var b := project(values[(i + 1) % values.size()], reference)
		var closest := Geometry2D.get_closest_point_to_segment(requested, a, b)
		if closest.distance_to(requested) > 0.04: continue
		var fraction := (closest - a).dot(b - a) / a.distance_squared_to(b)
		var old_a := project(Vector2(float(values[i][0]), float(values[i][1])), centre)
		var old_b := project(Vector2(float(values[(i+1)%values.size()][0]), float(values[(i+1)%values.size()][1])), centre)
		return (old_a.lerp(old_b, fraction) - minimum) * float(floor.get("footprint_scale", 1.0))
	return Vector2.INF

static func shared_segments(first: Dictionary, second: Dictionary) -> Array:
	if first.is_empty() or second.is_empty() or str(first.get("id", ""))==str(second.get("id", "")): return []
	if not geometry_valid(first) or not geometry_valid(second): return []
	if bool(first.get("shared_geometry_unverified", false)) or bool(second.get("shared_geometry_unverified", false)): return []
	var reference: Variant = origin(first)
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for point in geometry_points(first): a.append(project(point,reference))
	for point in geometry_points(second): b.append(project(point,reference))
	if a.size()>1 and a[0]==a[-1]: a.remove_at(a.size()-1)
	if b.size()>1 and b[0]==b[-1]: b.remove_at(b.size()-1)
	if a.size()<3 or b.size()<3: return []
	var box := Rect2(a[0],Vector2.ZERO)
	for point in a: box=box.expand(point)
	var other := Rect2(b[0],Vector2.ZERO)
	for point in b: other=other.expand(point)
	if not box.grow(WALL_EPSILON).intersects(other,true): return []
	var result: Array = []
	for i in a.size():
		var start := a[i]
		var delta := a[(i+1)%a.size()]-start
		var length := delta.length()
		if length<1.8: continue
		var direction := delta/length
		for j in b.size():
			var p := b[j]
			var q := b[(j+1)%b.size()]
			if absf(direction.cross(p-start))>WALL_EPSILON or absf(direction.cross(q-start))>WALL_EPSILON: continue
			var lo := maxf(0,minf(direction.dot(p-start),direction.dot(q-start)))
			var hi := minf(length,maxf(direction.dot(p-start),direction.dot(q-start)))
			if hi-lo<1.8: continue # A corner contact is not a wall.
			var middle := start+direction*((lo+hi)*0.5)
			var side := direction.orthogonal()*0.05
			# Duplicate/overlapping polygons are not adjacent interiors.
			if Geometry2D.is_point_in_polygon(middle+side,a)==Geometry2D.is_point_in_polygon(middle+side,b): continue
			result.append({"start":unproject(start+direction*lo,reference),"finish":unproject(start+direction*hi,reference)})
	return result

static func endpoint_for(feature: Dictionary, floor: Dictionary, anchor: Variant) -> Dictionary:
	if not geometry_valid(feature): return {}
	var requested := local_point(feature,floor,anchor)
	var boundary := ring(floor.get("boundary_metres", []))
	var closest := Vector2.INF
	var inward := Vector2.ZERO
	var distance := 0.04*float(floor.get("footprint_scale",1.0))
	for i in boundary.size():
		var a := boundary[i]
		var b := boundary[(i+1)%boundary.size()]
		var candidate := Geometry2D.get_closest_point_to_segment(requested,a,b)
		if candidate.distance_to(requested)>distance: continue
		var direction := (b-a).normalized().orthogonal()
		if not Geometry2D.is_point_in_polygon(candidate+direction*0.1,boundary): direction=-direction
		closest=candidate
		inward=direction
		distance=candidate.distance_to(requested)
	if closest==Vector2.INF: return {}
	var arrival := closest+inward*ARRIVAL_INSET
	return {"building_id":str(feature.id),"floor_id":str(floor.id),"wall_x_metres":closest.x,"wall_y_metres":closest.y,"x_metres":arrival.x,"y_metres":arrival.y,"normal_x":inward.x,"normal_y":inward.y}

static func endpoints(data: Dictionary, building_id: String, floor_id: String) -> Array:
	var result: Array = []
	for pair in data.get("building_connections", []):
		if not pair is Dictionary or not pair.get("from") is Dictionary or not pair.get("to") is Dictionary: continue
		for side in ["from","to"]:
			var endpoint: Dictionary = pair[side]
			if str(endpoint.get("building_id",""))!=building_id or str(endpoint.get("floor_id",""))!=floor_id: continue
			var value: Dictionary = endpoint.duplicate(true)
			value["id"]=str(pair.get("id",""))
			value["side"]=side
			value["locked"]=bool(pair.get("locked",false))
			value["destination"]=pair["to" if side=="from" else "from"].duplicate(true)
			value["destination_name"]=str(data.get("buildings",{}).get(str(value.destination.get("building_id","")),{}).get("name","Building"))
			result.append(value)
	return result

static func arrival_fits(data: Dictionary, endpoint: Dictionary, ignored_id := "", npcs: Array = []) -> bool:
	var floor := floor_for(data,str(endpoint.get("building_id","")),str(endpoint.get("floor_id","")))
	var point := position(endpoint)
	var outer := ring(floor.get("boundary_metres",[]))
	if outer.size()<3 or not point.is_finite() or not Geometry2D.is_point_in_polygon(point,outer): return false
	for i in outer.size():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,outer[i],outer[(i+1)%outer.size()]))<CLEARANCE: return false
	for hole in floor.get("holes_metres",[]):
		var polygon := ring(hole)
		if Geometry2D.is_point_in_polygon(point,polygon): return false
		for i in polygon.size():
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]))<CLEARANCE: return false
	for wall in floor.get("walls",[]):
		var a := Vector2(float(wall.start_x_metres),float(wall.start_y_metres))
		var b := Vector2(float(wall.end_x_metres),float(wall.end_y_metres))
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))<CLEARANCE+float(wall.thickness_metres)*0.5: return false
	for item in floor.get("furniture",[]):
		if Furniture.blocks_point(item,point,CLEARANCE,false): return false
	for entry in floor.get("entry_links",[]):
		if point.distance_to(Vector2(float(entry.spawn_x_metres),float(entry.spawn_y_metres)))<1.4: return false
	var record: Dictionary = data.get("buildings",{}).get(str(endpoint.building_id),{})
	for stair in Stairs.endpoints(record,str(endpoint.floor_id)):
		if Stairs.overlaps(Stairs.rectangle(point,Vector2.ONE*1.2),Stairs.clear_polygon(stair)): return false
	for other in endpoints(data,str(endpoint.building_id),str(endpoint.floor_id)):
		if str(other.id)!=ignored_id and point.distance_to(position(other))<1.4: return false
	for npc in npcs:
		var location: Dictionary = npc.get("location",{})
		if str(location.get("space",""))=="interior" and str(location.get("building_id",""))==str(endpoint.building_id) and str(location.get("floor_id",""))==str(endpoint.floor_id):
			if point.distance_to(Vector2(float(location.get("x_metres",INF)),float(location.get("y_metres",INF))))<1.2: return false
	return true

static func propose(data: Dictionary, features: Array, a_id: String, a_floor: String, b_id: String, b_floor: String, requested: Vector2, ignored_id := "", npcs: Array = [], snap_distance := 1.0) -> Dictionary:
	var a := feature_for(features,a_id)
	var b := feature_for(features,b_id)
	var af := floor_for(data,a_id,a_floor)
	var bf := floor_for(data,b_id,b_floor)
	if af.is_empty() or bf.is_empty(): return {"ok":false,"message":"Create both interiors before connecting them."}
	if int(af.get("level",-1))!=int(bf.get("level",-2)): return {"ok":false,"message":"Connect floors at the same level."}
	var anchor: Array = []
	var best := snap_distance
	for segment in shared_segments(a,b):
		var start := local_point(a,af,segment.start)
		var finish := local_point(a,af,segment.finish)
		var length := start.distance_to(finish)
		var physical_length := project(segment.finish,segment.start).length()
		var fraction := clampf((requested-start).dot(finish-start)/(length*length),0.85/physical_length,1.0-0.85/physical_length)
		var point := start.lerp(finish,fraction)
		if point.distance_to(requested)>best: continue
		best=point.distance_to(requested)
		anchor=[lerpf(float(segment.start[0]),float(segment.finish[0]),fraction),lerpf(float(segment.start[1]),float(segment.finish[1]),fraction)]
	if anchor.is_empty(): return {"ok":false,"message":"Click the actual shared wall. Gaps and corner-only contacts cannot be connected."}
	var from := endpoint_for(a,af,anchor)
	var to := endpoint_for(b,bf,anchor)
	if from.is_empty() or to.is_empty() or normal(from).dot(normal(to))>-.99: return {"ok":false,"message":"The floor boundaries do not align with opposite sides of this shared wall."}
	if not arrival_fits(data,from,ignored_id,npcs) or not arrival_fits(data,to,ignored_id,npcs): return {"ok":false,"message":"Keep both sides of the connecting door clear of walls, items, stairs, entrances and NPCs."}
	return {"ok":true,"pair":{"from":from,"to":to,"wall_longitude":anchor[0],"wall_latitude":anchor[1],"locked":false}}

static func set_door(data: Dictionary, features: Array, a_id: String, a_floor: String, b_id: String, b_floor: String, requested: Vector2, id := "", npcs: Array = [], snap_distance := 1.0) -> Dictionary:
	var proposal := propose(data,features,a_id,a_floor,b_id,b_floor,requested,id,npcs,snap_distance)
	if not proposal.ok: return proposal
	var updated := data.duplicate(true)
	var pairs: Array = updated.get("building_connections",[])
	if id.is_empty():
		if pairs.size()>=MAX_CONNECTIONS: return {"ok":false,"message":"This town already has 200 connecting doors."}
		var used := {}
		for pair in pairs: used[str(pair.id)]=true
		var number := 1
		while used.has("connection_%d" % number): number+=1
		id="connection_%d" % number
		proposal.pair["id"]=id
		pairs.append(proposal.pair)
	else:
		var found := false
		for i in pairs.size():
			if str(pairs[i].id)!=id: continue
			proposal.pair["id"]=id
			proposal.pair["locked"]=pairs[i].get("locked",false)
			pairs[i]=proposal.pair
			found=true
		if not found: return {"ok":false,"message":"The connecting door no longer exists."}
	updated["building_connections"]=pairs
	return {"ok":true,"data":updated,"id":id,"message":"Interiors connected. Both sides moved together; Save before Play test."}

static func validate(data: Dictionary, features: Array = [], npcs: Array = []) -> Dictionary:
	var pairs = data.get("building_connections",[])
	if not pairs is Array or pairs.size()>MAX_CONNECTIONS: return {"ok":false,"message":"Invalid building connections list."}
	# Validate every pair before clearance checks inspect other endpoints.
	for pair in pairs:
		if not pair is Dictionary or not pair.get("from") is Dictionary or not pair.get("to") is Dictionary: return {"ok":false,"message":"Invalid connecting door pair."}
		for endpoint in [pair.from, pair.to]:
			for field in ["building_id", "floor_id"]:
				if not endpoint.get(field) is String: return {"ok":false,"message":"Invalid connecting door identity."}
			for field in ["x_metres","y_metres","wall_x_metres","wall_y_metres","normal_x","normal_y"]:
				var value = endpoint.get(field)
				if (not value is int and not value is float) or not is_finite(float(value)): return {"ok":false,"message":"Invalid connecting door endpoint."}
	var ids := {}
	for pair in pairs:
		if not pair is Dictionary or not pair.get("id",null) is String or str(pair.id).is_empty() or ids.has(pair.id) or not pair.get("from",null) is Dictionary or not pair.get("to",null) is Dictionary or not pair.get("locked",false) is bool: return {"ok":false,"message":"Invalid or duplicate connecting door."}
		ids[pair.id]=true
		for field in ["wall_longitude","wall_latitude"]:
			if not pair.get(field,null) is float and not pair.get(field,null) is int: return {"ok":false,"message":"Connecting door needs a geographic wall anchor."}
		var anchor: Array = [float(pair.wall_longitude),float(pair.wall_latitude)]
		if not is_finite(anchor[0]) or not is_finite(anchor[1]) or absf(anchor[0])>180 or absf(anchor[1])>90: return {"ok":false,"message":"Invalid connecting door wall coordinates."}
		for endpoint in [pair.from,pair.to]:
			for field in ["building_id","floor_id"]:
				if not endpoint.get(field,null) is String: return {"ok":false,"message":"Connecting door needs stable building/floor IDs."}
			for field in ["x_metres","y_metres","wall_x_metres","wall_y_metres","normal_x","normal_y"]:
				var value = endpoint.get(field,null)
				if (not value is int and not value is float) or not is_finite(float(value)): return {"ok":false,"message":"Invalid connecting door endpoint."}
			var floor := floor_for(data,str(endpoint.building_id),str(endpoint.floor_id))
			if floor.is_empty() or absf(normal(endpoint).length()-1)>0.001 or position(endpoint).distance_to(wall_position(endpoint)+normal(endpoint)*ARRIVAL_INSET)>0.02: return {"ok":false,"message":"Connecting door has an invalid floor or arrival."}
			var boundary := ring(floor.get("boundary_metres",[]))
			var wall_distance := INF
			for i in boundary.size(): wall_distance=minf(wall_distance,wall_position(endpoint).distance_to(Geometry2D.get_closest_point_to_segment(wall_position(endpoint),boundary[i],boundary[(i+1)%boundary.size()])))
			if wall_distance>0.02 or not arrival_fits(data,endpoint,str(pair.id),npcs): return {"ok":false,"message":"Connecting door or its arrival is blocked or off its exterior wall."}
			if not features.is_empty():
				var feature := feature_for(features,str(endpoint.building_id))
				if feature.is_empty(): return {"ok":false,"message":"Connecting door references a removed or hidden building."}
				var expected := endpoint_for(feature,floor,anchor)
				if expected.is_empty() or wall_position(expected).distance_to(wall_position(endpoint))>0.04 or position(expected).distance_to(position(endpoint))>0.04: return {"ok":false,"message":"Connecting door no longer matches the mapped shared wall."}
		if str(pair.from.building_id)==str(pair.to.building_id) or int(floor_for(data,str(pair.from.building_id),str(pair.from.floor_id)).level)!=int(floor_for(data,str(pair.to.building_id),str(pair.to.floor_id)).level) or normal(pair.from).dot(normal(pair.to))>-.99: return {"ok":false,"message":"Connecting doors require distinct buildings and matching floors on opposite sides of a wall."}
		if not features.is_empty():
			var valid_wall := false
			var first := feature_for(features,str(pair.from.building_id))
			for segment in shared_segments(first,feature_for(features,str(pair.to.building_id))):
				var a := project(segment.start,anchor)
				var b := project(segment.finish,anchor)
				if Vector2.ZERO.distance_to(Geometry2D.get_closest_point_to_segment(Vector2.ZERO,a,b))<WALL_EPSILON and minf(a.length(),b.length())>=0.8: valid_wall=true
			if not valid_wall: return {"ok":false,"message":"Buildings must share a wall with no gap; corner contact is insufficient."}
	return {"ok":true}

static func draw_door(canvas: CanvasItem, endpoint: Dictionary, wall: Vector2, arrival: Vector2, scale: float, selected := false) -> void:
	var inward := normal(endpoint)
	var tangent := inward.orthogonal()
	var colour := Color("#e45b55") if bool(endpoint.get("locked",false)) else Color("#55d681")
	var half := DOOR_WIDTH*scale*0.5
	canvas.draw_line(wall-tangent*half,wall+tangent*half,Color("#15251f"),maxf(7,scale*0.22),true)
	canvas.draw_line(wall-tangent*half,wall+tangent*half,colour,maxf(3,scale*0.08),true)
	canvas.draw_line(wall,arrival,colour,1.5,true)
	canvas.draw_circle(arrival,maxf(3,scale*0.2),colour)
	if selected: canvas.draw_circle(arrival,maxf(8,scale*0.55),colour,false,2,true)
