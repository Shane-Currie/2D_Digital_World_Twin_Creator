class_name InteriorFurnitureCatalog
extends RefCounted

## Small built-in furniture library for the first v1.5 Interior Designer stage.
## Definitions use real metres so Creator preview, saved data and gameplay agree.

const DEFINITIONS := [
	{"id": "dining_table", "name": "Dining table", "object_type": "dining table", "category": "Dining", "size_metres": [1.8, 0.9], "fill": "#9a673d", "outline": "#4f3423", "collision": true, "catalog_source": "built_in"},
	{"id": "dining_chair", "name": "Dining chair", "object_type": "dining chair", "category": "Dining", "size_metres": [0.5, 0.5], "fill": "#c58a55", "outline": "#5f4028", "collision": true, "catalog_source": "built_in"},
	{"id": "sofa", "name": "Sofa", "object_type": "sofa", "category": "Living", "size_metres": [2.0, 0.85], "fill": "#557d8d", "outline": "#294852", "collision": true, "catalog_source": "built_in"},
	{"id": "single_bed", "name": "Single bed", "object_type": "bed", "category": "Bedroom", "size_metres": [1.0, 2.0], "fill": "#8f87ac", "outline": "#4d4863", "collision": true, "catalog_source": "built_in"},
	{"id": "wardrobe", "name": "Wardrobe", "object_type": "wardrobe", "category": "Bedroom", "size_metres": [1.2, 0.6], "fill": "#77533a", "outline": "#3d2a20", "collision": true, "catalog_source": "built_in"},
	{"id": "kitchen_counter", "name": "Kitchen counter", "object_type": "kitchen counter", "category": "Kitchen", "size_metres": [1.5, 0.65], "fill": "#a8a49a", "outline": "#55534e", "collision": true, "catalog_source": "built_in"},
	{"id": "bathroom_sink", "name": "Bathroom sink", "object_type": "sink", "category": "Bathroom", "size_metres": [0.65, 0.55], "fill": "#d7e2df", "outline": "#72827e", "collision": true, "catalog_source": "built_in"},
	{"id": "toilet", "name": "Toilet", "object_type": "toilet", "category": "Bathroom", "size_metres": [0.7, 0.9], "fill": "#e0e5dc", "outline": "#778078", "collision": true, "catalog_source": "built_in"},
	{"id": "office_desk", "name": "Office desk", "object_type": "desk", "category": "Office", "size_metres": [1.4, 0.7], "fill": "#806143", "outline": "#433225", "collision": true, "catalog_source": "built_in"},
	{"id": "shop_shelf", "name": "Shop shelf", "object_type": "shelf", "category": "Shop", "size_metres": [1.5, 0.5], "fill": "#72846b", "outline": "#394637", "collision": true, "catalog_source": "built_in"},
	{"id": "bar_counter", "name": "Bar counter", "object_type": "bar counter", "category": "Hospitality", "size_metres": [2.0, 0.7], "fill": "#70452f", "outline": "#38231a", "collision": true, "catalog_source": "built_in"},
	{"id": "bar_stool", "name": "Bar stool", "object_type": "bar stool", "category": "Hospitality", "size_metres": [0.45, 0.45], "fill": "#b27646", "outline": "#593921", "collision": true, "catalog_source": "built_in"}
]

# A furniture item may suit more than one kind of building. Keeping these as
# broad creator-facing uses means a dining chair can appear under Residential,
# Restaurant and Pub without duplicating its artwork or collision definition.
const USAGE_CATEGORIES := [
	"All items", "Residential", "Generic business", "Office", "Shop",
	"Restaurant", "Pub", "My creations"
]
const USAGE_BY_ID := {
	"dining_table": ["Residential", "Generic business", "Restaurant", "Pub"],
	"dining_chair": ["Residential", "Generic business", "Restaurant", "Pub"],
	"sofa": ["Residential", "Generic business", "Office", "Pub"],
	"single_bed": ["Residential"],
	"wardrobe": ["Residential"],
	"kitchen_counter": ["Residential", "Restaurant", "Pub"],
	"bathroom_sink": ["Residential", "Generic business", "Office", "Shop", "Restaurant", "Pub"],
	"toilet": ["Residential", "Generic business", "Office", "Shop", "Restaurant", "Pub"],
	"office_desk": ["Generic business", "Office"],
	"shop_shelf": ["Generic business", "Shop"],
	"bar_counter": ["Restaurant", "Pub"],
	"bar_stool": ["Restaurant", "Pub"]
}


static func all() -> Array:
	return DEFINITIONS.duplicate(true)


static func definition(item_id: String) -> Dictionary:
	for value in DEFINITIONS:
		if str(value.get("id", "")) == item_id:
			return value.duplicate(true)
	return {}


static func usage_categories(value: Dictionary) -> Array:
	var saved_categories = value.get("usage_categories", [])
	if saved_categories is Array and not saved_categories.is_empty():
		return saved_categories.duplicate()
	if str(value.get("catalog_source", "")) == "creator_imported":
		return ["My creations"]
	return USAGE_BY_ID.get(str(value.get("id", "")), ["Generic business"]).duplicate()


