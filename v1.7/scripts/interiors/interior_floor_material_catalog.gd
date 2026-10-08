class_name InteriorFloorMaterialCatalog
extends RefCounted

## Built-in paintable floor surfaces. Images tile in world metre space so
## separately painted cells join into one continuous floor rather than stamps.

const DEFINITIONS := [
	{"id": "default_floor", "name": "Plain floor / eraser", "category": "Basic", "fill": "#d8d1bf", "image_path": "", "catalog_source": "built_in"},
	{"id": "floor_light_oak", "name": "Light oak floorboards", "category": "Floorboards", "fill": "#bd7b3f", "image_path": "res://assets/interiors/flooring/floorboards_light_oak.png", "catalog_source": "built_in"},
	{"id": "floor_dark_walnut", "name": "Dark walnut floorboards", "category": "Floorboards", "fill": "#56301f", "image_path": "res://assets/interiors/flooring/floorboards_dark_walnut.png", "catalog_source": "built_in"},
	{"id": "floor_weathered_grey", "name": "Weathered grey floorboards", "category": "Floorboards", "fill": "#756f66", "image_path": "res://assets/interiors/flooring/floorboards_weathered_grey.png", "catalog_source": "built_in"},
	{"id": "floor_bathroom_ceramic", "name": "Bathroom tiles · white ceramic", "category": "Bathroom tiles", "fill": "#e3e9e7", "image_path": "res://assets/interiors/bathroom/tiles_ceramic.svg", "catalog_source": "built_in"},
	{"id": "floor_bathroom_slate", "name": "Bathroom tiles · grey slate", "category": "Bathroom tiles", "fill": "#76838c", "image_path": "res://assets/interiors/bathroom/tiles_slate.svg", "catalog_source": "built_in"},
	{"id": "floor_bathroom_checker", "name": "Bathroom tiles · cream and teal", "category": "Bathroom tiles", "fill": "#829d95", "image_path": "res://assets/interiors/bathroom/tiles_checker.svg", "catalog_source": "built_in"}
]


static func all() -> Array:
	return DEFINITIONS.duplicate(true)


static func definition(material_id: String) -> Dictionary:
	for value in DEFINITIONS:
		if str(value.get("id", "")) == material_id:
			return value.duplicate(true)
	return {}


static func thumbnail_texture(value: Dictionary, image_size := Vector2i(64, 40)) -> Texture2D:
	var path_value := str(value.get("image_path", ""))
	if path_value.begins_with("res://"):
		if ResourceLoader.exists(path_value):
			var texture = load(path_value)
			if texture is Texture2D: return texture
		# The fallback keeps first-run headless validation useful before Godot's
		# editor importer has written metadata. Exported builds use the resource.
		var imported_image := Image.new()
		if imported_image.load(ProjectSettings.globalize_path(path_value)) == OK and not imported_image.is_empty():
			imported_image.resize(image_size.x, image_size.y, Image.INTERPOLATE_LANCZOS)
			return ImageTexture.create_from_image(imported_image)
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(str(value.get("fill", "#d8d1bf"))))
	return ImageTexture.create_from_image(image)
