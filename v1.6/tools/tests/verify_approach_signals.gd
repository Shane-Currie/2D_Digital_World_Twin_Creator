extends SceneTree
const Zones = preload("res://scripts/runtime/traffic/runtime_signal_junctions.gd")
const Flow = preload("res://scripts/runtime/traffic/runtime_traffic_flow.gd")

func _initialize() -> void:
	var graph := {"nodes":{0:Vector2.ZERO},"adjacency":{},"edge_by_pair":{},"degree":{},"control_by_node":{0:"traffic_signals"}}
	for arm in 4:
		var direction := Vector2.RIGHT.rotated(arm*PI/2.0)
		var base := arm*3+1
		graph.nodes[base] = direction*100
		graph.nodes[base+1] = direction*120
		graph.nodes[base+2] = direction*1000
		graph.control_by_node[base] = "traffic_signals"
		graph.control_by_node[base+1] = "traffic_signals"
		_link(graph,0,base)
		_link(graph,base,base+1)
		_link(graph,base+1,base+2)
	_finish(graph)
	assert(graph.signal_posts.size() == 4, "A four-way junction must have four incoming lights, despite nine OSM signal vertices.")
	assert(graph.signal_approaches.size() == 4)
	var flow = Flow.new()
	var rng := RandomNumberGenerator.new()
	for key in graph.signal_approaches:
		var approach: Dictionary = graph.signal_approaches[key]
		var ids := str(key).split(">")
		var from := int(ids[0])
		var to := int(ids[1])
		for time in [0.0,19.0,23.0,25.0,43.0,47.0]:
			var car := {"kind":"traffic","traffic_id":from,"node":from,"target_node":to,"position":approach.stop_position,"target":graph.nodes[to]}
			Zones.plan(car,graph,rng)
			var allowed := Zones.permitted(car,[car],approach.stop_position+approach.direction,graph,flow,time)
			assert(allowed == (flow.signal_state(approach.post.direction,time) == "green"), "Displayed light and entry decision disagree.")
	# A split/divided intersection has several branching cores, each with
	# signal points. Shared interior nodes must not be assigned separate zones.
	var divided := {"nodes":{0:Vector2(-120,-120),1:Vector2(120,-120),2:Vector2(120,120),3:Vector2(-120,120)},"adjacency":{},"edge_by_pair":{},"degree":{},"control_by_node":{}}
	for corner in 4:
		_link(divided,corner,(corner+1)%4)
		var outside := Vector2(divided.nodes[corner])*5.0
		var signal_node := int(corner+4)
		var far := int(corner+8)
		divided.nodes[signal_node] = Vector2(divided.nodes[corner]).move_toward(outside,80)
		divided.nodes[far] = outside*2.0
		divided.control_by_node[signal_node] = "traffic_signals"
		_link(divided,corner,signal_node)
		_link(divided,signal_node,far)
	_finish(divided)
	for corner in 4:
		assert(divided.junction_zone_by_node[corner] == divided.junction_zone_by_node[0], "Divided-road core split into independent signal zones.")
	assert(divided.signal_posts.size() == 4, "Internal divided-road connectors gained traffic lights.")
	# Internal movement with no external entry permission must still not be
	# stopped by a second red. Reservations/conflicts remain checked.
	var internal := {"kind":"traffic","traffic_id":30,"node":0,"target_node":1,"position":divided.nodes[0],"target":divided.nodes[1]}
	Zones.plan(internal,divided,rng)
	assert(Zones.permitted(internal,[internal],divided.nodes[1],divided,flow,23), "An internal connector acquired an exit-side red light.")
	print("APPROACH SIGNALS PASSED: four posts from nine tags, matching display/entry phases, divided junction merge and no internal red control.")
	quit()

func _link(graph:Dictionary,a:int,b:int) -> void:
	graph.adjacency.get_or_add(a,[]).append(b)
	graph.adjacency.get_or_add(b,[]).append(a)
	graph.edge_by_pair["%d>%d"%[a,b]] = {}
	graph.edge_by_pair["%d>%d"%[b,a]] = {}

func _finish(graph:Dictionary) -> void:
	for node in graph.nodes:
		graph.degree[node] = graph.adjacency.get(node,[]).size()
	Zones.prepare(graph,8.0)