static func thumbnail_texture(value: Dictionary, image_size := Vector2i(64, 40)) -> Texture2D:
	# OptionButton supports icons but not custom scene controls. These compact
	# thumbnails use the same catalogue colours and identifying details as the
	# floor renderer, making the drop-down useful to non-technical creators.
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var fill := Color(str(value.get("fill", "#8a735d")))
	var outline := Color(str(value.get("outline", "#41362d")))
	var body := Rect2i(9, 8, image_size.x - 18, image_size.y - 16)
	_fill_rect(image, body, outline)
	_fill_rect(image, body.grow(-2), fill)
	var light := outline.lightened(0.58)
	var dark := outline.darkened(0.18)
	match str(value.get("id", "")):
		"dining_table":
			_stroke_rect(image, Rect2i(16, 13, 32, 14), light, 1)
			for point in [Vector2i(17, 14), Vector2i(46, 14), Vector2i(17, 25), Vector2i(46, 25)]: _fill_circle(image, point, 2, dark)
		"dining_chair":
			_stroke_rect(image, Rect2i(20, 14, 24, 15), light, 1)
			_fill_rect(image, Rect2i(18, 10, 28, 4), dark)
		"sofa":
			_stroke_rect(image, Rect2i(16, 15, 32, 14), light, 1)
			_fill_rect(image, Rect2i(13, 10, 38, 5), dark)
			_fill_rect(image, Rect2i(12, 15, 5, 15), dark)
			_fill_rect(image, Rect2i(47, 15, 5, 15), dark)
			_fill_rect(image, Rect2i(31, 15, 2, 14), outline)
		"single_bed":
			_fill_rect(image, Rect2i(15, 11, 34, 8), Color("#e7ded0"))
			_stroke_rect(image, Rect2i(15, 20, 34, 10), light, 1)
		"wardrobe":
			_fill_rect(image, Rect2i(31, 10, 2, 20), light)
			_fill_circle(image, Vector2i(28, 20), 1, light)
			_fill_circle(image, Vector2i(36, 20), 1, light)
		"kitchen_counter":
			_fill_rect(image, Rect2i(11, 10, 42, 4), light)
			_fill_circle(image, Vector2i(24, 21), 5, Color("#b9d0d2"))
			_stroke_circle(image, Vector2i(41, 21), 4, dark)
		"bathroom_sink":
			_fill_circle(image, Vector2i(32, 21), 10, Color("#f2f5f2"))
			_stroke_circle(image, Vector2i(32, 21), 6, Color("#9eb8ba"))
			_fill_rect(image, Rect2i(31, 10, 2, 7), dark)
		"toilet":
			_fill_rect(image, Rect2i(23, 10, 18, 8), Color("#f5f6f1"))
			_fill_circle(image, Vector2i(32, 25), 9, Color("#f5f6f1"))
			_stroke_circle(image, Vector2i(32, 25), 5, Color("#9fb7b8"))
		"office_desk":
			_fill_rect(image, Rect2i(24, 11, 16, 10), Color("#314f5e"))
			_fill_rect(image, Rect2i(31, 21, 2, 7), light)
		"shop_shelf":
			for y in [13, 20, 27]: _fill_rect(image, Rect2i(13, y, 38, 2), light)
		"bar_counter":
			_fill_rect(image, Rect2i(11, 10, 42, 5), light)
			for x in [22, 32, 42]: _fill_rect(image, Rect2i(x, 15, 2, 14), dark)
		"bar_stool":
			_fill_circle(image, Vector2i(32, 20), 10, light)
			_stroke_circle(image, Vector2i(32, 20), 6, dark)
	return ImageTexture.create_from_image(image)


static func _fill_rect(image: Image, rect: Rect2i, colour: Color) -> void:
	image.fill_rect(rect.intersection(Rect2i(Vector2i.ZERO, image.get_size())), colour)


static func _stroke_rect(image: Image, rect: Rect2i, colour: Color, thickness: int) -> void:
	_fill_rect(image, Rect2i(rect.position, Vector2i(rect.size.x, thickness)), colour)
	_fill_rect(image, Rect2i(rect.position + Vector2i(0, rect.size.y - thickness), Vector2i(rect.size.x, thickness)), colour)
	_fill_rect(image, Rect2i(rect.position, Vector2i(thickness, rect.size.y)), colour)
	_fill_rect(image, Rect2i(rect.position + Vector2i(rect.size.x - thickness, 0), Vector2i(thickness, rect.size.y)), colour)


static func _fill_circle(image: Image, centre: Vector2i, radius: int, colour: Color) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				var point := centre + Vector2i(x, y)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height(): image.set_pixelv(point, colour)


static func _stroke_circle(image: Image, centre: Vector2i, radius: int, colour: Color) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var distance_squared := x * x + y * y
			if distance_squared <= radius * radius and distance_squared >= (radius - 1) * (radius - 1):
				var point := centre + Vector2i(x, y)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height(): image.set_pixelv(point, colour)
