extends Node2D

## Solid ground trunks, streamed around actors rather than the movable map camera.
const PHYSICS_LAYER := 64
var trees
var active_cells: Dictionary = {}
var bodies: Dictionary = {}
var enabled := true

func setup(tree_layer) -> void:
	trees=tree_layer

func update_focus(positions: Array, outdoors: bool = true) -> void:
	if outdoors!=enabled:
		enabled=outdoors
		for body in bodies.values(): body.collision_layer=PHYSICS_LAYER if enabled else 0
	if not enabled: return
	var required: Dictionary = {}
	for point in positions:
		var centre := Vector2i((Vector2(point)/trees.CELL_SIZE).floor())
		# One-cell buffer keeps swept vehicle collisions ahead of movement.
		for y in range(centre.y-1,centre.y+2):
			for x in range(centre.x-1,centre.x+2): required[Vector2i(x,y)]=true
	if required==active_cells: return
	var wanted: Dictionary = {}
	for cell in required:
		for tree in trees.trees_in_cell(cell):
			wanted[tree.id]=true
			if bodies.has(tree.id): continue
			var body := StaticBody2D.new()
			body.position=tree.point
			body.collision_layer=PHYSICS_LAYER
			body.collision_mask=0
			var hit := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius=tree.radius
			hit.shape=circle
			body.add_child(hit)
			add_child(body)
			bodies[tree.id]=body
	for id in bodies.keys():
		if wanted.has(id): continue
		bodies[id].collision_layer=0
		bodies[id].queue_free()
		bodies.erase(id)
	active_cells=required
