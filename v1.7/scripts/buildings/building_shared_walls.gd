extends RefCounted

## Split a facade where an actual neighbouring ground boundary touches it.
## A close building with a real gap is NOT a party wall.
static func sections(a: Vector2, b: Vector2, outward: Vector2, neighbours: Array) -> Array:
	var length := a.distance_to(b)
	var direction := a.direction_to(b)
	var contacts: Array = []
	var breaks: Array[float] = [0.0,1.0]
	for neighbour in neighbours:
		if str(neighbour.get("owner", "")).is_empty() or int(neighbour.get("floors",0)) <= 0: continue
		var ring: PackedVector2Array = neighbour.points
		for index in ring.size():
			var first := ring[index]
			var second := ring[(index+1)%ring.size()]
			if first.distance_to(second) < 0.01: continue
			if absf(direction.dot(first.direction_to(second))) < 0.999: continue
			if absf((first-a).cross(direction)) > 0.05 or absf((second-a).cross(direction)) > 0.05: continue
			var first_fraction := (first-a).dot(direction)/length
			var second_fraction := (second-a).dot(direction)/length
			var start := clampf(minf(first_fraction,second_fraction),0.0,1.0)
			var end := clampf(maxf(first_fraction,second_fraction),0.0,1.0)
			if (end-start)*length < 0.1: continue
			if not Geometry2D.is_point_in_polygon(a.lerp(b,(start+end)*0.5)+outward*0.15,ring): continue
			contacts.append({"start":start,"end":end,"floors":int(neighbour.floors)})
			breaks.append(start)
			breaks.append(end)
	breaks.sort()
	var result: Array = []
	for index in range(breaks.size()-1):
		var start := breaks[index]
		var end := breaks[index+1]
		if (end-start)*length < 0.01: continue
		var middle := (start+end)*0.5
		var floors := 0
		for contact in contacts:
			if middle >= contact.start and middle <= contact.end: floors = maxi(floors,int(contact.floors))
		result.append({"start":start,"end":end,"neighbour_floors":floors})
	return result
