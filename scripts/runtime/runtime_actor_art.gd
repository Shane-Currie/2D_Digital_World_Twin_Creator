class_name RuntimeActorArt
extends RefCounted

## Transparent production sprites shared by every imported town. Keep the
## drawing rectangles in the caller so artwork never changes collision size.
const PATHS := {
	"player": "res://assets/actors/player_v2.png",
	"npr": "res://assets/actors/npr_v2.png",
	"npd": "res://assets/actors/npd_v2.png",
	"wagon": "res://assets/actors/wagon_v2.png",
	"npc_light_man_young": "res://assets/actors/npc_light_man_young_v3.png",
	"npc_light_man_adult": "res://assets/actors/npc_light_man_adult_v3.png",
	"npc_light_man_older": "res://assets/actors/npc_light_man_older_v3.png",
	"npc_light_woman_young": "res://assets/actors/npc_light_woman_young_v3.png",
	"npc_light_woman_adult": "res://assets/actors/npc_light_woman_adult_v3.png",
	"npc_light_woman_older": "res://assets/actors/npc_light_woman_older_v3.png",
	"npc_medium_man_young": "res://assets/actors/npc_medium_man_young_v3.png",
	"npc_medium_man_adult": "res://assets/actors/npc_medium_man_adult_v3.png",
	"npc_medium_man_older": "res://assets/actors/npc_medium_man_older_v3.png",
	"npc_medium_woman_young": "res://assets/actors/npc_medium_woman_young_v3.png",
	"npc_medium_woman_adult": "res://assets/actors/npc_medium_woman_adult_v3.png",
	"npc_medium_woman_older": "res://assets/actors/npc_medium_woman_older_v3.png",
	"npc_dark_man_young": "res://assets/actors/npc_dark_man_young_v3.png",
	"npc_dark_man_adult": "res://assets/actors/npc_dark_man_adult_v3.png",
	"npc_dark_man_older": "res://assets/actors/npc_dark_man_older_v3.png",
	"npc_dark_woman_young": "res://assets/actors/npc_dark_woman_young_v3.png",
	"npc_dark_woman_adult": "res://assets/actors/npc_dark_woman_adult_v3.png",
	"npc_dark_woman_older": "res://assets/actors/npc_dark_woman_older_v3.png",
	"car_sedan_blue": "res://assets/actors/car_sedan_blue_v3.png",
	"car_sedan_red": "res://assets/actors/car_sedan_red_v3.png",
	"car_sedan_silver": "res://assets/actors/car_sedan_silver_v3.png",
	"car_sedan_green": "res://assets/actors/car_sedan_green_v3.png",
	"car_wagon_white": "res://assets/actors/car_wagon_white_v3.png",
	"car_wagon_blue": "res://assets/actors/car_wagon_blue_v3.png",
	"car_wagon_bronze": "res://assets/actors/car_wagon_bronze_v3.png",
	"car_wagon_grey": "res://assets/actors/car_wagon_grey_v3.png",
	"car_ute_red": "res://assets/actors/car_ute_red_v3.png",
	"car_ute_blue": "res://assets/actors/car_ute_blue_v3.png",
	"car_ute_white": "res://assets/actors/car_ute_white_v3.png",
	"car_ute_green": "res://assets/actors/car_ute_green_v3.png"
}

static var cached_sprites: Dictionary = {}


static func sprite(kind: String) -> Dictionary:
	if cached_sprites.has(kind):
		return cached_sprites[kind]
	var image := Image.load_from_file(str(PATHS.get(kind, "")))
	if image == null or image.is_empty():
		cached_sprites[kind] = {}
		return {}
	# The delivered PNGs have transparent padding. Crop only the draw region;
	# leave the original source PNG and its alpha untouched.
	var used_region := _subject_region(image, kind)
	if used_region.size.x <= 0 or used_region.size.y <= 0:
		cached_sprites[kind] = {}
		return {}
	var result := {
		"texture": ImageTexture.create_from_image(image),
		"region": Rect2(used_region)
	}
	cached_sprites[kind] = result
	return result


static func _subject_region(image: Image, kind: String) -> Rect2i:
	var alpha_region := image.get_used_rect()
	if not kind.begins_with("car_") and not kind.begins_with("npc_"):
		return alpha_region
	# Generated cut-outs can retain a large, faint transparent glow. Treat the
	# solid painted subject as the crop so every catalogue entry reaches the
	# same gameplay scale. Sampling every fourth source pixel keeps startup fast.
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	var sample_step := 4
	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			if image.get_pixel(x, y).a < 0.6:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return alpha_region
	var padding := 8
	var start := Vector2i(maxi(0, minimum.x - padding), maxi(0, minimum.y - padding))
	var finish := Vector2i(
		mini(image.get_width(), maximum.x + sample_step + padding),
		mini(image.get_height(), maximum.y + sample_step + padding)
	)
	return Rect2i(start, finish - start)
