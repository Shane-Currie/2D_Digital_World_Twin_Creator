extends SceneTree

const Importer = preload("res://scripts/towns/osm_importer.gd")
const NavigationBuilder = preload("res://scripts/navigation/osm_navigation_builder.gd")

const MAPS := [
	{"name": "Howlong", "source": "res://../OSM/howlong.osm"},
	{"name": "Kingston ACT", "source": "res://../OSM/Canberra/kingston.osm"},
	{"name": "Gold Coast", "source": "res://../OSM/gold.osm"}
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for entry in MAPS:
		var imported: Dictionary = Importer.new().parse_files([str(entry.source)])
		assert(imported.ok, "An ordinary uploaded OSM map failed to import.")
		var graph: Dictionary = NavigationBuilder.new()._build_graph(imported.features, "pedestrian")
		var mapped_edges := int(graph.get("mapped_crossing_edge_count", 0))
		assert(mapped_edges > 0, "%s did not produce its mapped crossing links." % str(entry.name))
		assert(graph.edges.filter(func(edge: Dictionary) -> bool: return bool(edge.get("crossing", false))).size() == mapped_edges)
		print("MAPPED WALKER CROSSINGS: %s has %d directed OSM-tagged crossing edges" % [str(entry.name), mapped_edges])
	print("MAPPED WALKER CROSSING MAPS PASSED: inland town, ACT suburb and coastal city, without LLM or town-specific code")
	quit(0)
